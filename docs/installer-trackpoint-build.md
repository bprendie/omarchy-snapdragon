# ThinkPad installer with accumulated fixes — 2026-09-12

User authorized rebuilding and flashing the new USB at `/dev/sda` for installation
on the ThinkPad's replacement 1 TB drive. The HP base installation is separate.

Built: `dist/oma-snap-installer-kernel31-trackpoint-arm64.iso`, 6,865,131,520 bytes.
SHA-256: `a33cd031da105eb79626df9759b50dc4ef6297580288e12b7cff8be7b6eab748`.

This adds the committed model-specific TrackPoint user-provisioning script to the
keyring ISO, with paired Omarchy runtime/settings 4.0.3-1.4. It retains ARM package
trust, the graphical encrypted-disk unlock fix and corrected boot validator,
kernel 7.0.0-31-generic, matching firmware and boot helper 0.1.0-4.

The TrackPoint workaround saves `no_scroll` and disables scroll-button lock for
the 04F3 mouse on aarch64 model 21N10000US. It preserves user settings, backs up
the existing input file and is idempotent. No HID reset or experimental button
279 override is included. Right/middle button faults and reboot persistence are
not claimed fixed; see `docs/trackpoint-investigation.md`.

USB initially identified on the HP Dragonfly development host as a removable,
57.3 GiB SanDisk 3.2Gen1 USB, mounted as BIGFATTY. Recorded identity:
`build/trackpoint-usb-identity.txt`. Recheck identity and unmount before writing;
write and full-length direct readback **PASS**: all 6,865,131,520 bytes match the
ISO checksum. Readback took 46.8 seconds. USB was powered off with udisksctl and
disappeared from lsblk. Log: `build/trackpoint-usb-write-readback.log`.

The previous paired 1.3 package build is in `build/pre-trackpoint-iso/` during
this rebuild. The existing unlock/keyring ISOs remain available.

Validation: packaged provisioning script matches source and generates valid Lua
with the intended device/options; repeat execution does not duplicate the block.
Offline hashes/dependency closure and kernel/bootstrap authentication passed.
Compared package manifests: only the paired runtime/settings rebuilds changed.
The assembled root contains the script and its stock provisioning call.
VM live boot reached the Omarchy welcome screen; screenshot:
`build/installer-live-trackpoint/welcome.png`. No full installation or physical
boot of this new image has been completed yet.
The smoke VM was stopped after verification.
