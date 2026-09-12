# Console ISO UEFI boot evidence

2026-09-11. Image SHA-256: `af2ad8239501183636c982ab8d1f9ff5ce33d818e4317ad4a9fdbf4e6c146e01`.

Fixture: QEMU 10.2.1, `virt`, Cortex-A72, 2 CPUs, 4 GiB RAM, Ubuntu AArch64 EDK2 2025.11-3ubuntu7, Secure Boot disabled. ISO attached as a virtual SCSI CD-ROM, no hard disk or network. Commands in `scripts/smoke-uefi.sh`. Raw session log remains in ignored `build/uefi-console.log`; generated VM identifiers are omitted here.

Boot passes through UEFI, Ubuntu GRUB 2.14, Ubuntu kernel, Arch initramfs, squashfs/overlay and Arch systemd 261.3. Local root auto-login succeeds.

| Runtime check | Observed result |
| --- | --- |
| `uname -m` | `aarch64` |
| `uname -r` | `7.0.0-30-generic` |
| `systemd-detect-virt` | `qemu` |
| Root filesystem | `overlay` |
| ISO backing mount | `/dev/sr0`, `iso9660`, `ro` |
| Kernel package | `oma-snap-kernel-ubuntu 7.0.0.30.30-1` |
| Firmware package | `oma-snap-firmware-ubuntu 20260319.217ca6e4-1` |
| MSM module vermagic | `7.0.0-30-generic SMP preempt mod_unload modversions aarch64` |
| `modprobe virtio_rng` | Exit 0 |
| `systemctl --failed` | Zero failed units |
| Container marker | Absent |
| Combined kernel/root/module assertion | `KERNEL_ROOT_MODULE_PASS` |

This proves a virtual UEFI console boot and the distribution bridge for virtual hardware. It does not establish native T14s boot, DTB selection from that machine's SMBIOS, Qualcomm rendering, input, audio, radio, suspend or power behavior. MSM vermagic inspection is not a physical GPU driver test.

## Virtual USB result

The identical final ISO also reached the root console with `scripts/smoke-usb.sh`, presented as a read-only virtual USB mass-storage device through QEMU xHCI. The boot-medium mount was `/dev/sda`, `iso9660`; kernel `7.0.0-30-generic`; `systemctl --failed --no-legend` returned no units; `/.dockerenv` was absent. Marker `USB_BOOT_PASS` was observed, then the guest powered off cleanly. Raw local evidence is `build/uefi-usb.log` (not committed because terminal control sequences carry generated machine/session identifiers).

GRUB printed `file /boot/ not found` before displaying its menu and completing boot. This is a remaining boot-menu diagnostic to investigate, not a failed USB boot or proof of physical compatibility.
