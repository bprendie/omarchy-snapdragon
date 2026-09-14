package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

type evidence struct {
	Kind   string `json:"kind"`
	Path   string `json:"path"`
	SHA256 string `json:"sha256"`
}

type approval struct {
	Schema        int               `json:"schema"`
	Status        string            `json:"status"`
	Channel       string            `json:"channel"`
	Sequence      uint64            `json:"sequence"`
	Reviewer      string            `json:"reviewer"`
	HardwareSet   string            `json:"hardware_set"`
	KernelRelease string            `json:"kernel_release"`
	PackageSHA256 string            `json:"package_sha256"`
	Hardware      map[string]string `json:"hardware_validation"`
	Evidence      []evidence        `json:"evidence"`
	DeferredTests map[string]string `json:"deferred_tests,omitempty"`
}

var digestPattern = regexp.MustCompile(`^[a-f0-9]{64}$`)
var releasePattern = regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-generic$`)

func readJSON(path string, value any) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	d := json.NewDecoder(f)
	d.DisallowUnknownFields()
	if err = d.Decode(value); err != nil {
		return err
	}
	var extra any
	if d.Decode(&extra) != io.EOF {
		return fmt.Errorf("trailing JSON in %s", path)
	}
	return nil
}

func hashFile(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	info, err := f.Stat()
	if err != nil {
		return "", err
	}
	if !info.Mode().IsRegular() {
		return "", fmt.Errorf("not a regular file: %s", path)
	}
	h := sha256.New()
	if _, err = io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func (a approval) verify(base, archive string, previous uint64) error {
	if a.Schema != 1 || a.Status != "approved" || (a.Channel != "testing" && a.Channel != "stable") ||
		a.Sequence <= previous || strings.TrimSpace(a.Reviewer) == "" ||
		!digestPattern.MatchString(a.HardwareSet) || !releasePattern.MatchString(a.KernelRelease) {
		return fmt.Errorf("invalid approval identity, decision or sequence")
	}
	if len(a.Hardware) != 3 {
		return fmt.Errorf("all three hardware profiles must be recorded")
	}
	for _, profile := range []string{"t14s", "hp-g1q", "asus-ux3407ra"} {
		state := a.Hardware[profile]
		if state != "validated" && state != "untested" {
			return fmt.Errorf("invalid hardware result: %s", profile)
		}
		if a.Channel == "stable" && profile != "asus-ux3407ra" && state != "validated" {
			return fmt.Errorf("stable promotion requires ThinkPad and HP validation")
		}
	}
	required := map[string]bool{"source-verification": false, "package-reproducibility": false,
		"camera-build": false, "vm-rollback": false, "vm-encrypted-boot": false}
	for _, e := range a.Evidence {
		seen, known := required[e.Kind]
		if !known || seen || e.Path == "" || filepath.IsAbs(e.Path) ||
			filepath.Clean(e.Path) != e.Path || e.Path == ".." || strings.HasPrefix(e.Path, "../") {
			return fmt.Errorf("invalid or duplicate evidence: %s", e.Kind)
		}
		h, err := hashFile(filepath.Join(base, e.Path))
		if err != nil {
			return err
		}
		if !digestPattern.MatchString(e.SHA256) || h != e.SHA256 {
			return fmt.Errorf("evidence hash mismatch: %s", e.Kind)
		}
		required[e.Kind] = true
	}
	for kind, present := range required {
		if !present {
			if a.Channel == "testing" && kind == "vm-encrypted-boot" && strings.TrimSpace(a.DeferredTests[kind]) != "" {
				continue
			}
			return fmt.Errorf("missing reviewed evidence: %s", kind)
		}
	}
	for kind, reason := range a.DeferredTests {
		if a.Channel != "testing" || kind != "vm-encrypted-boot" || required[kind] || strings.TrimSpace(reason) == "" {
			return fmt.Errorf("invalid deferred testing check: %s", kind)
		}
	}
	h, err := hashFile(archive)
	if err != nil {
		return err
	}
	if !digestPattern.MatchString(a.PackageSHA256) || h != a.PackageSHA256 {
		return fmt.Errorf("package hash mismatch")
	}
	info, err := exec.Command("bsdtar", "-xOf", archive, ".PKGINFO").Output()
	if err != nil {
		return fmt.Errorf("read package metadata: %w", err)
	}
	for _, field := range []string{"pkgname = oma-snap-set-" + a.HardwareSet, "pkgver = 0.2.0-1", "arch = aarch64"} {
		if !strings.Contains("\n"+string(info), "\n"+field+"\n") {
			return fmt.Errorf("package identity mismatch: %s", field)
		}
	}
	manifest, err := exec.Command("bsdtar", "-xOf", archive, "usr/lib/oma-snap/sets/"+a.HardwareSet+"/set.json").Output()
	if err != nil {
		return err
	}
	var set struct {
		ID      string `json:"id"`
		Release string `json:"kernel_release"`
	}
	if err = json.Unmarshal(manifest, &set); err != nil {
		return err
	}
	if set.ID != a.HardwareSet || set.Release != a.KernelRelease {
		return fmt.Errorf("packaged set identity mismatch")
	}
	return nil
}
