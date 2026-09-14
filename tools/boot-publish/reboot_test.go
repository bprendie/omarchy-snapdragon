package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestRebootStatusUsesEntryNotKernelRelease(t *testing.T) {
	esp, a, b := selectionFixture(t)
	if err := selectMenu(esp, "ABCD-1234", "root=UUID=test", a, b, func(build) error { return nil }); err != nil {
		t.Fatal(err)
	}
	running := filepath.Join(t.TempDir(), "entry")
	for _, tc := range []struct{ id, want string }{{a, "current"}, {b, "required"}} {
		if err := os.WriteFile(running, []byte(tc.id+"\n"), 0644); err != nil {
			t.Fatal(err)
		}
		got, err := rebootStatus(esp, "ABCD-1234", "root=UUID=test", running, legacyRelease)
		if err != nil || got != tc.want {
			t.Fatalf("got %q, %v; want %q", got, err, tc.want)
		}
	}
	if err := os.WriteFile(running, []byte("invalid"), 0644); err != nil {
		t.Fatal(err)
	}
	if _, err := rebootStatus(esp, "ABCD-1234", "root=UUID=test", running, legacyRelease); err == nil {
		t.Fatal("invalid running identity accepted")
	}
}

func TestRebootStatusRecognizesReleasedBoot(t *testing.T) {
	esp, config := legacyFixture(t)
	menu := filepath.Join(esp, "oma-snap/grub/grub.cfg")
	if err := os.WriteFile(menu, config, 0644); err != nil {
		t.Fatal(err)
	}
	running := filepath.Join(t.TempDir(), "absent")
	for _, tc := range []struct{ release, want string }{{legacyRelease, "current"}, {"different-kernel", "required"}} {
		got, err := rebootStatus(esp, "ABCD-1234", "root=UUID=test rootflags=subvol=@ rw", running, tc.release)
		if err != nil || got != tc.want {
			t.Fatalf("got %q, %v", got, err)
		}
	}
	if err := os.WriteFile(menu, []byte("custom menu"), 0644); err != nil {
		t.Fatal(err)
	}
	if _, err := rebootStatus(esp, "ABCD-1234", "root=UUID=test", running, legacyRelease); err == nil {
		t.Fatal("unrecognized menu accepted")
	}
}
