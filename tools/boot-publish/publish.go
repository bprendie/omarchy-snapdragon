package main

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

type build struct {
	Schema     int    `json:"schema"`
	Status     string `json:"status"`
	Hardware   string `json:"hardware_set"`
	Entry      string `json:"boot_entry"`
	Release    string `json:"kernel_release"`
	KernelHash string `json:"kernel_sha256"`
	InitrdHash string `json:"initramfs_sha256"`
}

var hexID = regexp.MustCompile(`^[a-f0-9]{64}$`)

func (b build) validIdentity() bool {
	return b.Schema == 1 && hexID.MatchString(b.Hardware) && hexID.MatchString(b.Entry) && hexID.MatchString(b.KernelHash) && hexID.MatchString(b.InitrdHash) && regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-(generic|qcom-x1e)$`).MatchString(b.Release)
}

func readBuild(stage string) (build, error) {
	var b build
	data, err := os.ReadFile(filepath.Join(stage, "built.json"))
	if err != nil {
		return b, err
	}
	if err = json.Unmarshal(data, &b); err != nil {
		return b, err
	}
	if !b.validIdentity() || b.Status != "built-unvalidated" {
		return b, fmt.Errorf("invalid staging manifest")
	}
	identity, err := os.ReadFile(filepath.Join(stage, "boot-set"))
	if err != nil {
		return b, err
	}
	if string(identity) != b.Hardware+"\n"+b.Release+"\n"+b.Entry+"\n" {
		return b, fmt.Errorf("staging identity mismatch")
	}
	return b, nil
}

func verifiedCopy(source, dest, expected string) error {
	info, err := os.Lstat(source)
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() {
		return fmt.Errorf("non-regular input: %s", source)
	}
	in, err := os.Open(source)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(dest, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0644)
	if err != nil {
		return err
	}
	defer out.Close()
	h := sha256.New()
	if _, err = io.Copy(io.MultiWriter(out, h), in); err != nil {
		return err
	}
	if fmt.Sprintf("%x", h.Sum(nil)) != expected {
		return fmt.Errorf("payload hash mismatch: %s", source)
	}
	if err = out.Sync(); err != nil {
		return err
	}
	return out.Close()
}

func syncedWrite(path string, data []byte) error {
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0644)
	if err != nil {
		return err
	}
	defer f.Close()
	if _, err = f.Write(data); err != nil {
		return err
	}
	return f.Sync()
}

func syncDir(path string) error {
	d, err := os.Open(path)
	if err != nil {
		return err
	}
	defer d.Close()
	return d.Sync()
}

func entryConfig(b build, uuid, cmdline string) (string, error) {
	if !regexp.MustCompile(`^[a-zA-Z0-9-]+$`).MatchString(uuid) || !regexp.MustCompile(`^[a-zA-Z0-9_./:=,@+% -]+$`).MatchString(cmdline) {
		return "", fmt.Errorf("unsafe GRUB input")
	}
	hasRoot := false
	for _, word := range strings.Fields(cmdline) {
		if strings.HasPrefix(word, "root=") && len(word) > 5 {
			hasRoot = true
		}
	}
	if !hasRoot {
		return "", fmt.Errorf("missing root device")
	}
	path := "/oma-snap/entries/" + b.Entry
	return fmt.Sprintf("menuentry 'Omarchy Snapdragon %s (%s)' --id 'oma-snap-%s' {\n  search --no-floppy --fs-uuid --set=root %s\n  linux %s/vmlinuz.efi %s clk_ignore_unused pd_ignore_unused arm64.nopauth quiet splash\n  initrd %s/initramfs.img\n}\n", b.Release, b.Entry[:12], b.Entry, uuid, path, cmdline, path), nil
}

// A failed copy cannot expose a selectable entry. Renaming into entries is the
// last publication step; choosing a default remains a separate operation.
func publish(stage, set, entries, uuid, cmdline string, b build) (string, error) {
	cfg, err := entryConfig(b, uuid, cmdline)
	if err != nil {
		return "", err
	}
	if err = os.MkdirAll(entries, 0755); err != nil {
		return "", err
	}
	resolved, err := filepath.EvalSymlinks(entries)
	if err != nil || resolved != entries {
		return "", fmt.Errorf("substituted entries directory")
	}
	dest := filepath.Join(entries, b.Entry)
	if _, err = os.Lstat(dest); !os.IsNotExist(err) {
		return "", fmt.Errorf("entry already exists or is inaccessible")
	}
	scratch, err := os.MkdirTemp(entries, ".incomplete-")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(scratch)
	for _, p := range []struct{ source, name, hash string }{
		{filepath.Join(set, "vmlinuz.efi"), "vmlinuz.efi", b.KernelHash},
		{filepath.Join(stage, "initramfs.img"), "initramfs.img", b.InitrdHash},
	} {
		if err = verifiedCopy(p.source, filepath.Join(scratch, p.name), p.hash); err != nil {
			return "", err
		}
	}
	if err = syncedWrite(filepath.Join(scratch, "entry.cfg"), []byte(cfg)); err != nil {
		return "", err
	}
	b.Status = "published-unselected-unvalidated"
	data, err := json.MarshalIndent(b, "", "  ")
	if err != nil {
		return "", err
	}
	if err = syncedWrite(filepath.Join(scratch, "entry.json"), append(data, '\n')); err != nil {
		return "", err
	}
	if err = syncDir(scratch); err != nil {
		return "", err
	}
	if err = os.Rename(scratch, dest); err != nil {
		return "", err
	}
	if err = syncDir(entries); err != nil {
		return "", err
	}
	return dest, nil
}
