# References and provenance

Retrieved 2026-09-11 unless stated otherwise. Git revisions are recorded in `manifests/source-revisions.txt`; binary bootstrap checksums in `manifests/bootstrap.sha256`. Downloaded materials stay under `downloads/`; source checkouts under `sources/`. Source claims are distinguished from project tests.

| Source | Evidence used | Limitations |
| --- | --- | --- |
| [Ubuntu ARM summer 2026](https://discourse.ubuntu.com/t/ubuntu-on-arm-summer-26-update/84872) | Ubuntu describes generic ARM64 ISO Snapdragon support and Stubble | Does not validate our hybrid or exact machine |
| [Ubuntu download verification](https://ubuntu.com/tutorials/how-to-verify-ubuntu) | CD-image signing fingerprint `843938DF228D22F7B3742BC0D94AA3F0EFE21092` | Fingerprint verified against published primary documentation |
| [Ubuntu 26.04 image directory](https://cdimage.ubuntu.com/releases/26.04/release/) | 26.04.1 desktop ARM64 ISO, signed SHA256SUMS, image manifests | Candidate hardware stack; user's exact installed kernel still unknown |
| [Stubble source](https://github.com/ubuntu/stubble) | Read README, LCD/OLED T14s hardware mappings; pinned checkout | Latest source may differ from the stub embedded in the selected Ubuntu image |
| [Omarchy ARM port](https://github.com/alexisraitano-myffu/omarchy-arm/tree/arm64) | Read instructions, installer, package manifests, settings, hardware detection, user setup and update entry point | Advertised platform support is not T14s validation; required packages can be missing or inconsistent |
| [Omarchy ARM design](https://github.com/alexisraitano-myffu/omarchy-arm/blob/arm64/docs/arm64-port.md) | Explains ARM repository preservation and Lua/Quickshell desktop architecture | Its package counts and claims need independent current checks |
| [Arch Linux ARM downloads](https://archlinuxarm.org/about/downloads) | Generic aarch64 root archive + signature | Rolling `latest` filename; exact downloaded SHA pinned, upstream retention not guaranteed |
| [Arch Linux ARM signing](https://archlinuxarm.org/about/package-signing) | Official signing model | Bootstrap trust here anchors to official keyring checkout over HTTPS |
| [Arch Linux ARM keyring source](https://github.com/archlinuxarm/archlinuxarm-keyring) | Builder fingerprint `68B3537F39A313B3E574D06777193F152BDBE6A6` verifies downloaded rootfs | GPG reports one old rejected SHA-1 certification; rootfs SHA-512 signature itself verifies |
| [Arch Linux ARM mirror list](https://archlinuxarm.org/about/mirrors) | Official HTTP redirector for core/extra/alarm metadata and packages | HTTPS alias certificates failed validation; HTTP transport is used with mandatory package signatures. Repository metadata itself is not authenticated unless its detached signature is available |
| [Arch ISO source](https://github.com/archlinux/archiso) | Reference live ISO layout and boot command-line conventions | Its default profile targets x86; do not execute that installer for T14s |
| [Snapdragon Ubuntu FAQ](https://discourse.ubuntu.com/t/faq-ubuntu-25-04-25-10-on-snapdragon-x-elite/61016) | Starting hardware enablement lead | Detailed current feature audit pending |
| [T14s developer wiki](https://github.com/jhovold/linux/wiki/T14s) | Historical hardware pitfalls | Not treated as a current feature matrix |

## Verified local artifacts

Ubuntu checksum signature: valid Canonical CD-image fingerprint above; ISO hash matched. Extracted `/casper/vmlinuz` is ARM64 PE with embedded `.dtbauto` sections. Its manifest lists `linux-image-7.0.0-30-generic` and matching modules version `7.0.0-30.30`. Kernel configuration enables 4 KiB pages and DRM_MSM. None of this establishes the actual target's boot result.

Arch root archive signature: valid builder fingerprint above, dated 2026-08-05. Executing its aarch64 pacman under local QEMU user emulation succeeds. Package transaction for Hyprland fails on a missing Aquamarine soname dependency; see the retained build log and package audit. Repository metadata resolutions are candidates until full signed dependency transactions succeed.

## Maintenance and licensing

Retain original signed downloads and all source/package versions for rebuilds. Binary kernel repackaging must preserve provenance and provide the corresponding Ubuntu source reference before external distribution. Firmware package carries Ubuntu's Qualcomm copyright/license texts. No public ISO publication has occurred. We must finish checking the exact selected firmware's redistribution terms, embedded stub source version and source availability before publishing a distributable release.

[Aquamarine 0.14.0 source](https://github.com/hyprwm/aquamarine/tree/a79fb21b2e2a82dd061a6d071802bcf38bd5c383): CMake explicitly sets `SOVERSION 13`, matching the current Arch ARM Hyprland package's declared dependency. Cross-built ABI 13 package, full dependency transaction and container linkage/version checks now pass. Graphical validation remains outstanding.

## Stock Quattro, inspected 2026-09-11

- [ISO installer](https://github.com/omacom/omarchy-iso/tree/a23f8d464dcb0616a61bfaa8026e23d0533da209): configurator, Python orchestrator, archinstall adapter, bundled mirror and stock tests. Fast tests pass locally; x86 boot assumptions require adaptation.
- [Package recipes](https://github.com/omacom/omarchy-pkgs/tree/c31ef469c5f0dde2654770f5ce578e8b2e559193): runtime/settings already declare aarch64 and split boot dependencies/drop-ins. The release pair pins Omarchy commit `0534987009061cbe2dacdde4ad564092ab698d12` (v4.0.3).
- [Official Mac reference](https://github.com/omacom/omarchy-mac/tree/09f16de292febfc76225dee11ffa64497fc6f30d): ARM package-source selection is useful reference; Apple boot and hardware settings are not applicable to Qualcomm.

The user explicitly selected maximum stock Quattro installer reuse. See `docs/quattro-installer.md` for the resulting component map and outstanding validation.

[Official ARM package mirror](https://pkgs.omarchy.org/edge/aarch64/): metadata snapshot hash recorded in `manifests/omarchy-repository.sha256`; package signatures verified by pacman using the pinned upstream Omarchy keyring (fingerprint `40DFB630FF42BCFFB047046CF0134EE680CAC571`). Hyprland 0.56.2 from this mirror links to ABI 14, superseding the earlier custom ABI 13 workaround for the desktop image.

[Node 26.8.2 release](https://nodejs.org/dist/v26.8.2/): ARM64 tarball checksum pinned in `manifests/node.sha256` from the official HTTPS checksum listing. The binary executes in the ARM build environment. This checksum verification is not a separately verified release-signing-key signature. The user approved retaining stock cloud/AI tools; this ARM bundle supports stock offline Node provisioning.
