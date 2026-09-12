# Combined ThinkPad / HP installer candidate — 2026-09-12

Artifact: `dist/oma-snap-installer-thinkpad-hp-audio-arm64.iso`

- Size: 7,443,214,336 bytes.
- SHA-256: `70be7cdaf6f9f49c61716d7bf4116459684be402c565d6b4e97eb1283773aa99`.
- USB write and full direct readback **PASS** after the user returned and
  authorized /dev/sda. Reidentified SanDisk serial 03020423051326054610,
  61,504,880,640 bytes. All 7,443,214,336 image bytes match the SHA-256 above;
  OMADIAG detected, drive safely powered off. Evidence:
  `build/thinkpad-hp-audio-usb-write.log`.
- HP unlock addition is a candidate pending physical reboot validation.

## Included changes

Based on the retained kernel31-trackpoint root: Omarchy runtime/settings
4.0.3-1.4, ARM keyring provisioning, corrected end-of-install boot validation,
ThinkPad graphical unlock prerequisites and the model-scoped TrackPoint
workaround. Kernel remains 7.0.0-31-generic. The ThinkPad TrackPoint script
matches the retained baseline byte-for-byte; no HP input remaps are introduced.

HP GPU/DSP firmware package 7700.1-1 is retained. New `oma-snap-audio-hp 0.1.0-1`
adds the physically tested AudioReach topology and DMI-name ALSA profile link.
It is included in the live root and early target package list, and its versioned
firmware is included in the initramfs. The profile links affect the HP card
only, preserving the ThinkPad's existing ALSA configuration.

Boot helper 0.1.0-5 adds gpio_sbu_mux to the early dependency graph. The HP
display graph waits for this switch, and the previous image omitted the driver.
See [unlock/Fn investigation](hp-unlock-fn-investigation.md) for the evidence,
VM limitations and physical test still required.

Default menu identifies both supported test models. HP diagnostic entries,
512 MiB writable OMADIAG partition and explicit copy-to-RAM settings remain.
Fn/media handling is unresolved; use desktop widgets until repaired. ASUS
Zenbook A14 remains a subsequent stage before public GitHub handoff.

## Validation

- New topology rebuilt from pinned BSD-licensed source and matches the exact
  physically tested bytes. HP proprietary GPU/DSP provenance is unchanged.
- Audio, boot and HP firmware packages: 48 entries total, zero altered files.
- Offline dependency resolution from an empty database selects boot 0.1.0-5,
  audio 0.1.0-1, HP firmware 7700.1-1 and Omarchy runtime/settings 4.0.3-1.4.
- Offline payload count is 960 and matches the installer expectation.
- Initramfs contains HP topology/DSP files, ThinkPad DSP firmware and the new
  gpio-sbu-mux module. Existing ThinkPad display prerequisites remain included.
- Boot helper tests/vet and platform selection regression checks pass.
- Installed-root initramfs VM shows a visible text passphrase prompt and
  successfully decrypts its disposable LUKS fixture; no HP panel emulation.
- ISO checksum independently verified before the live VM boot test.
- ARM UEFI virtual-USB live boot reaches the Omarchy welcome screen; zero
  failed services, diagnostic service inactive, all three changed/added
  hardware packages pass integrity checks inside the running image.
  Evidence: `build/hp-audio-live-vm/welcome.png` and `validation.txt`.

Build log: `build/hp-audio-installer-build.log`. New staging directories are
`build/hp-audio-installer-root` and `build/hp-audio-installer-iso`; older HP and
ThinkPad artifacts are retained. Live VM evidence belongs in
`build/hp-audio-live-vm/`. No full install of this combined ISO has been tested.

## Resume

First validate the HP unlock candidate on hardware. The image is staged at
`~/hp-audio-candidate/hp-unlock-initramfs.img`; its SHA-256 matches
`manifests/hp-unlock-initramfs.sha256`. It is not installed under /boot or selected
in GRUB. Read the current boot configuration with privilege when the user
returns, then prepare a separate test entry and preserve the existing one.

For Fn diagnosis, run the staged 60-second raw keyboard observer only when the
user can press the keys. No privileged or input-capture process is waiting.

Before future USB writes, reidentify the SanDisk and unmount its volumes.
`scripts/write-hp-installer-usb.sh /dev/sdX` now requires an explicit path,
checks the previously recorded serial/model/capacity, writes this ISO and
performs full direct readback. The authorized write is now complete.
