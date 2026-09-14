package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func rollbackFixture() []record {
	rows := fixture()
	for _, r := range fixture()[3:] {
		copy := fields{}
		for key, value := range r.Fields {
			copy[key] = strings.ReplaceAll(value, "31", "30")
		}
		rows = append(rows, record{copy, r.Suite})
	}
	return rows
}

func TestRollbackResolution(t *testing.T) {
	p := policy{MetaPackage: "linux-generic"}
	_, release, err := resolvePolicy(rollbackFixture(), p)
	if err != nil || release != "7.0.0-31-generic" || candidateStatus(p) != "unvalidated" {
		t.Fatal(release, err)
	}
	p.TestRelease = "7.0.0-30-generic"
	rows, release, err := resolvePolicy(rollbackFixture(), p)
	if err != nil || release != p.TestRelease || len(rows) != 4 || candidateStatus(p) != "rollback-test" {
		t.Fatal(rows, release, err)
	}
	for _, name := range []string{"same ABI", "missing ABI", "unsafe ABI", "missing modules", "wrong headers", "conflicting image"} {
		t.Run(name, func(t *testing.T) {
			records := rollbackFixture()
			q := p
			switch name {
			case "same ABI":
				q.TestRelease = "7.0.0-31-generic"
			case "missing ABI":
				q.TestRelease = "7.0.0-32-generic"
			case "unsafe ABI":
				q.TestRelease = "../30"
			case "missing modules":
				records = append(records[:8], records[9:]...)
			case "wrong headers":
				records[9].Fields["Version"] = "7.0.0-30.31"
			case "conflicting image":
				records = append(records, record{fields{"Package": "linux-image-7.0.0-30-generic", "Version": "7.0.0-30.30", "SHA256": "different"}, "resolute-security"})
			}
			if _, _, err := resolvePolicy(records, q); err == nil {
				t.Fatal("accepted invalid rollback baseline")
			}
		})
	}
}

func TestRollbackRequiresExternalPolicy(t *testing.T) {
	p := policy{MetaPackage: "linux-generic", TestRelease: "7.0.0-30-generic"}
	c := candidate{Schema: 1, Downloaded: true, Policy: p, Status: "rollback-test"}
	dir := t.TempDir()
	write := func() {
		data, err := json.Marshal(c)
		if err != nil {
			t.Fatal(err)
		}
		if err = os.WriteFile(filepath.Join(dir, "candidate.json"), data, 0600); err != nil {
			t.Fatal(err)
		}
	}
	write()
	if _, err := verifyCandidate(policy{MetaPackage: "linux-generic"}, dir); err == nil || !strings.Contains(err.Error(), "external policy") {
		t.Fatal("test candidate accepted under normal policy", err)
	}
	c.Status = "unvalidated"
	write()
	if _, err := verifyCandidate(p, dir); err == nil || !strings.Contains(err.Error(), "expected state") {
		t.Fatal("test status could be relabeled", err)
	}
}
