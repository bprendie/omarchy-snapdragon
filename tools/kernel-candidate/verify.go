package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strconv"
)

func checkFile(path, hash string, size int64) error {
	info, err := os.Lstat(path)
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() || info.Size() != size {
		return fmt.Errorf("invalid file/size: %s", path)
	}
	actual, err := fileHash(path)
	if err != nil {
		return err
	}
	if actual != hash {
		return fmt.Errorf("SHA256 mismatch: %s", path)
	}
	return nil
}

func verifyCandidate(p policy, dir string) (candidate, error) {
	var c candidate
	f, err := os.Open(filepath.Join(dir, "candidate.json"))
	if err != nil {
		return c, err
	}
	defer f.Close()
	decoder := json.NewDecoder(f)
	decoder.DisallowUnknownFields()
	if err = decoder.Decode(&c); err != nil {
		return c, err
	}
	if c.Schema != 1 || !c.Downloaded || c.Status != candidateStatus(p) || !reflect.DeepEqual(c.Policy, p) {
		return c, fmt.Errorf("candidate does not match external policy or expected state")
	}
	var records []record
	var evidence []repository
	for _, suite := range p.suites() {
		rows, r, err := loadIndex(p, suite, filepath.Join(dir, suite), true)
		if err != nil {
			return c, err
		}
		records = append(records, rows...)
		evidence = append(evidence, r)
	}
	if !reflect.DeepEqual(evidence, c.Repositories) {
		return c, fmt.Errorf("repository provenance differs from authenticated metadata")
	}
	selected, release, err := resolvePolicy(records, p)
	if err != nil {
		return c, err
	}
	if release != c.KernelRelease || len(selected) != len(c.Artifacts) {
		return c, fmt.Errorf("candidate does not match authenticated dependency resolution")
	}
	for i, r := range selected {
		f := r.Fields
		size, err := strconv.ParseInt(f["Size"], 10, 64)
		if err != nil {
			return c, err
		}
		expected := artifact{f["Package"], f["Version"], f["Architecture"], r.Suite, f["Filename"], f["SHA256"], size, f["Depends"]}
		if c.Artifacts[i] != expected {
			return c, fmt.Errorf("artifact differs from authenticated metadata: %s", f["Package"])
		}
		if _, err = archiveURL(p.Archive, expected.Filename); err != nil {
			return c, err
		}
		if err = checkFile(filepath.Join(dir, "artifacts", filepath.Base(expected.Filename)), expected.SHA256, expected.Size); err != nil {
			return c, err
		}
	}
	return c, nil
}
