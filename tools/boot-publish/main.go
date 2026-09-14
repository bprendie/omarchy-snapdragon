// boot-publish stages an entry, or explicitly selects a verified entry pair.
package main

import (
	"errors"
	"flag"
	"fmt"
	bootlock "oma_snap/boot-lock"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
)

func run() (result error) {
	stage := flag.String("stage", "", "completed directory under /var/lib/oma-snap/staging")
	waitLock := flag.Duration("wait-lock", 0, "wait for pacman's lock release, at most 30m")
	selected := flag.String("select", "", "explicitly select a published boot entry")
	fallback := flag.String("fallback", "", "retain another published entry in the menu")
	migrate := flag.Bool("migrate-legacy", false, "preserve the released GRUB boot; requires --select legacy and a published --fallback")
	status := flag.Bool("reboot-status", false, "report whether selected boot entry differs from the running entry")
	activate := flag.Bool("activate-provider", false, "select the approved prepared provider once, retaining the running boot")
	esp := flag.String("esp", "/boot", "mounted FAT EFI system partition")
	flag.Parse()
	if flag.NArg() != 0 || os.Geteuid() != 0 || runtime.GOARCH != "arm64" {
		return fmt.Errorf("requires root on ARM64 and named arguments")
	}
	selecting := *selected != "" || *fallback != ""
	if (*status || *activate) && (selecting || *stage != "" || *migrate || (*status && *activate)) {
		return fmt.Errorf("reboot status cannot be combined with boot changes")
	}
	legacy := *selected == "legacy" || *fallback == "legacy"
	validID := func(id string) bool { return id == "legacy" || hexID.MatchString(id) }
	if *migrate && (!selecting || *selected != "legacy") {
		return fmt.Errorf("migration requires --select legacy and a published --fallback")
	}
	if selecting && (*stage != "" || !validID(*selected) || !validID(*fallback) || *selected == *fallback) {
		return fmt.Errorf("selection requires distinct --select and --fallback, without --stage")
	}
	if !selecting && !*status && !*activate && (filepath.Dir(*stage) != "/var/lib/oma-snap/staging" || filepath.Clean(*stage) != *stage) {
		return fmt.Errorf("invalid staging path")
	}
	if *esp != "/boot" && *esp != "/boot/efi" && *esp != "/efi" {
		return fmt.Errorf("unsupported ESP path")
	}
	database, err := bootlock.AcquireSystemFor(*waitLock)
	if err != nil {
		return err
	}
	defer func() { result = errors.Join(result, database.Close()) }()
	paths := []string{*esp}
	if !selecting && !*status && !*activate {
		paths = append(paths, *stage)
	}
	for _, path := range paths {
		resolved, err := filepath.EvalSymlinks(path)
		if err != nil || resolved != path {
			return fmt.Errorf("missing or substituted path: %s", path)
		}
	}
	output, err := exec.Command("findmnt", "-rn", "-M", *esp, "-o", "FSTYPE,UUID").Output()
	if err != nil {
		return err
	}
	fields := strings.Fields(string(output))
	if len(fields) != 2 || fields[0] != "vfat" {
		return fmt.Errorf("ESP must be a mounted FAT filesystem with UUID")
	}
	if err = os.MkdirAll("/run/oma-snap", 0755); err != nil {
		return err
	}
	lock, err := os.OpenFile("/run/oma-snap/stage.lock", os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return err
	}
	defer lock.Close()
	if err = syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		return fmt.Errorf("another boot operation is active: %w", err)
	}
	cmdline, err := os.ReadFile("/etc/kernel/cmdline")
	if err != nil {
		return err
	}
	if *status {
		release, err := exec.Command("uname", "-r").Output()
		if err != nil {
			return err
		}
		result, err := rebootStatus(*esp, fields[1], strings.TrimSpace(string(cmdline)), "/run/oma-snap/booted-entry", strings.TrimSpace(string(release)))
		if err != nil {
			return err
		}
		fmt.Println(result)
		return nil
	}
	if *activate {
		release, err := exec.Command("uname", "-r").Output()
		if err != nil {
			return err
		}
		return activateProvider(activationPaths{
			ESP: *esp, UUID: fields[1], Cmdline: strings.TrimSpace(string(cmdline)),
			Provider: "/usr/share/oma-snap/kernel-provider/candidate.json", Jobs: "/var/lib/oma-snap/jobs",
			Runtime: "/run/oma-snap", State: "/var/lib/oma-snap/provider-activation.json",
			Channel: "/etc/oma-snap/kernel-channel", Release: strings.TrimSpace(string(release)),
		}, verifySet, legacyDependencies)
	}
	if selecting {
		oldMenu, readErr := regularBytes(filepath.Join(*esp, "oma-snap/grub/grub.cfg"))
		if readErr != nil && !os.IsNotExist(readErr) {
			return readErr
		}
		if legacy || strings.HasPrefix(string(oldMenu), legacyMarker) {
			if err = legacyDependencies(); err != nil {
				return err
			}
		}
		if legacy {
			return selectLegacyMenu(*esp, fields[1], strings.TrimSpace(string(cmdline)), *selected, *fallback, *migrate, verifySet)
		}
		return selectMenu(*esp, fields[1], strings.TrimSpace(string(cmdline)), *selected, *fallback, verifySet)
	}
	b, err := readBuild(*stage)
	if err != nil {
		return err
	}
	if err = verifySet(b); err != nil {
		return err
	}
	set := filepath.Join("/usr/lib/oma-snap/sets", b.Hardware)
	dest, err := publish(*stage, set, filepath.Join(*esp, "oma-snap/entries"), fields[1], strings.TrimSpace(string(cmdline)), b)
	if err != nil {
		return err
	}
	fmt.Println("Published unselected, unvalidated entry:", dest)
	return nil
}

func verifySet(b build) error {
	set := filepath.Join("/usr/lib/oma-snap/sets", b.Hardware)
	resolved, err := filepath.EvalSymlinks(set)
	if err != nil || resolved != set {
		return fmt.Errorf("substituted hardware set")
	}
	verify := exec.Command("oma-snap-kernel-set", "--verify-installed", set)
	verify.Stdout, verify.Stderr = os.Stdout, os.Stderr
	return verify.Run()
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
