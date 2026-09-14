package main

import (
	"os"
	"path/filepath"
	"testing"
)

func fixtureFirmware(t *testing.T, data string) string {
	t.Helper()
	root := t.TempDir()
	if err := os.Mkdir(filepath.Join(root, "qcom"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "qcom/dsp.mbn"), []byte(data), 0644); err != nil {
		t.Fatal(err)
	}
	return root
}

func TestFirmwareCollision(t *testing.T) {
	first := fixtureFirmware(t, "original")
	identical := fixtureFirmware(t, "original")
	different := fixtureFirmware(t, "changed")
	destination := t.TempDir()
	if err := mergeFirmware(first, destination); err != nil {
		t.Fatal(err)
	}
	if err := mergeFirmware(identical, destination); err != nil {
		t.Fatal(err)
	}
	if err := mergeFirmware(different, destination); err == nil {
		t.Fatal("silently replaced firmware")
	}
	data, err := os.ReadFile(filepath.Join(destination, "qcom/dsp.mbn"))
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "original" {
		t.Fatal("changed existing firmware")
	}
}

func TestFirmwareDirectorySymlink(t *testing.T) {
	source, destination := fixtureFirmware(t, "original"), t.TempDir()
	if err := os.Symlink(t.TempDir(), filepath.Join(destination, "qcom")); err != nil {
		t.Fatal(err)
	}
	if err := mergeFirmware(source, destination); err == nil {
		t.Fatal("followed directory substitution")
	}
}

func TestFirmwareNamespace(t *testing.T) {
	payload := t.TempDir()
	old := filepath.Join(payload, "firmware-packages/oma-snap-firmware-test/usr/lib/firmware/old-release")
	if err := os.MkdirAll(old, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(old, "dsp.mbn"), []byte("original"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := normalizeFirmware(payload, "new-release"); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(payload, "firmware/new-release/dsp.mbn"))
	if err != nil || string(data) != "original" {
		t.Fatalf("namespace migration: %q %v", data, err)
	}
}
