package main

import (
	"bufio"
	"fmt"
	"io"
	"regexp"
	"strings"
)

type fields map[string]string

func paragraphs(r io.Reader, visit func(fields) error) error {
	s := bufio.NewScanner(r)
	s.Buffer(make([]byte, 65536), 8<<20)
	f := fields{}
	last := ""
	flush := func() error {
		if len(f) == 0 {
			return nil
		}
		err := visit(f)
		f = fields{}
		last = ""
		return err
	}
	for s.Scan() {
		line := s.Text()
		if line == "" {
			if err := flush(); err != nil {
				return err
			}
			continue
		}
		if line[0] == ' ' || line[0] == '\t' {
			if last == "" {
				return fmt.Errorf("orphan continuation")
			}
			f[last] += "\n" + line[1:]
			continue
		}
		key, value, ok := strings.Cut(line, ":")
		if !ok {
			return fmt.Errorf("invalid control field")
		}
		if _, ok = f[key]; ok {
			return fmt.Errorf("duplicate field %s", key)
		}
		f[key] = strings.TrimSpace(value)
		last = key
	}
	if err := s.Err(); err != nil {
		return err
	}
	return flush()
}

var kernelName = regexp.MustCompile(`^linux-(generic$|qcom-x1e$|qcom-x1e-headers-|image-|headers-|(main-)?modules-)`)
var bareDep = regexp.MustCompile(`^linux-[a-z0-9.+-]+$`)
var exactDep = regexp.MustCompile(`^(linux-[a-z0-9.+-]+)\s*\(=\s*([^ )]+)\)$`)

func kernelDeps(f fields) (map[string]string, error) {
	result := map[string]string{}
	for _, raw := range strings.Split(f["Depends"], ",") {
		dep := strings.TrimSpace(raw)
		// Ubuntu's separately signed modules permit either signed or unsigned images.
		// This pipeline deliberately chooses the signed image of the same ABI.
		if choices := strings.Split(dep, " | "); len(choices) == 2 {
			first := strings.TrimSpace(choices[0])
			if strings.HasPrefix(first, "linux-image-") && !strings.HasPrefix(first, "linux-image-unsigned-") &&
				strings.TrimSpace(choices[1]) == strings.Replace(first, "linux-image-", "linux-image-unsigned-", 1) {
				dep = first
			}
		}
		if !kernelName.MatchString(dep) {
			continue
		}
		if bareDep.MatchString(dep) {
			result[dep] = ""
			continue
		}
		match := exactDep.FindStringSubmatch(dep)
		if match == nil {
			return nil, fmt.Errorf("unsupported kernel dependency %q", dep)
		}
		result[match[1]] = match[2]
	}
	return result, nil
}
