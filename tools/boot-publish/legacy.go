package main

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const legacyMarker = "# Managed by oma-snap boot selection with legacy fallback v1\n"
const legacyRelease = "7.0.0-31-generic"

type legacyRecord struct {
	Schema int    `json:"schema"`
	Config string `json:"config_sha256"`
	Kernel string `json:"kernel_sha256"`
	Initrd string `json:"initramfs_sha256"`
}

func regularBytes(path string) ([]byte, error) {
	resolved, err := filepath.EvalSymlinks(path)
	if err != nil || resolved != path {
		return nil, fmt.Errorf("missing or substituted legacy file: %s", path)
	}
	info, err := os.Lstat(path)
	if err != nil || !info.Mode().IsRegular() {
		return nil, fmt.Errorf("non-regular legacy file: %s", path)
	}
	return os.ReadFile(path)
}

func bytesHash(data []byte) string { return fmt.Sprintf("%x", sha256.Sum256(data)) }

// Accept only the released installer's exact generated layout. Custom menus
// require separate migration review instead of interpreting arbitrary GRUB.
func releasedMenu(uuid, cmdline string) (string, error) {
	if _, err := entryConfig(build{Entry: strings.Repeat("0", 64)}, uuid, cmdline); err != nil {
		return "", err
	}
	return fmt.Sprintf(`set timeout=5
search --no-floppy --fs-uuid --set=root %s
smbios --type 4 --get-string 5 --set proc_version
if regexp "Snapdragon.*" "$proc_version"; then
  if [ "$lockdown" != "y" ]; then
    cutmem 0x8800000000 0x8fffffffff
  fi
fi
menuentry 'Omarchy Snapdragon' {
  linux /oma-snap/%s/vmlinuz.efi %s clk_ignore_unused pd_ignore_unused arm64.nopauth quiet splash
  initrd /oma-snap/%s/initramfs.img
}
menuentry 'Firmware settings' { fwsetup }
`, uuid, legacyRelease, cmdline, legacyRelease), nil
}

func legacySnapshot(esp string) (legacyRecord, error) {
	r := legacyRecord{Schema: 1}
	for name, dest := range map[string]*string{"vmlinuz.efi": &r.Kernel, "initramfs.img": &r.Initrd} {
		data, err := regularBytes(filepath.Join(esp, "oma-snap", legacyRelease, name))
		if err != nil {
			return r, err
		}
		if len(data) == 0 {
			return r, fmt.Errorf("empty legacy boot payload")
		}
		*dest = bytesHash(data)
	}
	return r, nil
}

func saveLegacy(esp string, config []byte) error {
	r, err := legacySnapshot(esp)
	if err != nil {
		return err
	}
	r.Config = bytesHash(config)
	parent := filepath.Join(esp, "oma-snap/grub")
	dest := filepath.Join(parent, "legacy")
	if _, err = os.Lstat(dest); err == nil {
		old, err := readLegacy(esp)
		if err != nil || string(old) != string(config) {
			return fmt.Errorf("existing legacy snapshot differs or is invalid")
		}
		return nil
	} else if !os.IsNotExist(err) {
		return err
	}
	scratch, err := os.MkdirTemp(parent, ".legacy-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(scratch)
	data, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		return err
	}
	if err = syncedWrite(filepath.Join(scratch, "grub.cfg"), config); err != nil {
		return err
	}
	if err = syncedWrite(filepath.Join(scratch, "legacy.json"), data); err != nil {
		return err
	}
	if err = syncDir(scratch); err != nil {
		return err
	}
	if err = os.Rename(scratch, dest); err != nil {
		return err
	}
	return syncDir(parent)
}

func readLegacy(esp string) ([]byte, error) {
	dir := filepath.Join(esp, "oma-snap/grub/legacy")
	data, err := regularBytes(filepath.Join(dir, "legacy.json"))
	if err != nil {
		return nil, err
	}
	var r legacyRecord
	if err = json.Unmarshal(data, &r); err != nil {
		return nil, err
	}
	actual, err := legacySnapshot(esp)
	if err != nil {
		return nil, err
	}
	config, err := regularBytes(filepath.Join(dir, "grub.cfg"))
	if err != nil {
		return nil, err
	}
	if r.Schema != 1 || r.Kernel != actual.Kernel || r.Initrd != actual.Initrd || r.Config != bytesHash(config) {
		return nil, fmt.Errorf("retained legacy boot changed")
	}
	return config, nil
}
