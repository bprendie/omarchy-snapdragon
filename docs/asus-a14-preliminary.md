# ASUS Zenbook A14 preliminary checks — 2026-09-12

September 13 identification update: the user's newly supplied ASUS model is an
[A16 UX3607OA-family machine](asus-a16-identification.md), a separate target.
The A14 checks below do not establish support for that A16.

September 13 follow-up: [camera and encrypted-unlock readiness](asus-camera-unlock-readiness.md)
checks the shipped RGB camera graph and known early-display prerequisites.
ASUS hardware remains untested.

Integration follow-up: the ASUS package and early panel driver are now wired
into the combined v0.1.0 builder. See `docs/snapdragon-v0.1.0.md` for the
resulting ISO validation. Hardware remains untested; the notes below describe
the earlier standalone checks.

Scope: UX3407RA / Snapdragon X Elite. The user confirms X Elite but has no
physical access; the exact model code must be verified by a future tester.
UX3407QA / X Plus is not covered by this firmware package.

## Inputs and gaps

Kernel31 embeds the UX3407RA device tree. Its five model-specific firmware
requests match the packaged GPU zap, ADSP and CDSP files. Existing base firmware
already contains the Zenbook AudioReach topology; alsa-ucm-conf already has the
Zenbook match. The OLED module `panel_samsung_atna33xc20` exists in kernel31 but
was absent from the ThinkPad/HP early image. The separate preliminary config
adds it while retaining the shared Qualcomm hook and all existing modules.

Official [ASUS UX3407RA support](https://www.asus.com/us/supportonly/ux3407ra/helpdesk_download/)
lists Qualcomm Board Support Package V1.312.8100.0, dated 2026-01-27, and publishes
SHA-256 `ce4593e948157ede6d936bec0db03b09bcbb39c3b11fab5d89c52b8954e72fde`.
The downloaded 375,072,688-byte archive matches. Download metadata is retained
in `build/asus-a14-audit/drivers.json`; the exact vendor URL is in the package's
PROVENANCE.txt. 7z extracted data; no Windows executable or BIOS/EC updater ran.

`oma-snap-firmware-asus-a14 1.312.8100.0-1` installs five ELF payloads under
`/usr/lib/firmware/7.0.0-31-generic/qcom/x1e80100/ASUSTeK/zenbook-a14/`:

- qcdxkmsuc8380.mbn — 12,088 bytes.
- qcadsp8380.mbn — 22,342,024 bytes; adsp_dtbs.elf — 73,528 bytes.
- qccdsp8380.mbn — 3,174,824 bytes; cdsp_dtbs.elf — 40,760 bytes.

The package contains no Windows drivers or executable installers. Vendor input,
extraction and built package are retained locally; public redistribution rights
have not been established. No public upload has occurred.

## Preliminary VM results

Generic ARM64 UEFI VM boots the unchanged combined ThinkPad/HP ISO, then receives
the ASUS firmware package over a local-only forwarded SSH connection.

- Package installation and integrity: **PASS**, 17 entries, zero altered files.
- All five firmware paths match the actual kernel31 DT requests: **PASS**.
- Modules load successfully: panel_samsung_atna33xc20, ps883x, msm,
  qcom_q6v5_pas, ath12k_wifi7, hci_uart, snd_soc_x1e80100, i2c_hid_of.
- Zero failed system services after loading those modules.
- Evidence: `build/asus-a14-preliminary-vm/validation.txt`, serial.log,
  welcome.png. This first VM is stopped after validation.

These modules register in the VM but do not bind ASUS hardware, because QEMU
does not emulate it. Firmware load acceptance by the DSP/GPU, audio output,
panel operation, Wi-Fi, Bluetooth, sleep and charging remain untested.
Do not use the ASUS DTB as the hardware description for QEMU's virt machine.

Candidate initramfs: `build/asus-a14-audit/initramfs.img`, with the added panel
module and the five firmware files. The separate boot regression uses
`scripts/test-asus-a14-boot-vm.sh`: a temporary EFI loader, candidate initramfs,
and the existing ISO as a read-only live root. This is not a new installation ISO.
Candidate boot regression: **PASS**, Omarchy welcome screen reached, Samsung
OLED panel module loaded from the initramfs, zero failed services, diagnostics
inactive. Evidence: `build/asus-a14-boot-vm/welcome.png`, validation.txt and
serial.log. Both test VMs are stopped.
Content checks confirm the OLED module and all five payloads in the archive.
SHA-256: `aca5183218780d9af33b7458beb23e94412c7239991891d30815db5e40371656`.
The ASUS package was removed from the shared ARM build container after creating
this candidate, preventing accidental inclusion in a later HP-only rebuild.
The built package, archive, extracted data and candidate image are retained.

To rebuild the candidate in the prepared ARM container, install the generated
ASUS package there, copy the profile's mkinitcpio-preliminary.conf to
build/asus-a14-audit/mkinitcpio.conf, and run mkinitcpio with that `/output/`
configuration path, kernel 7.0.0-31-generic and the candidate output path above.
Remove the ASUS package from the shared container afterward. The package and
profile are separate from the immutable HP handoff ISO.

## Next integration

The tracked profile is `profiles/asus-zenbook-a14-ux3407ra/`; reproducible firmware
preparation is `scripts/prepare-asus-a14-firmware.sh`. The v0.1.0 combined
builder now includes the package in early target provisioning and the panel
module in both live and installed initramfs generation. Combined regression
results are recorded in `docs/snapdragon-v0.1.0.md`.
Keep this ASUS profile explicitly hardware-untested until a UX3407RA owner tests.
The HP test USB contains SHA-256 70be7cdaf6f9f49c61716d7bf4116459684be402c565d6b4e97eb1283773aa99
and was not rewritten during ASUS work.
