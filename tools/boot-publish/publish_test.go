package main

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func fixture(t *testing.T) (string, string, string, build) {
	t.Helper()
	root := t.TempDir()
	stage, set, entries := filepath.Join(root, "stage"), filepath.Join(root, "set"), filepath.Join(root, "esp/oma-snap/entries")
	for _, path := range []string{stage, set, filepath.Dir(entries)} {
		if err := os.MkdirAll(path, 0755); err != nil {
			t.Fatal(err)
		}
	}
	b := build{Schema: 1, Status: "built-unvalidated", Hardware: strings.Repeat("a", 64), Entry: strings.Repeat("b", 64), Release: "7.0.0-31-generic", KernelHash: fmt.Sprintf("%x", sha256.Sum256([]byte("kernel"))), InitrdHash: fmt.Sprintf("%x", sha256.Sum256([]byte("initrd")))}
	data, _ := json.Marshal(b)
	files := map[string][]byte{
		filepath.Join(stage, "built.json"):               data,
		filepath.Join(stage, "boot-set"):                 []byte(b.Hardware + "\n" + b.Release + "\n" + b.Entry + "\n"),
		filepath.Join(stage, "initramfs.img"):            []byte("initrd"),
		filepath.Join(set, "vmlinuz.efi"):                []byte("kernel"),
		filepath.Join(filepath.Dir(entries), "grub.cfg"): []byte("known working default\n"),
	}
	for path, data := range files {
		if err := os.WriteFile(path, data, 0644); err != nil {
			t.Fatal(err)
		}
	}
	return stage, set, entries, b
}

func TestPublishPreservesDefaultAndExistingEntry(t *testing.T) {
	stage, set, entries, b := fixture(t)
	parsed, err := readBuild(stage)
	if err != nil || parsed != b {
		t.Fatalf("manifest: %v", err)
	}
	dest, err := publish(stage, set, entries, "ABCD-1234", "root=UUID=test rw", b)
	if err != nil {
		t.Fatal(err)
	}
	for name, want := range map[string]string{"vmlinuz.efi": "kernel", "initramfs.img": "initrd"} {
		data, err := os.ReadFile(filepath.Join(dest, name))
		if err != nil || string(data) != want {
			t.Fatalf("payload %s: %v", name, err)
		}
	}
	data, err := os.ReadFile(filepath.Join(dest, "entry.cfg"))
	if err != nil || !strings.Contains(string(data), "/oma-snap/entries/"+b.Entry+"/initramfs.img") {
		t.Fatal("entry does not bind exact initramfs")
	}
	data, _ = os.ReadFile(filepath.Join(filepath.Dir(entries), "grub.cfg"))
	if string(data) != "known working default\n" {
		t.Fatal("default changed")
	}
	if _, err = publish(stage, set, entries, "ABCD-1234", "root=UUID=test rw", b); err == nil {
		t.Fatal("overwrote existing entry")
	}
}

func TestIncompleteCopyNeverPublishes(t *testing.T) {
	for _, kind := range []string{"hash", "missing", "symlink"} {
		t.Run(kind, func(t *testing.T) {
			stage, set, entries, b := fixture(t)
			initrd := filepath.Join(stage, "initramfs.img")
			switch kind {
			case "hash":
				b.InitrdHash = strings.Repeat("0", 64)
			case "missing":
				if err := os.Remove(initrd); err != nil {
					t.Fatal(err)
				}
			case "symlink":
				if err := os.Rename(initrd, initrd+".real"); err != nil {
					t.Fatal(err)
				}
				if err := os.Symlink(initrd+".real", initrd); err != nil {
					t.Fatal(err)
				}
			}
			if _, err := publish(stage, set, entries, "ABCD-1234", "root=UUID=test", b); err == nil {
				t.Fatal("accepted bad initramfs")
			}
			contents, err := os.ReadDir(entries)
			if err != nil || len(contents) != 0 {
				t.Fatalf("partial entry exposed: %v %v", contents, err)
			}
			data, _ := os.ReadFile(filepath.Join(filepath.Dir(entries), "grub.cfg"))
			if string(data) != "known working default\n" {
				t.Fatal("default changed")
			}
		})
	}
}

func TestRejectIdentityAndConfigSubstitution(t *testing.T) {
	stage, _, _, b := fixture(t)
	if err := os.WriteFile(filepath.Join(stage, "boot-set"), []byte("other\n"), 0644); err != nil {
		t.Fatal(err)
	}
	if _, err := readBuild(stage); err == nil {
		t.Fatal("accepted different embedded identity")
	}
	for _, cmd := range []string{"quiet", "root=x\nreboot", "root=x;reboot", "root='x'"} {
		if _, err := entryConfig(b, "ABCD-1234", cmd); err == nil {
			t.Fatalf("accepted %q", cmd)
		}
	}
}
