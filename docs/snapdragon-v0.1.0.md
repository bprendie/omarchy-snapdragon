# Omarchy Snapdragon v0.1.0

Local testing installer: `omarchy-snapdragon-v0.1.0.iso` at the repository root.
Build with `bash scripts/build-boot-package.sh`, then
`bash scripts/build-snapdragon-installer.sh` from a prepared build workspace.
Existing output/staging directories are protected against overwrite.

This combines the physically tested ThinkPad T14s LCD and HP EliteBook Ultra
G1q work with experimental ASUS Zenbook A14 UX3407RA (X Elite) firmware.
ASUS hardware has not been tested; UX3407QA is not covered by this profile.

The installer keeps stock Quattro orchestration and Omarchy 4.0.3-1.4,
Ubuntu Snapdragon kernel 7.0.0-31-generic, ARM signing-key provisioning,
ThinkPad TrackPoint setup and the completed-install boot fixes. Boot package
0.1.0-6 includes both HP gpio_sbu_mux and ASUS panel_samsung_atna33xc20 early
in live and installed initramfs builds. The early target package list installs
HP firmware/audio and ASUS firmware before generating the installed boot image.
The offline mirror contains 961 packages.

HP graphical disk unlock and speaker audio were physically confirmed on the
previous combined image. HP Fn/media keys and keyboard backlight remain known
non-blocking limitations; use desktop brightness/volume widgets. The unexpected
reset during the earlier keyboard investigation remains unexplained. ThinkPad
charging still has the unplug/replug workaround; no speculative EC fixes are
included. The new combined image needs a physical installation retest.

The ASUS package contains five vendor firmware payloads from checksum-verified
BSP V1.312.8100.0; existing base packages supply topology and UCM support.
See `docs/asus-a14-preliminary.md` and the package provenance files. The ISO
contains vendor firmware and stays a local testing artifact; public redistribution
permission has not been established. It is ignored by Git, not uploaded.

Build validation:

- Boot helper Go tests and vet passed; platform detection regression passed.
- All four added/updated hardware packages pass `pacman -Qkk` (65 files,
  zero altered). An empty pacman database resolves the offline dependency set.
- The actual offline archive count matches the installer expectation: 961.
- Live initramfs contains the Samsung panel module, HP GPIO mux, retained
  ThinkPad display prerequisites and firmware, and all five ASUS payloads.
- ThinkPad TrackPoint setup is byte-identical to the retained installer baseline.
- ISO has an EFI boot entry and appended EFI/diagnostic partitions.
- Full ISO ARM UEFI VM boot passed: the stock Omarchy welcome screen appeared,
  zero failed services, hardware package integrity passed again in the guest,
  and the ASUS panel module loaded successfully. It is packaged early but does
  not auto-bind on QEMU, which has no ASUS panel. HP diagnostic mode correctly
  remained inactive. Screenshot and logs: `build/snapdragon-v0_1_0-vm/`.
  The VM was stopped after validation. This was a live boot smoke test, not
  a full installation or physical ASUS test.

Image size: 7,482,687,488 bytes.
SHA-256: `4f13254d37527fbaaf5cb45712544258104ddba11012f19022a953deb01ddc7c`.
The sidecar `omarchy-snapdragon-v0.1.0.iso.sha256` verifies the root artifact.
Build evidence is under `build/snapdragon-v0_1_0-*`.
