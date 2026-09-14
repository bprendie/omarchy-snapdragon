package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestActivationFromMigratedLegacy(t *testing.T) {
	p, _, _, b := activationFixture(t)
	verify := func(build) error { return nil }
	if err := os.RemoveAll(p.Runtime); err != nil {
		t.Fatal(err)
	}
	p.Release = legacyRelease
	menu, err := releasedMenu(p.UUID, p.Cmdline)
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(p.ESP, "oma-snap/grub/grub.cfg")
	if err = os.WriteFile(path, []byte(menu), 0644); err != nil {
		t.Fatal(err)
	}
	dir := filepath.Join(p.ESP, "oma-snap", legacyRelease)
	if err = os.MkdirAll(dir, 0755); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"vmlinuz.efi", "initramfs.img"} {
		if err = os.WriteFile(filepath.Join(dir, name), []byte(name), 0644); err != nil {
			t.Fatal(err)
		}
	}
	if err = activateProvider(p, verify, func() error { return nil }); err == nil {
		t.Fatal("silently migrated legacy layout")
	}
	if err = selectLegacyMenu(p.ESP, p.UUID, p.Cmdline, "legacy", b, true, verify); err != nil {
		t.Fatal(err)
	}
	checked := false
	if err = activateProvider(p, verify, func() error { checked = true; return nil }); err != nil {
		t.Fatal(err)
	}
	if !checked {
		t.Fatal("skipped legacy retention dependencies")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), "set default=oma-snap-"+b+"\n") || !strings.Contains(string(data), "--id 'oma-snap-legacy'") {
		t.Fatal("lost legacy fallback")
	}
	if original, err := readLegacy(p.ESP); err != nil || string(original) != menu {
		t.Fatal("changed original legacy payload", err)
	}
}
