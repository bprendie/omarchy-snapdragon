# ASUS A16 UX3607OA: v0.2.2 tester handoff

This is an experimental Snapdragon X2 Elite Extreme image. It is separate from
ASUS A14 UX3407RA/X Elite support. Preserve a working OS/recovery image and start
with a live boot before choosing installation. Secure Boot is outside scope.
No A16 physical results have been recorded yet.

## What was prepared, and what remains

| Area | Offline evidence | Physical acceptance |
| --- | --- | --- |
| Boot/storage | Exact Ubuntu Concept A16 DTB and Stubble matching; matching kernel/modules | Cold boot, internal NVMe visible, installer finishes, reboot |
| Panel/unlock | OLED driver, Glymur clocks/pinctrl/interconnect and SCMI power domain included early | Visible passphrase prompt, brightness, repeated boots |
| GPU | Gen80100 firmware present; live Mesa 26.2.2 | Accelerated renderer, no repeated GPU resets |
| Wi-Fi | QCC2072 upstream board/firmware bundle added; candidate driver supports QCC2072 and firmware-2.bin | Scan, connect, transfer, reconnect; calibration/board matching |
| Bluetooth | Orne firmware already present in the retained firmware set | Controller appears, pair and use a device |
| Speakers/mic | Exact upstream A16 topology; matching four-speaker UCM mapping and include closure | Low-volume playback, all speakers, microphone recording |
| Keyboard/touchpad | ASUS HID 0B05:4B42 driver alias; HID included early | Typing, touchpad, Fn/media, keyboard backlight |
| Battery/charging | SoCCP node is disabled; no battery operation inferred from firmware names | Percentage and AC state, charging on both ports |
| Camera | **Gap:** no enabled A16 sensor/CCI/CAMSS capture graph in this kernel | Requires further kernel/DT bring-up; a browser permission change will not supply it |
| NPU | Matching A16 cDSP pair present | Driver initialization and a small compute workload; HP/ThinkPad results do not transfer |
| Suspend/docks | No unvalidated EC, PCI or reference-project workarounds applied | Resume, battery drain, USB-C/display/dock behavior |

## First test

1. Boot the normal **v0.2.2** installer entry. Record whether the display goes
   black and when; a powered black panel is not proof the machine stopped.
2. Before installing, check keyboard/touchpad, display brightness and Wi-Fi.
   If networking works, collect the report below. Do not use the HP-specific
   automatic diagnostic menu as an A16 capture procedure.
3. Check audio initially at a modest volume, then record a short microphone
   sample. Report whether the output is a real speaker device or Dummy Output.
4. Only after a usable live session, proceed with the intended install. Confirm
   that the passphrase prompt is visible and desktop loads after a cold boot.
5. Test suspend and external devices after saving work and collecting the initial
   report. No suspend-success or battery-runtime claim exists yet.

From a checkout, the read-only collector is:

```bash
bash scripts/capture-asus-a16.sh
```

It writes a timestamped report directory in the current directory. Kernel logs
may contain device identifiers; review the report before sharing it publicly.
The collector neither enables SSH nor changes drivers, firmware or power state.
If the display fails, return a photo and exact boot stage first; avoid speculative
firmware/EC writes.

## Maintainer checks

`verify-asus-a16-readiness.sh` checks the DTB against the actual embedded tree,
known firmware paths and early module list. Run it against the final initramfs,
not the earlier provisional build. Generic ARM UEFI smoke testing exercises the
image boot path only; it cannot emulate the A16's Qualcomm devices.

Upstream inputs:

- [A16 AudioReach topology](https://github.com/linux-msm/audioreach-topology/blob/e7b20b2b16cdda18eb8ae143c8d95c4815c0288e/GLYMUR-ASUS-Zenbook-A16-UX3607OA.m4)
- [Glymur ALSA profile](https://github.com/alsa-project/alsa-ucm-conf/blob/00175aa645c482111d096c3d8230f182a875d286/ucm2/Qualcomm/glymur/HiFi.conf)
- [Pinned firmware inputs and license](../manifests/asus-a16-upstream-firmware.json)
- [Candidate provenance and build limits](snapdragon-v0.2.2.md)

The independent FixItFoundry A16 work provided useful investigation leads, but
its custom topology, SoCCP transport and kernel patches are not silently mixed
into this Ubuntu kernel. Current upstream inputs and the actual packaged DTB
are the evidence for this candidate.
