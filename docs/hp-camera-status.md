# HP EliteBook Ultra G1q camera — September 13, 2026

**RGB webcam capture works on the physical HP, including after reboot.**
The owner confirmed a usable preview. Two subsequent ten-frame libcamera
captures passed at approximately 30 fps after a clean reboot; a ten-frame
PipeWire/GStreamer capture also passed. The camera service started automatically.
These changes are local and are not in the published v0.1.0 ISO yet.
A later successful repeated capture logged one CAMSS “Received wm done for
unmapped index” warning; its effect is unestablished and needs monitoring.

## What was missing

The stock Ubuntu `7.0.0-31-generic` device tree disabled CAMSS and CCI and
contained no camera sensor node. The kernel also lacked the OV05C10 sensor
driver. Installing camera userspace alone could not fix this HP.

We recovered the machine's ACPI tables from the EFI RSDP using a temporary,
read-only kernel export module, then disassembled them without executing AML.
HP SoftPaq sp162865 camera resource tables supplied the front sensor's power
sequence, address and clock. Kernel pinctrl definitions and the working
ThinkPad topology helped cross-check the wiring. Physical sensor binding and
frame capture then validated the candidate.

## Implemented support

`packages/hp-camera/` packages an Intel-derived GPL-2.0 OV05C10 driver,
a board-specific DT overlay, a helper that populates the late-added CSI PHY,
and a hardware-gated systemd service. See its README for source provenance,
wiring and build requirements. No proprietary Windows camera binary runs.

The sensor uses CCI1 master 1, address 0x10, GPIO237 reset, GPIO50 supply enable,
PM8010 LDO3_M at 1.8 V, MCLK4 at 19.2 MHz, and CSI4 with two data lanes.
Native sensor capture is 2888×1808; libcamera produces 2880×1808 RGB frames.
The borrowed driver's VBLANK handling needed a runtime-PM correction to avoid
I2C reads while powered down and an unbalanced PM reference. The corrected
version passed repeated post-reboot capture without those earlier errors.

Userspace: `libcamera`, `libcamera-tools`, `pipewire-libcamera`, and
`gst-plugin-libcamera` (with their dependencies). PipeWire exposes node
`libcamera_input._base_soc_0_cci_ac16000_i2c-bus_1_camera_10`.

## Repeat validation

```sh
systemctl status oma-snap-camera-hp.service
cam -l
cam -c 1 --capture=10
cam -c 1 --capture=10
gst-launch-1.0 -q pipewiresrc \
  target-object=libcamera_input._base_soc_0_cci_ac16000_i2c-bus_1_camera_10 \
  num-buffers=10 ! video/x-raw ! fakesink
# Optional visible preview:
cam -c 1 --capture --sdl
```

Local evidence is retained in ignored `build/hp-camera-audit/`. Captured
images were not saved. ACPI dumps remain local.

## Remaining limitations

This is an interim out-of-tree implementation pinned to kernel 7.0.0-31;
it needs rebuilding and testing with any replacement kernel. It is not DKMS.
The modules are unsigned and taint the kernel. Runtime overlay removal emits
allocation warnings; disable the service and reboot for rollback instead of
unloading helpers under the camera stack. Original EFI/kernel files are intact.

Libcamera uses uncalibrated software ISP defaults and warns that sensor
properties, timing metadata and a sensor helper are absent. Color/exposure
quality, suspend/resume, browser applications, privacy LED behavior and IR
camera support remain unvalidated. A good RGB preview does not validate IR.
