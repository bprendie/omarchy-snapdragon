# HP OV05C10 camera integration

Target: HP EliteBook Ultra G1q, board 8CBE, Ubuntu kernel 7.0.0-31-generic.
This is an interim device-tree overlay and out-of-tree sensor driver, not
upstream kernel camera support. The service is hardware-gated and enabled on package installation; it starts
on the next boot. It skips machines other than HP board 8CBE.

The sensor driver is derived from Intel's GPL-2.0 driver:
https://github.com/intel/ipu6-drivers/blob/71bddb5158fb7f0bd244ad7aa6b2efab024531a7/drivers/media/i2c/ov05c10.c
Intel attribution remains in the source. Local additions supply DT matching,
HP power sequencing, and a fix avoiding powered-down I2C reads and an
unbalanced runtime-PM put during VBLANK updates. The original register-mode
sequences are retained, including their explicit 19.2 MHz setup.

Board data comes from HP SoftPaq sp162865's Camera_1/CAMF_RES_QRD.bin,
SCFG_FRONT_QRD.bin and SCF1_FRONT_QRD.bin, cross-checked against this machine's
ACPI and the kernel's pinctrl definition. No proprietary camera binary is
loaded by these modules. The RPMh LDO3_M regulator uses the vendor-specified
1.8 V. GPIO50 enables the camera supply; GPIO237 resets the sensor. AON CCI
pins235/236 map to CCI1 master1, at 7-bit sensor address0x10. CSI4 routing
has passed physical frame capture. Native capture is 2888x1808, around30fps.

The overlay is applied after userspace starts. `hp_camera_children` populates
the CSI PHY child device that is otherwise skipped during late overlay
application. A future kernel/device-tree integration should replace both
helper modules. Live overlay removal emits kernel warnings about retained
property allocations; normal reboot discards the overlay. Do not unload
these helpers while the camera stack is in use.

The package is tied to the exact kernel/module ABI. Building requires its
Ubuntu common and ARM64 generic header packages, checked against the retained
Ubuntu signed package index, extracted into the ARM build container's
`/usr/src`. The current build uses GCC16.1.1; Ubuntu built the base kernel
with GCC15.2. No module version checks are bypassed. BTF generation is skipped
because the Ubuntu vmlinux image is not present.

Install the package, then enable `oma-snap-camera-hp.service` and reboot for a
clean test. Disabling the service and rebooting returns to the stock hardware
description; the original kernel, initramfs and EFI boot files are unchanged.
No DKMS or automatic rebuild across kernel updates is provided yet.
