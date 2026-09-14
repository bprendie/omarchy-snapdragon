# ASUS Zenbook A16 identification — September 13, 2026

**Investigation resumed for v0.2.2 on September 14.** The owner confirms the
published v0.2.0 ISO works well. A newer Ubuntu Concept kernel contains the exact
A16 tree and boot-selection mappings; see [the kernel audit](asus-a16-kernel-audit.md).
This is an investigation result, not a hardware-support claim.

User-supplied identifiers, preserved verbatim:

- Model: ASUS Zenbook A16 (`UX36070A-ZB/A16_X0 / UX36070`)
- P/N: `90NB17W3-M004C0`

ASUS's official model spelling is **UX3607OA** (letter O before A).
The supplied model appears to match that family, but the exact part number was
not independently resolved during this check. Do not infer RAM, storage, touch
panel or exact CPU SKU from the family-level specification.

ASUS distinguishes UX3607OA with **Snapdragon X2 Elite Extreme** from UX3607QA
with Snapdragon X. Sources checked September 13:
[ASUS specifications](https://www.asus.com/us/laptops/for-home/zenbook/asus-zenbook-a16-ux3607/techspec/)
and [ASUS model comparison](https://press.asus.com/news/press-releases/asus-zenbook-a16/).

This is a different target from the **UX3407RA / first-generation X Elite A14**
profile currently carried in the ISO. Existing A14 firmware, device-tree,
camera and display work does not establish A16 support. Keep the A14 profile
scoped to its existing identifiers; do not add an A16 alias to it.

Next investigation: confirm X2 platform support in the selected Ubuntu kernel,
its board description/boot support, matching ASUS BSP firmware and userspace
graphics/audio requirements. A16 support remains **unimplemented and untested**.
No A16 boot, desktop, camera or NPU validation is claimed. Preserve the existing
ThinkPad/HP and preliminary A14 profiles while evaluating this additional model.
