package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type policy struct {
	Archive      string `json:"archive"`
	Release      string `json:"release"`
	Architecture string `json:"architecture"`
	MetaPackage  string `json:"meta_package"`
	Keyring      string `json:"keyring"`
	Signer       string `json:"signer"`
	MaxAge       int    `json:"max_update_age_hours"`
	TestRelease  string `json:"rollback_test_release,omitempty"`
}
type repository struct {
	Suite         string `json:"suite"`
	ReleaseSHA256 string `json:"inrelease_sha256"`
	IndexSHA256   string `json:"index_sha256"`
	Date          string `json:"date"`
}
type record struct {
	Fields fields
	Suite  string
}

func verifyRelease(p policy, suite, dir string, cached bool) (fields, error) {
	signed := filepath.Join(dir, "InRelease")
	temp, err := os.MkdirTemp("", "oma-release-")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(temp)
	plain := filepath.Join(temp, "Release")
	if !cached {
		if err := fetch(p.Archive, "dists/"+suite+"/InRelease", signed, "", 0, 4<<20); err != nil {
			return nil, err
		}
	}
	cmd := exec.Command("gpgv", "--status-fd", "1", "--keyring", p.Keyring, "--output", plain, signed)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("release signature: %w: %s", err, output)
	}
	valid := false
	for _, line := range strings.Split(string(output), "\n") {
		if strings.HasPrefix(line, "[GNUPG:] VALIDSIG ") {
			words := strings.Fields(line)
			valid = words[len(words)-1] == p.Signer
		}
	}
	if !valid {
		return nil, fmt.Errorf("release not signed by configured primary key")
	}
	data, err := os.Open(plain)
	if err != nil {
		return nil, err
	}
	defer data.Close()
	var result fields
	err = paragraphs(data, func(f fields) error {
		if result != nil {
			return fmt.Errorf("multiple Release paragraphs")
		}
		result = f
		return nil
	})
	if err != nil {
		return nil, err
	}
	if err := checkRelease(p, suite, result, time.Now()); err != nil {
		return nil, err
	}
	return result, nil
}

func checkRelease(p policy, suite string, result fields, now time.Time) error {
	if result["Origin"] != p.origin() || result["Suite"] != suite || result["Codename"] != p.Release {
		return fmt.Errorf("unexpected archive identity")
	}
	date, err := time.Parse(time.RFC1123, result["Date"])
	if err != nil {
		return err
	}
	age := time.Duration(p.MaxAge) * time.Hour
	if suite == p.Release && !p.concept() {
		age = 366 * 24 * time.Hour
	}
	if date.After(now.Add(24*time.Hour)) || now.Sub(date) > age {
		return fmt.Errorf("Release date outside freshness policy: %s", date)
	}
	if until := result["Valid-Until"]; until != "" {
		t, e := time.Parse(time.RFC1123, until)
		if e != nil {
			return e
		}
		if now.After(t) {
			return fmt.Errorf("expired Release")
		}
	}
	return nil
}

func loadIndex(p policy, suite, dir string, cached bool) ([]record, repository, error) {
	var evidence repository
	f, err := verifyRelease(p, suite, dir, cached)
	if err != nil {
		return nil, evidence, err
	}
	rel := "main/binary-" + p.Architecture + "/Packages.xz"
	hash := ""
	var size int64
	for _, line := range strings.Split(f["SHA256"], "\n") {
		parts := strings.Fields(line)
		if len(parts) == 3 && parts[2] == rel {
			hash = parts[0]
			size, err = strconv.ParseInt(parts[1], 10, 64)
			if err != nil {
				return nil, evidence, err
			}
		}
	}
	if len(hash) != 64 || size <= 0 || size > 256<<20 {
		return nil, evidence, fmt.Errorf("missing/invalid signed index hash")
	}
	index := filepath.Join(dir, "Packages.xz")
	if !cached {
		if err = fetch(p.Archive, "dists/"+suite+"/"+rel, index, hash, size, 256<<20); err != nil {
			return nil, evidence, err
		}
	}
	if err = checkFile(index, hash, size); err != nil {
		return nil, evidence, err
	}
	cmd := exec.Command("xz", "--decompress", "--stdout", index)
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, evidence, err
	}
	if err = cmd.Start(); err != nil {
		return nil, evidence, err
	}
	var records []record
	err = paragraphs(stdout, func(f fields) error {
		if strings.HasPrefix(f["Package"], "linux-") && (f["Architecture"] == p.Architecture || f["Architecture"] == "all") {
			records = append(records, record{f, suite})
		}
		return nil
	})
	if err != nil {
		cmd.Process.Kill()
	}
	waitErr := cmd.Wait()
	if err != nil {
		return nil, evidence, err
	}
	if waitErr != nil {
		return nil, evidence, waitErr
	}
	signedHash, err := fileHash(filepath.Join(dir, "InRelease"))
	if err != nil {
		return nil, evidence, err
	}
	evidence = repository{suite, signedHash, hash, f["Date"]}
	return records, evidence, nil
}
