# v0.2.2 — experimental Ubuntu Concept kernel

Experimental release built September 14, 2026. ARM UEFI smoke boot passed.
[Download v0.2.2](https://github.com/bprendie/omarchy-snapdragon/releases/tag/v0.2.2).
v0.2.0 remains the physically tested HP/ThinkPad baseline; no physical-system
validation on the new kernel is claimed.

## v0.2.0 versus v0.2.2

| Area | v0.2.0 | v0.2.2 |
| --- | --- | --- |
| Kernel | Ubuntu 7.0.0-31-generic | Ubuntu Concept 7.2.0-18-qcom-x1e, 7.2-rc7 base |
| Main purpose | Maintainable kernel packaging and updates for the existing X Elite baseline | Extend that pipeline to an experimental X2/A16 hardware stack |
| A16 boot matching | No matching A16 tree | Exact UX3607OA tree and Stubble mappings |
| A16 additions | Not provisioned | Wi-Fi/GPU/DSP firmware, board-specific audio topology/UCM, early SCMI power domain |
| Omarchy | 4.0.3, retained-kernel provider model | Same desktop and provider architecture; tools accept the Concept flavour |
| Validation | Physical HP/ThinkPad installation and camera results; normal Omarchy package updates observed | One complete ARM UEFI live boot, zero failed services, 976-package offline closure; no physical result |

The version number understates the hardware risk: this is a kernel change,
not merely extra A16 firmware. Rebuilt HP camera modules establish ABI build
compatibility, not a camera regression PASS. HP, ThinkPad and both ASUS profiles
need physical testing on the new kernel. Keep v0.2.0 for known-working X Elite
recovery; its old kernel is not an A16 recovery guarantee.

## What changes

- Ubuntu Concept `7.2.0-18-qcom-x1e`, package version `7.2.0-18.18`, replaces
  7.0.0-31 as the selected kernel. Its config identifies a **7.2.0-rc7** base;
  this is not a claim to ship upstream 7.2.3.
- The kernel embeds the exact ASUS A16 UX3607OA tree and 12 Stubble mappings,
  alongside ThinkPad LCD, HP G1q and first-generation ASUS A14 trees.
- HP OV05C10/overlay/children modules rebuild against the matching headers.
  The candidate's hid-asus module includes I2C ID `0B05:4B42` for the A16.
- Kernel lifecycle tools 0.2.2-1 handle both `-generic` and `-qcom-x1e` names.
  Provider sequence 2 requires those newer tools. Existing Omarchy/settings
  4.0.3-1.9 and the fresh-install boot helper remain in use.
- A separate, pinned Ubuntu Concept acquisition policy verifies its PPA signer,
  suite identity, metadata freshness and the entire kernel/header dependency
  closure. The ordinary Ubuntu generic policy remains available.

## ASUS A16 limits

The ASUS BSP V1.312.4500.0 was checked against ASUS's published SHA256. Five
GPU/DSP payloads are included in a separate A16 package and retained hardware
set. Provenance and local-testing restrictions accompany them.

The A16 remains **hardware untested**, with these additional prerequisites now
prepared:

- Upstream QCC2072 `board-2.bin`/`firmware-2.bin`, previously absent from the
  payload. Pinned linux-firmware commit and license are retained in the
  [firmware manifest](../manifests/asus-a16-upstream-firmware.json).
- The exact upstream `GLYMUR-ASUS-Zenbook-A16-UX3607OA` AudioReach topology,
  compiled from pinned commit `e7b20b2b16cdda18eb8ae143c8d95c4815c0288e`.
  An A16-only ALSA mapping uses the matching upstream four-speaker Glymur
  profile: MultiMedia1/PCM0 playback and MultiMedia2/PCM1 capture. The topology
  decodes successfully and its literal UCM include dependencies exist in the
  live base. This is preparation, not a speaker/microphone PASS.
- Early `scmi_pm_domain` plus current `pmdomain/qcom` modules, in both live
  and installed hooks. The existing OLED panel, Glymur clocks/pinctrl/interconnect,
  ASUS HID and GPU firmware are checked before the image smoke boot.

Correction to the initial audit: the DT contains `soccp.mbn` and
`soccp_dtb.mbn` names, but its SoCCP node is **disabled**. The PAS module contains
`qcom_pas_attach` and the Kaanapali-compatible fallback used by that node.
Consequently absence of those files alone does not establish a normal-boot
blocker. This also does not prove that the disabled SoCCP transport gives us
working battery reporting or restart/recovery; those remain open.

The camera has no enabled sensor/CCI/CAMSS capture graph in this candidate.
The A14's enabled camera graph and the ThinkPad's physical camera result do not
establish camera support on this different SoC.
Wi-Fi calibration, audio, accelerated rendering, hotkeys/backlight, battery,
NPU, suspend and actual panel/disk-unlock behavior all require A16 testing.
No first-generation ASUS firmware is relabelled as A16 firmware.
See [the tester checklist](asus-a16-testing.md).

## Build and validation

Source metadata/payload authentication and the matching HP camera build passed.
Candidate-policy and changed kernel lifecycle unit tests passed. The testing
provider explicitly defers independent package reproduction, VM rollback and
retained encrypted boot for this experimental physical-test iteration. All four
hardware profiles are marked untested on the new kernel. No previous kernel's
hardware or VM results are reused as new-kernel evidence.

Prepared local build sequence:

```bash
OMA_SNAP_KERNEL_POLICY=profiles/snapdragon/kernel-track-concept.json \
  bash scripts/discover-kernel-candidate.sh concept-v022 --download
bash scripts/prepare-kernel-set.sh concept-v022 concept-7.2.0-18 \
  profiles/snapdragon/kernel-track-concept.json
bash scripts/build-kernel-set-camera.sh concept-7.2.0-18
bash scripts/prepare-asus-a16-firmware.sh
bash scripts/prepare-asus-a16-audio.sh
bash scripts/prepare-hardware-package.sh concept-7.2.0-18 package-v022-a16 --asus-a16
bash scripts/build-hardware-package.sh package-v022-a16
bash scripts/build-kernel-tools-package.sh kernel-tools-v022-a16
# Build provider sequence 2 and sign the coordinated six-package testing repo.
bash scripts/stage-v022-installer.sh
bash scripts/prepare-v022-live-initramfs.sh package-v022-a16
bash scripts/assemble-v022-installer.sh kernel-repo-v022-a16-testing PINNED_SIGNER
```

These commands describe the prepared workspace, not a clean-clone build.
Outputs refuse overwrites. The installer staging still starts from the pinned
v0.1.2 base and carries the v0.2 provider integration forward. The new live
kernel uses the same retained payload as the installed provider. The legacy
7.0 boot remains the installed fallback; it is not a usable A16 recovery claim.
Keep the complete working v0.2.0 USB/image for HP/ThinkPad recovery.

The signed pacman repository remains a local testing snapshot, not an online
Ubuntu Concept update endpoint. Secure Boot remains out of scope.

## Release artifact

`omarchy-snapdragon-v0.2.2.iso`: 8,265,340,928 bytes.
SHA256: `9fcde763a1d70e59f5c0dba1579f30008d6d362ec2f1da6f9404304ae789f5bc`.

Retained set: `b79b849e5ebdb0425a99766f2122064366272b78634ed1f897a36195137e5111`.
Local signed repository: `build/kernel-repo-v022-a16-testing`, provider sequence 2.
All 976 offline installer packages resolve, including the A16 audio mapping.
The final initramfs passes `verify-asus-a16-readiness.sh`; this checks known
prerequisites only. The new SCMI module also exists in the retained 7.0 baseline.
No new physical result or USB write is claimed. The GitHub ISO release does
not publish an online pacman kernel update endpoint.

The complete ISO reached the Omarchy welcome screen in one ARM UEFI VM boot,
with `uname -r` reporting `7.2.0-18-qcom-x1e` and zero failed systemd units.
Evidence: `build/snapdragon-v0_2_2-vm/{result.json,welcome.png,userspace-check.txt}`.
A copy is retained in `~/ISOs`. This establishes live installer startup, not
an encrypted installation, rollback or Qualcomm hardware PASS. No repeated
installed-VM test campaign was run. Superseded provisional package builds were
removed; current authenticated inputs, packages and test evidence remain local.

The ISO is distributed as four release assets, each below GitHub's per-file
limit. Download every part and `omarchy-snapdragon-v0.2.2.iso.sha256`, concatenate
parts in numeric order, then verify the resulting ISO. `SHA256SUMS.parts`
provides individual-part checksums. Build caches, VMs, private data and the ISO
itself are not committed to Git source history.
