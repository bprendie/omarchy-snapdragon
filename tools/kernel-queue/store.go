package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"syscall"
)

var validID = regexp.MustCompile(`^[a-f0-9]{64}$`)
var states = []string{"pending", "running", "failed", "complete"}

type job struct {
	Schema int    `json:"schema"`
	ID     string `json:"hardware_set"`
	Work   string `json:"work_directory,omitempty"`
	Entry  string `json:"boot_entry,omitempty"`
	Error  string `json:"error,omitempty"`
}

type store struct{ root string }

func syncDirectory(path string) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	return f.Sync()
}

func (s store) initialize() error {
	for _, dir := range append(append([]string{}, states...), "work") {
		path := filepath.Join(s.root, dir)
		if err := os.MkdirAll(path, 0755); err != nil {
			return err
		}
		resolved, err := filepath.EvalSymlinks(path)
		if err != nil || resolved != path {
			return fmt.Errorf("substituted queue directory")
		}
	}
	return syncDirectory(s.root)
}

func (s store) locked(fn func() error) error {
	f, err := os.OpenFile(filepath.Join(s.root, "queue.lock"), os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return err
	}
	defer f.Close()
	if err = syscall.Flock(int(f.Fd()), syscall.LOCK_EX); err != nil {
		return err
	}
	return fn()
}

func (s store) path(state, id string) string { return filepath.Join(s.root, state, id+".json") }

func (s store) read(state, id string) (job, error) {
	var j job
	path := s.path(state, id)
	info, err := os.Lstat(path)
	if err != nil {
		return j, err
	}
	if !info.Mode().IsRegular() {
		return j, fmt.Errorf("substituted queue job")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return j, err
	}
	if err = json.Unmarshal(data, &j); err != nil {
		return j, err
	}
	if j.Schema != 1 || j.ID != id || !validID.MatchString(j.ID) {
		return j, fmt.Errorf("invalid queue job")
	}
	return j, nil
}

func (s store) write(state string, j job) error {
	data, err := json.MarshalIndent(j, "", "  ")
	if err != nil {
		return err
	}
	dir := filepath.Join(s.root, state)
	f, err := os.CreateTemp(dir, ".job-")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	defer f.Close()
	if err = f.Chmod(0644); err != nil {
		return err
	}
	if _, err = f.Write(append(data, '\n')); err != nil {
		return err
	}
	if err = f.Sync(); err != nil {
		return err
	}
	if err = f.Close(); err != nil {
		return err
	}
	if err = os.Rename(f.Name(), s.path(state, j.ID)); err != nil {
		return err
	}
	return syncDirectory(dir)
}

func (s store) move(from, to, id string) error {
	if _, err := os.Lstat(s.path(to, id)); !os.IsNotExist(err) {
		return fmt.Errorf("destination job already exists or is inaccessible")
	}
	if err := os.Rename(s.path(from, id), s.path(to, id)); err != nil {
		return err
	}
	if err := syncDirectory(filepath.Join(s.root, to)); err != nil {
		return err
	}
	return syncDirectory(filepath.Join(s.root, from))
}

func (s store) enqueue(id string, retry bool) error {
	from := ""
	if retry {
		from = "failed"
	}
	return s.request(id, from)
}

// Moving a completed record back to pending requests a fresh boot entry while
// preserving the published entry and prior work directory on disk.
func (s store) request(id, from string) error {
	if from != "" && from != "failed" && from != "complete" {
		return fmt.Errorf("invalid requeue source")
	}
	if !validID.MatchString(id) {
		return fmt.Errorf("invalid hardware set identity")
	}
	return s.locked(func() error {
		found := ""
		for _, state := range states {
			if _, err := os.Lstat(s.path(state, id)); err == nil {
				if found != "" {
					return fmt.Errorf("duplicate job state requires inspection")
				}
				if _, err = s.read(state, id); err != nil {
					return err
				}
				found = state
			} else if !os.IsNotExist(err) {
				return err
			}
		}
		if from != "" {
			if found != from {
				return fmt.Errorf("requeue requires a %s job", from)
			}
			return s.move(from, "pending", id)
		}
		if found != "" {
			return nil
		}
		return s.write("pending", job{Schema: 1, ID: id})
	})
}

func (s store) list(state string) ([]string, error) {
	entries, err := os.ReadDir(filepath.Join(s.root, state))
	if err != nil {
		return nil, err
	}
	var ids []string
	for _, entry := range entries {
		if len(entry.Name()) > 0 && entry.Name()[0] == '.' {
			continue
		}
		id := entry.Name()
		if len(id) != 69 || filepath.Ext(id) != ".json" || !validID.MatchString(id[:64]) {
			return nil, fmt.Errorf("invalid queue entry: %s", id)
		}
		if _, err = s.read(state, id[:64]); err != nil {
			return nil, err
		}
		ids = append(ids, id[:64])
	}
	return ids, nil
}
