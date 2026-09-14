// kernel-set assembles a private, content-addressed payload; it never activates it.
package main

import (
	"crypto/sha256"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

type paths []string

func (p *paths) String() string     { return strings.Join(*p, ",") }
func (p *paths) Set(s string) error { *p = append(*p, s); return nil }

func copyPath(from, to string) error {
	if err := os.MkdirAll(filepath.Dir(to), 0755); err != nil {
		return err
	}
	if _, err := os.Lstat(to); !os.IsNotExist(err) {
		return fmt.Errorf("destination exists: %s", to)
	}
	output, err := exec.Command("cp", "-a", "--", from, to).CombinedOutput()
	if err != nil {
		return fmt.Errorf("copy: %w: %s", err, output)
	}
	return nil
}

func run() error {
	input := flag.String("input", "", "verified extracted candidate with built hp-camera")
	output := flag.String("output", "", "new package build directory")
	verify := flag.String("verify", "", "verify an assembled package directory")
	installed := flag.String("verify-installed", "", "verify an installed private set directory")
	var firmware paths
	flag.Var(&firmware, "firmware", "firmware package staging root (repeat for each model)")
	flag.Parse()
	if *installed != "" {
		if *input != "" || *output != "" || *verify != "" || len(firmware) != 0 || flag.NArg() != 0 {
			return fmt.Errorf("--verify-installed must be used alone")
		}
		return verifyInstalled(*installed)
	}
	if *verify != "" {
		if *input != "" || *output != "" || len(firmware) != 0 || flag.NArg() != 0 {
			return fmt.Errorf("--verify must be used alone")
		}
		return verifySet(*verify)
	}
	if *input == "" || *output == "" || len(firmware) == 0 || flag.NArg() != 0 {
		return fmt.Errorf("require --input, --output and --firmware")
	}
	var extracted struct {
		Schema  int    `json:"schema"`
		Release string `json:"kernel_release"`
		Hash    string `json:"kernel_sha256"`
	}
	data, err := os.ReadFile(filepath.Join(*input, "extracted.json"))
	if err != nil {
		return err
	}
	if err = json.Unmarshal(data, &extracted); err != nil {
		return err
	}
	if extracted.Schema != 1 || !regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-generic$`).MatchString(extracted.Release) {
		return fmt.Errorf("invalid extracted candidate")
	}
	if err = os.Mkdir(*output, 0755); err != nil {
		return err
	}
	payload := filepath.Join(*output, "payload")
	if err = os.Mkdir(payload, 0755); err != nil {
		return err
	}
	root := filepath.Join(*input, "root")
	for source, dest := range map[string]string{
		"boot/vmlinuz-" + extracted.Release:    "vmlinuz.efi",
		"boot/config-" + extracted.Release:     "config",
		"boot/System.map-" + extracted.Release: "System.map",
		"usr/lib/modules/" + extracted.Release: "modules/" + extracted.Release,
	} {
		if err = copyPath(filepath.Join(root, source), filepath.Join(payload, dest)); err != nil {
			return err
		}
	}
	hash, err := hashFile(filepath.Join(payload, "vmlinuz.efi"))
	if err != nil {
		return err
	}
	if hash != extracted.Hash {
		return fmt.Errorf("extracted kernel image changed")
	}
	modules := filepath.Join(payload, "modules", extracted.Release)
	for _, name := range []string{"build", "source"} {
		p := filepath.Join(modules, name)
		if err = os.Remove(p); err != nil && !os.IsNotExist(err) {
			return err
		}
	}
	for _, name := range []string{"ov05c10", "hp_camera_overlay", "hp_camera_children"} {
		source := filepath.Join(*input, "hp-camera", name+".ko")
		magic, err := exec.Command("modinfo", "-F", "vermagic", source).Output()
		if err != nil {
			return err
		}
		if !strings.HasPrefix(string(magic), extracted.Release+" ") {
			return fmt.Errorf("camera ABI mismatch: %s", name)
		}
		if err = copyPath(source, filepath.Join(modules, "updates/oma-snap-camera-hp", name+".ko")); err != nil {
			return err
		}
	}
	if err = copyPath(filepath.Join(*input, "extracted.json"), filepath.Join(payload, "provenance/extracted.json")); err != nil {
		return err
	}
	for _, fw := range firmware {
		// Keep source package metadata and firmware alongside the normalized tree.
		name := filepath.Base(filepath.Clean(fw))
		if !regexp.MustCompile(`^oma-snap-firmware-[a-z0-9-]+$`).MatchString(name) && name != "oma-snap-audio-hp" {
			return fmt.Errorf("invalid firmware package root")
		}
		if err = copyFirmwarePackage(fw, filepath.Join(payload, "firmware-packages", name)); err != nil {
			return err
		}
	}
	if err = normalizeFirmware(payload, extracted.Release); err != nil {
		return err
	}
	if err = indexModules(payload, extracted.Release); err != nil {
		return err
	}
	entries, err := inventory(payload)
	if err != nil {
		return err
	}
	encoded, err := json.Marshal(entries)
	if err != nil {
		return err
	}
	id := fmt.Sprintf("%x", sha256.Sum256(encoded))
	manifest := map[string]any{"schema": 1, "id": id, "kernel_release": extracted.Release, "entries": entries, "status": "unvalidated"}
	if err = writeJSON(filepath.Join(*output, "set.json"), manifest); err != nil {
		return err
	}
	// Different content always has a different package name, even at the same uname.
	recipe := fmt.Sprintf(`pkgname=oma-snap-set-%s
pkgver=0.2.0
pkgrel=1
pkgdesc='Retained Snapdragon hardware payload; activation requires boot integration'
arch=('aarch64')
license=('custom')
depends=('kmod')
options=('!strip' '!debug')
package() {
  install -d "$pkgdir/usr/lib/oma-snap/sets/%s"
  cp -a "$startdir/payload/." "$pkgdir/usr/lib/oma-snap/sets/%s/"
  install -m644 "$startdir/set.json" "$pkgdir/usr/lib/oma-snap/sets/%s/set.json"
}
`, id, id, id, id)
	if err = os.WriteFile(filepath.Join(*output, "PKGBUILD"), []byte(recipe), 0644); err != nil {
		return err
	}
	fmt.Println("Prepared unvalidated hardware set:", id)
	return nil
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
