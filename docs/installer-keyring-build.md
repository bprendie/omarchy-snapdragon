# Installer rebuild with ARM package trust — 2026-09-12

Candidate: `dist/oma-snap-installer-kernel31-keyring-arm64.iso`.
Built, 6,865,045,504 bytes. SHA-256:
`8bfb6262da7705f7add99409ec448012a7329775978791be287401df8da39de3`.
VM live-boot smoke test **PASS**: reached the stock Omarchy welcome screen
(“Press Return to Start Install”). No physical test of this ISO is claimed.

Changes relative to the physically validated kernel31-unlock ISO:

- Include `archlinuxarm-keyring` in both the desktop package list and ARM early
  bootstrap so installed systems initialize ARM package-signing trust.
- Omarchy keyring updates refresh/populate ARM keys on aarch64 and stop on
  errors before reporting success.
- Repackage the paired Omarchy runtime/settings as 4.0.3-1.3.

Kernel 7.0.0-31-generic, matching firmware, boot package 0.1.0-4, graphical
encrypted-root unlock, and the pinned desktop stack remain the existing set.
The physical keyring repair and Alacritty installation passed separately; see
[package trust repair](package-trust-repair.md).

Previous root export, extracted root, assembly and profile packages are retained
under `build/pre-keyring-iso/`. The working kernel31-unlock ISO remains in dist.
Archived manifests retain historical paths; they are provenance, not checks for
the relocated files. Current manifests will describe the new staging.

This is still a development ISO with the explicitly authorized diagnostic SSH
public key. TrackPoint work is being handled by the user's separate Codex session
on the ThinkPad. This rebuild does not contact or change that machine, incorporate
unreported TrackPoint changes, write a USB, or resume charging investigation.

Validation before live boot:

- All installer shell checks and 72 Python tests passed.
- Kernel/bootstrap signatures and hashes, display modules/firmware, and platform
  checks passed.
- Clean ARM container installation of the keyring package automatically populated
  trust; the ALARM detached package signature then verified as fully trusted.
  This test did not use the separate physical repair script's bootstrap step.
- Offline package signature checks, hashes and dependency closure passed.
- Compared old/new package manifests: only the added ARM keyring and the paired
  Omarchy rebuilds differ; all other package hashes match.
- Runtime payload changes are limited to keyring updater and package list.
  Settings payload changes are build metadata and PNG metadata; decoded icon
  pixel hashes match the previous package.
- Assembled root contains the keyring archive at the verified hash, the ARM early
  bootstrap entry, the updated package list, and the new updater.

Logs: `build/keyring-*.log`, `build/keyring-install-hook-test.log`.
VM: `build/installer-live-keyring/`, container `oma-snap-live-test`, SSH port 2328.
This smoke VM has no installation target disk or unattended-install fixture.
Its serial console confirms the ARM keyring in both installer package lists
and zero failed systemd units. Live versions are runtime/settings 4.0.3-1.3,
ARM keyring 20240419-2, and boot helper 0.1.0-4. The smoke VM was stopped after
verification; the two older paused installation VMs were left untouched.
Welcome screenshot:
`build/installer-live-keyring/live.png`. Full installation and first installed
boot were not repeated for this ISO; the preceding unlock ISO passed those
tests on the physical ThinkPad.
