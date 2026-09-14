// kernel-retain rejects mutation of hardware packages referenced by boot state.
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

var identity = regexp.MustCompile(`^[a-f0-9]{64}$`)

func regularRead(path string) ([]byte, error) {
	info, err := os.Lstat(path)
	if err != nil {
		return nil, err
	}
	if !info.Mode().IsRegular() {
		return nil, fmt.Errorf("non-regular state: %s", path)
	}
	return os.ReadFile(path)
}

func protectedSets(entries, running string) (map[string]bool, error) {
	protected := map[string]bool{}
	data, err := regularRead(running)
	if err == nil {
		id := strings.TrimSpace(string(data))
		if !identity.MatchString(id) {
			return nil, fmt.Errorf("invalid running set identity")
		}
		protected[id] = true
	} else if !os.IsNotExist(err) {
		return nil, err
	}
	resolved, err := filepath.EvalSymlinks(entries)
	if err != nil || resolved != entries {
		return nil, fmt.Errorf("missing or substituted boot entries directory")
	}
	children, err := os.ReadDir(entries)
	if err != nil {
		return nil, err
	}
	for _, child := range children {
		if strings.HasPrefix(child.Name(), ".") {
			continue
		}
		if !identity.MatchString(child.Name()) || !child.IsDir() {
			return nil, fmt.Errorf("invalid boot entry: %s", child.Name())
		}
		data, err := regularRead(filepath.Join(entries, child.Name(), "entry.json"))
		if err != nil {
			return nil, err
		}
		var m struct {
			Schema   int    `json:"schema"`
			Entry    string `json:"boot_entry"`
			Hardware string `json:"hardware_set"`
		}
		if err = json.Unmarshal(data, &m); err != nil {
			return nil, err
		}
		if m.Schema != 1 || m.Entry != child.Name() || !identity.MatchString(m.Hardware) {
			return nil, fmt.Errorf("invalid boot entry manifest")
		}
		protected[m.Hardware] = true
	}
	return protected, nil
}

func checkTargets(input io.Reader, protected map[string]bool) error {
	scanner := bufio.NewScanner(input)
	count := 0
	for scanner.Scan() {
		target := scanner.Text()
		id := strings.TrimPrefix(target, "oma-snap-set-")
		if target == id || !identity.MatchString(id) {
			return fmt.Errorf("unexpected retention target: %q", target)
		}
		count++
		if protected[id] {
			return fmt.Errorf("cannot remove or replace %s: referenced by a retained boot entry or the running kernel", target)
		}
	}
	if err := scanner.Err(); err != nil {
		return err
	}
	if count == 0 {
		return fmt.Errorf("missing ALPM transaction targets")
	}
	return nil
}

func run() error {
	legacy := len(os.Args) == 2 && os.Args[1] == "--legacy"
	if len(os.Args) != 1 && !legacy {
		return fmt.Errorf("takes ALPM targets on stdin, no arguments")
	}
	if os.Geteuid() != 0 {
		return fmt.Errorf("requires root")
	}
	data, err := regularRead("/etc/oma-snap/esp-path")
	if err != nil {
		return err
	}
	esp := strings.TrimSpace(string(data))
	if esp != "/boot" && esp != "/boot/efi" && esp != "/efi" {
		return fmt.Errorf("invalid configured ESP path")
	}
	resolved, err := filepath.EvalSymlinks(esp)
	if err != nil || resolved != esp {
		return fmt.Errorf("substituted ESP")
	}
	output, err := exec.Command("findmnt", "-rn", "-M", esp, "-o", "FSTYPE").Output()
	if err != nil || strings.TrimSpace(string(output)) != "vfat" {
		return fmt.Errorf("mount the configured FAT ESP before changing hardware packages")
	}
	if legacy {
		return checkLegacyTargets(os.Stdin, filepath.Join(esp, "oma-snap/7.0.0-31-generic"))
	}
	protected, err := protectedSets(filepath.Join(esp, "oma-snap/entries"), "/run/oma-snap/booted-set")
	if err != nil {
		return err
	}
	return checkTargets(os.Stdin, protected)
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "Snapdragon retention guard:", err)
		os.Exit(1)
	}
}
