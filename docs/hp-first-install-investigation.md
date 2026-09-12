# HP EliteBook Ultra G1q first install — 2026-09-12

## Returned physical diagnostic capture

The first diagnostic USB run returned 12 files: STARTED.txt plus all 11 command
logs in snapshot 00. Copies were verified against the USB with SHA-256 and kept
locally in `private/hp-live/hp-diag-20260912T171158-a29ee08d/`. No COMPLETE marker,
sysfs report, firmware inventory or later snapshots were produced. IMG_0364
shows systemd stopping the collector at its six-minute timeout.

The collector advances from the saved command logs to `sysfiles()`, which reads
DRM connector state, power supplies and debugfs directly without timeouts and
only writes its combined report afterward. The evidence localizes the stall to
that phase (including its final report write); it does not identify the exact
file or prove a particular kernel deadlock. Future capture must preserve each
read incrementally and avoid or bound potentially blocking hardware queries.

Confirmed on this live boot:

- Correct HP device tree selected; BIOS F.34 dated 2026-06-26, board 8CBE.
- GPU initialization fails with error -2 after missing
  `qcom/x1e80100/hp/elitebook-ultra-g1q/qcdxkmsuc8380.mbn`; a GMU timeout follows.
  The display controller still registers an msm framebuffer. This confirms a
  live GPU enablement blocker; installed-system compositor logs remain absent.
- ADSP/CDSP startup fails requesting the HP-specific qcadsp8380.mbn and
  qccdsp8380.mbn files. Bluetooth also fails to obtain qca/wcnhpbtfw20.tlv and
  its qca/hpbtfw20.tlv fallback.
- Wi-Fi PCI 17cb:1107 binds to ath12k_wifi7_pci, identifies WCN7850 hw2.0 and
  loads firmware. NetworkManager lists wlan0 as wifi/disconnected; rfkill shows
  neither soft nor hard blocking. Association and traffic were not tested.
  This differs from the earlier installer report; its cause remains unresolved.
- The NVMe's ESP and encrypted root are not mounted. The log partition is on
  the removable boot USB. `/sys/class/udc` exists but is empty on this boot.

The earlier image-only audit and access context follow below.

User tested the previous project ISO on HP EliteBook Ultra G1q 14,
B13U7UT#ABA, X1E78100, 32 GB. The installer completed, Wi-Fi was unavailable
in nmtui, and the installed system did not reach a desktop. Exact ISO identity
and final boot screen have not been confirmed. Console/network access is
currently unavailable. No HP changes have been made remotely.

## Confirmed image gap

The retained kernel's HP DTB (`hp,elitebook-ultra-g1q`) requests these files under
`qcom/x1e80100/hp/elitebook-ultra-g1q/`:

- `qcdxkmsuc8380.mbn` (GPU)
- `qcadsp8380.mbn`, `adsp_dtbs.elf` (ADSP)
- `qccdsp8380.mbn`, `cdsp_dtbs.elf` (CDSP)

This directory is absent from both the retained Ubuntu firmware extraction and
the current installer root, including the kernel-specific firmware namespace.
The firmware package copies entire qcom/ath12k/qca trees; it does not deliberately
exclude an existing HP directory. The needed files are missing from its inputs.
This is a concrete enablement gap and a candidate explanation for desktop
failure, not a runtime-confirmed diagnosis. Logs are still needed to distinguish
unlock/boot, DRM, firmware, and compositor failures.

Wi-Fi is unresolved separately. The DT describes PCI 17cb:1107, and the image
contains WCN7850 ath12k firmware and kernel driver modules. Actual PCI identity,
rfkill state, probe errors and requested firmware/board IDs have not been read
from this HP. Do not infer that the DSP/GPU gap also explains Wi-Fi.

Evidence: `build/hp-investigation/` (decoded DTB, firmware references, module list).
Investigate obtaining model-appropriate firmware from authenticated HP/Qualcomm
driver inputs; do not substitute ThinkPad DSP blobs just to satisfy filenames.

## Access

A direct USB-C cable does not by itself provide SSH. USB gadget networking
requires supported device-mode hardware and explicit target configuration;
the current image has no configured USB networking gadget. Reference:
https://docs.kernel.org/usb/gadget_configfs.html

USB Ethernet/tethering plus a working console is one path. If unavailable,
prepare an HP diagnostic live image with deliberate log collection/access
instead of asking the user to reinstall blindly. USB4 networking capability has
not been verified on this hardware/kernel. The ThinkPad USB build/write remains
a separate operation and does not include an HP firmware fix.
