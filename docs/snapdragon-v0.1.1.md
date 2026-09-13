# Snapdragon v0.1.1 — local candidate

This remains Omarchy 4.0.3 on the pinned Ubuntu-derived 7.0.0-31 kernel.
No push or release upload is authorized yet. The published image is v0.1.0.

## Changes from v0.1.0

- Camera userspace for both physical machines: libcamera/tools, PipeWire camera
  integration and the GStreamer plugin, with a signed seven-package dependency
  set from Arch Linux ARM.
- HP EliteBook Ultra G1q OV05C10 driver, board overlay, CSI PHY population helper
  and a service enabled on installation. Both module and service gates restrict
  this to HP board 8CBE; the camera modules require the exact kernel ABI.
- Matched Lenovo T14s Gen 6 cDSP firmware from package 1.0.0.23, the pair used
  in the successful FastRPC, DSP validator and QNN HTP tests. NPU test runtime
  and Qualcomm SDK are not installed by this image.
- Existing ThinkPad boot/display/TrackPoint settings, HP Wi-Fi/audio/unlock
  fixes and preliminary ASUS UX3407RA firmware are retained.

No speculative Fn/backlight fix is included. Neither machine's keyboard
backlight is confirmed working. ASUS hardware remains untested.

## Build and validation

Prepare the HP camera package with `scripts/build-hp-camera-package.sh`, using
Ubuntu common and ARM64 headers verified by `manifests/hp-camera-headers.sha256`.
Prepare Lenovo firmware with `scripts/prepare-t14s-npu-firmware.sh` (requires
innoextract), and camera archives with `scripts/prepare-camera-offline.sh`.
The latter deliberately fails if the pinned upstream versions have changed.
The existing v0.1.0 prerequisites and base exports are still required.

Run `scripts/build-snapdragon-installer.sh`, then
`scripts/verify-snapdragon-offline.sh`. The builder refuses to overwrite an
existing v0.1.1 stage/image. It packages all hardware additions into the live
root and local repository, patches Quattro's package requests, regenerates the
initramfs and SquashFS, and creates a bootable ISO with the diagnostic partition.

Offline dependency closure: **PASS, 970 packages**. Added packages installed
through pacman in the ARM build environment and live root. HP camera physical
reboot, repeated direct capture and PipeWire capture: **PASS**. User confirmed
usable RGB preview. ThinkPad camera and NPU physical tests: **PASS** as detailed
in their separate documents; the NPU test used a temporary matching firmware
pair before this packaging step.

ISO build: **PASS**. UEFI boot entry and appended EFI/diagnostic partitions
verified. All 961 v0.1.0 package archives are retained byte-identically;
the new image adds nine packages. Live-root integrity check: all ten checked boot, firmware and camera
packages have zero altered files. The initramfs includes the new Lenovo pair
and retained HP/ASUS firmware. ARM UEFI VM smoke test: **PASS**. The stock Omarchy welcome screen appeared,
zero services failed, all ten package integrity checks passed again in the
guest, and the HP camera service correctly skipped the non-HP VM. Evidence:
`build/snapdragon-v0_1_1-vm/`. The disposable VM was stopped after validation.
A full physical reinstall from v0.1.1 remains untested.

The checksum sidecar next to the finished root ISO identifies the exact local
artifact. Firmware remains subject to its vendor redistribution terms; do not
infer a grant from its inclusion in a local test image.

Image: `omarchy-snapdragon-v0.1.1.iso`, 7,496,992,768 bytes.
SHA-256: `7d915cd50226598025f3800f14b0378f7dd14d976a64c2e0b7038968e10ec169`.
