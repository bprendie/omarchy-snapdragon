package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestRetainedPairPreservesLegacy(t *testing.T) {
	esp, a, b := selectionFixture(t)
	config, err := releasedMenu("ABCD-1234", "root=UUID=test")
	if err != nil {
		t.Fatal(err)
	}
	dir := filepath.Join(esp, "oma-snap", legacyRelease)
	if err := os.MkdirAll(dir, 0755); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"vmlinuz.efi", "initramfs.img"} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(name), 0644); err != nil {
			t.Fatal(err)
		}
	}
	path := filepath.Join(esp, "oma-snap/grub/grub.cfg")
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(config), 0644); err != nil {
		t.Fatal(err)
	}
	verify := func(build) error { return nil }
	if err := selectLegacyMenu(esp, "ABCD-1234", "root=UUID=test", "legacy", a, true, verify); err != nil {
		t.Fatal(err)
	}
	for _, pair := range [][2]string{{b, a}, {a, b}, {b, a}} {
		if err := selectMenu(esp, "ABCD-1234", "root=UUID=test", pair[0], pair[1], verify); err != nil {
			t.Fatal(err)
		}
		data, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		if !strings.HasPrefix(string(data), legacyMarker) || !strings.Contains(string(data), "set default=oma-snap-"+pair[0]+"\n") {
			t.Fatal("selection lost legacy tracking or selected the wrong default")
		}
		for _, id := range []string{a, b, "legacy"} {
			if strings.Count(string(data), "--id 'oma-snap-"+id+"'") != 1 {
				t.Fatal("missing or duplicated recovery entry", id)
			}
		}
		if original, err := readLegacy(esp); err != nil || string(original) != config {
			t.Fatal("legacy snapshot changed", err)
		}
		if checker := os.Getenv("OMA_SNAP_GRUB_CHECK"); checker != "" {
			if output, err := exec.Command(checker, path).CombinedOutput(); err != nil {
				t.Fatalf("GRUB syntax check: %v: %s", err, output)
			}
		}
	}
	before, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "initramfs.img"), []byte("corrupt"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := selectMenu(esp, "ABCD-1234", "root=UUID=test", a, b, verify); err == nil {
		t.Fatal("corrupt legacy recovery accepted")
	}
	after, err := os.ReadFile(path)
	if err != nil || string(before) != string(after) {
		t.Fatal("failed selection changed menu")
	}
}
