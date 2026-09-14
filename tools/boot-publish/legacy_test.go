package main

import (
	"os"
	"path/filepath"
	"testing"
)

func legacyFixture(t *testing.T) (string, []byte) {
	t.Helper()
	esp := t.TempDir()
	for _, dir := range []string{"oma-snap/grub", "oma-snap/" + legacyRelease} {
		if err := os.MkdirAll(filepath.Join(esp, dir), 0755); err != nil {
			t.Fatal(err)
		}
	}
	for _, name := range []string{"vmlinuz.efi", "initramfs.img"} {
		if err := os.WriteFile(filepath.Join(esp, "oma-snap", legacyRelease, name), []byte(name), 0644); err != nil {
			t.Fatal(err)
		}
	}
	config, err := releasedMenu("ABCD-1234", "root=UUID=test rootflags=subvol=@ rw")
	if err != nil {
		t.Fatal(err)
	}
	return esp, []byte(config)
}

func TestLegacySnapshotRetryAndCorruption(t *testing.T) {
	for _, target := range []string{"vmlinuz.efi", "initramfs.img", "config"} {
		t.Run(target, func(t *testing.T) {
			esp, config := legacyFixture(t)
			for i := 0; i < 2; i++ {
				if err := saveLegacy(esp, config); err != nil {
					t.Fatal(err)
				}
			}
			got, err := readLegacy(esp)
			if err != nil || string(got) != string(config) {
				t.Fatalf("snapshot mismatch: %v", err)
			}
			path := filepath.Join(esp, "oma-snap", legacyRelease, target)
			if target == "config" {
				path = filepath.Join(esp, "oma-snap/grub/legacy/grub.cfg")
			}
			if err := os.WriteFile(path, []byte("changed"), 0644); err != nil {
				t.Fatal(err)
			}
			if _, err := readLegacy(esp); err == nil {
				t.Fatal("changed legacy boot accepted")
			}
			if err := saveLegacy(esp, config); err == nil {
				t.Fatal("retry silently replaced changed snapshot")
			}
		})
	}
}

func TestLegacyMenuRejectsUnsafeInputs(t *testing.T) {
	for _, cmdline := range []string{"", "quiet", "root=test\nreboot", "root=test;reboot"} {
		if _, err := releasedMenu("ABCD-1234", cmdline); err == nil {
			t.Fatalf("unsafe menu accepted: %q", cmdline)
		}
	}
}
