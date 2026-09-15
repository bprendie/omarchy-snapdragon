# v0.2.2-1: Chromium startup hotfix

This maintenance image carries forward v0.2.2's Omarchy 4.0.3, Ubuntu Concept
`7.2.0-18-qcom-x1e` kernel and all hardware payloads. It fixes Chromium crashing
at launch when the Ubuntu kernel's AppArmor user-namespace gate is enabled
without Ubuntu's userspace policy stack.

The change sets `kernel.apparmor_restrict_unprivileged_userns=0` through a
sysctl drop-in in the live root and `oma-snap-kernel-tools` **0.2.2-2** for the
installed system. Chromium keeps its own namespace/seccomp sandbox. This
removes Ubuntu's additional restriction for all unprivileged applications; it
does not disable AppArmor as a whole. See the [diagnosis](chromium-userns-fix.md).

## Evidence and limits

- On the physical HP, the original kernel audit log denied Chromium's
  `userns_create`; `unshare -Ur true` failed and Chromium crashed with SIGTRAP.
- After applying this exact configuration, the namespace check passed and
  Chromium launched `chrome://sandbox`. Renderer processes reported
  `NoNewPrivs: 1`, `Seccomp: 2`, and an active seccomp filter.
- The owner confirmed the HP browser fix worked. This confirms the repair;
  it does not establish a separate fresh-install/reboot test of the hotfix ISO.
- The new tools archive preserves every original runtime file, mode and owner;
  only the sysctl directory/file is added. Package metadata changes for the new
  package revision. Uncommitted snapshot-hook experiments are not included.
- The six-package local testing repository was rebuilt and signed with the
  existing pinned test key. The hardware set, provider sequence and approval
  are unchanged. All 976 offline installer packages resolve, selecting the new
  tools revision.
- The ISO keeps the original kernel/initramfs and appended EFI/diagnostic
  partitions. This is a focused repack of a hardware-booted baseline, not a new
  kernel validation. A fresh installation and reboot of the hotfix image have
  not yet been physically tested. ASUS hardware remains unvalidated.

Output: `omarchy-snapdragon-v0.2.2-1.iso` and its `.sha256` file in the repository
root. [GitHub release v0.2.2-1](https://github.com/bprendie/omarchy-snapdragon/releases/tag/v0.2.2-1)
provides four parts plus whole-image and part checksums. Existing v0.2.2 assets
remain available. Reassemble with:

```bash
sha256sum -c SHA256SUMS.parts
cat omarchy-snapdragon-v0.2.2-1.iso.part-{00,01,02,03} > omarchy-snapdragon-v0.2.2-1.iso
sha256sum -c omarchy-snapdragon-v0.2.2-1.iso.sha256
```

## Rebuild and inheritance

`scripts/stage-v0221-hotfix.sh` verifies the pinned v0.2.2 ISO and extracts its
root into a fresh `build/snapdragon-v0221` directory.
`scripts/build-userns-hotfix-package.sh BASELINE_TOOLS_PACKAGE NEW_BUILD_NAME`
repackages the released tools payload with the one configuration addition,
using the existing `oma-snap-root` ARM build container. This special hotfix
recipe avoids rebuilding unrelated development changes.

Use `scripts/build-promoted-kernel-repo.sh` with the same original hardware,
provider, Omarchy/settings and trust packages, original approval/evidence and
signer, replacing only the tools package. Then run:

```bash
bash scripts/assemble-v0221-hotfix.sh kernel-repo-v0221-testing
bash scripts/verify-userns-image.sh build/snapdragon-v0221/root
bash scripts/verify-v022-offline.sh snapdragon-v0221 v0221-offline-check 0.2.2-2
sha256sum -c omarchy-snapdragon-v0.2.2-1.iso.sha256
```

The stage, package build, repository and check directories must be fresh.
The standard `packages/kernel-tools/PKGBUILD` and
`scripts/build-kernel-tools-package.sh` now include the same configuration,
so future source builds inherit it. `tests/kernel-tools-package.sh` requires
the file in the built archive. The v0.2.2 assembly path also runs
`scripts/verify-userns-image.sh`, which rejects a staged root missing the fix
in either live userspace or its installable kernel-tools package.

Future Limine work must stage this hotfix baseline and run the same guard;
the local Limine prototype has been updated accordingly, but remains separate
unpublished work. An older extracted v0.2.2 tree will fail that guard.
Existing v0.3.0-dev images are not modified
by these source changes. No USB drive was written during this build.
