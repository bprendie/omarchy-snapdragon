package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
)

var identity = regexp.MustCompile(`^[a-f0-9]{64}$`)
var releaseName = regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-generic$`)

func retainedReleases(root string) (map[string]bool, error) {
	result := map[string]bool{}
	info, err := os.Lstat(root)
	if os.IsNotExist(err) {
		return result, nil
	}
	if err != nil {
		return nil, err
	}
	if !info.IsDir() {
		return nil, fmt.Errorf("invalid retained sets directory")
	}
	entries, err := os.ReadDir(root)
	if err != nil {
		return nil, err
	}
	resolved, err := filepath.EvalSymlinks(root)
	if err != nil || resolved != root {
		return nil, fmt.Errorf("substituted retained sets directory")
	}
	for _, entry := range entries {
		if !identity.MatchString(entry.Name()) || !entry.IsDir() {
			return nil, fmt.Errorf("invalid retained set directory: %s", entry.Name())
		}
		path := filepath.Join(root, entry.Name(), "set.json")
		info, err := os.Lstat(path)
		if err != nil || !info.Mode().IsRegular() {
			return nil, fmt.Errorf("missing or substituted retained manifest: %s", path)
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return nil, err
		}
		var m struct {
			Schema  int    `json:"schema"`
			ID      string `json:"id"`
			Release string `json:"kernel_release"`
		}
		if err = json.Unmarshal(data, &m); err != nil {
			return nil, err
		}
		if m.Schema != 1 || m.ID != entry.Name() || !releaseName.MatchString(m.Release) {
			return nil, fmt.Errorf("invalid retained manifest identity")
		}
		result[m.Release] = true
	}
	return result, nil
}

// Existing bind mounts are left untouched. Creation covers empty mountpoints
// removed by a legacy package transaction, including the firmware mountpoint.
func ensureMountpoints(lib string, releases map[string]bool) error {
	for release := range releases {
		for _, kind := range []string{"modules", "firmware"} {
			parent := filepath.Join(lib, kind)
			resolved, err := filepath.EvalSymlinks(parent)
			if err != nil || resolved != parent {
				return fmt.Errorf("missing or substituted %s parent", kind)
			}
			path := filepath.Join(parent, release)
			if err = os.MkdirAll(path, 0755); err != nil {
				return err
			}
			resolved, err = filepath.EvalSymlinks(path)
			if err != nil || resolved != path {
				return fmt.Errorf("substituted %s mountpoint", kind)
			}
		}
	}
	return nil
}
