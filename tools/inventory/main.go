// inventory prints a bounded, read-only hardware report. No network or writes.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

type result struct {
	Value string `json:"value,omitempty"`
	Error string `json:"error,omitempty"`
}

func read(path string) result {
	b, err := os.ReadFile(path)
	if err != nil {
		return result{Error: err.Error()}
	}
	return result{Value: strings.TrimSpace(strings.ReplaceAll(string(b), "\x00", " "))}
}
func command(name string, args ...string) result {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	b, err := exec.CommandContext(ctx, name, args...).Output()
	r := result{Value: strings.TrimSpace(string(b))}
	if err != nil {
		r.Error = err.Error()
	}
	return r
}
func main() {
	r := map[string]any{"schema": 1, "time_utc": time.Now().UTC().Format(time.RFC3339), "architecture": runtime.GOARCH}
	for key, path := range map[string]string{
		"model": "/sys/class/dmi/id/product_version", "machine_type": "/sys/class/dmi/id/product_name",
		"vendor": "/sys/class/dmi/id/sys_vendor", "bios_version": "/sys/class/dmi/id/bios_version",
		"bios_date": "/sys/class/dmi/id/bios_date", "device_tree_model": "/proc/device-tree/model",
		"device_tree_compatible": "/proc/device-tree/compatible", "soc": "/sys/devices/soc0/soc_id",
		"soc_revision": "/sys/devices/soc0/revision", "os": "/etc/os-release",
		"kernel": "/proc/sys/kernel/osrelease", "alsa_cards": "/proc/asound/cards",
	} {
		r[key] = read(path)
	}
	model := read("/sys/class/dmi/id/product_version").Value + read("/proc/device-tree/model").Value
	class := "non-target"
	if runtime.GOARCH == "arm64" && strings.Contains(strings.ToLower(model), "t14s") {
		class = "candidate-t14s-target"
	}
	vm := command("systemd-detect-virt")
	if vm.Value != "" && vm.Value != "none" {
		class = "virtual-machine-or-container"
	}
	r["host_class"] = class
	r["virtualization"] = vm
	for _, line := range strings.Split(read("/proc/meminfo").Value, "\n") {
		if strings.HasPrefix(line, "MemTotal:") {
			r["memory"] = strings.TrimSpace(line)
		}
	}
	// Omit UUIDs, labels, serials, WWNs and mount paths that may contain usernames.
	r["storage"] = command("lsblk", "--json", "--bytes", "--output", "NAME,TYPE,SIZE,FSTYPE,PARTTYPE,RO,RM")
	r["root_filesystem"] = command("findmnt", "-n", "-o", "FSTYPE", "/")
	r["pci_devices"] = command("lspci", "-nn")
	r["usb_devices"] = command("lsusb")
	r["modules"] = command("lsmod")
	r["firmware_packages"] = command("dpkg-query", "-W", "-f=${Package} ${Version}\n", "linux-firmware", "linux-image-*", "linux-modules-*", "stubble", "alsa-ucm-conf")
	r["arch_packages"] = command("pacman", "-Q", "linux-firmware", "mesa", "alsa-ucm-conf", "hyprland", "quickshell")
	// Only non-identifying command-line options are copied; unknown values stay private.
	var cmdline []string
	for _, arg := range strings.Fields(read("/proc/cmdline").Value) {
		key, _, hasValue := strings.Cut(arg, "=")
		switch key {
		case "quiet", "splash", "ro", "rw", "rootwait", "rootfstype", "loglevel", "clk_ignore_unused", "pd_ignore_unused", "efi", "iommu", "arm64.nopauth", "stubble.dtb_override":
			cmdline = append(cmdline, arg)
		default:
			if hasValue {
				cmdline = append(cmdline, key+"=<redacted>")
			} else {
				cmdline = append(cmdline, "<redacted-flag>")
			}
		}
	}
	r["kernel_command_line_redacted"] = cmdline
	panels := map[string]any{}
	paths, err := filepath.Glob("/sys/class/drm/card*-*")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	for _, p := range paths {
		if _, err := os.Stat(filepath.Join(p, "status")); err != nil {
			continue
		}
		panels[filepath.Base(p)] = map[string]result{"status": read(p + "/status"), "modes": read(p + "/modes")}
	}
	r["display_connectors"] = panels
	batteries := map[string]any{}
	paths, err = filepath.Glob("/sys/class/power_supply/*")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	for _, p := range paths {
		if read(p+"/type").Value != "Battery" {
			continue
		}
		b := map[string]result{}
		for _, field := range []string{"status", "energy_full", "energy_full_design", "energy_now", "power_now", "charge_full", "charge_full_design", "charge_now", "current_now", "voltage_now", "cycle_count"} {
			b[field] = read(p + "/" + field)
		}
		batteries[filepath.Base(p)] = b
	}
	r["batteries"] = batteries
	_, err = os.Stat("/sys/firmware/efi")
	r["efi_boot"] = err == nil
	r["limitations"] = "No raw logs, EDID serials, boot identifiers, addresses or secrets collected. Kernel config, boot artifacts, graphics renderer, panel identity and relevant errors require separate local inspection. Target classification is provisional."
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	if err := enc.Encode(r); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
