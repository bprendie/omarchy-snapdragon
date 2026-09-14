package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestFirmwareMetadataSurvivesWithOrdinaryNames(t *testing.T) {
	source := t.TempDir()
	for _, name := range []string{".PKGINFO", ".BUILDINFO", ".MTREE", ".INSTALL", ".CHANGELOG"} {
		if err := os.WriteFile(filepath.Join(source, name), []byte(name), 0644); err != nil {
			t.Fatal(err)
		}
	}
	destination := filepath.Join(t.TempDir(), "firmware")
	if err := copyFirmwarePackage(source, destination); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"PKGINFO", "BUILDINFO", "MTREE", "INSTALL", "CHANGELOG"} {
		data, err := os.ReadFile(filepath.Join(destination, "package-metadata", name))
		if err != nil || string(data) != "."+name {
			t.Fatalf("metadata %s changed: %q, %v", name, data, err)
		}
		if _, err = os.Lstat(filepath.Join(destination, "."+name)); !os.IsNotExist(err) {
			t.Fatalf("reserved name remains: %s", name)
		}
		if _, err = os.Stat(filepath.Join(source, "."+name)); err != nil {
			t.Fatal("source metadata changed", err)
		}
	}
}

func TestFirmwareMetadataRejectsCollision(t *testing.T) {
	source := t.TempDir()
	if err := os.Mkdir(filepath.Join(source, "package-metadata"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := copyFirmwarePackage(source, filepath.Join(t.TempDir(), "out")); err == nil {
		t.Fatal("accepted metadata destination collision")
	}
}
