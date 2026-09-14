package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

// These packages supply the released v0.1.2 boot's kernel, modules, firmware,
// and boot preparation. Preserve them until the legacy boot is retired.
var legacyPackages = map[string]bool{
	"oma-snap-kernel-ubuntu":     true,
	"oma-snap-camera-hp":         true,
	"oma-snap-audio-hp":          true,
	"oma-snap-firmware-ubuntu":   true,
	"oma-snap-firmware-hp":       true,
	"oma-snap-firmware-t14s-npu": true,
	"oma-snap-firmware-asus-a14": true,
	"oma-snap-boot":              true,
}

func checkLegacyTargets(input io.Reader, payload string) error {
	parent := filepath.Dir(payload)
	resolved, err := filepath.EvalSymlinks(parent)
	if err != nil || resolved != parent {
		return fmt.Errorf("missing or substituted legacy boot parent")
	}
	retained := false
	info, err := os.Lstat(payload)
	if err == nil {
		resolved, resolveErr := filepath.EvalSymlinks(payload)
		if !info.IsDir() || resolveErr != nil || resolved != payload {
			return fmt.Errorf("substituted legacy boot directory")
		}
		// An incomplete directory still protects packages: a missing boot file
		// is a repair condition, not authorization to destroy recovery inputs.
		retained = true
	} else if !os.IsNotExist(err) {
		return err
	}
	scanner := bufio.NewScanner(input)
	count := 0
	for scanner.Scan() {
		target := scanner.Text()
		if !legacyPackages[target] {
			return fmt.Errorf("unexpected legacy retention target: %q", target)
		}
		count++
		if retained {
			return fmt.Errorf("cannot remove or replace %s: released legacy boot remains at %s", target, payload)
		}
	}
	if err := scanner.Err(); err != nil {
		return err
	}
	if count == 0 {
		return fmt.Errorf("missing ALPM transaction targets")
	}
	return nil
}
