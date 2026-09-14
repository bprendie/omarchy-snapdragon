package main

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func providerFixture(t *testing.T, status, channel string) (string, string) {
	t.Helper()
	root := t.TempDir()
	id, entry := strings.Repeat("a", 64), strings.Repeat("b", 64)
	files := map[string]any{
		"usr/share/oma-snap/kernel-provider/candidate.json": map[string]any{"schema": 1, "status": status, "channel": channel, "sequence": 1, "hardware_set": id, "kernel_release": "7.0.0-31-generic"},
		"var/lib/oma-snap/jobs/complete/" + id + ".json":    map[string]any{"schema": 1, "hardware_set": id, "boot_entry": entry},
		"boot/oma-snap/entries/" + entry + "/entry.json":    map[string]string{"hardware_set": id, "kernel_release": "7.0.0-31-generic"},
	}
	for name, value := range files {
		path := filepath.Join(root, name)
		if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
			t.Fatal(err)
		}
		data, err := json.Marshal(value)
		if err != nil {
			t.Fatal(err)
		}
		if err = os.WriteFile(path, data, 0644); err != nil {
			t.Fatal(err)
		}
	}
	return root, entry
}

func TestInstallProviderSequence(t *testing.T) {
	root, entry := providerFixture(t, "approved", "stable")
	var calls []string
	err := initializeProvider(root, "/boot", func(name string, args ...string) error {
		if name != "arch-chroot" || args[0] != root {
			t.Fatal("escaped target")
		}
		calls = append(calls, strings.Join(args[1:], " "))
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	expected := []string{"oma-snap-kernel-queue --process", "oma-snap-kernel-queue --check-provider-prepared",
		"oma-snap-boot-publish --esp /boot --migrate-legacy --select legacy --fallback " + entry,
		"oma-snap-boot-publish --esp /boot --select " + entry + " --fallback legacy"}
	if strings.Join(calls, "\n") != strings.Join(expected, "\n") {
		t.Fatalf("wrong sequence: %v", calls)
	}
}

func TestInstallProviderFailureStopsSelection(t *testing.T) {
	for stop := 0; stop < 4; stop++ {
		root, _ := providerFixture(t, "approved", "stable")
		calls := 0
		err := initializeProvider(root, "/boot", func(string, ...string) error {
			calls++
			if calls == stop+1 {
				return errors.New("injected failure")
			}
			return nil
		})
		if err == nil || calls != stop+1 {
			t.Fatalf("continued after stage %d: %d, %v", stop, calls, err)
		}
	}
	for _, values := range [][2]string{{"unvalidated", "stable"}, {"approved", "testing"}} {
		root, _ := providerFixture(t, values[0], values[1])
		if err := initializeProvider(root, "/boot", func(string, ...string) error { t.Fatal("ran unapproved operation"); return nil }); err == nil {
			t.Fatal("invalid approval accepted")
		}
	}
}

func TestLegacyInstallWithoutProvider(t *testing.T) {
	if err := initializeProvider(t.TempDir(), "/boot", func(string, ...string) error { t.Fatal("changed legacy install"); return nil }); err != nil {
		t.Fatal(err)
	}
}
