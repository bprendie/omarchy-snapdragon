# Maintainer handoff: Omarchy Snapdragon

Updated September 13, 2026. Current testing release: **v0.2.0**, based on
**Omarchy 4.0.3**. [Download the release](https://github.com/bprendie/omarchy-snapdragon/releases/tag/v0.2.0).

## Purpose and current state

This project turns Snapdragon X Elite laptops into usable Omarchy machines while retaining as much of the stock Quattro installer and desktop as possible. It combines Arch Linux ARM userspace with Ubuntu's Snapdragon hardware stack and a small set of integration patches. The intended destination is maintainable upstream support, subject to the Omarchy team's review and acceptance.

The ThinkPad T14s Gen 6 LCD is essentially working for everyday desktop use. The HP EliteBook Ultra G1q also installs and boots successfully. ASUS Zenbook A14 UX3407RA support has been integrated for community testing, but we have no physical ASUS machine. This is an unofficial MVP, with several important lifecycle features still incomplete.

| Target | Physically confirmed | Remaining qualifications |
| --- | --- | --- |
| ThinkPad T14s Gen 6, X Elite, 32 GB, BOE LCD | End-to-end installation, graphical encrypted-disk unlock, Omarchy desktop, audio, Wi-Fi, Bluetooth and brightness | Charging can require unplug/replug. A scoped TrackPoint scrolling workaround is included; remaining button/EC behavior is not settled. OLED variants are not validated. |
| HP EliteBook Ultra G1q 14, B13U7UT#ABA, board 8CBE | Installation, graphical encrypted-disk unlock, desktop, Wi-Fi, Bluetooth, touchpad, speaker audio, brightness through the desktop widget and RGB camera (local follow-up) | Native Fn/media keys and keyboard backlight do not work. HP-only Super+F3/F4 brightness and Super+F6/F7/F8 mute/volume shortcuts are physically verified in local user configuration; normal installer integration is included in local v0.1.2. One unexpected reset during keyboard investigation remains unexplained. Microphone/headset operation and comprehensive power testing remain open. |
| HP NPU, separate follow-up | FastRPC calculator, Qualcomm DSP validator and a small QNN HTP ReLU graph returned correct results | Runtime staged separately on the HP; not installed by v0.1.0. No performance, power, large-model or cross-device claim. |
| ASUS Zenbook A14 UX3407RA, X Elite | None | Firmware package and early OLED driver pass generic ARM VM checks. Automatic device-tree selection and all physical functions need testing. UX3407QA is outside this profile. |

## The v0.2.0 maintenance milestone

v0.2.0 supplies a kernel-provider lifecycle: authenticated Ubuntu candidate
acquisition, matching headers and camera module rebuilds, reproducible retained
hardware packages, signed coordinated repository assembly, queued boot
preparation, and provider-controlled selection with a retained fallback. The
kernel binary itself is still Ubuntu's 7.0.0-31-generic Stubble image.

The owner confirmed a successful physical HP installation. Direct camera
previews work on both HP and ThinkPad; Chromium access remains a separate deferred
issue, with permissions not yet confirmed as its cause. The owner also reported
that **connecting to Wi-Fi after installation let the normal Omarchy update run
and immediately pull available updated packages**. This is a practical online
package-update success, not proof that a newer Snapdragon kernel was delivered.

Read [the maintainability overview](docs/v0.2-maintainability.md) for the before/
after architecture, update sequence, evidence and remaining work. The
[v0.2.0 notes](docs/snapdragon-v0.2.0.md) identify the exact ISO, testing approval
and deferred checks. The included kernel repository is still a local signed
snapshot; production hosting and trust transition remain unfinished.

The extraction and hardware sections below explain the original v0.1 bootstrap.
Their fixed paths and package tables are historical where indicated; the
provider/set layout in the v0.2.0 overview is the current update model.

## Why this took integration work

The main challenge was the boundary between existing projects. Ubuntu could boot the Snapdragon hardware; Arch Linux ARM supplied native userspace; Omarchy supplied the desktop and Quattro installation flow. Those components did not automatically agree on kernel packaging, bootloader assumptions, firmware paths, package trust or when the display needed to become available.

Specific failures guided the changes:

- A system could reach the desktop after a blindly typed passphrase while showing a black screen during encrypted-disk unlock. The display's device-tree dependencies were not all present in the initramfs.
- The HP initially lacked the GPU/DSP firmware paths requested by its device tree. Later, its DSP booted but ALSA still exposed no usable sound card because the requested topology filename was absent.
- Fresh installations could download valid Arch Linux ARM packages but reject their signatures because the ARM signing keyring had not been provisioned.
- The installer could finish almost everything and then fail boot validation because it still expected the x86 Limine artifacts.
- ARM package availability differs from x86, and the Omarchy/Hyprland package combination needs a coordinated update policy.

Upstream Linux, Qualcomm contributors, Ubuntu, Arch Linux ARM and Omarchy supplied the substantial underlying functionality. This repository's contribution is packaging, boot integration, model-specific fixes and evidence from physical tests.

## How we lifted the Ubuntu kernel

### 1. Establish a known hardware baseline

We started with the signed **Ubuntu 26.04.1 desktop ARM64 ISO** and its published checksum/signature files. The bootstrap scripts preserve the original download and verify it before extraction. Its hardware stack supplied the initial kernel and the Qualcomm firmware trees.

That initial ISO contained kernel **7.0.0-30**. The current build moved to Ubuntu's authenticated **7.0.0-31.31** ARM64 update packages:

- `linux-image-7.0.0-31-generic_7.0.0-31.31_arm64.deb`
- `linux-modules-7.0.0-31-generic_7.0.0-31.31_arm64.deb`

The kernel's runtime release string is `7.0.0-31-generic`. This is a pinned input for this release, not a promise that it is always the latest available kernel.

The acquisition audit verified Ubuntu's signed `InRelease` metadata, checked the package index against that metadata, and checked the downloaded packages against the index. Retained hashes are in `manifests/ubuntu-kernel-7.0.0-31*.sha256`. `scripts/verify-kernel-update.sh` rechecks the pinned files and signed metadata. Matching `linux-source-7.0.0` was also retained; see `manifests/ubuntu-kernel-source-7.0.0-31.sha256`.

### 2. Extract payloads without installing Debian packages

`scripts/extract-kernel-update.sh` uses `dpkg-deb -x` in an isolated builder to extract the image and matching modules. It separately extracts control files for inspection with `dpkg-deb -e`. **No Debian maintainer scripts are run, and no Ubuntu package manager is installed on the target.**

We do not rebuild, patch or strip this kernel binary. The original bootstrap
package remains as a legacy fallback in v0.2.0; retained updates use separate
hardware-set packages. `packages/ubuntu-t14s-kernel/PKGBUILD` creates an Arch package named `oma-snap-kernel-ubuntu`, version `7.0.0.31.31-1`, containing:

```text
/usr/lib/oma-snap/7.0.0-31-generic/vmlinuz.efi
/usr/lib/oma-snap/7.0.0-31-generic/config
/usr/lib/oma-snap/7.0.0-31-generic/System.map
/usr/lib/modules/7.0.0-31-generic/...
```

The modules directory gets a `vmlinuz` symlink to that image. Ubuntu's `build` and `source` symlinks are removed because the package does not provide a kernel development tree. DKMS/header support is therefore not part of this MVP. `depmod` operates on the exact matching module release.

### 3. Preserve Stubble and the device trees

Ubuntu's kernel is a UEFI-loadable image wrapped with [Stubble](https://github.com/ubuntu/stubble). It carries machine-specific device trees, allowing the boot stub to select a suitable tree using machine identity. This bridges machines whose firmware does not provide Linux with the device-tree description it needs.

We retain the wrapped image byte-for-byte. `tools/inspect-kernel` inspects its ARM64 PE structure, embedded device trees and hardware mappings. The kernel configuration uses 4 KiB pages and includes the Qualcomm/MSM support used by these machines.

This matters: extracting only a raw Linux image or combining it with arbitrary modules would discard part of the working boot path. The installer checks that the kernel copied onto the EFI System Partition matches the packaged Stubble image.

The original kernel signature is preserved with the binary. **Secure Boot is
disabled and out of scope.** Ubuntu metadata and pacman package signature checks
verify software provenance; they do not enable Secure Boot.

### 4. Package firmware in the kernel's namespace

The base `oma-snap-firmware-ubuntu` package is `20260319.217ca6e4-2`. It copies Ubuntu's `qcom`, `qca` and `ath12k` trees under:

```text
/usr/lib/firmware/7.0.0-31-generic/
```

Linux searches a release-specific firmware directory before the generic firmware directory. This lets the selected hardware stack coexist with Arch firmware packages without overwriting their files. The package carries the Qualcomm copyright/license texts extracted from Ubuntu.

HP and ASUS packages add five model-specific GPU/ADSP/CDSP payloads each, also under that namespace. Their inputs are HP SoftPaq **sp162865 / driver pack 7700.1** and ASUS UX3407RA Qualcomm BSP **V1.312.8100.0**. The extraction scripts treat Windows packages as archives; they do not execute Windows installers, BIOS updates or EC updates. Exact sources and hashes are beside the recipes.

The broad base firmware set is intentional for bring-up. A production profile could reduce it once each model's actual requirements are established. Proprietary firmware ownership and redistribution terms remain separate from the repository's code; the published image does not itself settle those obligations.

### 5. Generate Arch initramfs images and install a bounded boot payload

We use **mkinitcpio**, not Ubuntu's initramfs-tools. The live image uses archiso hooks to discover the ISO, mount SquashFS and create a writable overlay. The installed image uses the packaged configuration in `profiles/t14s-lcd/mkinitcpio-installed.conf`, including Plymouth, keyboard and encryption hooks.

The shared `oma_snap_qcom` build hook explicitly includes device-tree prerequisites that ordinary module dependency discovery misses: Qualcomm clocks, pin control, regulators, interconnects, remote processors and display dependencies. It includes the versioned firmware directory in full.

The display fixes are small but significant:

- ThinkPad LCD: panel/backlight, GPU fuse, remote-processor and bridge prerequisites must be available before root unlock.
- HP: `gpio_sbu_mux` must be available early so the PMIC GLINK/display dependency graph can complete.
- ASUS UX3407RA: include `panel_samsung_atna33xc20` for the OLED panel before root unlock. Presence in a QEMU initramfs is not physical panel validation.

Quattro mounts and provisions the target, then invokes the Go helper in `tools/boot-install`. The helper validates the target and FAT ESP, creates a separate `oma-snap` namespace, copies the kernel, generates the target initramfs and installs ARM64 GRUB with `--no-nvram`. It adds `EFI/BOOT/BOOTAA64.EFI` only when fallback installation is explicitly requested, and refuses to overwrite an existing fallback directory.

The current boot command includes `clk_ignore_unused pd_ignore_unused arm64.nopauth`; GRUB also retains the Snapdragon memory-range workaround from the bring-up path. These should be reviewed against newer upstream support, rather than silently propagated forever. The original bootstrap has fixed legacy paths. v0.2.0 adds separate retained-set
preparation and selection commands plus approved-provider integration in the
fresh installer; complete power-loss recovery remains a follow-up.

## How the Omarchy ARM packages actually work

### Native userspace, architecture-specific dependencies

The target runs native AArch64 executables. QEMU is used on the development host to run the ARM build environment; it is not how the installed desktop runs.

The base distribution is Arch Linux ARM: `core`, `extra` and `alarm` repositories use its ARM mirror. Omarchy's repository supplies additional ARM desktop packages through `https://pkgs.omarchy.org/edge/$arch`, where pacman resolves the architecture to `aarch64`.

An ARM package is not automatically created when its x86 equivalent is released. The relevant repository must actually build and publish an AArch64 package with compatible dependencies. Package names can be shared across architectures while their executable payloads differ.

### Omarchy runtime and settings

We reuse Omarchy's package recipes from `omacom/omarchy-pkgs`. Both `omarchy` and `omarchy-settings` are built from the pinned **4.0.3** source commit `0534987009061cbe2dacdde4ad564092ab698d12`, with the local ARM profile patch applied through `OMARCHY_SRC`. The original `scripts/build-quattro-profile.sh` produced **4.0.3-1.4** packages;
v0.2.0 uses `scripts/build-quattro-update-profile.sh` and the coordinated
**4.0.3-1.9** runtime/settings pair with kernel lifecycle patches.

`omarchy` supplies runtime commands and installation/user-setup code. `omarchy-settings` supplies packaged defaults and assets used by the desktop and live installer. The recipes separate the pair so settings can be installed before the complete desktop. The runtime has a versioned dependency on its settings counterpart.

Much of Omarchy's payload is shell/Lua/configuration, but its package metadata and dependencies are architecture-specific. The upstream recipe already has AArch64 dependency handling associated with the Apple Silicon port, avoiding the x86 Limine dependency set. Our Snapdragon boot and hardware integration is layered onto that foundation.

The Asahi connection is through Omarchy Mac and ARM reference work. **This image does not use an Asahi kernel, m1n1, Apple graphics drivers or an Asahi root filesystem.** Boot hardware support comes from the Ubuntu/Qualcomm stack.

### Package selection and the offline installer

`scripts/quattro-package-list.sh` derives the selection from the stock release list plus explicit profile exclusions, replacements and additions. It does not silently treat unavailable software as installed. Current exclusions include Obsidian, dotnet-runtime, Pinta, OBS Studio, `qemu-user-static-binfmt`, and the Apple Studio Display helper. `nvim` maps to `neovim`. See `profiles/t14s-lcd/packages.*` for the exact policy and reasons.

The mirror preparation explicitly selects Omarchy's `hyprland`, `hyprtoolkit` and `hyprland-guiutils` packages where required, preserving the chosen desktop ABI combination. The v0.1.0 offline mirror contains **961 package archives**, including eight locally built integration packages:

```text
omarchy                         4.0.3-1.4
omarchy-settings                4.0.3-1.4
oma-snap-kernel-ubuntu           7.0.0.31.31-1
oma-snap-firmware-ubuntu         20260319.217ca6e4-2
oma-snap-boot                    0.1.0-6
oma-snap-firmware-hp             7700.1-1
oma-snap-audio-hp                0.1.0-1
oma-snap-firmware-asus-a14        1.312.8100.0-1
```

The upstream archives retain their signatures. They are indexed separately from the local integration packages. The legacy `oma-snap-local` offline repository uses unsigned packages checked against retained hash manifests; upstream signature checks remain required. This scoped exception is not equivalent to disabling pacman signature verification globally. v0.2.0 adds a separate signed `oma-snap` repository for its coordinated update
packages, while preserving that legacy offline set. Public hosting and production
trust deployment remain release-engineering work.

The early installer package list includes the boot helper, ARM keyring and model firmware/audio packages before installed boot generation. For simplicity, the combined ISO currently installs HP and ASUS payload packages on ARM targets together. Their firmware filenames/UCM matches are model-scoped, but the package-selection stage is not yet an elegant per-machine dispatcher.

### Trust repair and updates

The fresh-install signature failure was fixed by installing and populating `archlinuxarm-keyring`, alongside the existing keyrings. A previously failing Alacritty install then succeeded with its Arch Linux ARM signature verified. That fix is integrated into the installer and keyring-update path.

The owner physically confirmed that the normal Omarchy update flow fetched
available online packages after a v0.2.0 installation connected to Wi-Fi. ARM
packages still depend on their repositories publishing compatible AArch64 builds.

The v0.2.0 refresh templates use:

```ini
IgnorePkg = hyprland hyprtoolkit hyprland-guiutils
```

The original `omarchy` and `omarchy-settings` holds are removed. Their patched
pair is supplied through the signed Snapdragon repository, while the upstream
Omarchy repository retains `Usage = Sync Search Install`. This protects the
Snapdragon-specific update integration from an unrestricted upstream replacement.
The helper waits for kernel preparation and checks the provider before activation;
the orphan cleanup path protects retained kernel sets.

The custom repository shipped in this ISO is an offline signed snapshot, not
a hosted kernel release channel. Ubuntu APT updates do not run on the target.
Future Ubuntu kernels must pass the candidate/approval workflow and be delivered
as pacman packages through a maintained endpoint. The successful physical package
update did not establish that a new custom kernel was fetched or activated.

## Changes a maintainer would review

| Area | Main implementation | Suggested ownership |
| --- | --- | --- |
| ARM package/profile behavior, keyring, unsupported lifecycle commands | `patches/0002-quattro-arm-profile.patch` | Omarchy/ARM maintainers |
| Kernel selection, ARM Node bundle, GRUB finalization and boot validation | `patches/0003-quattro-arm-installer.patch` | Quattro installer maintainers |
| Kernel/module repackaging and source provenance | `packages/ubuntu-t14s-kernel/`, `scripts/*kernel*` | Hardware package/release maintainers |
| Early display dependencies | `profiles/t14s-lcd/initcpio/oma_snap_qcom` | Hardware profile and initramfs integration |
| HP/ASUS payload extraction | `packages/`, `scripts/prepare-*-firmware.sh` | Firmware packaging; coordinate licensing upstream |
| HP topology and UCM mapping | `packages/hp-audio/` | AudioReach/ALSA and distro packaging |
| Boot finalization | `tools/boot-install/` | Installer/boot maintenance |
| NPU validation | `docs/hp-npu-validation.md` | Optional runtime packaging follow-up |

The `t14s-lcd` directory names reflect the first target; some contents are now shared Snapdragon infrastructure. Splitting common code from model data would make review and future additions clearer.

## How to test

### Get the exact image

For the current testing release, use `omarchy-snapdragon-v0.2.0.iso` in the repo
root or `~/ISOs`, with the adjacent checksum. Exact size, hash and qualification
are in [the v0.2.0 notes](docs/snapdragon-v0.2.0.md). The GitHub release supplies four ISO parts and checksums; the README explains
how to reconstruct the image.

The owner has paused further VM testing. The procedures below are for an explicit
future validation run, not instructions to restart the existing paused job.

### VM smoke test

With the documented builder image available:

```bash
OMA_SNAP_TEST_ISO=omarchy-snapdragon-v0.2.0.iso \
OMA_SNAP_VM_DIR=build/maintainer-live-test \
OMA_SNAP_SSH_PORT=2334 \
bash scripts/smoke-installer-live.sh
```

This uses generic QEMU `virt`, ARM UEFI, 8 GB RAM and no installation target disk. Expect the Omarchy welcome screen and a recovery shell on the serial console. Inspect `systemctl --failed` and `pacman -Qkk` for the hardware packages. Stop the test container afterward with `docker stop oma-snap-live-test`.

The test uses serial/QMP sockets in its build directory rather than a visible host window. `scripts/test-installer-vm.sh` is the separate full-install harness with a disposable 40 GB file-backed disk and fixture credentials. It still expects an ISO directly under `dist/` and has older defaults; adapt those explicitly before use. Do not substitute an ASUS device tree for QEMU's `virt` machine.

### Physical installation regression

Use a backed-up or expendable target installation and identify the USB by model, serial and capacity before writing it. The repository's USB writer is bound to a locally recorded device identity; it is not a generic unattended flashing command for a maintainer's machine.

On a supported model, test this sequence:

1. Boot USB to the Omarchy welcome screen and confirm keyboard/display operation.
2. Confirm networking, complete the normal owner installation, and retain the installation log.
3. Reboot from the installed disk. Verify the passphrase prompt is visible and leads to the desktop.
4. Check Wi-Fi, Bluetooth, touchpad/TrackPoint, speakers, brightness widget and physical keys separately.
5. Test cold boot, warm reboot, suspend/resume and charging across each USB-C port. Record gaps rather than extrapolating from desktop success.
6. Verify a signed ordinary ARM package install. Treat whole-system/desktop/kernel upgrades as a separate, currently unfinished test plan.

Useful non-mutating checks on the installed target:

```bash
uname -r
pacman -Q omarchy omarchy-settings oma-snap-kernel-ubuntu oma-snap-boot
systemctl --failed
cat /proc/cmdline
cat /proc/asound/cards
wpctl status
journalctl -b -k --no-pager
```

Record exact model/SKU, panel type, BIOS version and ISO checksum with the report. Redact machine identifiers and account/network details before publishing logs. The optional HP diagnostic boot entry writes logs to the USB's `OMADIAG` partition and powers off; `COMPLETE.txt` identifies a finished capture.

For NPU evidence and runtime inputs, see [HP NPU validation](docs/hp-npu-validation.md). The successful test executed a four-element quantized ReLU through `HTP_QTI_AISW`, with no CPU fallback backend loaded. It did not change firmware or enable a permanent daemon. This setup is not yet a supported installable NPU package.

## Build reproducibility and release gaps

The v0.2.0 assembly path is `scripts/stage-v020-installer.sh`, followed by
`scripts/assemble-v020-installer.sh` with the prepared signed candidate repository
and pinned signing-key fingerprint. Provider generation and repository assembly
are documented in [the promotion guide](docs/kernel-promotion.md). The process
still requires the pinned v0.1.2 base ISO, matching packages and a populated
builder; **a clean Git clone alone is not sufficient**.

Cleanup removed the obsolete extracted roots and duplicate images that older
commands referenced. Retained input archives, recipes, manifests, current
packages and test logs remain available. Historical scratch paths may need to
be regenerated. Approximately 275 GiB was removed.

The retained hardware package was reproduced byte for byte. That does not prove
that the entire ISO, initialized trust store and generated initramfs reproduce
from a clean checkout. See [candidate results](docs/snapdragon-v0.2.0.md) and
[earlier reproducibility evidence](docs/reproducibility.md) for their exact scope.

Before treating this as an officially maintained distribution, the main gaps are:

- A clean, documented build pipeline with immutable input retention and CI.
- Production hosting and trust transition for the signed package repository;
  broader ARM desktop update parity beyond the retained compatibility holds.
- Complete encrypted retained-candidate and approved-provider activation tests.
  Kernel hooks, retained sets and different-ABI VM rollback now exist; automatic
  pruning, legacy retirement and complete interruption recovery remain open.
- Correct corresponding-source delivery and per-payload firmware licensing review for distribution.
- Snapshot boot selection/restore and factory reset: explicitly blocked in this profile. Snapshot creation alone must not be advertised as full recovery parity.
- Hibernation/resume: deferred. Encrypted deferred owner provisioning is rejected before disk work.
- Physical ASUS testing and broader panel/model coverage.
- HP Fn/media keys/backlight, upstreaming the [working camera integration](docs/hp-camera-status.md), ThinkPad charging/remaining pointing-device behavior, and systematic power/thermal/suspend testing.
- Optional application gaps and NPU runtime packaging.

A useful first upstream slice would be architecture-aware Quattro boot finalization and ARM keyring provisioning, followed by separately reviewable hardware packages. The working ISO is a reference and test vehicle; the goal is to make these changes small enough, well-owned enough and reproducible enough that maintaining Snapdragon support does not depend on this original workspace.

## Historical v0.1.1 follow-up

The HP RGB camera now passes physical capture after reboot with a user-confirmed
usable preview. Its missing sensor driver and board description are packaged
in `packages/hp-camera/`; see [camera bring-up](docs/hp-camera-status.md).
The [v0.1.1 candidate](docs/snapdragon-v0.1.1.md) includes that support, both
machines' camera userspace and the matched Lenovo cDSP firmware used in the
ThinkPad NPU test. It retains the existing HP, ThinkPad and ASUS additions.
Those hardware additions were carried forward into v0.1.2 and v0.2.0.

HP EC access was identified from recovered firmware tables and a single
hotkey-enable register read succeeded. Its enable bit was already set.
No EC setting was changed; Fn/media keys and keyboard lighting remain gaps.
