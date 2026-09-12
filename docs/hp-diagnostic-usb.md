# HP diagnostic USB — 2026-09-12

The user authorized replacing the newly reidentified `/dev/sda` with a diagnostic
image and returning logs on that same USB. Device: 115.5 GiB USB DISK 3.0,
123,964,751,872 bytes; exact identity recorded in `build/hp-diag-usb-identity.txt`.
This is a different device from the 57.3 GiB SanDisk ThinkPad installer handoff.

## Design

`scripts/build-hp-diag-iso.sh` creates `dist/oma-snap-hp-diag-arm64.iso` from the
retained kernel31 live root. It adds `tools/hp-diag`, a one-shot systemd service,
diagnostic GRUB entries, and a 512 MiB FAT32 partition labeled **OMADIAG**.
It suppresses installer startup and desktop login, removes the offline package
bundle, masks udisks/pacman initialization, and disables GPT automount generation.
No internal filesystem is mounted by the collector, and no installation starts.

The collector verifies an archiso boot on a removable USB disk and selects only
the OMADIAG partition on that same parent disk. It checks the volume marker before
writing. For copy-to-RAM boots that unmount the boot partition, it requires one
unambiguous OMA_SNAP image disk before selecting its OMADIAG partition.
Three snapshots capture kernel/journal, PCI/USB, modules, network/rfkill,
DRM connector state, deferred probes, regulators, power state, hardware identity,
USB device-mode availability, and DT firmware requests with file presence checks.
It does not capture typed input, Wi-Fi passwords, account credentials or internal
user files. Logs may include hardware/network identifiers and should be reviewed
before public sharing.

Snapshots are scheduled at start, 30 seconds and 90 seconds after log initialization.
After successful file flush and unmount, the machine powers off automatically.
Command failures are recorded in their log files; a failed volume check or write
stops collection without attempting another disk. Partial folders have STARTED.txt;
COMPLETE.txt means all snapshots were saved. No background logging daemon remains.

The default entry exercises normal graphics initialization. The fallback adds
`nomodeset`. This image gathers evidence; it does not supply the missing HP DSP/GPU
firmware or claim to repair Wi-Fi. Early failures before live userspace starts
cannot be captured by this service.

## Use

1. Boot the USB on the HP and let the default diagnostic entry run.
2. Wait for automatic poweroff, usually within 2–4 minutes.
3. Return the USB to the Dragonfly. Logs are in `hp-diag-*` folders on OMADIAG.

If it has not powered off after six minutes, shut down before unplugging. Try the
fallback GRUB entry on the next boot; prior log folders are retained.

## Validation status

Physical HP run: the six-minute service timeout stopped collection. The returned
USB preserved STARTED.txt and all 11 command logs from phase 00, copied and
hash-verified under `private/hp-live/hp-diag-20260912T171158-a29ee08d/`.
No sysfs.txt, firmware-requests.txt or COMPLETE.txt was saved. Direct hardware
status reads in sysfiles() are unbounded and buffered until the phase ends;
the exact blocking read is unknown. VM success did not expose this hardware
failure. See [recovered findings](hp-first-install-investigation.md).

Go compilation/vet, shell syntax, and refusal to run on an ordinary host passed.
The first VM attempt exposed a missing `.disk/info` boot-discovery marker; this
was corrected and recorded in `build/hp-diag-build/first-grub-failure.log`.
The second attempt reached Linux but safely refused collection because archiso
had copied the live root to RAM and unmounted bootmnt. The collector now handles
that mode while refusing ambiguous image disks. Evidence is retained in
`build/hp-diag-vm-copytoram-failure/`.
The next attempt exposed that an unqualified blkid scan omits the hybrid whole
disk's ISO label even though udev/lsblk expose it. Image discovery now uses
lsblk's PATH/LABEL inventory and retains the unique-parent check. Evidence:
`build/hp-diag-vm-label-failure/`.
The final image passed writable-USB ARM UEFI VM boot, automatic collection,
flush/unmount and automatic poweroff. Recovered `COMPLETE.txt` plus all 39
nonempty snapshot files from the FAT partition after QEMU exited normally.
The final snapshot reports zero failed services. No target disk was attached.
`lsusb` is absent from the retained live root; its error is recorded, while PCI,
kernel, module and sysfs evidence remain available. QEMU has no USB device-mode
controller, also recorded as an unavailable diagnostic. Physical HP validation
remains pending; virtual graphics/network devices cannot establish HP support.

Artifact: `dist/oma-snap-hp-diag-arm64.iso`, 4,765,427,712 bytes.
SHA-256: `6e3b2c27387198d034c568fb6cd0511befac329b8c4ba5d2d3a2acae5ee68d82`.
Physical USB write completed. The desktop automounted OMADIAG during the first
readback, which did not match. After unmounting, a full byte comparison reported
no differences. Final direct SHA-256 verification passed for all 4,765,427,712
bytes; OMADIAG on `/dev/sda3` was confirmed and the USB was powered off for
removal. Evidence: `build/hp-diag-usb-write-readback.log` (original write in
`build/hp-diag-usb-first-write.log`). The writer now
temporarily sets UDISKS_IGNORE for this USB during write/readback and removes
its temporary rule on exit; `--verify-only` repeats the checks without rewriting.

VM test: `scripts/test-hp-diag-vm.sh`, `build/hp-diag-vm/`, no target disk attached.
Writer: `scripts/write-hp-diag-usb.sh` rechecks USB identity/mounts, verifies the ISO,
writes it, verifies full direct readback, and checks the OMADIAG partition label.
