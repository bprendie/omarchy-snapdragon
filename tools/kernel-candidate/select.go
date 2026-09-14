package main

import (
	"fmt"
	"os/exec"
	"sort"
	"strings"
)

func newer(a, b string) (bool, error) {
	err := exec.Command("dpkg", "--compare-versions", a, "gt", b).Run()
	if err == nil {
		return true, nil
	}
	if e, ok := err.(*exec.ExitError); ok && e.ExitCode() == 1 {
		return false, nil
	}
	return false, fmt.Errorf("compare Debian versions: %w", err)
}

func selectRecord(records []record, name, version string) (record, error) {
	var best record
	for _, r := range records {
		if r.Fields["Package"] != name || (version != "" && r.Fields["Version"] != version) {
			continue
		}
		if best.Fields == nil {
			best = r
			continue
		}
		if best.Fields["Version"] == r.Fields["Version"] {
			if best.Fields["SHA256"] != r.Fields["SHA256"] {
				return best, fmt.Errorf("conflicting archive hashes for %s %s", name, r.Fields["Version"])
			}
			continue
		}
		greater, err := newer(r.Fields["Version"], best.Fields["Version"])
		if err != nil {
			return best, err
		}
		if greater {
			best = r
		}
	}
	if best.Fields == nil {
		return best, fmt.Errorf("missing %s %s", name, version)
	}
	return best, nil
}

func closure(records []record, meta string) ([]record, string, error) {
	root, err := selectRecord(records, meta, "")
	if err != nil {
		return nil, "", err
	}
	return closureRoots(records, []record{root})
}

func closureRoots(records, pending []record) ([]record, string, error) {
	seen := map[string]record{}
	for len(pending) > 0 {
		r := pending[0]
		pending = pending[1:]
		name := r.Fields["Package"]
		if prev, ok := seen[name]; ok {
			if prev.Fields["Version"] != r.Fields["Version"] {
				return nil, "", fmt.Errorf("conflicting dependency versions")
			}
			continue
		}
		seen[name] = r
		deps, err := kernelDeps(r.Fields)
		if err != nil {
			return nil, "", err
		}
		names := make([]string, 0, len(deps))
		for n := range deps {
			names = append(names, n)
		}
		sort.Strings(names)
		for _, n := range names {
			child, err := selectRecord(records, n, deps[n])
			if err != nil {
				return nil, "", err
			}
			pending = append(pending, child)
		}
	}
	release := ""
	version := ""
	for name, r := range seen {
		if strings.HasPrefix(name, "linux-image-") && name != "linux-image-generic" {
			if release != "" {
				return nil, "", fmt.Errorf("multiple image payloads")
			}
			release = strings.TrimPrefix(name, "linux-image-")
			version = r.Fields["Version"]
		}
	}
	if release == "" || !strings.HasSuffix(release, "-generic") {
		return nil, "", fmt.Errorf("no generic image")
	}
	for _, name := range []string{"linux-modules-" + release, "linux-headers-" + release, "linux-headers-" + strings.TrimSuffix(release, "-generic")} {
		r, ok := seen[name]
		if !ok || r.Fields["Version"] != version {
			return nil, "", fmt.Errorf("missing/mismatched payload %s", name)
		}
	}
	result := make([]record, 0, len(seen))
	for _, r := range seen {
		result = append(result, r)
	}
	sort.Slice(result, func(i, j int) bool { return result[i].Fields["Package"] < result[j].Fields["Package"] })
	return result, release, nil
}
