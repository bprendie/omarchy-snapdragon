// package-audit compares the pinned Omarchy list with downloaded pacman databases.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type row struct {
	Requested  string `json:"requested"`
	Package    string `json:"package"`
	Status     string `json:"status"`
	Repository string `json:"repository,omitempty"`
	Version    string `json:"version,omitempty"`
	File       string `json:"file,omitempty"`
	SHA256     string `json:"sha256,omitempty"`
	Reason     string `json:"reason,omitempty"`
}

func mustRead(path string) string {
	b, e := os.ReadFile(path)
	if e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
	return string(b)
}
func fields(path string) [][]string {
	var rows [][]string
	for _, s := range strings.Split(mustRead(path), "\n") {
		s, _, _ = strings.Cut(s, "#")
		if f := strings.Fields(s); len(f) > 0 {
			rows = append(rows, f)
		}
	}
	return rows
}
func main() {
	if len(os.Args) != 3 {
		fmt.Fprintln(os.Stderr, "usage: package-audit REPOSITORY-INDEX OMARCHY-CHECKOUT")
		os.Exit(2)
	}
	index, checkout := os.Args[1], os.Args[2]
	db := map[string]row{}
	for _, repo := range []string{"core", "extra", "alarm"} {
		paths, e := filepath.Glob(filepath.Join(index, repo, "*", "desc"))
		if e != nil || len(paths) == 0 {
			fmt.Fprintln(os.Stderr, "missing database:", repo, e)
			os.Exit(1)
		}
		for _, p := range paths {
			m := map[string]string{}
			parts := strings.Split(mustRead(p), "\n\n")
			for _, part := range parts {
				k, v, ok := strings.Cut(strings.TrimSpace(part), "\n")
				if ok {
					m[k] = v
				}
			}
			name := m["%NAME%"]
			if name == "" {
				continue
			}
			if _, ok := db[name]; ok {
				continue
			}
			db[name] = row{Package: name, Repository: repo, Version: m["%VERSION%"], File: m["%FILENAME%"], SHA256: m["%SHA256SUM%"], Status: "repository metadata (signature/build not checked by this tool)"}
		}
	}
	replace := map[string]string{}
	for _, f := range fields(checkout + "/install/arm/packages.replace") {
		if len(f) > 1 {
			replace[f[0]] = f[1]
		}
	}
	policy := map[string]string{"asdcontrol": "Apple Studio Display helper"}
	exceptions := map[string]string{}
	for _, manifest := range []string{"packages.exclude", "packages.aur", "packages.aur-required", "packages.unavailable"} {
		for _, f := range fields(checkout + "/install/arm/" + manifest) {
			exceptions[f[0]] = manifest
		}
	}
	var out []row
	for _, f := range fields(checkout + "/install/omarchy-base.packages") {
		original, name := f[0], f[0]
		if v, ok := replace[name]; ok {
			name = v
		}
		r, ok := db[name]
		if !ok {
			r = row{Package: name, Status: "unresolved", Reason: exceptions[name]}
			if strings.Contains(r.Reason, "aur") {
				r.Status = "AUR recipe claim only; build unverified"
			}
		}
		r.Requested = original
		if reason, ok := policy[original]; ok {
			r.Status = "excluded by local profile"
			r.Reason = reason
		}
		out = append(out, r)
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	if e := enc.Encode(out); e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
}
