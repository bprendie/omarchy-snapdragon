# Next kernel input audit

Checked 2026-09-11, following the user's request for the latest available kernel.
The selected update track is Ubuntu 26.04's published generic ARM64 kernel,
consistent with the existing Ubuntu/Stubble bridge. This is not a claim to use
the newest upstream release candidate or an unpublished development build.

The current [resolute-updates ARM64 index](https://ports.ubuntu.com/ubuntu-ports/dists/resolute-updates/main/binary-arm64/)
and the separately verified resolute-security index both select
`linux-image-generic` 7.0.0-31.31, depending on
`linux-image-7.0.0-31-generic` and matching modules. The handed-off ISO still
uses 7.0.0-30.30; the working physical Ubuntu uses 6.14.0-15.15.

## Verification and retained artifacts

- `downloads/ubuntu-kernel-current/InRelease`: gpgv verified with the builder's
  Ubuntu archive keyring, signing fingerprint
  `F6ECB3762474EDA9D21B7022871920D1991BC93C`.
- `Packages.xz`: SHA-256 matched its entry in the verified InRelease.
- Downloaded signed-image and modules `.deb` files: both matched the SHA-256
  entries in that package index. Manifests:
  `manifests/ubuntu-kernel-7.0.0-31-index.sha256` and
  `manifests/ubuntu-kernel-7.0.0-31.sha256`.
- Extracted files and maintainer scripts are in
  `build/ubuntu-kernel-7.0.0-31/`; `scripts/extract-kernel-update.sh` reproduces
  that extraction into a fresh directory. No Debian maintainer script was executed.
  Post-install scripts call depmod, Debian kernel hooks and symlink management;
  the Arch bridge must continue to own its own initramfs and boot updates.
- `build/kernel-7.0.0-31-inspection.json` confirms an ARM64 PE image with an
  embedded T14s LCD tree. Image SHA-256:
  `8e67dc8d70becb2305d66b132cbcb8f058691ef82513ba949a66a0f33002d3fa`.
- Embedded LCD DTB hash is unchanged from the 7.0.0-30 build:
  `a60194373192f2046a2e0a1e3f03999502a356ad030a4051f9df28c074393377`.
- Matching `linux-source-7.0.0` 7.0.0-31.31 was also cached and verified against
  the authenticated package index; see
  `manifests/ubuntu-kernel-source-7.0.0-31.sha256`. The complete signed-kernel
  rebuild/signing workflow has not been reproduced.

Archive authenticity does not prove that the target will accept the EFI trust
chain. The inspection tool does not verify PE signatures or actual UEFI selection.

## Remaining integration

The new kernel/modules, firmware release 2 and boot-helper release 2 have built
and installed in the build container. Its kernel image hash matches the
authenticated input. The helper pins the matching kernel/firmware package
versions, and assembly now selects the updated image instead of the old casper
kernel. The first kernel31 ISO passed UEFI virtual-USB live boot, overlay root,
matching kernel/firmware/boot packages, zero failed services, key-only SSH and
clean poweroff. Evidence is in `build/installer-live-kernel31/`. The separate
LCD-module fix also passed a 7.0.0-30 console VM boot. Neither proves physical
LCD support. A package-list staging omission found in the full installer test
requires another ISO build before full installation testing.

## Expected ThinkPad device-tree selection

The read-only upstream Stubble HWID collector ran over verified target SSH.
Its family plus BOE0b66 EDID ID matches the actual image's LCD entry at priority
16; the SKU-only ID also matches the LCD-compatible generic T14s entry at
priority 7. There is no priority-17 match. The manufacturer-only ID is excluded
from Stubble's selection priorities and cannot override these matches.
The 7.0.0-30 and 7.0.0-31 HWID tables are identical. See `sources/stubble/chid.c`
and the two `build/kernel-7.0.0-*-inspection.json` reports. Raw computed IDs and
matches remain in `private/thinkpad-live/`. This predicts LCD selection if UEFI
provides the same DMI/EDID values Linux reported; it does not observe selection
during a physical boot.
