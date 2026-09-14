package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type activationPaths struct {
	ESP, UUID, Cmdline, Provider, Jobs, Runtime, State, Channel, Release string
}

type approvedProvider struct {
	Schema   int    `json:"schema"`
	Status   string `json:"status"`
	Channel  string `json:"channel"`
	Sequence uint64 `json:"sequence"`
	Hardware string `json:"hardware_set"`
	Release  string `json:"kernel_release"`
}

type activationRecord struct {
	Schema       int    `json:"schema"`
	Sequence     uint64 `json:"sequence"`
	ApprovalHash string `json:"approval_sha256"`
	Entry        string `json:"entry"`
	Fallback     string `json:"fallback"`
}

// Caller holds the shared pacman and boot-operation locks throughout.
func activateProvider(p activationPaths, verify func(build) error, legacyCheck func() error) error {
	if _, err := os.Lstat(p.Provider); os.IsNotExist(err) {
		return nil
	} else if err != nil {
		return err
	}
	data, err := regularBytes(p.Provider)
	if err != nil {
		return err
	}
	var provider approvedProvider
	if err = json.Unmarshal(data, &provider); err != nil {
		return err
	}
	if provider.Schema != 1 || !hexID.MatchString(provider.Hardware) {
		return fmt.Errorf("invalid provider metadata")
	}
	if provider.Status == "unvalidated" {
		return nil
	}
	if provider.Status != "approved" || provider.Sequence == 0 || provider.Release == "" {
		return fmt.Errorf("provider has no valid approval")
	}
	channel := "stable"
	if _, err := os.Lstat(p.Channel); err == nil {
		value, err := regularBytes(p.Channel)
		if err != nil {
			return err
		}
		channel = strings.TrimSpace(string(value))
	} else if !os.IsNotExist(err) {
		return err
	}
	if (channel != "stable" && channel != "testing") || provider.Channel != channel {
		return fmt.Errorf("provider approval channel does not match installed kernel channel")
	}
	approvalHash := bytesHash(data)
	if _, err := os.Lstat(p.State); err == nil {
		data, err := regularBytes(p.State)
		if err != nil {
			return err
		}
		var old activationRecord
		if err = json.Unmarshal(data, &old); err != nil {
			return err
		}
		if old.Schema != 1 || old.Sequence == 0 || !hexID.MatchString(old.ApprovalHash) || !hexID.MatchString(old.Entry) {
			return fmt.Errorf("invalid previous activation record")
		}
		if provider.Sequence < old.Sequence {
			return fmt.Errorf("provider sequence regressed")
		}
		if provider.Sequence == old.Sequence {
			if old.ApprovalHash != approvalHash {
				return fmt.Errorf("provider sequence reused with changed approval")
			}
			// Do not undo a deliberate manual rollback on the next updater call.
			return nil
		}
	} else if !os.IsNotExist(err) {
		return err
	}
	entry, err := preparedProviderEntry(p, provider)
	if err != nil {
		return err
	}
	b, err := readEntry(p.ESP, entry)
	if err != nil {
		return err
	}
	if b.Hardware != provider.Hardware || b.Release != provider.Release {
		return fmt.Errorf("prepared entry differs from approved provider")
	}
	if err = verify(b); err != nil {
		return err
	}
	running, err := runningFallback(p, verify)
	if err != nil {
		return err
	}
	if running != entry {
		menu, err := regularBytes(filepath.Join(p.ESP, "oma-snap/grub/grub.cfg"))
		if err != nil {
			return err
		}
		if running == "legacy" || strings.HasPrefix(string(menu), legacyMarker) {
			if err = legacyCheck(); err != nil {
				return err
			}
		}
		if running == "legacy" {
			err = selectLegacyMenu(p.ESP, p.UUID, p.Cmdline, entry, running, false, verify)
		} else {
			err = selectMenu(p.ESP, p.UUID, p.Cmdline, entry, running, verify)
		}
		if err != nil {
			return err
		}
	}
	record := activationRecord{1, provider.Sequence, approvalHash, entry, running}
	return saveActivation(p.State, record)
}

func preparedProviderEntry(p activationPaths, provider approvedProvider) (string, error) {
	for _, state := range []string{"pending", "running", "failed"} {
		if _, err := os.Lstat(filepath.Join(p.Jobs, state, provider.Hardware+".json")); err == nil {
			return "", fmt.Errorf("provider preparation is %s", state)
		} else if !os.IsNotExist(err) {
			return "", err
		}
	}
	data, err := regularBytes(filepath.Join(p.Jobs, "complete", provider.Hardware+".json"))
	if err != nil {
		return "", err
	}
	var job struct {
		Schema int    `json:"schema"`
		ID     string `json:"hardware_set"`
		Entry  string `json:"boot_entry"`
		Error  string `json:"error"`
	}
	if err = json.Unmarshal(data, &job); err != nil {
		return "", err
	}
	if job.Schema != 1 || job.ID != provider.Hardware || job.Error != "" || !hexID.MatchString(job.Entry) {
		return "", fmt.Errorf("invalid provider completion record")
	}
	return job.Entry, nil
}

func runningFallback(p activationPaths, verify func(build) error) (string, error) {
	path := filepath.Join(p.Runtime, "booted-entry")
	if _, err := os.Lstat(path); os.IsNotExist(err) {
		if p.Release != legacyRelease {
			return "", fmt.Errorf("unidentified running kernel")
		}
		if _, err = readLegacy(p.ESP); err != nil {
			return "", err
		}
		return "legacy", nil
	} else if err != nil {
		return "", err
	}
	data, err := regularBytes(path)
	if err != nil {
		return "", err
	}
	id := strings.TrimSpace(string(data))
	b, err := readEntry(p.ESP, id)
	if err != nil {
		return "", err
	}
	set, err := regularBytes(filepath.Join(p.Runtime, "booted-set"))
	if err != nil {
		return "", err
	}
	if b.Release != p.Release || b.Hardware != strings.TrimSpace(string(set)) {
		return "", fmt.Errorf("running kernel identity mismatch")
	}
	if err = verify(b); err != nil {
		return "", err
	}
	return id, nil
}

func saveActivation(path string, record activationRecord) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	resolved, err := filepath.EvalSymlinks(dir)
	if err != nil || resolved != dir {
		return fmt.Errorf("substituted activation directory")
	}
	data, err := json.MarshalIndent(record, "", "  ")
	if err != nil {
		return err
	}
	scratch, err := os.MkdirTemp(dir, ".activation-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(scratch)
	next := filepath.Join(scratch, "record.json")
	if err = syncedWrite(next, append(data, '\n')); err != nil {
		return err
	}
	if err = os.Rename(next, path); err != nil {
		return err
	}
	return syncDir(dir)
}
