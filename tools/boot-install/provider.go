package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// Run synchronously in the mounted target: systemd services cannot prepare a
// target chroot. The already-created released boot remains available as fallback.
func initializeProvider(target, esp string, execute func(string, ...string) error) error {
	path := filepath.Join(target, "usr/share/oma-snap/kernel-provider/candidate.json")
	if _, err := os.Lstat(path); os.IsNotExist(err) {
		return nil
	} else if err != nil {
		return err
	}
	data, err := regularProviderFile(path)
	if err != nil {
		return err
	}
	var provider struct {
		Schema   int    `json:"schema"`
		Status   string `json:"status"`
		Channel  string `json:"channel"`
		Sequence uint64 `json:"sequence"`
		ID       string `json:"hardware_set"`
		Release  string `json:"kernel_release"`
	}
	if err = json.Unmarshal(data, &provider); err != nil {
		return err
	}
	validID := regexp.MustCompile(`^[a-f0-9]{64}$`)
	if provider.Schema != 1 || provider.Status != "approved" || provider.Sequence == 0 || !validID.MatchString(provider.ID) || provider.Release == "" {
		return fmt.Errorf("installer requires an approved kernel provider")
	}
	channel := "stable"
	channelPath := filepath.Join(target, "etc/oma-snap/kernel-channel")
	if _, err = os.Lstat(channelPath); err == nil {
		data, err = regularProviderFile(channelPath)
		if err != nil {
			return err
		}
		channel = strings.TrimSpace(string(data))
	} else if !os.IsNotExist(err) {
		return err
	}
	if (channel != "testing" && channel != "stable") || channel != provider.Channel {
		return fmt.Errorf("installer kernel approval/channel mismatch")
	}
	if err = os.MkdirAll(filepath.Join(target, "etc/oma-snap"), 0755); err != nil {
		return err
	}
	if err = os.WriteFile(filepath.Join(target, "etc/oma-snap/esp-path"), []byte(esp+"\n"), 0644); err != nil {
		return err
	}
	chroot := func(args ...string) error { return execute("arch-chroot", append([]string{target}, args...)...) }
	if err = chroot("oma-snap-kernel-queue", "--process"); err != nil {
		return err
	}
	if err = chroot("oma-snap-kernel-queue", "--check-provider-prepared"); err != nil {
		return err
	}
	data, err = regularProviderFile(filepath.Join(target, "var/lib/oma-snap/jobs/complete", provider.ID+".json"))
	if err != nil {
		return err
	}
	var job struct {
		ID    string `json:"hardware_set"`
		Entry string `json:"boot_entry"`
		Error string `json:"error"`
	}
	if err = json.Unmarshal(data, &job); err != nil {
		return err
	}
	if job.ID != provider.ID || !validID.MatchString(job.Entry) || job.Error != "" {
		return fmt.Errorf("invalid installed provider job")
	}
	data, err = regularProviderFile(filepath.Join(target, esp, "oma-snap/entries", job.Entry, "entry.json"))
	if err != nil {
		return err
	}
	var entry struct {
		ID      string `json:"hardware_set"`
		Release string `json:"kernel_release"`
	}
	if err = json.Unmarshal(data, &entry); err != nil {
		return err
	}
	if entry.ID != provider.ID || entry.Release != provider.Release {
		return fmt.Errorf("installed entry differs from approved provider")
	}
	if err = chroot("oma-snap-boot-publish", "--esp", esp, "--migrate-legacy", "--select", "legacy", "--fallback", job.Entry); err != nil {
		return err
	}
	return chroot("oma-snap-boot-publish", "--esp", esp, "--select", job.Entry, "--fallback", "legacy")
}

func regularProviderFile(path string) ([]byte, error) {
	resolved, err := filepath.EvalSymlinks(path)
	if err != nil || resolved != path {
		return nil, fmt.Errorf("missing or substituted provider file: %s", path)
	}
	info, err := os.Lstat(path)
	if err != nil {
		return nil, err
	}
	if !info.Mode().IsRegular() {
		return nil, fmt.Errorf("not a regular provider file: %s", path)
	}
	return os.ReadFile(path)
}
