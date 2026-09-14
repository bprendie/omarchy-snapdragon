package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestLegacyMigrationAndSelection(t *testing.T) {
	esp, a, _ := selectionFixture(t)
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
	if err := selectLegacyMenu(esp, "ABCD-1234", "root=UUID=test", a, "legacy", true, verify); err == nil {
		t.Fatal("migration activated candidate")
	}
	if err := selectLegacyMenu(esp, "ABCD-1234", "root=UUID=test", "legacy", a, true, verify); err != nil {
		t.Fatal(err)
	}
	for _, pair := range [][2]string{{a, "legacy"}, {"legacy", a}} {
		if err := selectLegacyMenu(esp, "ABCD-1234", "root=UUID=test", pair[0], pair[1], false, verify); err != nil {
			t.Fatal(err)
		}
		data, err := os.ReadFile(path)
		if err != nil || !strings.Contains(string(data), "set default=oma-snap-"+pair[0]+"\n") {
			t.Fatal("wrong selection")
		}
		if !strings.Contains(string(data), "set default=0\n  configfile /oma-snap/grub/legacy/grub.cfg") {
			t.Fatal("missing legacy default reset")
		}
		if checker := os.Getenv("OMA_SNAP_GRUB_CHECK"); checker != "" {
			for _, menu := range []string{path, filepath.Join(esp, "oma-snap/grub/legacy/grub.cfg")} {
				if output, err := exec.Command(checker, menu).CombinedOutput(); err != nil {
					t.Fatalf("GRUB syntax check: %v: %s", err, output)
				}
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
	if err := selectLegacyMenu(esp, "ABCD-1234", "root=UUID=test", a, "legacy", false, verify); err == nil {
		t.Fatal("changed fallback accepted")
	}
	after, err := os.ReadFile(path)
	if err != nil || string(before) != string(after) {
		t.Fatal("failure changed menu")
	}
}
