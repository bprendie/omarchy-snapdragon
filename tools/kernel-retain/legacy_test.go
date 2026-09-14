package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestLegacyPayloadProtectsEveryDependency(t *testing.T) {
	payload := filepath.Join(t.TempDir(), "7.0.0-31-generic")
	if err := os.Mkdir(payload, 0755); err != nil {
		t.Fatal(err)
	}
	for name := range legacyPackages {
		if err := checkLegacyTargets(strings.NewReader(name+"\n"), payload); err == nil {
			t.Fatalf("retained legacy package accepted: %s", name)
		}
	}
	if err := os.Remove(payload); err != nil {
		t.Fatal(err)
	}
	for name := range legacyPackages {
		if err := checkLegacyTargets(strings.NewReader(name+"\n"), payload); err != nil {
			t.Fatalf("retired legacy package rejected: %s: %v", name, err)
		}
	}
}

func TestLegacyGuardRejectsSubstitutionAndBadTargets(t *testing.T) {
	root := t.TempDir()
	payload := filepath.Join(root, "legacy")
	for _, input := range []string{"", "linux\n", "oma-snap-kernel-tools\n"} {
		if err := checkLegacyTargets(strings.NewReader(input), payload); err == nil {
			t.Fatalf("unexpected target accepted: %q", input)
		}
	}
	if err := os.Symlink(filepath.Join(root, "absent"), payload); err != nil {
		t.Fatal(err)
	}
	if err := checkLegacyTargets(strings.NewReader("oma-snap-kernel-ubuntu\n"), payload); err == nil {
		t.Fatal("dangling payload symlink accepted")
	}
	parent := filepath.Join(root, "parent")
	if err := os.Symlink(root, parent); err != nil {
		t.Fatal(err)
	}
	if err := checkLegacyTargets(strings.NewReader("oma-snap-kernel-ubuntu\n"), filepath.Join(parent, "missing")); err == nil {
		t.Fatal("substituted parent accepted")
	}
}
