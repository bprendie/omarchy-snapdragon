# Stock Quattro reuse

User decision, 2026-09-11: use as much of the stock Quattro installer as possible. The primary installation source is now `omacom/omarchy-iso` on its pinned quattro revision. The earlier third-party ARM fork remains a hardware-port reference, not the main installer. Source identities are recorded in `manifests/quattro-sources.tsv`; `scripts/fetch-quattro.sh` restores and checks them without modifying existing checkouts.

## Reuse boundary

| Stock component | Intended treatment | Evidence and remaining adaptation |
| --- | --- | --- |
| Configurator and progress dashboard | Retain upstream UI | `configs/airootfs/root/configurator` writes archinstall JSON; kernel selection and EFI intent currently select x86 defaults |
| Partitioning, encryption, mounting | Retain upstream helpers and archinstall adapter | Protected mode supports an existing layout; Ubuntu ESP detection and preservation must be checked specifically, because `detect_windows_esp` looks for `EFI/Microsoft` |
| Python phase runner | Retain | `orchestrator/main.py` owns phase ordering and failure cleanup; no replacement installer framework |
| Bundled offline pacman mirror | Retain design | Populate with verified ARM packages and our kernel/firmware packages; stock offline config disables signature checks based on a signed ISO, which this prototype does not yet provide |
| Runtime/settings packaging | Use upstream PKGBUILDs | Both now declare aarch64; runtime omits x86 Limine dependencies and settings omit x86 boot/memory drop-ins |
| User creation and setup | Retain with bounded profile changes | Preserve upstream user/defaults flow; audit optional cloud tools, first-run work and architecture-specific downloads |
| Factory snapshot | Retain Btrfs concept and upstream phase where compatible | Reset/provisioning and boot-entry restoration must be adapted and tested together; current code assumes Limine |
| Live and installed boot | Snapdragon-specific adaptation required | Stock orchestrator finalizes and validates Limine/UKIs; preserve the working Ubuntu Stubble kernel/DTB path until an equivalent boot path is demonstrated |
| Updates | Keep pacman ownership and upstream update orchestration | Ensure ARM repositories, matching kernel/modules/firmware and recovery survive migrations; no unreviewed x86 replacements |

The official Mac port is reference material for ARM package selection only. Its Apple boot path and hardware defaults are not a Snapdragon profile. The stock package recipes already carry relevant ARM separation, reducing the patch set needed here. The user explicitly approved stock AI/cloud applications and optional Electron apps; those are no longer policy exclusions.

## Concrete work completed

- Cloned and pinned stock ISO builder, Quattro runtime, release runtime, package recipes and the official Mac reference.
- Ran stock `omarchy-iso/test/all`: shell tests passed, including synthetic GPT partition-numbering/rollback checks; all 63 Python tests passed. This suite does not perform an ARM install or validate the real archinstall library against ARM hardware.
- Selected the exact v4.0.3 runtime commit named by the stock release PKGBUILDs for the package build baseline, separately from current quattro HEAD. Build-only dependency bypass is not installation/dependency validation.
- Built unmodified `omarchy` and `omarchy-settings` 4.0.3-1 aarch64 archives under `build/quattro-packages/`; checksums in `manifests/quattro-packages.sha256`. Package metadata confirms the ARM runtime dependency set has no Limine. Settings archive inspection confirms the x86 mkinitcpio/Limine/zram configuration paths are absent. Both are now installed in the ARM build container; neither is embedded in the console ISO.
- Installed the selected desktop set, including Herdr, from signature-verified repositories. Stock official ARM Hyprland 0.56.2 uses ABI 14, eliminating the custom ABI 13 requirement for the desktop image.
- Adapted stock setup/provisioning-state Node selection for ARM64. The ARM Node 26.8.2 binary executes in the container; the installer suite passes 65 Python tests plus shell tests, including rejection of an x64-only Node bundle on ARM.
- Existing bridge ISO has passed ARM UEFI virtual CD and USB console boot. It is still a console prototype, without this installer or Omarchy desktop embedded.

## Integration sequence

1. Build and inspect stock ARM runtime/settings packages, preserving their native ownership and upstream layout.
2. Resolve the ARM offline package set against signed packages. Add the matching kernel/firmware packages and the genuine Aquamarine ABI 13 compatibility package where required.
3. Adapt the existing configurator's kernel/boot intent and the orchestrator's boot finalization/validation. Keep its partition and user setup flows. Audit hibernation, deferred provisioning and reset, which also carry Limine assumptions.
4. Assemble the stock installer payload into the proven ARM live boot environment. Run installation only against disposable virtual disks until target layout and recovery are known.
5. Validate physical boot and desktop on the user's LCD, 32 GB T14s, followed by recovery, updates and power tests.

Full-disk destructive installation is not a substitute for verifying Ubuntu-preserving installation. No physical disk has been modified.
