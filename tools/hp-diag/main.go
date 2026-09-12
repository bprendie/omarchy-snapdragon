package main

import (
	"bytes"
	"context"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

const mountpoint = "/run/oma-snap-diag"
const marker = "oma-snap-hp-diagnostic-v1"

func command(timeout time.Duration, args ...string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	type result struct {
		data []byte
		err  error
	}
	done := make(chan result, 1)
	go func() {
		cmd := exec.CommandContext(ctx, args[0], args[1:]...)
		cmd.WaitDelay = time.Second
		data, err := cmd.CombinedOutput()
		done <- result{data, err}
	}()
	select {
	case r := <-done:
		return r.data, r.err
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

func parent(device string) (string, error) {
	resolved, err := filepath.EvalSymlinks(device)
	if err != nil {
		return "", err
	}
	out, err := command(5*time.Second, "lsblk", "-dn", "-o", "PKNAME", resolved)
	if err != nil {
		return "", fmt.Errorf("lsblk: %w: %s", err, out)
	}
	name := strings.TrimSpace(string(out))
	if name == "" {
		name = filepath.Base(resolved)
	}
	if strings.ContainsAny(name, "/ \n\t") {
		return "", fmt.Errorf("ambiguous parent %q", name)
	}
	return name, nil
}

func logVolume() (string, error) {
	boot, err := command(5*time.Second, "findmnt", "-n", "-o", "SOURCE", "/run/archiso/bootmnt")
	if err != nil {
		// copytoram deliberately unmounts bootmnt. Require one unique image
		// disk; never select an arbitrary matching label when multiple exist.
		if _, err := os.Stat("/run/archiso/copytoram"); err != nil {
			return "", fmt.Errorf("not an archiso live boot: %w", err)
		}
		devices, err := command(5*time.Second, "lsblk", "-prn", "-o", "PATH,LABEL")
		if err != nil {
			return "", fmt.Errorf("live image device not found: %w", err)
		}
		parents := make(map[string]string)
		for _, line := range strings.Split(string(devices), "\n") {
			fields := strings.Fields(line)
			if len(fields) != 2 || fields[1] != "OMA_SNAP" {
				continue
			}
			device := fields[0]
			p, err := parent(device)
			if err != nil {
				return "", err
			}
			parents[p] = device
		}
		if len(parents) != 1 {
			return "", fmt.Errorf("ambiguous live image disks: %d", len(parents))
		}
		for _, device := range parents {
			boot = []byte(device)
		}
	}
	bootParent, err := parent(strings.TrimSpace(string(boot)))
	if err != nil {
		return "", err
	}
	removable, err := os.ReadFile("/sys/class/block/" + bootParent + "/removable")
	if err != nil || strings.TrimSpace(string(removable)) != "1" {
		return "", fmt.Errorf("boot disk is not removable")
	}
	syspath, err := filepath.EvalSymlinks("/sys/class/block/" + bootParent)
	if err != nil || !strings.Contains(syspath, "/usb") {
		return "", fmt.Errorf("boot disk is not USB")
	}
	devices, err := command(5*time.Second, "blkid", "-t", "LABEL=OMADIAG", "-o", "device")
	if err != nil {
		return "", fmt.Errorf("OMADIAG volume not found: %w", err)
	}
	var matches []string
	for _, device := range strings.Fields(string(devices)) {
		p, err := parent(device)
		if err == nil && p == bootParent {
			matches = append(matches, device)
		}
	}
	if len(matches) != 1 {
		return "", fmt.Errorf("expected one log volume on boot USB, found %d", len(matches))
	}
	return matches[0], nil
}

func saveCommand(dir, name string, args ...string) error {
	out, err := command(8*time.Second, args...)
	header := fmt.Sprintf("$ %s\nresult: %v\n\n", strings.Join(args, " "), err)
	// A missing/failed diagnostic command is evidence; a failed USB write is fatal.
	return os.WriteFile(filepath.Join(dir, name+".txt"), append([]byte(header), out...), 0600)
}

func sysfiles(dir string) error {
	patterns := []string{
		"/proc/cmdline", "/proc/version", "/sys/firmware/devicetree/base/model",
		"/sys/firmware/devicetree/base/compatible", "/sys/class/dmi/id/product_name",
		"/sys/class/dmi/id/product_sku", "/sys/class/dmi/id/board_name", "/sys/class/dmi/id/bios_version",
		"/sys/class/drm/card*-*/status", "/sys/class/drm/card*-*/enabled", "/sys/class/drm/card*-*/modes",
		"/sys/class/power_supply/*/status", "/sys/class/power_supply/*/online",
		"/sys/class/power_supply/*/capacity", "/sys/kernel/debug/devices_deferred",
		"/sys/kernel/debug/regulator/regulator_summary",
	}
	out, err := os.Create(filepath.Join(dir, "sysfs.txt"))
	if err != nil {
		return err
	}
	defer out.Close()
	for _, pattern := range patterns {
		paths, _ := filepath.Glob(pattern)
		for _, path := range paths {
			if _, err := fmt.Fprintf(out, "\nReading %s\n", path); err != nil {
				return err
			}
			data, readErr := command(3*time.Second, "cat", path)
			if _, err := fmt.Fprintf(out, "error: %v\n%s\n", readErr, bytes.ReplaceAll(data, []byte{0}, []byte{'\n'})); err != nil {
				return err
			}
			if readErr != nil {
				return out.Sync()
			}
		}
	}
	return out.Sync()
}

func firmware(dir string) error {
	var out bytes.Buffer
	release, err := command(5*time.Second, "uname", "-r")
	if err != nil {
		return err
	}
	kernel := strings.TrimSpace(string(release))
	err = filepath.WalkDir("/sys/firmware/devicetree/base", func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			fmt.Fprintf(&out, "%s: %v\n", path, walkErr)
			return nil
		}
		if entry.IsDir() || entry.Name() != "firmware-name" {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			fmt.Fprintf(&out, "%s: %v\n", path, err)
			return nil
		}
		for _, name := range strings.Split(string(data), "\x00") {
			if name == "" {
				continue
			}
			fmt.Fprintf(&out, "\n%s requests %s\n", path, name)
			for _, base := range []string{"/usr/lib/firmware/" + kernel, "/usr/lib/firmware"} {
				for _, suffix := range []string{"", ".zst", ".xz"} {
					file := filepath.Join(base, name) + suffix
					_, err := os.Stat(file)
					fmt.Fprintf(&out, "%s: %v\n", file, err)
				}
			}
		}
		return nil
	})
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dir, "firmware-requests.txt"), out.Bytes(), 0600)
}

func snapshot(root, phase string) error {
	dir := filepath.Join(root, phase)
	if err := os.Mkdir(dir, 0700); err != nil {
		return err
	}
	commands := [][]string{
		{"kernel", "dmesg"}, {"journal", "journalctl", "-b", "-n", "5000", "--no-pager", "-o", "short-monotonic"},
		{"pci", "lspci", "-nnk", "-vv"}, {"usb", "lsusb", "-t"}, {"modules", "lsmod"},
		{"network", "nmcli", "-t", "device", "status"}, {"links", "ip", "-details", "link"},
		{"rfkill", "rfkill", "list"}, {"failed-units", "systemctl", "--failed", "--no-pager"},
		{"disks", "lsblk", "-o", "NAME,PATH,SIZE,FSTYPE,LABEL,MOUNTPOINTS"},
		{"usb-device-mode", "ls", "-l", "/sys/class/udc"},
	}
	for _, cmd := range commands {
		if err := saveCommand(dir, cmd[0], cmd[1:]...); err != nil {
			return err
		}
	}
	if err := sysfiles(dir); err != nil {
		return err
	}
	return firmware(dir)
}

func collect() error {
	command(20*time.Second, "udevadm", "settle", "--timeout=15")
	volume, err := logVolume()
	if err != nil {
		return err
	}
	if err = os.MkdirAll(mountpoint, 0700); err != nil {
		return err
	}
	out, err := command(10*time.Second, "mount", "-t", "vfat", "-o", "rw,nosuid,nodev,noexec,umask=077", volume, mountpoint)
	if err != nil {
		return fmt.Errorf("mount: %w: %s", err, out)
	}
	mounted := true
	defer func() {
		if mounted {
			command(15*time.Second, "umount", mountpoint)
		}
	}()
	data, err := os.ReadFile(filepath.Join(mountpoint, "DIAG-VOLUME.txt"))
	if err != nil || strings.TrimSpace(string(data)) != marker {
		return fmt.Errorf("log volume marker mismatch")
	}
	bootID, err := os.ReadFile("/proc/sys/kernel/random/boot_id")
	if err != nil {
		return err
	}
	dir := filepath.Join(mountpoint, "hp-diag-"+time.Now().UTC().Format("20060102T150405")+"-"+strings.TrimSpace(string(bootID))[:8])
	if err = os.Mkdir(dir, 0700); err != nil {
		return err
	}
	if err = os.WriteFile(filepath.Join(dir, "STARTED.txt"), []byte("Diagnostic live boot. Internal disks are not mounted by this collector.\n"), 0600); err != nil {
		return err
	}
	start := time.Now()
	for i, delay := range []time.Duration{0, 30 * time.Second, 90 * time.Second} {
		if remaining := time.Until(start.Add(delay)); remaining > 0 {
			time.Sleep(remaining)
		}
		if err = snapshot(dir, fmt.Sprintf("%02d", i)); err != nil {
			return err
		}
		if out, err = command(15*time.Second, "sync", "-f", mountpoint); err != nil {
			return fmt.Errorf("sync: %w: %s", err, out)
		}
	}
	if err = os.WriteFile(filepath.Join(dir, "COMPLETE.txt"), []byte("All three snapshots saved. Logs are local to this USB.\n"), 0600); err != nil {
		return err
	}
	if out, err = command(15*time.Second, "sync", "-f", mountpoint); err != nil {
		return fmt.Errorf("final sync: %w: %s", err, out)
	}
	if out, err = command(15*time.Second, "umount", mountpoint); err != nil {
		return fmt.Errorf("unmount: %w: %s", err, out)
	}
	mounted = false
	fmt.Println("Diagnostics saved successfully; powering off.")
	return nil
}

func main() {
	data, err := os.ReadFile("/proc/cmdline")
	args := " " + string(data) + " "
	if err != nil || os.Geteuid() != 0 || !strings.Contains(args, " oma_snap_diag=1 ") {
		fmt.Fprintln(os.Stderr, "Requires root and diagnostic live-boot command line")
		os.Exit(1)
	}
	if err = collect(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if out, err := command(10*time.Second, "systemctl", "--no-block", "poweroff"); err != nil {
		fmt.Fprintf(os.Stderr, "Logs saved, poweroff failed: %v: %s\n", err, out)
		os.Exit(1)
	}
}
