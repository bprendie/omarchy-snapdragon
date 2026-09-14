# ASUS A16: v0.2.2 kernel and device-tree investigation

Checked September 14, 2026, after the owner confirmed the published v0.2.0 ISO
works well. Target: UX3607OA / Snapdragon X2 Elite Extreme (Glymur), with the
owner's exact identifiers retained in [identification notes](asus-a16-identification.md).

## Result

Ubuntu Concept already ships an ARM64 kernel containing the exact A16 device
tree and Stubble hardware matching. Prefer evaluating this complete kernel stack
for an experimental v0.2.2 candidate over backporting only the board tree into
7.0.0-31. No laptop was modified and no new ISO was built during this audit.

| Inspected artifact | Finding |
| --- | --- |
| Existing v0.2.0 kernel, 7.0.0-31-generic | Existing inspection lists Glymur CRD boot mappings but no A16 mapping; the image string check finds no A16 identity. Several Glymur platform drivers are present, which alone does not establish A16 support. |
| Ubuntu Concept 7.2.0-18-qcom-x1e, version 7.2.0-18.18 | Exact `asus,zenbook-a16-ux3607oa` tree embedded in the EFI image; 12 matching Stubble hardware-ID entries. |
| Same candidate | ThinkPad T14s LCD, HP EliteBook Ultra G1q and ASUS A14 UX3407RA trees remain embedded. This is presence evidence, not regression testing. |
| Separately packaged A16 DTB | Root compatible is `asus,zenbook-a16-ux3607oa`, `qcom,glymur`; display panel is `samsung,atna33xc20`. |

The candidate comes from the [Ubuntu Concept x1e PPA](https://launchpad.net/~ubuntu-concept/+archive/ubuntu/x1e),
for **resolute**, not the standard Ubuntu archive used by the current updater.
The September 9 InRelease signature verified against the PPA key fingerprint
`8818B03153EA3CE7BBEF3A2A07E5CB0286C3AF17`, obtained from Launchpad's archive API
and matched to the signature. The Packages.xz hash/size matched InRelease and
the downloaded modules package SHA-256 matched that index. No package maintainer
scripts were executed. This verifies archive provenance, not runtime behavior.

Exact hashes and results are in
[the candidate manifest](../manifests/asus-a16-kernel-candidate.json).
Local inputs and inspection output are under `build/asus-a16-audit/`.

## Device-tree and firmware implications

Qualcomm's [A16 series](https://lkml.iu.edu/2607.2/11083.html) describes a distinct
board layout, with SoCCP/TCSR dependencies and additional display/Bluetooth
requirements. The board patch was [accepted by the Qualcomm maintainer](https://lists.openwall.net/linux-kernel/2026/08/03/202).
The [upstream board source](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/glymur-asus-zenbook-a16-ux3607oa.dts)
and Ubuntu's packaged DTB give us concrete definitions; inventing a new tree or
aliasing the first-generation A14 is unnecessary.

The candidate DTB explicitly requests these files under
`qcom/glymur/ASUSTeK/UX3607OA/`:

- `qcadsp8480.mbn` and `adsp_dtbs.elf`
- `qccdsp8480.mbn` and `cdsp_dtbs.elf`
- `soccp.mbn` and `soccp_dtb.mbn` (node disabled in this candidate)

This is the board's explicit remote-processor list, not a complete firmware
inventory. GPU firmware and Wi-Fi/Bluetooth firmware/calibration must also be
resolved from driver requirements and matching ASUS inputs. Existing A14 blobs
are not evidence of compatibility. That was the initial audit state; the subsequent v0.2.2 work packages the
GPU/DSP inputs, upstream Wi-Fi bundle and board-specific audio topology.
A disabled node containing firmware names is not evidence those files are
requested during normal boot.

There is also a separate [ASUS keyboard driver change](https://lists.openwall.net/linux-kernel/2026/08/03/2444)
for I2C HID ID `0B05:4B42`. Its inclusion and behavior should be checked in the
candidate before treating keyboard or Fn/media functionality as available.

## Concrete integration work

1. Add an explicit experimental Ubuntu Concept acquisition policy with its own
   pinned signer and `linux-qcom-x1e` package family. Current candidate code
   validates `linux-generic`; changing only the archive URL will not suffice.
2. Acquire matching headers/modules through that policy and rebuild the HP
   camera modules. In this PPA layout the actual kernel image lives in the
   **modules** package; the small image package primarily supplies packaging
   metadata. Preserve this in extraction and provenance checks.
3. Resolve and package the ASUS A16 firmware separately. Check the candidate
   keyboard, display and GPU driver requirements, audio topology/UCM, and Mesa
   compatibility. The tree's existence does not settle these dependencies.
4. Add the A16's required storage, input and OLED/display modules to early boot
   based on the candidate's real drivers. Keep visible disk unlock as a physical
   acceptance check; a generic ARM VM cannot prove it on this panel.
5. Build an explicitly experimental candidate with retained 0.2 recovery. Use a
   bounded packaging/boot check, then physical testing when an A16 owner is
   available. Recheck HP/ThinkPad before replacing their shared default kernel.

The existing v0.2.0 release and live systems remain unchanged. There is no A16
boot, desktop, camera, NPU or encrypted-unlock pass yet. Secure Boot remains
outside scope. No repeated installed-VM validation was resumed for this audit.

## Integration started after this audit

The owner authorized moving forward with the newer kernel. Candidate acquisition
now has an explicit Concept policy, matched HP camera modules rebuild, and the
kernel lifecycle tools accept the Concept flavour. See
[v0.2.2 build notes](snapdragon-v0.2.2.md) for the current artifact and limitations.
The configuration in this package identifies a Linux 7.2.0-rc7 base; the Ubuntu
ABI name does not mean it is upstream Linux 7.2.3.
