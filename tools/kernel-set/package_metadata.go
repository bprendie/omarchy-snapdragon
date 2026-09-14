package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Pacman/makepkg reserve these archive basenames. Preserve source-package
// metadata as ordinary files so the installed payload matches its inventory.
func copyFirmwarePackage(source, destination string) error {
	if err := copyPath(source, destination); err != nil {
		return err
	}
	metadata := filepath.Join(destination, "package-metadata")
	if _, err := os.Lstat(metadata); !os.IsNotExist(err) {
		return fmt.Errorf("firmware package metadata destination already exists or is inaccessible")
	}
	created := false
	for _, name := range []string{".PKGINFO", ".BUILDINFO", ".MTREE", ".INSTALL", ".CHANGELOG"} {
		from := filepath.Join(destination, name)
		info, err := os.Lstat(from)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return err
		}
		if !info.Mode().IsRegular() {
			return fmt.Errorf("non-regular firmware package metadata: %s", name)
		}
		if !created {
			if err = os.Mkdir(metadata, 0755); err != nil {
				return err
			}
			created = true
		}
		if err = os.Rename(from, filepath.Join(metadata, strings.TrimPrefix(name, "."))); err != nil {
			return err
		}
	}
	return nil
}
