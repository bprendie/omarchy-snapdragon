package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func activationFixture(t *testing.T) (activationPaths, approvedProvider, string, string) {
	t.Helper()
	esp, a, b := selectionFixture(t)
	root := t.TempDir()
	p := activationPaths{ESP: esp, UUID: "ABCD-1234", Cmdline: "root=UUID=test",
		Provider: filepath.Join(root, "candidate.json"), Jobs: filepath.Join(root, "jobs"),
		Runtime: filepath.Join(root, "run"), State: filepath.Join(root, "activation.json"), Channel: filepath.Join(root, "channel")}
	entry, err := readEntry(esp, b)
	if err != nil {
		t.Fatal(err)
	}
	p.Release = entry.Release
	provider := approvedProvider{1, "approved", "stable", 1, entry.Hardware, entry.Release}
	writeTestJSON(t, p.Provider, provider)
	writeTestJSON(t, filepath.Join(p.Jobs, "complete", provider.Hardware+".json"), map[string]any{
		"schema": 1, "hardware_set": provider.Hardware, "boot_entry": b})
	if err = os.MkdirAll(p.Runtime, 0755); err != nil {
		t.Fatal(err)
	}
	for name, value := range map[string]string{"booted-entry": a, "booted-set": entry.Hardware} {
		if err = os.WriteFile(filepath.Join(p.Runtime, name), []byte(value), 0644); err != nil {
			t.Fatal(err)
		}
	}
	if err = selectMenu(esp, p.UUID, p.Cmdline, a, b, func(build) error { return nil }); err != nil {
		t.Fatal(err)
	}
	return p, provider, a, b
}

func writeTestJSON(t *testing.T, path string, value any) {
	t.Helper()
	data, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(path, data, 0644); err != nil {
		t.Fatal(err)
	}
}

func TestActivationRetainsRunningAndRespectsRollback(t *testing.T) {
	p, provider, a, b := activationFixture(t)
	verify := func(build) error { return nil }
	legacy := func() error { t.Fatal("unexpected legacy dependency check"); return nil }
	if err := activateProvider(p, verify, legacy); err != nil {
		t.Fatal(err)
	}
	menu := filepath.Join(p.ESP, "oma-snap/grub/grub.cfg")
	data, err := os.ReadFile(menu)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), "set default=oma-snap-"+b+"\n") || !strings.Contains(string(data), "--id 'oma-snap-"+a+"'") {
		t.Fatal("wrong activation/fallback")
	}
	if err = selectMenu(p.ESP, p.UUID, p.Cmdline, a, b, verify); err != nil {
		t.Fatal(err)
	}
	before, err := os.ReadFile(menu)
	if err != nil {
		t.Fatal(err)
	}
	if err = activateProvider(p, verify, legacy); err != nil {
		t.Fatal(err)
	}
	after, err := os.ReadFile(menu)
	if err != nil || string(before) != string(after) {
		t.Fatal("repeated activation undid rollback")
	}
	provider.Release = "changed"
	writeTestJSON(t, p.Provider, provider)
	if err = activateProvider(p, verify, legacy); err == nil {
		t.Fatal("reused sequence accepted")
	}
}

func TestActivationFailuresPreserveMenu(t *testing.T) {
	for _, kind := range []string{"failed-job", "pending-job", "running-job", "wrong-release", "wrong-runtime", "corrupt-entry", "testing-channel", "unapproved"} {
		t.Run(kind, func(t *testing.T) {
			p, provider, _, b := activationFixture(t)
			menu := filepath.Join(p.ESP, "oma-snap/grub/grub.cfg")
			before, err := os.ReadFile(menu)
			if err != nil {
				t.Fatal(err)
			}
			switch kind {
			case "failed-job", "pending-job", "running-job":
				writeTestJSON(t, filepath.Join(p.Jobs, strings.TrimSuffix(kind, "-job"), provider.Hardware+".json"), map[string]int{"schema": 1})
			case "wrong-release":
				provider.Release = "7.0.0-99-generic"
			case "wrong-runtime":
				p.Release = "7.0.0-99-generic"
			case "testing-channel":
				provider.Channel = "testing"
			case "unapproved":
				provider.Status = "unvalidated"
			case "corrupt-entry":
				if err = os.WriteFile(filepath.Join(p.ESP, "oma-snap/entries", b, "initramfs.img"), []byte("broken"), 0644); err != nil {
					t.Fatal(err)
				}
			}
			writeTestJSON(t, p.Provider, provider)
			err = activateProvider(p, func(build) error { return nil }, func() error { return nil })
			if kind == "unapproved" && err != nil {
				t.Fatal(err)
			}
			if kind != "unapproved" && err == nil {
				t.Fatal("invalid activation accepted")
			}
			after, err := os.ReadFile(menu)
			if err != nil || string(before) != string(after) {
				t.Fatal("failed activation changed menu")
			}
			if _, err = os.Stat(p.State); !os.IsNotExist(err) {
				t.Fatal("failed activation recorded as applied")
			}
		})
	}
}
