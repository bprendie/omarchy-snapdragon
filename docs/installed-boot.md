# Installed boot adapter (prototype)

The stock Quattro installer remains responsible for disk layout, encryption, mounting, package installation, user creation and system setup. Patch `0003-quattro-arm-installer.patch` changes ARM kernel selection and routes boot finalization to the small `oma-snap-boot-install` command. Its installed-target path has not yet been exercised by a complete VM installation.

## Evidence

`scripts/smoke-arch-grub.sh` builds an ARM64 EFI loader with the Arch ARM GRUB 2:2.14-1.1 package and boots the existing console ISO through it, with no physical disks or network. The resulting VM reached a root shell with kernel `7.0.0-30-generic`, overlay root and no failed systemd units. `ARCH_GRUB_BOOT_PASS` was observed; the VM then shut down cleanly. This tests Arch GRUB loading the Ubuntu Stubble image, not installed disk discovery, Qualcomm device-tree selection or Secure Boot. The VM had Secure Boot disabled.

`cutmem` is supplied by GRUB's `mmap` module, not a separate `cutmem.mod`; both the Ubuntu and Arch ARM command maps contain it. The generated installed configuration retains the Ubuntu Snapdragon SMBIOS check, memory exclusion and command-line workarounds. Those hardware branches remain untested on the T14s.

## Payload and ownership

- `oma-snap-boot` owns the ARM Go finalizer, installed-root mkinitcpio configuration and Qualcomm build hook. The hook was previously an unowned console-build file in the development container; after comparing it byte-for-byte, it was moved aside and the package installed successfully.
- Quattro writes `/etc/kernel/cmdline` using its existing archinstall or protected-root parameter generation.
- The finalizer requires root/ARM64, a separately mounted ext4/Btrfs target and FAT ESP. It rejects `/`, path aliases and unsafe command-line syntax. It refuses an existing `oma-snap` boot namespace or existing fallback directory when fallback is requested.
- The unchanged kernel and a newly generated installed-root initramfs go under `ESP/oma-snap/7.0.0-30-generic/`. The config uses the actual ESP UUID and the target root parameters.
- Arch GRUB is installed under `ESP/EFI/oma-snap`, with its modules/config under `ESP/oma-snap/grub`. Firmware boot order is not changed. On a fresh ESP, Quattro may request the removable `EFI/BOOT/BOOTAA64.EFI` path. Protected installs do not overwrite that fallback; firmware entry registration/selection for that mode remains to implement/test.

The installed initramfs uses `encrypt` and filesystem discovery instead of `archiso`, with matching Qualcomm modules and firmware. Hibernation setup is deferred. Encrypted deferred provisioning is explicitly rejected before disk operations because its upstream automatic-unlock flow assumes Limine; normal owner installation still needs end-to-end encryption validation. Factory snapshot/reset and update/recovery integration remain unfinished.

## Validation limits and next action

Go unit tests exercise input rejection; installer tests exercise payload mismatch detection, missing fallback detection, protected-path dispatch and early rejection of the unsupported provisioning mode. The patched installer has 70 passing Python tests plus its existing shell suite. These checks are not evidence of a successful disk installation.

The user initially waived the complete VM installation/boot gate for a physical test, then requested resuming internal VM testing after the live hardware failures. Earlier VM tests exposed missing swap/audio packages, now included in the mirror. A fresh run is underway; see status for current evidence. The boot adapter remains unverified end to end.

The current runtime package explicitly refuses factory reset and automatic snapshot restore when the Snapdragon boot helper is present. Stock factory reset rebuilds Limine and may re-key encryption, so advertising it with this GRUB payload would be incorrect. Snapshot creation remains usable but does not promise boot-menu selection. Recovery-guard tests confirm refusal before elevation or disk mutations. The handed-off hardware-test ISO includes this guard.
