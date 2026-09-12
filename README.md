# Omarchy Snapdragon

**This is a real Omarchy 4.0.3 distribution for Snapdragon X Elite laptops, built from Omarchy's desktop and Quattro installer. It is a work in progress and an unofficial community port.**

**The ThinkPad T14s Gen 6 with Snapdragon X Elite and an LCD panel is essentially fully working for everyday use.** Installation, encrypted-disk unlock, the Omarchy desktop, audio, Wi-Fi, Bluetooth and display brightness have all been physically tested. The remaining charging and TrackPoint caveats are listed below.

Snapdragon X Elite “Copilot+ PCs” are capable laptops that can feel abandoned if you want to run Linux instead of the Windows installation they shipped with. Our experience has been a patchwork of working desktops, missing firmware, invisible disk-unlock prompts, silent speakers and model-specific quirks. This project is an attempt to make that hardware useful as a Linux daily driver—and make getting there repeatable with a bootable Omarchy installer.

There is substantial Linux enablement work behind these machines, particularly from the upstream Qualcomm/Linux community and Ubuntu. [Ubuntu's Snapdragon work](https://discourse.ubuntu.com/t/ubuntu-on-arm-summer-26-update/84872) is what makes our hardware foundation possible. The gap this project addresses is assembling those pieces into an Omarchy installation that works on the laptops we can test.

The goal is to preserve as much of **stock Omarchy Quattro** as possible, contribute the Snapdragon-specific work back, and give the Omarchy team a practical basis for considering official support. This is currently an independent community effort; official Omarchy Snapdragon support has not been established.

## What it installs

A native ARM64 Omarchy desktop using **Arch Linux ARM userspace, Ubuntu's Snapdragon-capable kernel and firmware, and the stock-derived Quattro installer**. Quattro handles the installation flow, disk configuration, encryption, packages and user setup. This repository adds the hardware packages, early boot drivers and boot finalization needed for Snapdragon machines.

Current image: **omarchy-snapdragon-v0.1.0.iso** — [download v0.1.0](https://github.com/bprendie/omarchy-snapdragon/releases/tag/v0.1.0) (7.48 GB), with a [SHA-256 checksum](omarchy-snapdragon-v0.1.0.iso.sha256). See the [release notes](docs/snapdragon-v0.1.0.md) for exact versions and validation.

GitHub release assets have a 2 GiB per-file limit. Download all four
`omarchy-snapdragon-v0.1.0.iso.part-*` files and the ISO checksum from the release,
then reconstruct the original image:

```bash
cat omarchy-snapdragon-v0.1.0.iso.part-{00,01,02,03} > omarchy-snapdragon-v0.1.0.iso
sha256sum -c omarchy-snapdragon-v0.1.0.iso.sha256
```

## Hardware status

| Machine | Status | Known gaps |
| --- | --- | --- |
| Lenovo ThinkPad T14s Gen 6, Snapdragon X Elite, LCD | Physical installation, encrypted-disk unlock and Omarchy desktop confirmed; audio, Wi-Fi, Bluetooth and panel brightness work | Charging can require unplug/replug; TrackPoint workaround included, with remaining EC/button behavior unconfirmed |
| HP EliteBook Ultra G1q 14, B13U7UT#ABA | Physical installation, graphical disk unlock and desktop confirmed; Wi-Fi, Bluetooth, touchpad, speaker audio and brightness widget work; **NPU validated with a QNN HTP workload** (separate test runtime) | Fn/media keys and keyboard backlight; one unexplained reset during keyboard investigation |
| ASUS Zenbook A14 UX3407RA, Snapdragon X Elite | Firmware and early OLED driver included; package and boot checks pass in an ARM VM | **No physical hardware test yet**; UX3407QA is outside this profile |

The combined v0.1.0 ISO reaches the Omarchy welcome screen in an ARM UEFI VM with zero failed services. The ThinkPad and HP confirmations come from preceding images carrying their respective fixes. A VM cannot establish ASUS hardware support or replace a physical installation test. Untested functions, including comprehensive suspend/resume and microphone/headset behavior, are not implied by a successful desktop boot.

**HP NPU follow-up:** a small neural-network operation has now passed on the
physical HP through Qualcomm's QNN HTP backend. The separately staged test
runtime is not included in v0.1.0. See [NPU validation](docs/hp-npu-validation.md).

## Where the pieces come from

| Source | Contribution to this project |
| --- | --- |
| [Omarchy](https://github.com/omacom/omarchy), [Quattro installer](https://github.com/omacom/omarchy-iso) and [Omarchy packages](https://github.com/omacom/omarchy-pkgs) | Desktop, installer orchestration, package selection, offline mirror workflow and user setup. The current image packages Omarchy 4.0.3-1.4 with targeted ARM changes. |
| [Arch Linux ARM](https://archlinuxarm.org/) | Native ARM64 base system, package repositories and signing keyring. Additional desktop packages come from Omarchy's ARM package repository. |
| [Ubuntu 26.04 ARM64](https://cdimage.ubuntu.com/releases/26.04/release/) | Initial hardware/firmware baseline from the verified 26.04.1 desktop ISO. The current kernel and matching modules come from authenticated Ubuntu update packages: **7.0.0-31-generic**, package version **7.0.0-31.31**. These are repackaged for Arch without running Debian maintainer scripts. |
| [Ubuntu Stubble](https://github.com/ubuntu/stubble) | The boot stub in Ubuntu's kernel image selects an embedded device tree for the machine. We retain the wrapped kernel image unchanged. |
| [Omarchy ARM reference port](https://github.com/alexisraitano-myffu/omarchy-arm) and [Omarchy Mac](https://github.com/omacom/omarchy-mac) | Reference work for bringing Omarchy to ARM, alongside the stock Quattro sources. Omarchy Mac builds on **Asahi Linux / Asahi Alarm** for Apple Silicon. That is the Asahi connection here: ARM integration reference work, rather than an Asahi kernel, Apple GPU drivers or an Asahi root filesystem in this Snapdragon ISO. |
| [Linux Qualcomm community](https://github.com/torvalds/linux/tree/master/arch/arm64/boot/dts/qcom) | The upstream device descriptions and drivers behind the Ubuntu hardware stack. |
| [HP Qualcomm Driver Pack](https://ftp.hp.com/pub/softpaq/sp162501-163000/sp162865.cva) | Five HP GPU/DSP firmware payloads extracted from SoftPaq **sp162865**, driver pack **7700.1**. |
| [ASUS UX3407RA support](https://www.asus.com/us/supportonly/ux3407ra/helpdesk_download/) | Five ASUS GPU/DSP firmware payloads extracted from Qualcomm BSP **V1.312.8100.0**. |
| [AudioReach topology](https://github.com/linux-msm/audioreach-topology) and [ALSA UCM](https://github.com/alsa-project/alsa-ucm-conf) | Audio topology and sound-card profiles. The HP fix packages the compatible topology under the requested HP filename and adds the matching UCM links. |

Our contribution is the integration: reproducible extraction and packaging scripts, model-specific firmware provisioning, early display support for encrypted-disk unlock, ARM package-trust repair, boot finalization, scoped hardware workarounds and test evidence.

Exact source revisions and input checksums are in [manifests/](manifests/), including [Quattro sources](manifests/quattro-sources.tsv) and [kernel inputs](manifests/ubuntu-kernel-7.0.0-31.sha256). Package-specific provenance is kept beside the recipes in [packages/](packages/). Vendor firmware retains its original ownership and licensing; its inclusion does not grant blanket redistribution rights.

## Building and testing

The current build requires a prepared Linux workspace with Docker, Go, Git, GnuPG, xorriso and ARM64 execution through QEMU/binfmt. The scripts depend on retained inputs, an ARM build container and staged installer roots; this is not yet a one-command build from a clean checkout. See [reproducibility notes](docs/reproducibility.md).

From that prepared workspace:

```bash
bash scripts/build-boot-package.sh
bash scripts/build-snapdragon-installer.sh
```

The builder writes the versioned ISO at the repository root and refuses to overwrite an existing image or staging tree. Verify it with:

```bash
sha256sum -c omarchy-snapdragon-v0.1.0.iso.sha256
```

Build intermediates, old images, VMs, downloaded inputs and private target data stay outside Git. The root release ISO and checksum are explicitly allowed. Source recipes, patches, provenance and technical documentation remain available for review and upstream collaboration.

Hardware reports are especially useful: include the exact model/SKU, image checksum, what works, what fails, and relevant logs with personal identifiers removed. ASUS UX3407RA testing is the next hardware gap to close.
