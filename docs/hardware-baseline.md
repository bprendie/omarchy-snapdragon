# Hardware baseline

Updated 2026-09-11.

| Item | Evidence |
| --- | --- |
| Target | User: Lenovo ThinkPad T14s, Snapdragon X Elite, 32 GB RAM, LCD |
| Working OS | Measured over SSH: Ubuntu 25.04, Plucky development branch |
| Execution host | Measured: x86_64 HP Dragonfly 13.5 inch G4; not the target |
| Machine type / BIOS | 21N10000US / N42ET92W (2.22) |
| Working kernel | 6.14.0-15-generic, package 6.14.0-15.15 |
| Panel | BOE NE140WUM-N6G (0x0b66), card1-eDP-1 connected, 1920x1200 |
| Device tree | `lenovo,thinkpad-t14s qcom,x1e78100 qcom,x1e80100` |
| Storage | 256,060,514,304-byte NVMe; p1 1,127,219,200-byte VFAT ESP; p2 254,930,845,696-byte ext4 |
| Target SSH access | Dedicated key authenticated after user-confirmed host fingerprint; project-local known_hosts; sudo requires a password |

The user confirmed this is an older Snapdragon Ubuntu installation and wants
the latest available kernel. The working 6.14 installation is a comparison
baseline, not the selected kernel for the next ISO.

## Working boot and display

`/boot/dtb` points to the external
`dtbs/6.14.0-15-generic/qcom/x1e78100-lenovo-thinkpad-t14s.dtb`.
The working command line includes `clk_ignore_unused pd_ignore_unused cma=128M`;
the GRUB drop-in supplies these. Boot identifiers remain private.
The ISO instead uses 7.0.0-30-generic with Stubble's embedded LCD device tree.
Both inspected trees have an `edp-panel`, PMK8550 PWM and PWM backlight.
Their PWM periods differ (5,000,000 versus 4,266,537 ns); this difference alone
does not establish a display failure cause. Both kernel configs enable the
panel/backlight drivers as modules and default CMA to 32 MiB.

Working backlight reports brightness 1257/4095 and bl_power=0. The kernel log
detects the BOE panel and initializes msm. Early SQE firmware lookup failures
are followed by successful SQE/GMU loading; they are not a final GPU failure.
ADSP starts with Lenovo 21N1 firmware. An audio topology lookup fails later;
audio functionality has not been tested.

## Power observation

Later user report (2026-09-12, hybrid testing): the charger remained connected
and the cable wattmeter dropped from 45 W to 0 W during kernel boot. The user
requested deferring this issue until after boot recovery. This establishes
external power was connected for that observation; the cause and actual battery
charge/discharge behavior still need controlled measurement.

User reports charging trouble on this Ubuntu. At collection, battery status was
Discharging, energy 57.44 Wh, full capacity 59.21 Wh and cycle count 26.
Every reported AC/USB/wireless/UCSI input was offline. Whether the charger was
attached during collection is pending user clarification. No charge threshold
was obtained. This is a single observation, not a controlled power test or a
confirmed charging-driver diagnosis.

## Evidence retained locally

Raw inventory, kernel journal, boot configuration, external DTB, live device
tree and initramfs are under ignored `private/thinkpad-live/`. Kernel image and
raw firmware FDT require elevated access and have not been copied. No target
system configuration, boot files, partitions or installed packages were changed.
USB topology collection had permission errors and cannot establish missing USB
drivers. Firmware package: linux-firmware 20250317.git1d4c88ee-0ubuntu1;
alsa-ucm-conf 1.2.12-1ubuntu1; Mesa 25.0.3-1ubuntu2.

`dist/oma-snap-inventory-arm64` is a standalone read-only executable for the ThinkPad. Run `./oma-snap-inventory-arm64 > t14s-inventory.json` there. It has no network or recurring activity. Missing optional commands appear as explicit errors. It redacts kernel root identifiers and excludes serials, addresses, raw EDIDs and raw logs. Keep complete kernel command lines, EFI paths and logs local until individually reviewed.

This inventory does not validate the hybrid. Graphics renderer, complete EFI
boot-chain details and a controlled battery baseline remain outstanding. No
target disk plan has been selected. Preserve Ubuntu and its boot entry.
