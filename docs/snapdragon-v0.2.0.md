# v0.2.0 — testing release

Built at the project owner's explicit request to stop repeated VM testing and
produce the installable image. Subsequently authorized for publication as a
[GitHub testing release](https://github.com/bprendie/omarchy-snapdragon/releases/tag/v0.2.0),
with the ISO split into four release assets and accompanied by checksums.
Secure Boot is disabled and outside scope.

- File: `omarchy-snapdragon-v0.2.0.iso` at the repository root.
- Copy: `~/ISOs/omarchy-snapdragon-v0.2.0.iso`.
- Size: 8,020,740,096 bytes.
- SHA-256: `1f817fe8a112fc180f5a7b24fcdf784a3854cb54e04b4e731d88b408d21732e4`.

The installer now carries a testing-channel provider for the Ubuntu-derived
7.0.0-31 kernel and its retained modules/firmware, tools 0.2.0-10, Omarchy and
settings 4.0.3-1.9, and fresh-install boot helper 0.1.0-7. The provider is
sequence 1 (`1:1-1`), explicitly approved for local testing. Unlike the earlier
smoke-only image, it passes the installer provider-approval requirement and is
configured to prepare and select the retained kernel with the original boot as
fallback. The owner subsequently confirmed successful installation and operation
on the physical HP. See the physical follow-up below.

The image preserves the v0.1.2 ThinkPad/HP fixes and hardware-untested ASUS
UX3407RA profile. No ASUS A16/X2 enablement is claimed; that work is deferred.

## Physical follow-up and maintainability

The owner confirmed that the physical HP installed and ran successfully. Direct
camera previews also work on both HP and ThinkPad; the earlier Chromium camera
failures are deferred browser-access troubleshooting, not a hardware regression.
Permissions have not been established as the cause.

After installation and connecting to Wi-Fi, the owner reported that Omarchy's
normal update ran and immediately pulled the available updated packages. This
validates an ordinary online package-update experience on the installed system.
No transaction inventory was collected, so it is not evidence that a new Ubuntu
kernel was installed or that every held desktop package was upgraded.

See [the v0.2.0 maintainability changes](v0.2-maintainability.md) for the difference
between that working package path and the remaining custom-kernel delivery work.

## Validation and deferred work

Completed evidence includes authenticated Ubuntu inputs, byte-identical repeat
hardware-package builds, matching HP camera module builds, and installed
kernel 30 → 31 → 30 boots with matching retained payloads. The earlier v0.2.0
smoke image reached the interactive installer. The baseline encrypted VM booted
kernel 31 with active LUKS2 root, SSH and zero failed services, using the serial
unlock prompt; its graphical prompt did not appear.

At the owner's direction, retained-candidate encrypted boot and approved-provider
runtime activation remain pending. The signed provider explicitly records the
encrypted-boot deferral; no successful test evidence was invented. The encrypted
VM was paused during its package-upgrade test and remains paused. The final ISO
was assembled and its copy compared byte for byte; no additional VM test was run.

The included signed repository is a **local testing snapshot**, available at
`file:///var/cache/oma-snap/repository`, with a local test key. It is not a live
Ubuntu or public pacman update endpoint. Production repository hosting, trust
transition and the remaining update-path checks are still work to complete.

## Build records and cleanup

Build logs and signed packages remain under `build/kernel-repo-v020-testing/`,
`build/kernel-provider-v020-testing/`, `build/kernel-v020-reviewed-evidence/`,
and `build/assemble-v020-testing.log`. The approved record includes the actual
pending-test explanation. `docs/kernel-promotion.md` describes the testing-only
deferral; stable promotion still requires all evidence.

Obsolete extracted roots, prior ISO trees, old release-asset chunks, diagnostic
USB images and the completed unencrypted VM disk were removed after assembly.
The source, required inputs/firmware, signed candidate packages, test logs, paused
encrypted VM, and v0.1.2 fallback ISO are retained. The exact removal list and log
are `build/cleanup-v020-manifest.json` and `build/cleanup-v020.log`. Deleted
intermediate paths in historical notes are evidence locations, not promises that
those scratch trees are still present; regenerate them from retained inputs.

Cleanup reduced the working folder from 355 GiB to 80 GiB as reported by
`du -xsh` (approximately 275 GiB removed). A second pass removed 51 superseded
package/VM build directories; small evidence files were copied to
`build/cleanup-evidence/`. Its list and results are
`build/cleanup-v020-packages-manifest.json` and
`build/cleanup-v020-packages.log`. Remaining space includes current package
inputs, the paused encrypted VM, hardware audit artifacts and two root ISOs.
