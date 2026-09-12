# HP firmware installer candidate — 2026-09-12

The returned physical logs confirm that the selected HP device tree requests
GPU and DSP files absent from the kernel31 baseline. This candidate adds those
five files to the live root, live initramfs and installed target via a separate
pacman package, `oma-snap-firmware-hp 7700.1-1`.

## Provenance and scope

HP Qualcomm Driver Pack SP162865, version 7700.1 revision E pass 5, explicitly
lists board 0x8CBE and the EliteBook Ultra G1q in its CVA. Downloaded over HTTPS
from HP; the full executable's SHA-256 matches HP's CVA value:
`215ec14bef7090660a5e868f22e84fbeea2ee1139706a0615bfda62948417e08`.
The Windows installer was extracted with 7z, never executed. No BIOS/EC update
or Windows driver is installed. This is a pinned model-specific source, not a
claim that SP162865 is HP's newest pack.

- [HP download metadata](https://ftp.hp.com/pub/softpaq/sp162501-163000/sp162865.cva)
- [HP original archive](https://ftp.hp.com/pub/softpaq/sp162501-163000/sp162865.exe)

Packaged files under `/usr/lib/firmware/7.0.0-31-generic/qcom/x1e80100/hp/elitebook-ultra-g1q/`:

- qcdxkmsuc8380.mbn from src/Driver/qcdx8380
- qcadsp8380.mbn and adsp_dtbs.elf from src/Driver/1ADSP_7700_0711_hamoa
- qccdsp8380.mbn and cdsp_dtbs.elf from src/Driver/1qcnspmcdm_ext_cdsp8380_7800

This is a local hardware-test artifact. Vendor binary redistribution permission
has not been established; upstream handoff should preserve the extraction recipe
and provenance rather than publishing these blobs as project-owned firmware.

The installed physical HP now reaches the desktop; the user confirms working
Wi-Fi, Bluetooth and touchpad. Audio and brightness remain under investigation.
See [live findings](hp-audio-brightness.md).

Earlier diagnostic Bluetooth concern: the live DT selects qcom,wcn6855-bt, and the driver
requests wcnhpbtfw20.tlv/hpbtfw20.tlv. This driver pack contains hpbtfw21.tlv and
hmtbtfw20.tlv. No mismatched file is renamed to satisfy that request. Upstream's
HP shared DT also currently selects wcn6855-bt. No additional Bluetooth rename
was needed for the user's successful installed-system test.

## Build and operation

`scripts/prepare-hp-firmware.sh` verifies the pinned input, extracts only the
selected files, and builds the package without running the Windows installer.
`scripts/build-hp-installer.sh` creates a separate HP image from the retained
ThinkPad installer root and boot files. The ThinkPad ISOs remain unchanged.
The HP-only profile patch adds the firmware package to early ARM provisioning,
so it is present before the normal boot helper generates the installed initramfs.
The same package is added to the existing local offline repository, preserving
mandatory upstream package signatures. Kernel and base firmware pins are unchanged.

Default GRUB entry runs the Omarchy installer. Optional normal/nomodeset diagnostic
entries save to the appended 512 MiB OMADIAG volume and skip installer startup.
The collector now writes each sysfs read incrementally with a three-second
command deadline and stops further hardware reads in that snapshot on error.
The process wait also has an outer deadline so a kernel-blocked child cannot
hold up the collector itself. This cannot guarantee that a kernel deadlock will
allow shutdown. Its blocked-FIFO regression test and Go race/vet checks pass.

## Validation and handoff

Current artifact: `dist/oma-snap-installer-hp-firmware-ram-arm64.iso`,
7,443,206,144 bytes. SHA-256:
`0e4b4ec5108e9c4f0ebded8a98da33cbfad5984beb5bc23c519af1515cb36932`.

The first firmware candidate reached the welcome screen but its optional
diagnostic run revealed that the rebuilt initramfs left the whole USB mounted
as ISO9660. Mounting the FAT partition then failed with "Can't open blockdev".
The final GRUB profile explicitly sets `copytoram=y copytoram_size=12G` for all
entries, restoring RAM-backed operation on the 32 GB HP. The log-volume README
also now distinguishes the default installer from optional diagnostics.

Validation passed:

- Vendor archive SHA-256 and all five ELF firmware payloads in the live root.
- All five requested files included in the rebuilt live initramfs.
- Pacman package ownership/integrity, 18 entries and zero altered files.
- Offline HP firmware/boot dependency resolution against an empty package DB.
- HP-specific early package list selection on ARM, unchanged x86 behavior.
- First firmware candidate ARM UEFI virtual-USB boot to the Omarchy welcome screen, zero failed services,
  intact firmware package in the running live system, diagnostic service inactive
  in normal installer mode. No installation target was attached.

Evidence: `build/hp-installer-vm/welcome.png`, `validation.txt`, `serial.log`,
`build/hp-offline-dependencies.log`, `build/hp-initramfs-contents.txt`.
The corrected image's writable-USB diagnostic VM passed: it saved COMPLETE.txt
and all 39 nonempty snapshot logs, flushed/unmounted the log volume, and powered
off automatically. The recovered final snapshot reports zero failed units.
Evidence: `build/hp-firmware-diag-vm/returned/` and `serial.log`. The collector's
hardware timeout fix has a blocked-read regression test; a
complete diagnostic capture with this new combined image has not been retested
on physical hardware. Neither has the new HP firmware or installed desktop.

The first candidate passed full physical write/readback. The correction changes
only 15,093,760 bytes across four blocks. `tools/image-delta` first verifies the
entire target against the old image, applies changed blocks, flushes and checks
the new image. The USB writer separately checks identity/mounts, suppresses
automount, and performs full direct readback. The update and final direct
readback passed for all 7,443,206,144 bytes, matching the corrected ISO hash.
OMADIAG was confirmed on /dev/sdb3 and the SanDisk was powered off for removal.
Evidence: `build/hp-installer-usb-ram-readback.log` (initial full write in
`build/hp-installer-usb-write-readback.log`).
Delta tests cover wrong-old-image refusal without writes, input alias refusal,
multiple changed blocks, and preservation of bytes beyond the image.
No physical HP firmware success is claimed.
The user selected the 57.3 GiB SanDisk on /dev/sdb for this image; the prior
115.5 GiB diagnostic USB on /dev/sda retains the captured logs.
