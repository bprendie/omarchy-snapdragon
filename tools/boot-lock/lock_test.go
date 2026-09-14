package bootlock

import (
	"os"
	"path/filepath"
	"testing"
)

func TestExclusiveAndRelease(t *testing.T) {
	path := filepath.Join(t.TempDir(), "db.lck")
	first, err := Acquire(path)
	if err != nil {
		t.Fatal(err)
	}
	before, _ := os.ReadFile(path)
	if _, err = Acquire(path); err == nil {
		t.Fatal("concurrent operation accepted")
	}
	after, _ := os.ReadFile(path)
	if string(after) != string(before) {
		t.Fatal("existing lock changed")
	}
	if err = first.Close(); err != nil {
		t.Fatal(err)
	}
	second, err := Acquire(path)
	if err != nil {
		t.Fatal(err)
	}
	if err = second.Close(); err != nil {
		t.Fatal(err)
	}
}

func TestDoNotRemoveReplacementLock(t *testing.T) {
	path := filepath.Join(t.TempDir(), "db.lck")
	held, err := Acquire(path)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.Rename(path, path+".old"); err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(path, []byte("another owner"), 0644); err != nil {
		t.Fatal(err)
	}
	if err = held.Close(); err == nil {
		t.Fatal("removed replaced lock")
	}
	data, err := os.ReadFile(path)
	if err != nil || string(data) != "another owner" {
		t.Fatal("replacement lock changed")
	}
}
