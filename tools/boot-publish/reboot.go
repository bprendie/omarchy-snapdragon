package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// This reports selection versus runtime identity, not candidate validation.
func rebootStatus(esp, uuid, cmdline, runningPath, runningRelease string) (string, error) {
	data, err := regularBytes(filepath.Join(esp, "oma-snap/grub/grub.cfg"))
	if err != nil {
		return "", err
	}
	menu := string(data)
	selected := ""
	if strings.HasPrefix(menu, menuMarker) || strings.HasPrefix(menu, legacyMarker) {
		for _, line := range strings.Split(menu, "\n") {
			if strings.HasPrefix(line, "set default=") {
				if selected != "" {
					return "", fmt.Errorf("multiple selected boot entries")
				}
				selected = strings.TrimPrefix(line, "set default=oma-snap-")
			}
		}
		if selected != "legacy" && !hexID.MatchString(selected) {
			return "", fmt.Errorf("invalid selected boot entry")
		}
		if !strings.Contains(menu, "--id 'oma-snap-"+selected+"'") {
			return "", fmt.Errorf("selected boot entry missing from menu")
		}
	} else {
		expected, err := releasedMenu(uuid, cmdline)
		if err != nil || menu != expected {
			return "", fmt.Errorf("unrecognized boot menu; cannot determine reboot status")
		}
		selected = "legacy"
	}
	running := "legacy"
	if _, err := os.Lstat(runningPath); err == nil {
		identity, err := regularBytes(runningPath)
		if err != nil {
			return "", err
		}
		running = strings.TrimSpace(string(identity))
		if !hexID.MatchString(running) {
			return "", fmt.Errorf("invalid running boot identity")
		}
	} else if !os.IsNotExist(err) {
		return "", err
	} else if runningRelease != legacyRelease {
		return "required", nil
	}
	if running != selected {
		return "required", nil
	}
	return "current", nil
}
