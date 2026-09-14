package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestProviderPreparedChecksCurrentCandidate(t *testing.T) {
	for _, state := range []string{"missing", "pending", "running", "failed", "complete"} {
		t.Run(state, func(t *testing.T) {
			s := store{root: filepath.Join(t.TempDir(), "jobs")}
			if err := s.initialize(); err != nil {
				t.Fatal(err)
			}
			id := strings.Repeat("a", 64)
			path := filepath.Join(t.TempDir(), "candidate.json")
			if err := os.WriteFile(path, []byte(`{"schema":1,"hardware_set":"`+id+`"}`), 0644); err != nil {
				t.Fatal(err)
			}
			if state != "missing" {
				if err := s.write(state, job{Schema: 1, ID: id, Entry: strings.Repeat("b", 64)}); err != nil {
					t.Fatal(err)
				}
			}
			if err := s.write("failed", job{Schema: 1, ID: strings.Repeat("c", 64), Error: "historical failure"}); err != nil {
				t.Fatal(err)
			}
			err := s.providerPrepared(path)
			if (err == nil) != (state == "complete") {
				t.Fatalf("state %s: %v", state, err)
			}
			if state == "complete" {
				if err := s.request(id, "complete"); err != nil {
					t.Fatal(err)
				}
				if err := s.providerPrepared(path); err == nil {
					t.Fatal("pending refresh reported complete")
				}
			}
		})
	}
}
