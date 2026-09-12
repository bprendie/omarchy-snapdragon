// boot-install installs the bounded Snapdragon boot payload after Quattro mounts its target.
package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
)

const kernel = "7.0.0-31-generic"

func fail(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func capture(name string, args ...string) (string, error) {
	b, err := exec.Command(name, args...).CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("%s: %w: %s", name, err, b)
	}
	return strings.TrimSpace(string(b)), nil
}

func run(name string, args ...string) error {
	c := exec.Command(name, args...)
	c.Stdout, c.Stderr, c.Stdin = os.Stdout, os.Stderr, os.Stdin
	if err := c.Run(); err != nil {
		return fmt.Errorf("%s: %w", name, err)
	}
	return nil
}

func validate(target, esp, cmdline string) error {
	if !filepath.IsAbs(target) || filepath.Clean(target) != target || target == "/" {
		return fmt.Errorf("target must be a canonical absolute mounted target, never /")
	}
	if esp != "/boot" && esp != "/boot/efi" && esp != "/efi" {
		return fmt.Errorf("unsupported ESP mount: %q", esp)
	}
	if !regexp.MustCompile(`^[a-zA-Z0-9_./:=,@+% -]+$`).MatchString(cmdline) {
		return fmt.Errorf("kernel command line contains unsupported GRUB characters")
	}
	for _, word := range strings.Fields(cmdline) {
		if strings.HasPrefix(word, "root=") && len(word) > 5 {
			return nil
		}
	}
	return fmt.Errorf("kernel command line has no root device")
}

func copyFile(from, to string) error {
	src, err := os.Open(from)
	if err != nil {
		return err
	}
	defer src.Close()
	if err = os.MkdirAll(filepath.Dir(to), 0755); err != nil {
		return err
	}
	dst, err := os.OpenFile(to, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	_, err = io.Copy(dst, src)
	closeErr := dst.Close()
	if err != nil {
		return err
	}
	return closeErr
}

func main() {
	target := flag.String("target", "", "mounted Quattro installation target")
	esp := flag.String("esp", "/boot", "ESP mount inside target")
	fallback := flag.Bool("fallback", false, "write removable loader on a newly created ESP")
	flag.Parse()
	data, err := os.ReadFile(filepath.Join(*target, "etc/kernel/cmdline"))
	fail(err)
	cmdline := strings.TrimSpace(string(data))
	fail(validate(*target, *esp, cmdline))
	if os.Geteuid() != 0 || runtime.GOARCH != "arm64" {
		fail(fmt.Errorf("requires root in the ARM64 live installer"))
	}
	resolved, err := filepath.EvalSymlinks(*target)
	fail(err)
	if resolved != *target {
		fail(fmt.Errorf("target must not resolve through symlinks"))
	}
	rootType, err := capture("findmnt", "-rn", "-M", *target, "-o", "FSTYPE")
	fail(err)
	if rootType != "btrfs" && rootType != "ext4" {
		fail(fmt.Errorf("unexpected target filesystem: %s", rootType))
	}
	espRoot := filepath.Join(*target, *esp)
	espType, err := capture("findmnt", "-rn", "-M", espRoot, "-o", "FSTYPE")
	fail(err)
	if espType != "vfat" {
		fail(fmt.Errorf("ESP must be a separately mounted FAT filesystem"))
	}
	uuid, err := capture("findmnt", "-rn", "-M", espRoot, "-o", "UUID")
	fail(err)
	if !regexp.MustCompile(`^[A-Fa-f0-9-]+$`).MatchString(uuid) {
		fail(fmt.Errorf("invalid ESP UUID"))
	}
	for _, path := range []string{"EFI/oma-snap", "oma-snap"} {
		_, err = os.Lstat(filepath.Join(espRoot, path))
		if !os.IsNotExist(err) {
			fail(fmt.Errorf("refusing existing boot namespace: %s", path))
		}
	}
	if *fallback {
		_, err = os.Lstat(filepath.Join(espRoot, "EFI/BOOT"))
		if !os.IsNotExist(err) {
			fail(fmt.Errorf("refusing to replace an existing fallback loader"))
		}
	}
	rel := "oma-snap/" + kernel
	dest := filepath.Join(espRoot, rel)
	fail(copyFile(filepath.Join(*target, "usr/lib/oma-snap", kernel, "vmlinuz.efi"), filepath.Join(dest, "vmlinuz.efi")))
	fail(run("arch-chroot", *target, "mkinitcpio", "-c", "/usr/share/oma-snap/mkinitcpio-installed.conf", "-k", kernel, "-g", filepath.Join(*esp, rel, "initramfs.img")))
	grubDir := filepath.Join(espRoot, "oma-snap/grub")
	fail(os.MkdirAll(grubDir, 0755))
	config := fmt.Sprintf(`set timeout=5
search --no-floppy --fs-uuid --set=root %s
smbios --type 4 --get-string 5 --set proc_version
if regexp "Snapdragon.*" "$proc_version"; then
  if [ "$lockdown" != "y" ]; then
    cutmem 0x8800000000 0x8fffffffff
  fi
fi
menuentry 'Omarchy Snapdragon' {
  linux /%s/vmlinuz.efi %s clk_ignore_unused pd_ignore_unused arm64.nopauth quiet splash
  initrd /%s/initramfs.img
}
menuentry 'Firmware settings' { fwsetup }
`, uuid, rel, cmdline, rel)
	fail(os.WriteFile(filepath.Join(grubDir, "grub.cfg"), []byte(config), 0644))
	args := []string{*target, "grub-install", "--target=arm64-efi", "--efi-directory=" + *esp, "--boot-directory=" + filepath.Join(*esp, "oma-snap"), "--bootloader-id=oma-snap", "--no-nvram"}
	fail(run("arch-chroot", args...))
	if *fallback {
		fail(copyFile(filepath.Join(espRoot, "EFI/oma-snap/grubaa64.efi"), filepath.Join(espRoot, "EFI/BOOT/BOOTAA64.EFI")))
	}
	fmt.Println("Boot payload installed; existing firmware boot order unchanged.")
}
