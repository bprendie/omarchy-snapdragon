// Package bootlock coordinates boot mutations with pacman's database lock.
package bootlock

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type Lock struct {
	file *os.File
	path string
}

func AcquireSystem() (*Lock, error) {
	path, err := systemPath()
	if err != nil {
		return nil, err
	}
	return Acquire(path)
}

func systemPath() (string, error) {
	output, err := exec.Command("pacman-conf", "DBPath").Output()
	if err != nil {
		return "", fmt.Errorf("read pacman database path: %w", err)
	}
	path := strings.TrimSpace(string(output))
	if !filepath.IsAbs(path) || strings.ContainsAny(path, "\n\r") {
		return "", fmt.Errorf("invalid pacman database path")
	}
	path = filepath.Clean(path)
	resolved, err := filepath.EvalSymlinks(path)
	if err != nil || resolved != path {
		return "", fmt.Errorf("missing or substituted pacman database directory")
	}
	return filepath.Join(path, "db.lck"), nil
}

func Acquire(path string) (*Lock, error) {
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0644)
	if err != nil {
		return nil, fmt.Errorf("cannot reserve pacman database; an existing lock is never removed automatically: %w", err)
	}
	lock := &Lock{file: f, path: path}
	if _, err = fmt.Fprintf(f, "oma-snap boot operation pid=%d\n", os.Getpid()); err != nil {
		_ = lock.Close()
		return nil, err
	}
	return lock, nil
}

func (l *Lock) Close() error {
	if l.file == nil {
		return nil
	}
	defer func() { _ = l.file.Close(); l.file = nil }()
	ours, err := l.file.Stat()
	if err != nil {
		return err
	}
	current, err := os.Lstat(l.path)
	if err != nil {
		return fmt.Errorf("boot-operation lock disappeared: %w", err)
	}
	if !os.SameFile(ours, current) {
		return fmt.Errorf("boot-operation lock was replaced; refusing to remove another lock")
	}
	return os.Remove(l.path)
}
