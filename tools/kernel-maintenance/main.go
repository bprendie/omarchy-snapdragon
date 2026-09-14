// kernel-maintenance preserves retained mountpoints during ordinary Arch
// module maintenance. It runs only on package events or the existing boot unit.
package main

import (
	"bufio"
	"errors"
	"flag"
	"fmt"
	"io"
	bootlock "oma_snap/boot-lock"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func depmodTargets(input io.Reader, releases map[string]bool) ([]string, error) {
	var targets []string
	scanner := bufio.NewScanner(input)
	for scanner.Scan() {
		target := scanner.Text()
		parts := strings.Split(target, "/")
		if len(parts) != 5 || parts[0] != "usr" || parts[1] != "lib" || parts[2] != "modules" || parts[4] != "" || parts[3] == "" || parts[3] == "." || parts[3] == ".." {
			return nil, fmt.Errorf("unexpected depmod hook target: %q", target)
		}
		if !releases[parts[3]] {
			targets = append(targets, target)
		}
	}
	return targets, scanner.Err()
}

func command(name string, args ...string) error {
	c := exec.Command(name, args...)
	c.Stdout, c.Stderr = os.Stdout, os.Stderr
	return c.Run()
}

func cleanup(modules, running string, retained map[string]bool) error {
	paths, err := filepath.Glob(filepath.Join(modules, "[0-9]*"))
	if err != nil {
		return err
	}
	for _, path := range paths {
		if filepath.Base(path) == running || retained[filepath.Base(path)] {
			continue
		}
		info, err := os.Lstat(path)
		if err != nil || !info.IsDir() {
			return fmt.Errorf("invalid module directory: %s", path)
		}
		query := exec.Command("pacman", "-Qo", "--", path)
		if err = query.Run(); err == nil {
			continue
		} else {
			var exit *exec.ExitError
			if !errors.As(err, &exit) || exit.ExitCode() != 1 {
				return fmt.Errorf("package ownership query failed: %w", err)
			}
		}
		if err = command("rsync", "-AHXal", "--", path, filepath.Join(modules, ".old")+"/"); err != nil {
			return err
		}
		if err = os.RemoveAll(path); err != nil {
			return err
		}
	}
	return nil
}

func run() (result error) {
	depmod := flag.Bool("depmod", false, "filter retained releases from the stock depmod hook")
	clean := flag.Bool("cleanup", false, "clean obsolete modules while preserving retained releases")
	flag.Parse()
	if *depmod == *clean || flag.NArg() != 0 || os.Geteuid() != 0 {
		return fmt.Errorf("requires root and exactly one of --depmod or --cleanup")
	}
	if *clean {
		lock, err := bootlock.AcquireSystem()
		if err != nil {
			return err
		}
		defer func() { result = errors.Join(result, lock.Close()) }()
	}
	// --depmod is invoked inside ALPM's post-transaction hook while it owns the
	// database lock. Reacquiring that lock here would deadlock the transaction.
	retained, err := retainedReleases("/usr/lib/oma-snap/sets")
	if err != nil {
		return err
	}
	if *depmod {
		targets, err := depmodTargets(os.Stdin, retained)
		if err != nil {
			return err
		}
		if len(targets) > 0 {
			c := exec.Command("/usr/share/libalpm/scripts/depmod")
			c.Stdin = strings.NewReader(strings.Join(targets, "\n") + "\n")
			c.Stdout, c.Stderr = os.Stdout, os.Stderr
			if err = c.Run(); err != nil {
				return err
			}
		}
		return ensureMountpoints("/usr/lib", retained)
	}
	if err = ensureMountpoints("/usr/lib", retained); err != nil {
		return err
	}
	running, err := exec.Command("uname", "-r").Output()
	if err != nil {
		return err
	}
	return cleanup("/usr/lib/modules", strings.TrimSpace(string(running)), retained)
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "Snapdragon module maintenance:", err)
		os.Exit(1)
	}
}
