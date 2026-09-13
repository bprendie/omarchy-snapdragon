# Snapdragon v0.1.2 — experimental release

Omarchy 4.0.3, Ubuntu-derived kernel 7.0.0-31-generic.
[GitHub prerelease](https://github.com/bprendie/omarchy-snapdragon/releases/tag/v0.1.2).

## Changes

- Retains all v0.1.1 camera, ThinkPad NPU firmware, boot/unlock, audio and
  preliminary ASUS firmware work. All 970 preceding package archives are
  byte-identical; one package is added, for 971 total.
- Adds `oma-snap-hotkeys-hp 0.1.0-1`: Super+F3/F4 brightness, Super+F6 mute,
  Super+F7/F8 volume. These shortcuts were physically confirmed on the HP.
  Normal installation applies them after stock user provisioning, as the
  installation user. Both helper and Lua fragment restrict activation to
  HP board 8CBE. Plain function keys remain available to applications.
- Runs the ASUS camera/early-display prerequisite check during image assembly.
  No speculative ASUS kernel patch is introduced: the shipped RGB camera graph,
  drivers, OLED module and display firmware prerequisites are already present.
- Corrects the live boot-menu version label to v0.1.2.

Native HP Fn behavior and keyboard backlights remain unresolved. Deferred-owner
and factory-reset provisioning do not automatically apply the HP shortcut
helper. ASUS physical camera/display operation remains untested.

## Build

Use the existing v0.1.1 inputs plus `bash scripts/build-hp-hotkeys-package.sh`.
Then run `bash scripts/build-snapdragon-installer.sh` and
`bash scripts/verify-snapdragon-offline.sh`. The builder refuses to overwrite
existing v0.1.2 stages or images. The resulting root ISO is
`omarchy-snapdragon-v0.1.2.iso`; its SHA-256 sidecar identifies the exact artifact.

`bash scripts/smoke-snapdragon-iso.sh 0.1.2` boots the full ISO read-only in a
generic ARM UEFI VM, without a physical disk or network. It retains serial/QMP
endpoints in `build/snapdragon-v0_1_2-vm/`; stop the VM via QMP after inspection.
This smoke test checks installer startup, not an end-to-end physical install.

## Validation

- Offline dependency closure: PASS, 971 package archives available.
- Previous 970 archives preserved byte-for-byte: PASS.
- HP helper: installation and repeat invocation PASS; one require line and one
  backup. Non-HP board checks created no user files. Finalizer ordering and
  execution as the configured user verified against the patched Python function.
- Installer patch applies without fuzz; Python compilation and shell syntax pass.
- ISO assembly and UEFI/diagnostic partition layout: PASS.
- ASUS camera and early-display prerequisites in the resulting image: PASS.
- Live-root and guest integrity: 11 boot/firmware/camera/hotkey packages, zero altered files.
- Complete ISO ARM UEFI smoke boot: PASS, stock Omarchy welcome screen, zero
  failed services. HP camera service and shortcut helper correctly skip the
  non-HP guest. Evidence: `build/snapdragon-v0_1_2-vm/validation.txt` and
  `welcome.png`. The disposable VM was stopped after validation.
- Repo-root ISO and `~/ISOs` copy both pass the SHA-256 sidecar check.

A full physical v0.1.2 reinstall remains untested. The VM retains the preceding
image's nonfatal GRUB font-path lookup message before the boot menu; it does
not prevent the welcome screen.

No USB was written during this build. The owner subsequently authorized publishing
the source and ISO after updating the README with the September 13 changes.


Image: `omarchy-snapdragon-v0.1.2.iso`, 7,497,000,960 bytes.
SHA-256: `c622aff8c5e413e71d26009ad09192b4dc31e50a050198c5e2d7235bd39ddb5d`.
A copy and checksum sidecar are also saved in `~/ISOs/`.
