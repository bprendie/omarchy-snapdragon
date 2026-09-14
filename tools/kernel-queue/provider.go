package main

import (
	"encoding/json"
	"fmt"
	"os"
)

// Completion means boot preparation, not validation, promotion or selection.
// Historical failed candidates do not invalidate the installed provider.
func (s store) providerPrepared(path string) error {
	info, err := os.Lstat(path)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() {
		return fmt.Errorf("substituted kernel provider metadata")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var provider struct {
		Schema int    `json:"schema"`
		ID     string `json:"hardware_set"`
	}
	if err := json.Unmarshal(data, &provider); err != nil {
		return err
	}
	if provider.Schema != 1 || !validID.MatchString(provider.ID) {
		return fmt.Errorf("invalid kernel provider identity")
	}
	return s.locked(func() error {
		for _, state := range []string{"pending", "running", "failed"} {
			if _, err := os.Lstat(s.path(state, provider.ID)); err == nil {
				return fmt.Errorf("installed kernel provider preparation is %s: %s; inspect oma-snap-kernel-queue --status", state, provider.ID)
			} else if !os.IsNotExist(err) {
				return err
			}
		}
		j, err := s.read("complete", provider.ID)
		if err != nil {
			return fmt.Errorf("installed provider has no readable completed preparation: %w", err)
		}
		if !validID.MatchString(j.Entry) || j.Error != "" {
			return fmt.Errorf("installed provider has invalid completed preparation")
		}
		return nil
	})
}
