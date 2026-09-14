package main

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestInventoryMutation(t *testing.T) {
	root := t.TempDir()
	path := filepath.Join(root, "kernel")
	if err := os.WriteFile(path, []byte("kernel A"), 0644); err != nil {
		t.Fatal(err)
	}
	before, err := inventory(root)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(path, []byte("kernel B"), 0644); err != nil {
		t.Fatal(err)
	}
	after, err := inventory(root)
	if err != nil {
		t.Fatal(err)
	}
	if reflect.DeepEqual(before, after) {
		t.Fatal("content mutation did not change inventory")
	}
	if err = os.Chmod(path, 0755); err != nil {
		t.Fatal(err)
	}
	mode, err := inventory(root)
	if err != nil {
		t.Fatal(err)
	}
	if reflect.DeepEqual(after, mode) {
		t.Fatal("mode mutation did not change inventory")
	}
}

func TestInventorySymlinkEscape(t *testing.T) {
	link := filepath.Join(t.TempDir(), "root")
	if err := os.Symlink(t.TempDir(), link); err != nil {
		t.Fatal(err)
	}
	if _, err := inventory(link); err == nil {
		t.Fatal("accepted symlink payload root")
	}
	for _, target := range []string{"/etc/passwd", "../outside", "a/../../outside"} {
		t.Run(target, func(t *testing.T) {
			root := t.TempDir()
			if err := os.Symlink(target, filepath.Join(root, "link")); err != nil {
				t.Fatal(err)
			}
			if _, err := inventory(root); err == nil {
				t.Fatal("accepted escaping link")
			}
		})
	}
}

func TestInventoryIndependentOfRoot(t *testing.T) {
	a, b := t.TempDir(), t.TempDir()
	for _, root := range []string{a, b} {
		if err := os.WriteFile(filepath.Join(root, "file"), []byte("same"), 0644); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink("file", filepath.Join(root, "link")); err != nil {
			t.Fatal(err)
		}
	}
	first, err := inventory(a)
	if err != nil {
		t.Fatal(err)
	}
	second, err := inventory(b)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(first, second) {
		t.Fatal("inventory depends on root path")
	}
}
