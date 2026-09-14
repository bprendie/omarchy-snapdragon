package main

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"reflect"
)

// Merge only byte-identical collisions. No package order may silently replace
// another model's firmware. Hard links preserve bytes without a second copy.
func mergeFirmware(source, destination string) error {
	entries, err := inventory(source)
	if err != nil {
		return err
	}
	if err = os.MkdirAll(destination, 0755); err != nil {
		return err
	}
	for _, e := range entries {
		from, to := filepath.Join(source, e.Path), filepath.Join(destination, e.Path)
		mode := fs.FileMode(e.Mode)
		if mode.IsDir() {
			if info, err := os.Lstat(to); err == nil {
				if !info.IsDir() || info.Mode() != mode {
					return fmt.Errorf("firmware directory collision: %s", e.Path)
				}
			} else if !os.IsNotExist(err) {
				return err
			}
			if err = os.MkdirAll(to, mode.Perm()); err != nil {
				return err
			}
			continue
		}
		if info, err := os.Lstat(to); err == nil {
			actual := entry{Path: e.Path, Mode: uint32(info.Mode())}
			if info.Mode().IsRegular() {
				actual.SHA256, err = hashFile(to)
			}
			if info.Mode()&os.ModeSymlink != 0 {
				actual.Link, err = os.Readlink(to)
			}
			if err != nil {
				return err
			}
			if !reflect.DeepEqual(e, actual) {
				return fmt.Errorf("firmware payload collision: %s", e.Path)
			}
			continue
		} else if !os.IsNotExist(err) {
			return err
		}
		if mode.IsRegular() {
			err = os.Link(from, to)
		} else {
			err = os.Symlink(e.Link, to)
		}
		if err != nil {
			return err
		}
	}
	return nil
}

func normalizeFirmware(payload, release string) error {
	packages, err := os.ReadDir(filepath.Join(payload, "firmware-packages"))
	if err != nil {
		return err
	}
	for _, pkg := range packages {
		root := filepath.Join(payload, "firmware-packages", pkg.Name(), "usr/lib/firmware")
		namespaces, err := os.ReadDir(root)
		if err != nil {
			return err
		}
		if len(namespaces) != 1 || !namespaces[0].IsDir() {
			return fmt.Errorf("expected one firmware namespace in %s", pkg.Name())
		}
		if err = mergeFirmware(filepath.Join(root, namespaces[0].Name()), filepath.Join(payload, "firmware", release)); err != nil {
			return err
		}
	}
	return nil
}
