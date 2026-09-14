package main

import (
	"archive/tar"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func fixture(t *testing.T) (approval, string, string) {
	t.Helper()
	dir := t.TempDir()
	a := approval{Schema: 1, Status: "approved", Channel: "testing", Sequence: 2,
		Reviewer: "fixture only", HardwareSet: strings.Repeat("a", 64), KernelRelease: "7.0.0-31-generic",
		Hardware: map[string]string{"t14s": "untested", "hp-g1q": "untested", "asus-ux3407ra": "untested"}}
	for _, kind := range []string{"source-verification", "package-reproducibility", "camera-build", "vm-rollback", "vm-encrypted-boot"} {
		path := filepath.Join(dir, kind+".log")
		if err := os.WriteFile(path, []byte("synthetic test evidence: "+kind), 0600); err != nil {
			t.Fatal(err)
		}
		h, err := hashFile(path)
		if err != nil {
			t.Fatal(err)
		}
		a.Evidence = append(a.Evidence, evidence{Kind: kind, Path: filepath.Base(path), SHA256: h})
	}
	archive := filepath.Join(dir, "payload.pkg.tar")
	f, err := os.Create(archive)
	if err != nil {
		t.Fatal(err)
	}
	tw := tar.NewWriter(f)
	files := map[string]string{
		".PKGINFO": "pkgname = oma-snap-set-" + a.HardwareSet + "\npkgver = 0.2.0-1\narch = aarch64\n",
		"usr/lib/oma-snap/sets/" + a.HardwareSet + "/set.json": `{"id":"` + a.HardwareSet + `","kernel_release":"` + a.KernelRelease + `"}`,
	}
	for name, data := range files {
		if err = tw.WriteHeader(&tar.Header{Name: name, Mode: 0644, Size: int64(len(data))}); err != nil {
			t.Fatal(err)
		}
		if _, err = tw.Write([]byte(data)); err != nil {
			t.Fatal(err)
		}
	}
	if err = tw.Close(); err != nil {
		t.Fatal(err)
	}
	if err = f.Close(); err != nil {
		t.Fatal(err)
	}
	a.PackageSHA256, err = hashFile(archive)
	if err != nil {
		t.Fatal(err)
	}
	return a, dir, archive
}

func TestPromotionBindsEvidenceAndPackage(t *testing.T) {
	for _, test := range []struct {
		name string
		edit func(*approval)
	}{
		{"unapproved", func(a *approval) { a.Status = "unvalidated" }},
		{"old-sequence", func(a *approval) { a.Sequence = 1 }},
		{"missing-reviewer", func(a *approval) { a.Reviewer = " " }},
		{"missing-encryption", func(a *approval) { a.Evidence = a.Evidence[:4] }},
		{"duplicate-evidence", func(a *approval) { a.Evidence[4] = a.Evidence[0] }},
		{"changed-evidence", func(a *approval) { a.Evidence[0].SHA256 = strings.Repeat("b", 64) }},
		{"changed-package", func(a *approval) { a.PackageSHA256 = strings.Repeat("b", 64) }},
		{"wrong-release", func(a *approval) { a.KernelRelease = "7.0.0-30-generic" }},
		{"wrong-set", func(a *approval) { a.HardwareSet = strings.Repeat("b", 64) }},
		{"stable-untested", func(a *approval) { a.Channel = "stable" }},
		{"unsafe-path", func(a *approval) { a.Evidence[0].Path = "../outside" }},
	} {
		t.Run(test.name, func(t *testing.T) {
			a, dir, archive := fixture(t)
			test.edit(&a)
			if err := a.verify(dir, archive, 1); err == nil {
				t.Fatal("accepted invalid promotion")
			}
		})
	}
}

func TestGenerateApprovedProvider(t *testing.T) {
	a, dir, archive := fixture(t)
	a.Channel = "stable"
	a.Hardware["hp-g1q"], a.Hardware["t14s"] = "validated", "validated"
	data, err := json.Marshal(a)
	if err != nil {
		t.Fatal(err)
	}
	record := filepath.Join(dir, "approval.json")
	if err = os.WriteFile(record, data, 0600); err != nil {
		t.Fatal(err)
	}
	out := filepath.Join(dir, "provider")
	if err = generate(record, archive, out, 1); err != nil {
		t.Fatal(err)
	}
	build, err := os.ReadFile(filepath.Join(out, "PKGBUILD"))
	if err != nil {
		t.Fatal(err)
	}
	for _, expected := range []string{"epoch=1\npkgver=2", "oma-snap-set-" + a.HardwareSet + "=0.2.0-1"} {
		if !strings.Contains(string(build), expected) {
			t.Fatalf("missing %s", expected)
		}
	}
	var got approval
	if err = readJSON(filepath.Join(out, "candidate.json"), &got); err != nil {
		t.Fatal(err)
	}
	if got.Hardware["asus-ux3407ra"] != "untested" || got.PackageSHA256 != a.PackageSHA256 {
		t.Fatal("lost approval provenance")
	}
	if err = generate(record, archive, out, 1); err == nil {
		t.Fatal("overwrote existing build")
	}
}
