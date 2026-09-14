package main

import (
	"os/exec"
	"strings"
	"testing"
	"time"
)

func TestControlIntegrity(t *testing.T) {
	for _, text := range []string{"Package: a\nPackage: b\n", " continuation\n", "bad line\n"} {
		if err := paragraphs(strings.NewReader(text), func(fields) error { return nil }); err == nil {
			t.Fatalf("accepted %q", text)
		}
	}
	var got []fields
	err := paragraphs(strings.NewReader("Package: linux-generic\nDepends: linux-image-generic (= 1),\n linux-headers-generic (= 1)\n\nPackage: other\n"), func(f fields) error { got = append(got, f); return nil })
	if err != nil || len(got) != 2 {
		t.Fatal(got, err)
	}
	deps, err := kernelDeps(got[0])
	if err != nil || len(deps) != 2 || deps["linux-headers-generic"] != "1" {
		t.Fatal(deps, err)
	}
	_, err = kernelDeps(fields{"Depends": "linux-image-a | linux-image-b"})
	if err == nil {
		t.Fatal("accepted ambiguous alternatives")
	}
}

func fixture() []record {
	specs := [][2]string{
		{"linux-generic", "linux-image-generic (= 7.0.0-31.31), linux-headers-generic (= 7.0.0-31.31)"},
		{"linux-image-generic", "linux-image-7.0.0-31-generic"},
		{"linux-headers-generic", "linux-headers-7.0.0-31-generic"},
		{"linux-image-7.0.0-31-generic", "kmod, linux-base (>= 4.5), linux-modules-7.0.0-31-generic"},
		{"linux-modules-7.0.0-31-generic", ""},
		{"linux-headers-7.0.0-31-generic", "linux-headers-7.0.0-31, libc6 (>= 2.38)"},
		{"linux-headers-7.0.0-31", "coreutils"},
	}
	var result []record
	for _, s := range specs {
		result = append(result, record{fields{"Package": s[0], "Version": "7.0.0-31.31", "Depends": s[1], "SHA256": "same"}, "resolute-updates"})
	}
	return result
}
func TestMatchedClosure(t *testing.T) {
	got, release, err := closure(fixture(), "linux-generic")
	if err != nil || release != "7.0.0-31-generic" || len(got) != 7 {
		t.Fatal(got, release, err)
	}
	cases := []string{"missing modules", "different headers", "conflicting pockets"}
	for _, name := range cases {
		t.Run(name, func(t *testing.T) {
			rows := fixture()
			switch name {
			case "missing modules":
				rows = append(rows[:4], rows[5:]...)
			case "different headers":
				rows[6].Fields["Version"] = "7.0.0-31.32"
			case "conflicting pockets":
				rows = append(rows, record{fields{"Package": "linux-generic", "Version": "7.0.0-31.31", "SHA256": "different"}, "resolute-security"})
			}
			if _, _, err := closure(rows, "linux-generic"); err == nil {
				t.Fatal("accepted incomplete/conflicting candidate")
			}
		})
	}
}
func TestArchivePaths(t *testing.T) {
	for _, rel := range []string{"/pool/a", "../pool/a", "pool/../a", "pool/a?x=1", "pool/a#x", "pool\\a"} {
		if _, err := archiveURL("https://archive.ubuntu.com/ubuntu", rel); err == nil {
			t.Fatal(rel)
		}
	}
	if _, err := archiveURL("http://archive.ubuntu.com/ubuntu", "pool/a"); err == nil {
		t.Fatal("plain HTTP allowed")
	}
}
func TestDebianOrdering(t *testing.T) {
	if _, err := exec.LookPath("dpkg"); err != nil {
		t.Skip("dpkg comparison tested in candidate builder")
	}
	for _, pair := range [][2]string{{"7.0.0-32.32", "7.0.0-31.31"}, {"7.0.0-31.31", "7.0.0-31.31~test"}, {"1:7.0.0-1.1", "7.9.0-99.99"}} {
		ok, err := newer(pair[0], pair[1])
		if err != nil || !ok {
			t.Fatal(pair, ok, err)
		}
	}
}

func TestSignedModuleAlternative(t *testing.T) {
	deps, err := kernelDeps(fields{"Depends": "linux-image-7.0.0-31-generic | linux-image-unsigned-7.0.0-31-generic"})
	if err != nil || len(deps) != 1 {
		t.Fatal(deps, err)
	}
	if _, ok := deps["linux-image-7.0.0-31-generic"]; !ok {
		t.Fatal(deps)
	}
	rows := fixture()
	rows[4].Fields["Depends"] = "linux-main-modules-zfs-7.0.0-31-generic"
	rows = append(rows, record{fields{"Package": "linux-main-modules-zfs-7.0.0-31-generic", "Version": "7.0.0-31.31+2", "SHA256": "zfs", "Depends": "linux-image-7.0.0-31-generic | linux-image-unsigned-7.0.0-31-generic"}, "resolute-updates"})
	got, _, err := closure(rows, "linux-generic")
	if err != nil || len(got) != 8 {
		t.Fatal(got, err)
	}
}

func TestReleaseFreshnessAndIdentity(t *testing.T) {
	now := time.Date(2026, 9, 13, 15, 0, 0, 0, time.UTC)
	p := policy{Release: "resolute", MaxAge: 168}
	good := func() fields {
		return fields{"Origin": "Ubuntu", "Suite": "resolute-updates", "Codename": "resolute", "Date": now.Add(-time.Hour).Format(time.RFC1123)}
	}
	if err := checkRelease(p, "resolute-updates", good(), now); err != nil {
		t.Fatal(err)
	}
	for _, pair := range [][2]string{{"Origin", "Other"}, {"Suite", "resolute-proposed"}, {"Codename", "other"}, {"Date", now.Add(-8 * 24 * time.Hour).Format(time.RFC1123)}, {"Date", now.Add(48 * time.Hour).Format(time.RFC1123)}, {"Valid-Until", now.Add(-time.Minute).Format(time.RFC1123)}} {
		f := good()
		f[pair[0]] = pair[1]
		if err := checkRelease(p, "resolute-updates", f, now); err == nil {
			t.Fatal("accepted", pair)
		}
	}
}
