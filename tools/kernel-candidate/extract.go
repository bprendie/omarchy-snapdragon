package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
)

func extractCandidate(c candidate, dir, output string) error {
	if !regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-generic$`).MatchString(c.KernelRelease) {
		return fmt.Errorf("unsupported kernel release")
	}
	if err := os.Mkdir(output, 0755); err != nil {
		return err
	}
	root := filepath.Join(output, "root")
	controls := filepath.Join(output, "controls")
	for _, p := range []string{root, controls} {
		if err := os.Mkdir(p, 0755); err != nil {
			return err
		}
	}
	for _, a := range c.Artifacts {
		if !regexp.MustCompile(`^linux-[a-z0-9.+-]+$`).MatchString(a.Name) {
			return fmt.Errorf("unsafe package name")
		}
		path := filepath.Join(dir, "artifacts", filepath.Base(a.Filename))
		if err := checkFile(path, a.SHA256, a.Size); err != nil {
			return err
		}
		for _, args := range [][]string{{"--extract", path, root}, {"--control", path, filepath.Join(controls, a.Name)}} {
			if data, err := exec.Command("dpkg-deb", args...).CombinedOutput(); err != nil {
				return fmt.Errorf("dpkg-deb: %w: %s", err, data)
			}
		}
	}
	for _, p := range []string{"boot/vmlinuz-" + c.KernelRelease, "usr/lib/modules/" + c.KernelRelease, "usr/src/linux-headers-" + c.KernelRelease + "/Module.symvers"} {
		if _, err := os.Stat(filepath.Join(root, p)); err != nil {
			return err
		}
	}
	hash, err := fileHash(filepath.Join(root, "boot/vmlinuz-"+c.KernelRelease))
	if err != nil {
		return err
	}
	result := map[string]any{"schema": 1, "kernel_release": c.KernelRelease, "kernel_sha256": hash, "candidate": c, "maintainer_scripts_executed": false}
	data, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		return err
	}
	if err = os.WriteFile(filepath.Join(output, "extracted.json"), append(data, '\n'), 0644); err != nil {
		return err
	}
	fmt.Println("PASS: authenticated artifacts extracted; Debian maintainer scripts were not executed")
	return nil
}
