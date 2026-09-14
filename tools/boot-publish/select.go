package main

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

const menuMarker = "# Managed by oma-snap boot selection v1\n"

func readEntry(esp, id string) (build, error) {
	var b build
	if !hexID.MatchString(id) {
		return b, fmt.Errorf("invalid entry ID")
	}
	dir := filepath.Join(esp, "oma-snap/entries", id)
	resolved, err := filepath.EvalSymlinks(dir)
	if err != nil || resolved != dir {
		return b, fmt.Errorf("substituted or missing entry")
	}
	info, err := os.Lstat(filepath.Join(dir, "entry.json"))
	if err != nil {
		return b, err
	}
	if !info.Mode().IsRegular() {
		return b, fmt.Errorf("non-regular entry manifest")
	}
	data, err := os.ReadFile(filepath.Join(dir, "entry.json"))
	if err != nil {
		return b, err
	}
	if err = json.Unmarshal(data, &b); err != nil {
		return b, err
	}
	if !b.validIdentity() || b.Entry != id || b.Status != "published-unselected-unvalidated" {
		return b, fmt.Errorf("invalid published entry")
	}
	for name, expected := range map[string]string{"vmlinuz.efi": b.KernelHash, "initramfs.img": b.InitrdHash} {
		path := filepath.Join(dir, name)
		info, err := os.Lstat(path)
		if err != nil {
			return b, err
		}
		if !info.Mode().IsRegular() {
			return b, fmt.Errorf("substituted boot payload")
		}
		f, err := os.Open(path)
		if err != nil {
			return b, err
		}
		h := sha256.New()
		_, err = io.Copy(h, f)
		closeErr := f.Close()
		if err != nil {
			return b, err
		}
		if closeErr != nil {
			return b, closeErr
		}
		if fmt.Sprintf("%x", h.Sum(nil)) != expected {
			return b, fmt.Errorf("published %s hash mismatch", name)
		}
	}
	return b, nil
}

func selectMenu(esp, uuid, cmdline, selected, fallback string, verify func(build) error) error {
	if selected == fallback {
		return fmt.Errorf("fallback must be a different entry")
	}
	var entries []build
	for _, id := range []string{selected, fallback} {
		b, err := readEntry(esp, id)
		if err != nil {
			return err
		}
		if err = verify(b); err != nil {
			return err
		}
		entries = append(entries, b)
	}
	config := menuMarker + "set timeout=5\nset default=oma-snap-" + selected + "\n"
	// Preserve the Snapdragon workaround used by the released installer loader.
	config += `smbios --type 4 --get-string 5 --set proc_version
if regexp "Snapdragon.*" "$proc_version"; then
  if [ "$lockdown" != "y" ]; then
    cutmem 0x8800000000 0x8fffffffff
  fi
fi
`
	for _, b := range entries {
		entry, err := entryConfig(b, uuid, cmdline)
		if err != nil {
			return err
		}
		config += entry
	}
	dir := filepath.Join(esp, "oma-snap/grub")
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	resolved, err := filepath.EvalSymlinks(dir)
	if err != nil || resolved != dir {
		return fmt.Errorf("substituted GRUB directory")
	}
	path := filepath.Join(dir, "grub.cfg")
	info, err := os.Lstat(path)
	if err == nil {
		if !info.Mode().IsRegular() {
			return fmt.Errorf("substituted GRUB configuration")
		}
		old, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		if strings.HasPrefix(string(old), legacyMarker) {
			if _, err := readLegacy(esp); err != nil {
				return err
			}
			config = strings.Replace(config, menuMarker, legacyMarker, 1)
			config += legacyMenuEntry(uuid)
		} else if !strings.HasPrefix(string(old), menuMarker) {
			return fmt.Errorf("existing loader requires explicit legacy migration")
		}
	} else if !os.IsNotExist(err) {
		return err
	}
	config += "menuentry 'Firmware settings' { fwsetup }\n"
	scratch, err := os.MkdirTemp(dir, ".selection-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(scratch)
	next := filepath.Join(scratch, "grub.cfg")
	if err = syncedWrite(next, []byte(config)); err != nil {
		return err
	}
	if err = syncDir(scratch); err != nil {
		return err
	}
	if err = os.Rename(next, path); err != nil {
		return err
	}
	if err = syncDir(dir); err != nil {
		return err
	}
	fmt.Printf("Selected %s; retained fallback %s\n", selected, fallback)
	return nil
}
