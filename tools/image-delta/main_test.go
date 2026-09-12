package main

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

func TestApplyAndPreserveTail(t *testing.T) {
	d := t.TempDir()
	old := filepath.Join(d, "old")
	next := filepath.Join(d, "new")
	target := filepath.Join(d, "target")
	a := make([]byte, 9*1024*1024+123)
	b := bytes.Clone(a)
	b[0] = 1
	b[5*1024*1024] = 2
	b[len(b)-1] = 3
	for p, data := range map[string][]byte{old: a, next: b, target: append(bytes.Clone(a), []byte("keep-tail")...)} {
		if err := os.WriteFile(p, data, 0600); err != nil {
			t.Fatal(err)
		}
	}
	if err := run(true, []string{old, next, target}); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(target)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(got, append(b, []byte("keep-tail")...)) {
		t.Fatal("wrong image or changed tail")
	}
	before := bytes.Clone(got)
	if err := run(true, []string{old, next, target}); err == nil {
		t.Fatal("accepted mismatched old image")
	}
	got, err = os.ReadFile(target)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(got, before) {
		t.Fatal("wrote after rejecting target")
	}
	if err := run(true, []string{old, next, old}); err == nil {
		t.Fatal("accepted input as target")
	}
}
