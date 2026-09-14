// boot-stage builds an initramfs in a private mount namespace. Publishing boot
// entries is a separate operation, so a failed build cannot replace a default.
package main

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	bootlock "oma_snap/boot-lock"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"syscall"
)

type manifest struct {
	ID      string `json:"id"`
	Release string `json:"kernel_release"`
}

func command(name string, args ...string) error {
	c := exec.Command(name, args...)
	c.Stdout, c.Stderr = os.Stdout, os.Stderr
	return c.Run()
}

func digest(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err = io.Copy(h, f); err != nil {
		return "", err
	}
	return fmt.Sprintf("%x", h.Sum(nil)), nil
}

func worker(set, release, work string) error {
	for _, kind := range []string{"modules", "firmware"} {
		source := filepath.Join(set, kind, release)
		target := filepath.Join("/usr/lib", kind, release)
		if err := os.MkdirAll(target, 0755); err != nil {
			return err
		}
		resolved, err := filepath.EvalSymlinks(target)
		if err != nil || resolved != target {
			return fmt.Errorf("substituted %s mountpoint", kind)
		}
		if err = command("mount", "--bind", source, target); err != nil {
			return err
		}
		if err = command("mount", "-o", "remount,bind,ro", target); err != nil {
			return err
		}
	}
	if err := os.Setenv("OMA_SNAP_SET_ID_FILE", filepath.Join(work, "boot-set")); err != nil {
		return err
	}
	return command("mkinitcpio", "--nopost", "-k", release, "-c", filepath.Join(work, "mkinitcpio.conf"), "-g", filepath.Join(work, "initramfs.img"))
}

func run() (result error) {
	id := flag.String("set", "", "installed hardware set identity")
	waitLock := flag.Duration("wait-lock", 0, "wait for pacman's lock release, at most 30m")
	resultFile := flag.String("result-file", "", "write structured completion to a new file")
	workerPath := flag.String("worker", "", "internal: private namespace work directory")
	flag.Parse()
	if !regexp.MustCompile(`^[a-f0-9]{64}$`).MatchString(*id) || flag.NArg() != 0 {
		return fmt.Errorf("require --set SHA256")
	}
	if os.Geteuid() != 0 || runtime.GOARCH != "arm64" {
		return fmt.Errorf("requires root on the ARM64 target or builder")
	}
	if *workerPath == "" {
		database, err := bootlock.AcquireSystemFor(*waitLock)
		if err != nil {
			return err
		}
		defer func() { result = errors.Join(result, database.Close()) }()
	}
	set := filepath.Join("/usr/lib/oma-snap/sets", *id)
	resolved, err := filepath.EvalSymlinks(set)
	if err != nil || resolved != set {
		return fmt.Errorf("missing or substituted set directory")
	}
	if err = command("oma-snap-kernel-set", "--verify-installed", set); err != nil {
		return err
	}
	data, err := os.ReadFile(filepath.Join(set, "set.json"))
	if err != nil {
		return err
	}
	var m manifest
	if err = json.Unmarshal(data, &m); err != nil {
		return err
	}
	if m.ID != *id || !regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-generic$`).MatchString(m.Release) {
		return fmt.Errorf("invalid set identity/release")
	}
	staging := "/var/lib/oma-snap/staging"
	if *workerPath != "" {
		if filepath.Dir(*workerPath) != staging || filepath.Clean(*workerPath) != *workerPath {
			return fmt.Errorf("invalid worker path")
		}
		// The parent must have entered a different mount namespace first.
		ours, err := os.Readlink("/proc/self/ns/mnt")
		if err != nil {
			return err
		}
		parent, err := os.Readlink(fmt.Sprintf("/proc/%d/ns/mnt", os.Getppid()))
		if err != nil || ours == parent {
			return fmt.Errorf("worker needs a private mount namespace")
		}
		return worker(set, m.Release, *workerPath)
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
		return fmt.Errorf("another staging operation is active: %w", err)
	}
	if err = os.MkdirAll(staging, 0755); err != nil {
		return err
	}
	work, err := os.MkdirTemp(staging, *id+"-")
	if err != nil {
		return err
	}
	// Incomplete directories are retained for diagnosis, never labelled ready.
	config, err := os.ReadFile("/usr/share/oma-snap/kernel-update/mkinitcpio.conf")
	if err != nil {
		return err
	}
	config = append(config, []byte("\nHOOKS+=(oma_snap_set)\n")...)
	if err = os.WriteFile(filepath.Join(work, "mkinitcpio.conf"), config, 0600); err != nil {
		return err
	}
	var random [32]byte
	if _, err = rand.Read(random[:]); err != nil {
		return err
	}
	entryID := fmt.Sprintf("%x", random[:])
	identity := fmt.Sprintf("%s\n%s\n%s\n", *id, m.Release, entryID)
	if err = os.WriteFile(filepath.Join(work, "boot-set"), []byte(identity), 0600); err != nil {
		return err
	}
	executable, err := os.Executable()
	if err != nil {
		return err
	}
	if err = command("unshare", "--mount", "--propagation", "private", executable, "--set", *id, "--worker", work); err != nil {
		return err
	}
	imageHash, err := digest(filepath.Join(set, "vmlinuz.efi"))
	if err != nil {
		return err
	}
	initrdHash, err := digest(filepath.Join(work, "initramfs.img"))
	if err != nil {
		return err
	}
	builtManifest := map[string]any{"schema": 1, "status": "built-unvalidated", "hardware_set": *id, "boot_entry": entryID, "kernel_release": m.Release, "kernel_sha256": imageHash, "initramfs_sha256": initrdHash}
	encoded, err := json.MarshalIndent(builtManifest, "", "  ")
	if err != nil {
		return err
	}
	if err = os.WriteFile(filepath.Join(work, "built.json"), append(encoded, '\n'), 0600); err != nil {
		return err
	}
	if *resultFile != "" {
		builtManifest["directory"] = work
		data, err := json.MarshalIndent(builtManifest, "", "  ")
		if err != nil {
			return err
		}
		f, err := os.OpenFile(*resultFile, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
		if err != nil {
			return err
		}
		_, writeErr := f.Write(append(data, '\n'))
		syncErr := f.Sync()
		closeErr := f.Close()
		if err = errors.Join(writeErr, syncErr, closeErr); err != nil {
			return err
		}
	}
	fmt.Println("Built unvalidated initramfs:", work)
	return nil
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
