# HP EliteBook Ultra G1q camera status — September 13, 2026

**The internal webcam is not enabled by the current hardware description.**
This differs from the ThinkPad's missing-userspace-package issue.

Read-only inspection of the physical B13U7UT#ABA / 8CBE machine, BIOS F.34,
kernel `7.0.0-31-generic`, found:

- No `/dev/video*`, `/dev/media*` or `/sys/class/video4linux` devices.
- No camera source in PipeWire.
- Loaded device-tree model: `HP EliteBook Ultra G1q`.
- `soc@0/isp@acb7000` (CAMSS): `status = "disabled"`.
- Both CCI controllers, at `ac16000` and `ac15000`: disabled.
- No camera sensor node or sensor-to-ISP graph in the loaded device tree.
- USB enumeration contains root hubs only; no USB camera was detected.
- The libcamera/PipeWire camera packages are absent, but installing them alone
  cannot supply the missing hardware description.

The upstream [EliteBook device tree](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/x1e80100-hp-elitebook-ultra-g1q.dts)
and its [shared HP definitions](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/x1-hp-omnibook-x14.dtsi)
also contain no camera sensor enablement at the time of inspection. A newer
kernel must be evaluated for actual camera changes, not assumed to fix this.

The retained HP SoftPaq sp162865 archive listing contains camera modules and
tuning data for `ov05c10` and `hm1092`. These are investigation leads from a
multi-driver archive, not proof of the exact sensors fitted to this machine.

Next bring-up steps:

1. Identify the installed RGB/IR sensors and their board wiring from Windows
   device/ACPI data, vendor configuration or a verified matching upstream patch.
2. Confirm Linux sensor-driver support and describe CCI address, supplies,
   reset/power GPIOs, clocks and CSI lane/endpoints in the HP device tree.
3. Test that description through a recoverable boot path, preserving the
   known-working installed boot entry.
4. Once the sensor enumerates, use the camera packages now queued in the
   shared installer profile and repeat the ThinkPad's libcamera and PipeWire
   capture checks, followed by visual and suspend/resume validation.

No packages, firmware, boot files or device-tree settings were changed on the
HP for this audit. No capture test was possible. Local evidence is retained
under ignored `build/hp-camera-audit/`.
