package main

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRefreshCompletedSetPreservesPriorWork(t *testing.T) {
	s := fixture(t)
	id := strings.Repeat("a", 64)
	if err := s.enqueue(id, false); err != nil {
		t.Fatal(err)
	}
	if err := s.process(func(j job) (job, error) {
		j.Entry = strings.Repeat("b", 64)
		return j, os.WriteFile(filepath.Join(j.Work, "evidence"), []byte("old boot"), 0600)
	}); err != nil {
		t.Fatal(err)
	}
	old, err := s.read("complete", id)
	if err != nil {
		t.Fatal(err)
	}
	if err = s.request(id, "complete"); err != nil {
		t.Fatal(err)
	}
	if err = s.request(id, "complete"); err == nil {
		t.Fatal("refresh accepted an already pending job")
	}
	if err = s.process(func(j job) (job, error) {
		if j.Work == old.Work || j.Entry != "" {
			t.Fatal("refresh reused previous output identity")
		}
		return j, errors.New("new configuration failed")
	}); err != nil {
		t.Fatal(err)
	}
	failed, err := s.read("failed", id)
	if err != nil || failed.Error != "new configuration failed" {
		t.Fatal("refresh failure not recorded", err)
	}
	data, err := os.ReadFile(filepath.Join(old.Work, "evidence"))
	if err != nil || string(data) != "old boot" {
		t.Fatal("prior work was changed", err)
	}
	if err = s.request(id, "complete"); err == nil {
		t.Fatal("refresh retried a failed job")
	}
}

func TestRefreshProducesNewEntryForSameHardware(t *testing.T) {
	s := fixture(t)
	id := strings.Repeat("a", 64)
	if err := s.enqueue(id, false); err != nil {
		t.Fatal(err)
	}
	for _, entry := range []string{strings.Repeat("b", 64), strings.Repeat("c", 64)} {
		if err := s.process(func(j job) (job, error) { j.Entry = entry; return j, nil }); err != nil {
			t.Fatal(err)
		}
		j, err := s.read("complete", id)
		if err != nil || j.Entry != entry {
			t.Fatal("wrong refreshed identity", err)
		}
		if entry == strings.Repeat("b", 64) {
			if err = s.enqueue(id, false); err != nil {
				t.Fatal(err)
			}
			if err = s.process(func(j job) (job, error) {
				t.Fatal("duplicate package event refreshed implicitly")
				return j, nil
			}); err != nil {
				t.Fatal(err)
			}
			if err = s.request(id, "complete"); err != nil {
				t.Fatal(err)
			}
		}
	}
}
