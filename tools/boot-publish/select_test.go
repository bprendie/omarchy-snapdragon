package main

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func selectionFixture(t *testing.T) (string, string, string) {
	t.Helper()
	stage, set, entries, b := fixture(t)
	if _, err := publish(stage, set, entries, "ABCD-1234", "root=UUID=test", b); err != nil {
		t.Fatal(err)
	}
	first := b.Entry
	b.Entry = strings.Repeat("c", 64)
	if _, err := publish(stage, set, entries, "ABCD-1234", "root=UUID=test", b); err != nil {
		t.Fatal(err)
	}
	return filepath.Dir(filepath.Dir(entries)), first, b.Entry
}

func TestSelectionAndRollback(t *testing.T) {
	esp, a, b := selectionFixture(t)
	verify := func(build) error { return nil }
	for _, pair := range [][2]string{{a, b}, {b, a}, {a, b}} {
		if err := selectMenu(esp, "ABCD-1234", "root=UUID=test", pair[0], pair[1], verify); err != nil {
			t.Fatal(err)
		}
		data, err := os.ReadFile(filepath.Join(esp, "oma-snap/grub/grub.cfg"))
		if err != nil {
			t.Fatal(err)
		}
		text := string(data)
		if !strings.Contains(text, "set default=oma-snap-"+pair[0]+"\n") {
			t.Fatal("wrong default")
		}
		for _, id := range pair {
			if !strings.Contains(text, "--id 'oma-snap-"+id+"'") {
				t.Fatal("missing retained entry")
			}
		}
	}
}

func TestSelectionFailurePreservesMenu(t *testing.T) {
	for _, kind := range []string{"corrupt-fallback", "missing-set", "legacy-menu"} {
		t.Run(kind, func(t *testing.T) {
			esp, a, b := selectionFixture(t)
			verify := func(build) error { return nil }
			if err := selectMenu(esp, "ABCD-1234", "root=UUID=test", a, b, verify); err != nil {
				t.Fatal(err)
			}
			path := filepath.Join(esp, "oma-snap/grub/grub.cfg")
			switch kind {
			case "corrupt-fallback":
				if err := os.WriteFile(filepath.Join(esp, "oma-snap/entries", a, "initramfs.img"), []byte("broken"), 0644); err != nil {
					t.Fatal(err)
				}
			case "missing-set":
				verify = func(build) error { return errors.New("retained package missing") }
			case "legacy-menu":
				if err := os.WriteFile(path, []byte("legacy working menu"), 0644); err != nil {
					t.Fatal(err)
				}
			}
			before, err := os.ReadFile(path)
			if err != nil {
				t.Fatal(err)
			}
			if err = selectMenu(esp, "ABCD-1234", "root=UUID=test", b, a, verify); err == nil {
				t.Fatal("selected invalid pair")
			}
			after, err := os.ReadFile(path)
			if err != nil || string(before) != string(after) {
				t.Fatal("failed selection changed default")
			}
		})
	}
}
