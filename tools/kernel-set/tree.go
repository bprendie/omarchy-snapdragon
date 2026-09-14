package main

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

type entry struct {
	Path   string `json:"path"`
	Mode   uint32 `json:"mode"`
	SHA256 string `json:"sha256,omitempty"`
	Link   string `json:"link,omitempty"`
}

func hashFile(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err = io.Copy(h, f); err != nil {
		return "", err
	}
	return fmt.Sprintf("%x", h.Sum(nil)), nil
}

func inventory(root string) ([]entry, error) {
	return inventoryExcept(root, "")
}

func inventoryExcept(root, exclude string) ([]entry, error) {
	info, err := os.Lstat(root)
	if err != nil {
		return nil, err
	}
	if !info.IsDir() {
		return nil, fmt.Errorf("payload root must be a directory")
	}
	var entries []entry
	err = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if path == root {
			return nil
		}
		rel, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		if rel == exclude {
			return nil
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		e := entry{Path: rel, Mode: uint32(info.Mode())}
		switch {
		case info.Mode().IsRegular():
			e.SHA256, err = hashFile(path)
		case info.IsDir():
		case info.Mode()&os.ModeSymlink != 0:
			e.Link, err = os.Readlink(path)
			resolved := filepath.Clean(filepath.Join(filepath.Dir(rel), e.Link))
			if filepath.IsAbs(e.Link) || resolved == ".." || strings.HasPrefix(resolved, "../") {
				return fmt.Errorf("link escapes payload: %s", rel)
			}
		default:
			return fmt.Errorf("unsupported file type: %s", rel)
		}
		if err != nil {
			return err
		}
		entries = append(entries, e)
		return nil
	})
	return entries, err
}

func writeJSON(path string, value any) error {
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, append(data, '\n'), 0644)
}
