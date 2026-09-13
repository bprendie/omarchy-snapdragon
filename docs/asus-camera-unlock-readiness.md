# ASUS camera and encrypted-unlock readiness — September 13, 2026

Scope: Zenbook A14 UX3407RA, Snapdragon X Elite. No physical ASUS testing has
occurred. These results do not cover UX3407QA or establish camera/display success.

## RGB camera: kernel support already present

The actual EFI kernel in the local v0.1.1 image contains an ASUS device tree with
an enabled OV02C10 at CCI1, bus 1, address 0x36. Its endpoint connects reciprocally
to CSI4; CCI1, CAMSS and CSI4 are enabled. The sensor description supplies its
clock, regulators, reset GPIO and privacy LED. The shipped OV02C10 module exposes
the matching `ovti,ov02c10` device-tree alias. CAMSS, the CSI PHY and CCI drivers
are also present.

This is closer to the working ThinkPad camera than the HP OV05C10, which needed
a new sensor driver and board overlay. v0.1.1 already includes libcamera, its IPA
and tools, pipewire-libcamera and gst-plugin-libcamera. There is no demonstrated
missing ASUS RGB patch to add at this point. Do not transplant the HP overlay:
its sensor, power sequence and wiring are board-specific.

The [ASUS enablement developer's notes](https://github.com/alexVinarskis/linux-x1e80100-zenbook-a14)
report camera progress on a separate Linaro-based tree, including stable Hamoa
(X Elite) operation. That supports investigating the existing path first; it is
not validation of our kernel/image. IR camera support is not established here.

## Early display: known prerequisites already included

The shipped tree identifies the OLED as Samsung ATNA40CU11, with ATNA33XC20
compatibility. Both USB-C ports use PS8833/PS8830-compatible bridges. The common
early hook already includes their driver, the Samsung panel module, PMIC GLINK,
ADSP, QRTR, Qualcomm clocks/regulators/GPIOs/PHYs and GPU-fuse prerequisites.
All five ASUS GPU/DSP firmware payloads are included before root unlock.

The checked live initramfs contains the selected prerequisites. The installed
configuration uses the same hook and orders Plymouth before encrypt. The HP's
gpio_sbu_mux addition remains included, although ASUS uses PS883x for its ports.
No missing driver has been demonstrated that justifies a new ASUS boot patch.

`scripts/verify-asus-readiness.py` checks the embedded camera graph, root camera
drivers/packages and selected early display/input modules plus firmware. The ISO
builder now runs this check before assembling the image, so losing a known
prerequisite fails the build. This is a bounded check, not an exhaustive proof
of all device-tree dependencies or successful physical driver probing.

Validation: the v0.1.1 live archive passes, and a fresh installed-system initramfs
built from `profiles/t14s-lcd/mkinitcpio-installed.conf` passes the same checks.
A negative check removing the Samsung module from the archive listing correctly
fails. Evidence is retained in `build/asus-readiness/`: `live-validation.txt`,
`installed-validation.txt`, `driver-aliases.txt` and `initramfs-build.log`.
The new installed candidate was checked for contents, not booted in a new VM.

Existing ARM VM boot tests passed, as recorded in `asus-a14-preliminary.md` and
`snapdragon-v0.1.1.md`. QEMU cannot emulate this panel, sensor or firmware handshake.
Removing splash alone cannot repair a display controller that has not bound.
Do not force the ASUS device tree onto a QEMU virt machine.

## First physical test

1. Confirm UX3407RA and record `/proc/device-tree/model`, BIOS and kernel version.
2. Cold-boot an encrypted installation without an external display/dock. Confirm
   a visible passphrase prompt, successful unlock and desktop. Repeat a warm reboot.
3. If black, try Escape for Plymouth's text view. A still-black display needs
   evidence from the subsequent boot: kernel journal, DRM connector status,
   firmware errors and `/sys/kernel/debug/devices_deferred` (as root). Entering
   the passphrase blindly is only a recovery attempt, not a passing result.
4. Run `cam -l` in the desktop session, then `cam -c 1 --capture=10` if a camera
   is listed. Confirm a usable preview and PipeWire exposure separately; inspect
   image orientation and privacy LED behavior. Enumeration alone is insufficient.

Existing ISO files, USB media, HP and ThinkPad installations are unchanged by
this audit. No changes have been pushed.
