package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func legacyDependencies() error {
	packages := []string{"oma-snap-kernel-ubuntu", "oma-snap-camera-hp", "oma-snap-audio-hp", "oma-snap-firmware-ubuntu", "oma-snap-firmware-hp", "oma-snap-firmware-t14s-npu", "oma-snap-firmware-asus-a14", "oma-snap-boot"}
	if output, err := exec.Command("pacman", append([]string{"-Q"}, packages...)...).CombinedOutput(); err != nil {
		return fmt.Errorf("legacy recovery packages missing: %w: %s", err, output)
	}
	data, err := regularBytes("/usr/share/libalpm/hooks/02-oma-snap-retain-legacy.hook")
	if err != nil {
		return err
	}
	required := []string{"Operation = Remove", "Operation = Upgrade", "Type = Package", "When = PreTransaction", "AbortOnFail", "NeedsTargets", "Exec = /usr/bin/oma-snap-kernel-retain --legacy"}
	for _, name := range packages {
		required = append(required, "Target = "+name)
	}
	for _, line := range required {
		want := line + "\n"
		if !strings.Contains(string(data), want) {
			return fmt.Errorf("legacy retention hook incomplete")
		}
	}
	// A higher-priority hook can mask the packaged guard, including /dev/null.
	output, err := exec.Command("pacman-conf", "HookDir").Output()
	if err != nil {
		return fmt.Errorf("cannot inspect pacman hook overrides: %w", err)
	}
	for _, dir := range strings.Fields(string(output)) {
		if _, err := os.Lstat(filepath.Join(dir, "02-oma-snap-retain-legacy.hook")); !os.IsNotExist(err) {
			return fmt.Errorf("legacy retention hook override requires review")
		}
	}
	return nil
}

func selectLegacyMenu(esp, uuid, cmdline, selected, fallback string, migrate bool, verify func(build) error) error {
	if (selected == "legacy") == (fallback == "legacy") {
		return fmt.Errorf("legacy selection requires exactly one legacy entry")
	}
	if migrate && selected != "legacy" {
		return fmt.Errorf("migration must keep legacy as the default")
	}
	id := selected
	if id == "legacy" {
		id = fallback
	}
	b, err := readEntry(esp, id)
	if err != nil {
		return err
	}
	if err = verify(b); err != nil {
		return err
	}
	entry, err := entryConfig(b, uuid, cmdline)
	if err != nil {
		return err
	}
	path := filepath.Join(esp, "oma-snap/grub/grub.cfg")
	old, err := regularBytes(path)
	if err != nil {
		return err
	}
	if migrate {
		expected, err := releasedMenu(uuid, cmdline)
		if err != nil {
			return err
		}
		if string(old) != expected {
			return fmt.Errorf("legacy menu differs from the released installer layout")
		}
		if err = saveLegacy(esp, old); err != nil {
			return err
		}
	} else if !strings.HasPrefix(string(old), legacyMarker) {
		return fmt.Errorf("explicit legacy migration required")
	}
	if _, err = readLegacy(esp); err != nil {
		return err
	}
	config := legacyMarker + "set timeout=5\nset default=oma-snap-" + selected + "\n"
	config += `smbios --type 4 --get-string 5 --set proc_version
if regexp "Snapdragon.*" "$proc_version"; then
  if [ "$lockdown" != "y" ]; then
    cutmem 0x8800000000 0x8fffffffff
  fi
fi
`
	config += legacyMenuEntry(uuid)
	config += entry + "menuentry 'Firmware settings' { fwsetup }\n"
	dir := filepath.Dir(path)
	scratch, err := os.MkdirTemp(dir, ".legacy-selection-")
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
	fmt.Printf("Selected %s; retained %s and verified released boot\n", selected, fallback)
	return nil
}

func legacyMenuEntry(uuid string) string {
	return fmt.Sprintf("menuentry 'Omarchy Snapdragon (released legacy boot)' --id 'oma-snap-legacy' {\n  search --no-floppy --fs-uuid --set=root %s\n  set default=0\n  configfile /oma-snap/grub/legacy/grub.cfg\n}\n", uuid)
}
