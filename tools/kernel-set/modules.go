package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

func indexModules(payload, release string) error {
	absolute, err := filepath.Abs(payload)
	if err != nil {
		return err
	}
	// A private basedir and explicit module directory keep host modules untouched.
	result, err := exec.Command("depmod", "-b", absolute, "-m", "/modules", release).CombinedOutput()
	if err != nil {
		return fmt.Errorf("candidate depmod: %w: %s", err, result)
	}
	if len(result) != 0 {
		return fmt.Errorf("candidate depmod diagnostics require review: %s", result)
	}
	for _, name := range []string{"modules.dep.bin", "modules.alias.bin", "modules.symbols.bin"} {
		info, err := os.Stat(filepath.Join(absolute, "modules", release, name))
		if err != nil {
			return err
		}
		if !info.Mode().IsRegular() || info.Size() == 0 {
			return fmt.Errorf("invalid module index: %s", name)
		}
	}
	return nil
}
