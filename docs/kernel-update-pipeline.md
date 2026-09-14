# Ubuntu-derived kernel update pipeline — v0.2.0 work

The user designated **v0.2.0** as the first ISO version for this work. The local
installation candidate is now built at the repository root and copied to
`~/ISOs`; see [candidate notes](snapdragon-v0.2.0.md). The owner explicitly
requested building it without further VM validation. Its testing approval records
the deferred encrypted-candidate check; stable promotion and the full pipeline
objective remain incomplete. v0.1.2 remains the published baseline. Secure Boot
is disabled and out of scope. Historical progress entries below describe earlier
states and are superseded by the candidate notes where they differ.

The ASUS A16/X2 investigation is deferred to **v0.2.2** by user direction.
Finish this v0.2.0 update pipeline and build first, preserving ThinkPad, HP and
the existing hardware-untested A14 profile. See
[the A16 identification note](asus-a16-identification.md); X2 support is not a
v0.2.0 acceptance requirement or a promised v0.2.2 capability.

## Current physical follow-up

The owner confirmed a successful physical HP v0.2.0 installation and working
camera previews on HP and ThinkPad. The owner also reported that connecting to
Wi-Fi after installation allowed Omarchy's normal update flow to immediately
retrieve the available updated packages. This is user-reported physical evidence
for the ordinary ARM package-update path; no package inventory or new-kernel
activation was established by that report. Chromium camera access is deferred,
with permissions only a hypothesis. See [the maintainability overview](v0.2-maintainability.md).

The entries below are an implementation journal. References to pending image
assembly or running VM tests describe earlier states: the ISO is built, the VM
remains paused, and the release notes record the remaining validation limits.

## First workable release boundary

User direction: complete a usable v0.2.0 and address remaining edge cases in
follow-up work. The release path is one authenticated candidate, matching hardware
payloads, explicit maintainer promotion, signed pacman update, preparation and
reboot with a retained working fallback, then the integrated installer and HP
physical test. Different-ABI rollback and encrypted unlock remain essential
checks. All existing ThinkPad/HP fixes and the untested A14 profile must survive.

Automatic old-set pruning, legacy-package retirement, key-rotation automation,
broader upstream development-channel support and new hardware investigations
can follow the first release. Until implemented, retain old sets, use the
supported patched updater and document manual recovery and space requirements.
These deferrals do not establish completion of the full maintenance objective.
The candidate approval and normal update-to-reboot path still require integration;
an inactive test package alone is not the release deliverable.

## Latest integration evidence

The installed VM completed three actual boots: ABI30, ABI31, then ABI30 again.
The phase checks verified each running kernel against its retained entry and
matching private modules/firmware, and verified that the legacy kernel/initramfs
hashes remained unchanged. The host runner exited successfully with
`PASS: installed ABI30 -> ABI31 -> ABI30 boots with matching retained payloads and preserved legacy fallback`.
Evidence: `build/kernel-update-vm/abi-rollback-sequence.log` and the three
`abi-rollback-*-check.log` files. The final boot ID is
`56c42139-cfed-4bde-a133-5c56dc9dc68d`. This proves different-ABI rollback on the
unencrypted installed VM; approved-provider activation and encrypted boot still
require their own results. The encrypted baseline installation completed and
booted its virtual disk without the ISO. SSH confirmed kernel 31, an active
LUKS2 root on `/dev/vda2`, multi-user state, and zero failed systemd units.
Evidence: `build/kernel-encrypted-vm/baseline-boot-check.log`; boot ID
`ae9009fc-f26a-4f56-8cc8-10036d672247`. The graphical unlock prompt did not appear
in this generic VM; the test passphrase was accepted through the serial prompt.
This is baseline encrypted-root evidence, not a retained-candidate boot result
or validation of graphical unlock. The real signed-package upgrade and candidate
preparation test is now running on that encrypted installed system.

The v0.2.0 image base is staged in `build/snapdragon-v020/` directly from the
checksum-verified root v0.1.2 ISO. `scripts/stage-v020-installer.sh` verifies the
pinned ISO and embedded SquashFS checksums, extracts the filesystem and EFI
loader, and preserves the appended diagnostic partition. The extracted installer
matches the prior v0.1.2 source byte for byte, and the update patch applies with
zero fuzz. Evidence: `build/stage-v020-installer.log`. This is an unchanged base
ready for integration, not an assembled or validated v0.2.0 image.

`scripts/assemble-v020-installer.sh REPOSITORY_BUILD_NAME PINNED_FINGERPRINT`
is prepared to integrate a reviewed snapshot. It verifies the signed checksum
manifest against the externally supplied key, requires an approved provider and
matching repository trust configuration, adds the installer boot package, then
rebuilds SquashFS and the ISO using the extracted EFI/diagnostic partitions.
Testing images may use `file:///var/cache/oma-snap/repository`; the installer
copies that signed snapshot into the target before finalization. Stable images
require a release HTTPS mirror. The assembly command has passed a rejection test
against the ordinary unapproved VM repository (`build/v020-unapproved-image-rejection.log`)
and shell syntax checks, but has not yet completed an approved image build.

The testing ISO's trust package is built in
`build/kernel-repository-v020-iso-testing/`, using the existing local test signer
and `file:///var/cache/oma-snap/repository`. Its archive/public-key/mirror checks
pass in `build/kernel-repository-iso-testing-package-check.log`. This replaces
the VM-only `/var/tmp/...` mirror when assembling the hardware-test candidate.
It supplies an offline signed snapshot, not a published live update service.
Production key/endpoint deployment remains necessary before claiming automatic
network kernel updates; changing from this test configuration also requires a
versioned trust-package update and deliberate mirror transition.

The new [maintainer approval command](kernel-promotion.md) generates provider
package inputs from a reviewed decision bound to exact archive and evidence
hashes. Its rejection and generation tests pass. Tools revision 10 and the
Omarchy 4.0.3-1.9 source now connect completed preparation to explicit approved
provider activation, retaining the running boot as fallback and preserving manual
rollback on repeated calls. Source tests pass in `build/kernel-activation-tests.log`
and `build/quattro-kernel-activation-wait.log`. The tools package build and archive
checks passed in `build/kernel-tools-v020-activation/` and
`build/kernel-tools-activation-package-check.log`. The Omarchy 1.9 pair also built
and passed archive checks in `build/quattro-activation-package-check.log`.
Installed activation and production publication remain unproven, and no real
candidate has been approved through the generator.

The approval-gated repository assembler now signs a coordinated six-package
directory without uploading. Its synthetic integration test passes real GPG
signing, repository generation, checksum verification and rejection of changed
evidence (`build/kernel-promoted-repo-synthetic-test.log`). Those synthetic
archives are not installable release candidates. A separate ordinary local test
repository was signed from the real tools 10 and Omarchy 1.9 packages and copied
to the installed VM; all transferred checksums pass in
`build/kernel-update-vm/activation-repo-checksums.log`. Boot package 7 built
separately for the installer in `build/boot-v020-provider/`;
legacy retention intentionally excludes it from the normal update repository.

The boot installer source now detects an installed approved provider after
creating the released boot payload. It prepares the queued set directly in the
target chroot, checks completion and the approved entry identity, then migrates
the legacy menu and selects the provider with legacy fallback. It does not run
systemd or pretend the installation target is the running system. No-provider
installs retain their original path. Command-order/failure tests pass in
`build/kernel-provider-installer-tests.log`; actual chroot and ISO validation
remain pending. Boot package revision 7 carries this change. Its builder accepts
a new output name so this candidate can be built without overwriting the MVP
package directory or its checksum manifest.

`profiles/snapdragon/installer-kernel-update.patch` applies after the existing
v0.1.2 hardware patch. It adds the provider/tools/repository to bootstrap package
selection, explicitly stages the ISO's kernel channel into the target, and checks
the approved provider, selected entry, fallback and both boot-payload hashes in
the final validation phase. A test executes the actual patched validator against
temporary files and rejects approval/channel/menu/payload/identity failures:
`build/installer-kernel-update-tests.log`. The patch is prepared, not yet applied
to a built v0.2.0 ISO.

The installed VM passed real packaged repository refresh for stable, rc and edge
templates and the system package updater against signed local fixtures. Tools
revision 8 prevents empty preparation jobs from exhausting systemd's start limit;
the subsequent refresh run passed with unchanged boot configuration and mirror
customization. Evidence: `build/kernel-update-vm/deployed-refresh-retry.log` and
`queue-recovered-runtime-audit.log`. This does not validate upstream development
packages or a public repository endpoint.

The authenticated ABI30 payload completed signed installation, queued preparation
and publication without changing the installed provider or original boot menu
(`build/kernel-update-vm/abi30-install-prepare.log`, exit zero). Its published entry
is `0266e70173c0dd4375af468cbc1252bd087335212ab44e222da70b32ab6ec2e6`;
the completed job is saved in `build/kernel-update-vm/abi30-complete.json`.
The installed tools 10 / Omarchy 1.9 signed transaction and packaged preparation/
activation helper passed without selecting the unapproved provider; GRUB stayed
byte-identical (`build/kernel-update-vm/activation-stack-install.log`, exit zero).
`scripts/test-installed-abi-rollback.sh` is now running the
ABI30 → ABI31 → ABI30 boot test. It requires a new boot ID and active multi-user
target before each guest identity/payload check, and never restarts QEMU on a
timeout. Evidence accumulates in `build/kernel-update-vm/abi-rollback-*`.
A separate encrypted baseline install is
also running. Neither boot sequence is yet a pass. The phase-based guest harness is
`tests/kernel-abi-rollback-installed.sh`; it checks exact boot identities, private
read-only module/firmware mounts and preserved legacy payload hashes. It never
reboots the guest itself. The installed-VM launcher accepts `OMA_SNAP_VM_NAME`
so the encrypted guest can boot independently of the existing update guest.

## Earlier integration checkpoint

The full installed ARM VM has completed signed provider installation and queued
preparation of audio-inclusive set `66fd1aea…`, publishing entry
`71dd9d71ce879091e5d4fd4764918e6f0a4f6566687e77e31438339c8e8742ba`.
Initramfs payload checks pass for all three profiles' cDSP pairs, HP audio
topology, encryption/runtime hooks and early display modules. Signed tools
revision 6 installed and explicit GRUB migration retained the released boot as
default. A subsequent reboot through that migrated legacy menu passed: new
boot ID, active multi-user target, no retained-set runtime mounts, and unchanged
legacy kernel/initramfs hashes. Evidence is under `build/kernel-update-vm/`:
`audio-provider-complete.log`, `audio-provider-initramfs-check.log`,
`install-migration-tools.log`, and `migrated-legacy-boot-check.log`.

The installed VM completed the released → retained candidate → released boot
sequence. Candidate boot verified the exact entry/set identities and read-only
module/firmware mounts backed by the selected private set (device/inode checks).
The display manager was active and no systemd units had failed. Rollback boot
ID `4b567319-bdc3-4c24-9905-d6185c3387e4` differs from the candidate boot and
passed the original-payload hash checks with no retained runtime mounts.
Evidence: `candidate-boot-check.log`, `candidate-runtime-audit.log`,
`rollback-selection.log`, and `rollback-boot-check.log` in that same directory.
This is same-release, unencrypted-root evidence; encrypted-root and different-ABI
upgrade/rollback remain unproven.

The signed tools revision 7 and Omarchy 4.0.3-1.5 pair passed a real
pacman upgrade in that installed VM (`install-updater-stack.log`, exit zero).
The installed preparation helper succeeded, reboot status was `current`, GRUB
configuration remained byte-identical and the transaction lock was released.
This used an isolated signed local repository; it does not validate network
repository refresh. Queries emitted missing core/extra/alarm/omarchy database
warnings because this fixture synchronizes only its isolated local repository.

Source patch 0007 additionally makes `omarchy-refresh-pacman` fail on copy,
customization-hook or transaction errors and wait for kernel preparation before
returning to channel switching. The actual script passes isolated command tests
for success and each failure boundary (`build/quattro-refresh-kernel-wait.log`).
Profile checks pass (`build/quattro-refresh-profile.log`). The next Omarchy pair
revision 1.6 distinguishes this additional change. Its build and archive checks
passed in `build/quattro-v020-refresh/` and
`build/quattro-refresh-package-check.log`; it has not been installed. Repository configuration and channel compatibility remain open.
Historical checkpoints below record earlier partial results and limitations.

## Proposed installed repository profile

`profiles/snapdragon/pacman-update.conf` is the v0.2.0 deployment profile under
construction, separate from the published MVP profile. It places `[oma-snap]`
first and requires trusted signatures on both its database and packages. Its
mirrorlist is supplied separately at `/etc/pacman.d/oma-snap-mirrorlist`; the
release must install that file and its verified trust anchor before activating
this configuration. No placeholder network endpoint or production key is implied.

The profile removes the MVP holds on `omarchy` and `omarchy-settings` so the
coordinated pair can update from the Snapdragon repository. It keeps the three
Hyprland package holds, and upstream `[omarchy]` remains available for explicit
installs and searches without automatic upgrades. Keeping the patched pair
available in the first repository is a release requirement. Switching to upstream
`omarchy-dev` is not yet a supported substitute for the patched updater.

`tests/kernel-update-pacman-config.sh` exercises the actual pacman configuration
parser with isolated mirrorlists: repository order, upgrade usage, signature
policy, exact holds, and rejection of a missing Snapdragon mirrorlist all pass
(`build/kernel-update-pacman-config.log`). The next pair, revision 1.7, now builds from its own source snapshot with this
profile copied into all three packaged refresh templates. Its runtime dependency
requires `oma-snap-repository>=0.2.0-1`. The build and archive checks passed in
`build/quattro-v020-repository/` and `build/kernel-repository-refresh-fixture.log`;
the pair is not installed yet. Refresh persistence, real package
resolution and promotion remain required before activation; parser checks alone
do not prove the deployed update path.

## Repository trust package

`packages/kernel-repository/` and `scripts/build-kernel-repository-package.sh`
produce `oma-snap-repository` from an explicitly supplied primary fingerprint,
key bundle and literal HTTPS mirror URL. `--local-test` also permits a local
file URL, with that mode recorded in packaged metadata. The builder exports only
the pinned public key and rejects expired, revoked, disabled, future-dated or
non-signing primaries. It does not generate a production key, promote a kernel
or publish a repository. An existing trusted signer must authenticate package
upgrades; initial ISO bootstrap must pin the expected fingerprint independently.

The package uses pacman's standard keyring files and populate scriptlet, with
backup protection for the mirrorlist. Archive checks verify root ownership,
exact expected fingerprint/mirror/mode, absence of secret keys, install script
and backup declaration. The local test package passed those checks, and a
network-disabled disposable ARM container installed it through a separately
bootstrapped trusted keyring. Its scriptlet populated a fresh system keyring;
that keyring then accepted the signed repository and package. Reinstalling
preserved local mirror edits and released the transaction lock. Evidence:
`build/kernel-repository-v020-package-check.log`,
`build/kernel-repository-v020-signing.log`, and
`build/kernel-repository-install-test.log` (all successful).

The first cross-directory rebuild differed only in makepkg's `.BUILDINFO`
paths and the corresponding `.MTREE`. The builder now uses an exclusive fixed
staging directory and cleans it on exit. Two subsequent builds in
`build/kernel-repository-v020-fixed-{b,c}` are byte-identical and both pass
archive checks (`build/kernel-repository-v020-fixed-check.log` and
`build/kernel-repository-v020-reproducibility.log`). The local test key remains a
30-day test key; production trust selection, rotation and revocation procedures
remain open. None of these test packages is a public release.

## Deployed refresh and encrypted-root test work

`tests/kernel-repository-refresh-fixture.sh` assembles the signed local deployment
fixture from the checked 1.7 Omarchy pair, tools 7 and the repository package.
`tests/kernel-repository-refresh-installed.sh` is restricted to the installed
ARM QEMU guest. It installs through the already pinned bootstrap keyring, then
uses the actual packaged refresh command for stable/rc/edge and the actual
system-package updater. The supported user hook redirects only upstream mirrors
to empty local databases; the installed Snapdragon mirror include and signature
policy are checked unchanged. This tests deployed templates, not the separate
`omarchy-channel-set` package replacements or upstream network availability.
The 1.7 pair and deployment repository package passed archive checks, and the
local deployment fixture is signed and verified
(`build/kernel-repository-refresh-fixture.log`). Transfer checksums passed. The
installed test upgraded to Omarchy/settings 1.7 and populated normal system trust.
Stable and rc refresh checks passed, but edge's final preparation wait failed:
the service's three-start/60-second limiter also counted successful empty-queue
waits. Evidence: `build/kernel-update-vm/deployed-refresh-test.log` and
`refresh-start-limit.log`. This exposed a real normal-update failure; the overall
refresh test did not pass.

Tools revision 8 adds OR conditions for nonempty pending/running job directories.
The service keeps its start limiter, but empty waits no longer launch a worker.
An actual systemd test made eight idle calls, independently exercised pending and
interrupted work, then made eight more idle calls; all passed and the temporary
test unit was cleaned up (`build/kernel-update-vm/queue-idle-systemd.log`). The
revision 8 package built and passed archive checks. Its signed replacement fixture
is transferring to the VM under a new directory; the original failure evidence
and repository are retained. The refresh harness supports `resume` to retry
against the original saved configuration/hash evidence after upgrading tools.

The revision 8 fixture subsequently passed transfer checksums and the full
installed refresh retry (`build/kernel-update-vm/deployed-refresh-retry.log`,
exit zero): stable, rc, edge, then the real system-package updater. Signature
policy and mirror customization persisted, the transaction lock was released,
and GRUB matched its original saved hash. This uses local empty upstream
repositories and does not establish compatibility with upstream dev packages.

The runtime audit then found the path watcher still failed from the earlier
revision 7 rate-limit test. Resetting that known test-induced failure restored
watching. An intentionally absent hardware set was automatically processed into
a durable failed job; the watcher stayed active, the installed provider remained
prepared and GRUB stayed unchanged. Evidence:
`build/kernel-update-vm/queue-watcher-recovery-retry.log`. The first recovery
fixture assertion treated an omitted optional JSON field as an empty string;
that assertion was corrected and the test reran with a new missing-set identity.
No failed job records or original failure logs were deleted.

The next Omarchy pair is revision 1.8, requiring tools >=0.2.0-8 so fresh
installations cannot resolve to the earlier worker implementation. Its build and archive checks passed
in `build/quattro-v020-queue-conditions/` and
`build/quattro-queue-conditions-package-check.log`; it is not yet installed. The package checker
now accepts explicit expected version/dependency arguments for inspecting earlier
fixtures, with the new pair as its default expectation.

The stock `omarchy-hook` reports individual user-hook errors and continues; the
refresh shell's error handling does not change that stock behavior.

A separate encrypted-root installer VM is now running from the checksum-verified
v0.1.2 baseline. `OMA_SNAP_VM_ENCRYPT=1` extends the existing upstream cidata
fixture with its actual LUKS configuration format and a public disposable-VM
passphrase (`omarchy-vm-only`). Readback of the FAT seed configuration is
byte-identical to the generated JSON and selects exactly the Btrfs partition.
VM: `oma-snap-encrypted-install-test`, SSH port 2342, disk/evidence directory
`build/kernel-encrypted-vm/`, orchestrator log
`build/kernel-encrypted-install-vm.log`. This is not a v0.2.0 ISO and encrypted
installation/upgrade/rollback results are not yet claimed. Live SSH access is
working after unmasking sshd in this disposable installer only. The installer
has created LUKS and mounted Btrfs inside `/dev/mapper/root` at `/mnt`, and is
installing packages (`build/kernel-encrypted-vm/install-progress-1.log`).

## Different-ABI rollback fixture

The authenticated Ubuntu indexes also contain ABI 30. To test a real ABI change,
`scripts/prepare-rollback-candidate.sh NEW_NAME 7.0.0-30-generic` writes a separate
external test policy; the normal track file is unchanged. `rollback_test_release`
requires an older image than the latest signed meta-package resolution, seeds the
matching image/header closure and checks matching modules/common headers. Such
candidates have status `rollback-test`, not `unvalidated`. Verification requires
the same external policy and status, so editing candidate metadata alone cannot
select or relabel an older kernel under the normal policy. This is test input,
not a candidate for automatic release promotion.

All candidate tests passed in the network-disabled builder, including normal
latest selection, older test selection, invalid/missing/mismatched payloads,
conflicting signed-pocket records and external-policy/status rejection
(`build/kernel-candidate-baseline-tests.log`). The updated verifier still accepts
the saved normal ABI 31 candidate (`build/kernel-normal-policy-regression.log`).

`build/kernel-candidates/ubuntu-abi30-rollback-v020/` downloaded five artifacts
for `7.0.0-30-generic` and passed a separate network-disabled re-verification
(`build/kernel-rollback-candidate-abi30.log`). Its policy is
`build/kernel-rollback-policies/ubuntu-abi30-rollback-v020.json`.
`prepare-kernel-set.sh` now accepts an explicit third policy argument, defaulting
to the unchanged normal track. Authenticated extraction passed in
`build/kernel-abi30-extract.log`, and all three HP camera modules rebuilt for ABI 30
(`build/kernel-abi30-camera.log`). GCC/pahole differences and skipped BTF remain
recorded in that log. The five pinned firmware/audio inputs assembled and passed
inventory verification as hardware set
`4f9f71d26d9a93760cd0a4315d5e7656903ef00377b6b17912f4c168b125849d`
(`build/kernel-abi30-hardware-prepare.log`). Its provenance retains the
`rollback-test` candidate status. `scripts/build-hardware-package.sh` now provides
a fixed-path makepkg wrapper. The ABI 30 archive built successfully and passed
installed-payload/inventory and root-ownership checks
(`build/kernel-abi30-hardware-package.log`, `build/kernel-abi30-package-check.log`,
`build/kernel-abi30-package-ownership.log`). The permanent package check now also
requires root ownership.
Different-ABI boot/rollback and hardware compatibility are not yet proven.

## Retained pair with original recovery

The selector previously rejected a retained A/B pair after legacy migration.
It now recognizes the migrated layout, verifies the legacy snapshot and payloads,
and preserves its recovery menu entry alongside both selected retained entries.
The command-line path also checks the legacy package dependencies and effective
retention hook before this transition. It keeps the legacy tracking marker, so
explicit selection back to the original boot remains available. It does not
retire the original packages or automatically activate a candidate.

A/B/A selection with all three entries, corruption preserving the prior menu,
and existing boot-publisher tests pass with the race detector
(`build/boot-publish-legacy-pair-tests.log`). Actual generated three-entry and
migration menus pass ARM GRUB's syntax checker
(`build/boot-publish-legacy-pair-grub.log`). Tools revision 9 built and passed
package checks (`build/kernel-tools-legacy-pair-{build,check}.log`). Its local repository with the ABI 30 payload is signed and transferred
(`build/kernel-abi30-repo-signing.log`). The installed VM has 27 GiB free on
root and 1.2 GiB on the ESP. The guarded continuation verifies transferred
checksums, installs tools 9 and the test set through real signed pacman, then
waits for automatic preparation without changing the provider or boot selection.
Script: `tests/kernel-abi30-install.sh`; logs:
`build/kernel-update-vm/abi30-repository-checksums.log` and
`abi30-install-prepare.log`. This continuation is running; three-entry boot and
different-ABI rollback remain to be tested.

## Objective and delivery model

Follow the hardware-kernel-provider model used by Omarchy Mac: Ubuntu maintains
our selected Snapdragon-capable ARM64 kernel, while this project owns verified
conversion to pacman packages, boot integration, model-specific additions,
validation and promotion. Do not run apt/dpkg package installation against an
Arch target. Binary extraction is a build operation, without Debian maintainer
scripts. Retain the wrapped Ubuntu/Stubble image unchanged.

The final path is authenticated candidate discovery → matched kernel/modules/
headers → reproducible Arch packages and rebuilt HP camera modules → isolated
boot staging → candidate tests → explicit promotion into a signed pacman
repository. Users receive tested coordinated updates through ordinary package
management. A previous bootable kernel, modules, firmware availability and
initramfs must survive updates and failed candidate boots. Both the installed
update path and future ISO builds must use the same selected package set.

## Candidate discovery

`profiles/snapdragon/kernel-track.json` selects Ubuntu Resolute, generic ARM64,
the archive URL, the trusted Ubuntu archive signing key and metadata freshness.
The command reads release, updates and security pockets to resolve dependencies.
It intentionally excludes proposed/backports and does not change distro releases.
The selected Ubuntu release/support policy remains a maintainer responsibility.

```bash
docker build -t oma-snap-candidate-builder:local - < containers/Dockerfile.builder
bash scripts/discover-kernel-candidate.sh NEW_CANDIDATE_NAME --download
```

The wrapper builds a small Go command and runs it in a separate x86 build
container with Ubuntu's archive keyring, gpgv, dpkg and xz. Only the candidate
output directory is writable. No daemon or recurring target-side poll is added.

It verifies InRelease with the configured primary signing fingerprint, archive
identity, metadata date/expiry, index SHA-256/size and downloaded package
SHA-256/size. Debian package version ordering selects the newest meta-package.
The resolver follows the kernel image/module/header dependency subset, including
unversioned ABI-named dependencies, and refuses mismatched image/module/header
versions, missing payloads, ambiguous dependencies or conflicting pocket hashes.
Debian userspace dependencies are recorded, not installed. They need explicit
Arch build/runtime mapping during packaging.

A successful run writes `build/kernel-candidates/NAME/candidate.json`, with
metadata provenance and selected artifacts. Its status is **unvalidated**.
Discovery does not establish hardware compatibility, authorize promotion, modify
boot files, or install packages. Failed/incomplete runs leave no success manifest
and must be inspected; output directories are never silently reused.

## Remaining implementation and acceptance work

- Integrate the findings and VM cases in [the Omarchy updater audit](omarchy-update-compatibility.md), including channel refresh, package replacements, orphan retention and boot-set-aware reboot detection.
- Generalize kernel packaging and header build inputs from the candidate manifest.
- Rebuild/verify HP camera modules for the selected ABI; prevent incompatible
  kernel and camera package combinations.
- Remove hardcoded firmware/kernel-release paths from update-time boot assembly.
- Implement recoverable side-by-side boot sets and failure-safe boot selection;
  preserve the previous modules as well as ESP files across pacman upgrades.
- Test interrupted staging, bad candidates, successful activation and rollback
  in disposable ARM VMs; then validate on the ThinkPad and HP without sacrificing
  the working boot entry. ASUS remains hardware-untested.
- Establish repository signing, candidate evidence, promotion and retention.
- Integrate the tested release set into v0.2.0 ISO generation and verify that an
  installed machine can follow the same repository update path.

## Retained hardware-package prototype

```bash
bash scripts/prepare-hardware-package.sh SET_NAME NEW_PACKAGE_NAME
```

This packages the verified build outputs into a content-addressed hardware
payload. It preserves Ubuntu's image byte-for-byte, includes matching modules
and all three rebuilt HP camera modules, and snapshots the existing firmware
packages for ThinkPad, HP and ASUS. The wrapper verifies the four firmware
archive hashes against tracked manifests before extraction and retains their
metadata, licenses and provenance. These are local testing inputs; hash
verification does not establish permission to redistribute vendor firmware.

`tools/kernel-set` inventories file bytes, modes and symlink targets, rejects
links escaping the payload, and derives a SHA-256 set identity. It emits an
unvalidated manifest and PKGBUILD. Each set has a distinct package name
`oma-snap-set-<identity>` and owns only `/usr/lib/oma-snap/sets/<identity>/`.
Consequently, even revisions sharing `uname -r` can coexist without overwriting
one another. The generated package does not select a kernel, install a boot
entry, enable a service, or alter the active modules/firmware namespace.

The assembly directory can be checked with `build/kernel-set --verify DIR`.
This checks integrity against the recorded identity, not authenticity of an
arbitrary caller-supplied manifest. Use the authenticated extraction/camera
build chain first; signing and promotion still need implementation.

The first ARM package built successfully in `build/kernel-sets/package-v020`.
Its identity is
`f11880c98140483db428b502d9ce796bc80c2abf4284c5bbc8a943a35e423a9a`.
Re-extracting pinned firmware archives into separate directories produced the
same identity. `tests/kernel-set-package.sh` unpacked the package, checked its
complete inventory and verified that it owns no live boot, module or config
paths (`build/kernel-set-package-test.log`). This proves payload preservation,
not a working update or fallback boot.

Two completed makepkg runs produced byte-identical archives (SHA-256
`762b368103121aa0e1d74dc5b97858c4410a7b7dc3089495d52acf4662d88a64`).
Both used the same ARM container, assembly path, `SOURCE_DATE_EPOCH=1785542400`,
`LC_ALL=C` and `TZ=UTC`. Evidence: `build/kernel-set-package-repro.sha256`.
This is repeat-build evidence in one toolchain; makepkg records build/start
directories in BUILDINFO, so cross-directory archive reproducibility requires
a standardized build path. The earlier camera-module comparison did use
different source/header build paths.

The original prototype above retained firmware only in its package layout.
The next assembly now also merges those snapshots into
`firmware/<selected-kernel-release>/`, using hard links for regular files and
preserving relative symlinks. Differing files at the same destination fail
assembly; identical collisions are accepted. Original package metadata and
provenance remain in the payload. No package ordering silently overrides a
model's firmware.

The new assembly runs depmod only against its private `modules/` tree, after
adding HP modules. Diagnostics or missing indexes fail assembly. Isolated
`modprobe --show-depends` checks pass for MSM, both panel drivers, HP's USB-C
mux, ath12k, FastRPC and all three HP camera modules. OV05C10 resolves to our
updated driver. Required cDSP pairs exist for all three model namespaces.
Evidence: `build/kernel-set-lookup.log`; no module was inserted on the host.

Two assemblies using the independently built camera outputs produced identical
manifests with identity
`cc69bc2a9d34983c4d679f9d4495bb7ad27394b63d32b808883edba54d27754c`.
Unit tests cover conflicting firmware, directory symlink substitution and
mapping an old firmware namespace to a different selected release.
The normalized ARM package also built and passed full archive inventory and
private-path checks (`build/kernel-set-normalized-package-test.log`).

The Qualcomm initramfs hook now uses mkinitcpio's `KERNELVERSION` and fails on
a missing firmware namespace. Its baseline/missing/unset-version checks pass
inside the ARM builder (`build/kernel-firmware-hook-test.log`). Boot assembly
must still expose the selected private firmware tree to that hook, build
initramfs and select matching modules at runtime. Package retention, transaction
guards, reboot detection, signing and VM boot/rollback tests remain open.

## Early-boot selection prototype

`profiles/snapdragon/initcpio/{install,hooks}/oma_snap_set` embeds a three-line
hardware set ID/kernel release/boot entry ID file in initramfs. After mounting root, it validates the
identity and mountpoints, then bind-mounts the selected private modules and
firmware over the matching public release directories, remounting both
read-only. It records the booted hardware ID in `/run/oma-snap/booted-set` and
the individual initramfs build in `/run/oma-snap/booted-entry`, so a later
reboot check can distinguish initramfs-only changes at the same hardware ID. The root
mountpoints must be prepared by boot staging; the hook does not require writing
to the root filesystem. Failure enters recovery instead of continuing with a
different tree.

The hook is not yet included in an installed boot image. Its real mount
behavior was tested inside a disposable container with a private mount namespace
and SYS_ADMIN capability: A/B/A selection at one `uname -r` exposes the correct
fixture files, preserves the underlying legacy directories, and rejects writes.
Wrong release, extra identity data, missing mountpoints and symlink substitution
are rejected before mounting. Evidence: `build/kernel-set-runtime-test.log`.
ARM initramfs BusyBox ash also accepts its syntax. This does not yet prove
switch_root, systemd integration or boot rollback; those require VM boots.

`tools/kernel-set --verify-installed DIR` verifies an extracted/installed package
directly in its private layout. The top-level manifest must be a regular file;
all other contents, including provenance and firmware, must match its inventory.
The archive test now exercises this path as well as the assembly layout.

`tools/boot-stage` is the next integration prototype. As root on ARM64, it
verifies an installed hardware set, locks staging, records a unique boot-entry
ID and invokes mkinitcpio in a private mount namespace with the retained modules
and firmware mounted read-only. It appends the retained-set hook to the installed
Snapdragon initramfs configuration. Completed builds get `built.json` with image
hashes; failed work directories remain for inspection. It does not write the ESP
or select a boot default. It compiles, passes Go vet and has now completed an
isolated ARM initramfs build and a component VM boot. Boot-entry publication,
full installed-system integration and rollback are still pending.

## Current VM and build-infrastructure evidence

The disposable update baseline is installing the verified v0.1.2 ISO into a
new 40 GiB virtual disk under `build/kernel-update-vm`. Its QEMU container is
`oma-snap-kernel-update-baseline`; SSH is forwarded only to localhost:2340.
The installer has progressed through target formatting and base-package
installation. A native ARM `unshare --mount --propagation private true` check
passed in this VM. Wait for installation to finish before running staging
against its installed userspace.

Later progress: the installer completed all base/Omarchy package installation
and Omarchy setup, then entered boot initramfs generation. Root SSH for this
disposable target was prepared using the generated VM fixture key, and its new
host key is pinned in `build/kernel-update-vm/installed-known_hosts` for the
post-install boot. These are test-fixture changes, not laptop changes.
An additional `arch-chroot` used while preparing SSH reported a busy `/mnt/dev`
on cleanup and left a second bind there. The original `/mnt/proc`, `/mnt/sys`,
`/mnt/run` and `/mnt/dev` mounts remain, and the original initramfs shell was
confirmed running. Do not remove mounts while it is active; verify the
installer's final cleanup. Use `systemctl --root=/mnt` for future offline service
enablement instead of starting another overlapping `arch-chroot`.

The installer subsequently completed boot finalization and user provisioning,
then rebooted. The launcher exited zero; serial shutdown evidence reports all
filesystems and loop/DM devices detached. The additional test bind did not remain
as a final shutdown blocker. The installed disk is now booting without ISO/seed
media via `scripts/test-installed-vm.sh`, with serial evidence in
`build/kernel-update-vm/installed-serial.log`. Installed-system validation is
not yet complete.

An attempted `docker commit` of the existing ARM builder failed while applying
a diff: fs-verity rejected a containerd content blob. No new builder image was
created. The host Btrfs corruption counter was already 183318 on September 12
and remained unchanged after the failure; read/write/flush error counters were
zero. This does not establish a drive failure or identify the root cause of the
new blob error. Git fsck and a full re-verification of the normalized hardware
payload passed afterward. The failed snapshot is not a trusted build input.

The existing emulated builder's exec configuration also rejected mount-namespace
creation, whereas the native ARM VM accepted it. VM boot tests remain required.
No integrity check was disabled, host filesystem repair attempted, or
physical laptop changed to work around the builder failure.

Follow-up: a fresh container from the existing `oma-snap-arch-base:local` image
successfully runs staging with SYS_ADMIN, an unconfined container seccomp profile
and a private mount namespace. This avoids committing/importing another image.
It has no network and receives only read-only payload, tools, hooks and offline
packages, plus a writable staging-output directory. Its package keyring was
initialized and populated with Arch Linux ARM keys; Plymouth and dependencies
installed with required signatures using
`profiles/snapdragon/pacman-stage-builder.conf`. The first staging run completed
in the isolated worker. `tests/kernel-stage-artifact.sh` extracted the image and
confirmed the exact three-line identity, executable retained-set/encryption
hooks, all three model cDSP pairs, MSM, both panel modules and the HP USB-C mux.
Parent-namespace mounts remained unchanged. Evidence:
`build/kernel-stage-build.log` and `build/kernel-stage-artifact-test.log`.

The resulting boot entry is
`458d584cfc067d5c4f657823c54394f11a147c708d42e42b0defbe0cc5298f20`.
Initramfs SHA-256:
`dba10710924899b4ca54895f6bb2d54ccc148a54838eabcad808a7ea286d7298`.
Wrapped-kernel SHA-256:
`8e67dc8d70becb2305d66b132cbcb8f058691ef82513ba949a66a0f33002d3fa`.
Copies prepared for the component VM match both hashes. The builder's default
Plymouth theme was used; this is not yet a check of the installed Omarchy theme.

The ordinary parent container sees no retained module/firmware bind mounts while
the worker is building. mkinitcpio's missing-image warning is expected with this
private layout: its generic `kver` probe also cannot parse the Stubble wrapper.
Staging supplies the authenticated release explicitly, leaves the wrapped image
unchanged and records its hash; bootloader post-hooks are disabled with `--nopost`.
Do not infer successful boot from initramfs generation alone.

The component VM subsequently booted that exact kernel/initramfs through ARM
UEFI and GRUB, mounted an ext4 root and executed its test PID 1. It checked the
kernel release and both identity records, verified that the ordinary root was
writable while the retained module/firmware mounts rejected writes, and found
the module indexes and all three models' cDSP firmware. Its serial log contains
`OMA_SET_BOOT_PASS` with both expected identities, followed by power-down;
QEMU exited successfully. Evidence: `build/kernel-set-boot-vm/serial.log`.

The first attempt failed because the minimal fixture omitted BusyBox's dynamic
loader. The fixture now includes its ARM loader, libc and libcrypt and checks
execution in a chroot before booting. Initramfs already transfers `/proc` to the
real root; the fixture checks that mount instead of invoking an unavailable
BusyBox mount applet. This component root is unencrypted, so the configured
encrypt hook reports that SETROOT is not LUKS before continuing. This does not
validate encryption, Plymouth branding, systemd or update/rollback.

`scripts/prepare-kernel-set-boot-vm.sh CONTAINER STAGING_DIRECTORY NEW_NAME`
reconstructs the fixture from a verified private hardware set and checks staged
image hashes and the three-line identity. Then run
`bash scripts/test-kernel-set-boot-vm.sh NEW_NAME`. The launcher refuses an
existing serial log and checks the exact expected identity in the PASS marker,
so an old success cannot satisfy a new run. Fixture preparation never writes
a physical disk or changes a laptop's boot entries.

## Signed local repository fixture

`scripts/build-local-kernel-repo.sh NEW_NAME KEY_HOME FINGERPRINT PACKAGE...`
copies explicitly supplied packages into a new local directory, signs each
unchanged archive, creates a signed pacman database with embedded package
signatures, verifies the signatures using an exported public keyring, and
records package/database checksums. This is a test-repository builder, not a
promotion command or a publisher.

The first fixture at `build/kernel-repo-v020-test` contains the tools package
and retained hardware set `cc69bc2a9d34983c4d679f9d4495bb7ad27394b63d32b808883edba54d27754c`.
Its isolated 30-day signing key is explicitly named LOCAL TEST ONLY, with
fingerprint `6B516CB2E4C718688CB66A111E22DE33B6C29CF5`. Private key material stays
under the ignored `private/kernel-repo-test-gnupg` directory; it is not an ISO or
production repository trust anchor. The user's ordinary keyring was not changed.
Signing does not establish vendor firmware redistribution rights or hardware
compatibility, and no fixture has been uploaded.

`tests/kernel-repo-pacman.sh` passed in a network-disabled ARM userspace container
with a fresh isolated pacman keyring, explicitly pinned/imported/local-signed
test key, and `PackageRequired DatabaseRequired TrustedOnly` policy:

- Both signed packages download, pass pacman's integrity checks and match the
  exact source archive bytes.
- Changing signed database bytes makes database synchronization fail.
- Changing package bytes without changing its size is rejected under the valid
  signed database.
- A separately signed, valid database referring to an unsigned package cannot
  authorize that package; pacman refuses the missing `.sig`.

The first corrupt-package fixture increased file size and was correctly rejected
by the downloader's size limit; it was refined to test same-size corruption.
An assertion was also corrected to recognize pacman's missing `.sig` filename
error. The complete final test exits zero with all four PASS markers in
`build/kernel-repo-pacman-final-test.log`. Producer verification is recorded in
`build/kernel-repo-signing-test.log`. Test keyrings and caches remain isolated
under `build/`; these are package/signature tests, not hardware validation.

Production signing-key policy, authenticated promotion evidence, retention and
the installed system's repository/update integration remain unfinished.

## Packaged update tools

`bash scripts/build-kernel-tools-package.sh NEW_BUILD_NAME` now builds
`oma-snap-kernel-tools-0.2.0-1-aarch64.pkg.tar.xz`. It contains the installed-set
verifier, staging/publication tools, retention guard, persistent preparation
queue, ALPM hooks and systemd units. Its `/etc/oma-snap/esp-path` is a pacman
backup file, defaulting to `/boot`; alternate supported ESP mounts must be set
explicitly. Initial installation enables the path unit and requests a nonblocking
start (systemctl ignores live starts inside an installation chroot).

Update-time mkinitcpio configuration is owned at
`/usr/share/oma-snap/kernel-update/mkinitcpio.conf`, with a separately named
`oma_snap_qcom_update` build hook. This preserves the legacy boot package's files
and command while carrying the dynamic firmware namespace into future kernel
updates. The configuration retains the same modules, encryption and Plymouth
hooks. Staging now reads this new package-owned path; standalone builder fixtures
must install it before another full staging run.

Archive checks pass for the ARM executable bytes, scoped configuration/hooks,
systemd units and preserved configuration path. No payload-file ownership
overlaps the legacy `oma-snap-boot-0.1.0-6` archive. Two independent assembly
directories produced byte-identical archives by using a fixed makepkg working
directory and SOURCE_DATE_EPOCH. Go binaries use trimpath, no VCS build stamp,
disabled CGO and an empty build ID. Toolchain evidence is in
`build/kernel-tools-toolchain.txt`; the local Go version reports
`go1.27.0-X:nodwarf5`. This is reproducibility under that same toolchain/builder,
not a cross-toolchain claim.

Canonical artifact: `build/kernel-tools-v020-canonical/`.
SHA-256: `0b435b0abbafb5175c51144e13124ed69f72f1251d3218e54b6e7fb7d95803d7`.
Evidence: `build/kernel-tools-package-test.log` and both canonical/reproduction
build logs. Package installation and successful queued preparation on the
installed VM remain pending. This local unsigned test artifact has not been
promoted, published or installed on either laptop.

Installed-VM follow-up: the baseline installation completed and rebooted from
its target disk without the ISO. SSH confirms `7.0.0-31-generic`, a running
systemd system, Btrfs root and a 2 GiB FAT ESP. The signed local repository was
copied to the guest and every archive/signature/database checksum verified.
Installation is in progress using an isolated test keyring pinned to fingerprint
`6B516CB2E4C718688CB66A111E22DE33B6C29CF5` and a separate pacman configuration
requiring trusted signatures for both database and packages. Normal guest
repository configuration is unchanged. Evidence/script:
`build/kernel-update-vm/install-signed-candidate{,-2.log,.sh}` (the first attempt
stopped before package changes because its GRUB baseline path was wrong;
attempt 2 uses `/boot/oma-snap/grub/grub.cfg`). Neither package installation nor
successful queued publication is claimed complete at this checkpoint.

That real installation exposed a defect missed by archive-only verification:
pacman skips the nested source firmware packages' `.MTREE` files as absent from
its package file list. The candidate's content inventory includes those files,
so this payload cannot be accepted as a successfully installed retained set.
`tools/kernel-set` now preserves the five reserved package metadata basenames
under each source package's `package-metadata/` directory with ordinary names.
Metadata bytes remain unchanged, and source directories are untouched; a
preexisting destination or non-regular metadata is rejected. Race-enabled Go
tests pass. Reassembly and inventory verification passed for new set
`72bed4bc76d90fe42d2d6eac114e4cb862e2ffa7c35bfad844a4b20257d33303`
in `build/kernel-sets/package-v020-metadata`. Its wrapped kernel is byte-identical
to the previous candidate (SHA-256
`8e67dc8d70becb2305d66b132cbcb8f058691ef82513ba949a66a0f33002d3fa`).
Package rebuild is underway; signature, actual pacman extraction and queued
preparation must be rerun against the corrected artifact before acceptance.

The corrected package build has completed: archive SHA-256
`dba854dc79721062f7eaf687c4557733e759b3563abb37afe62b03e2445c156f`.
Updated tools `0.2.0-2` add explicit completed-job refresh and the metadata fix;
archive SHA-256
`883a2d4e421e9fd0964bb7a67d997eddc5971d86db97f287dbbc4aff7e691ee3`.
Tools archive checks pass (`build/kernel-tools-refresh-package-test.log`). Both
archives are signed in `build/kernel-repo-v020-metadata-test`, with independently
verified package/database signatures (`build/kernel-repo-metadata-signing.log`).
The corrected repository is transferring to the VM; actual installation and
successful preparation remain pending.

The first, defective candidate's installation has now completed. Its signatures
were accepted, its package hook queued preparation, the systemd path unit
started the worker, and the existing GRUB file's checksum stayed unchanged.
The worker was observed verifying the installed inventory; a successful package
transaction does not imply that this defective candidate is bootable. Evidence:
`build/kernel-update-vm/install-signed-candidate-2.log` and
`build/kernel-update-vm/first-queued-result.log`.

The first candidate's queued preparation subsequently failed with
`payload inventory changed`, as expected from the omitted metadata files. The
worker recorded a terminal failed job; evidence is
`build/kernel-update-vm/first-queued-result-3.log`. This validates automatic
activation and rejection of the defective installed payload, not successful
staging/publication. The corrected candidate has a distinct content identity.

The corrected signed candidate and tools `0.2.0-2` have now installed in the
VM without the nested-metadata extraction warnings. Its package hook started
queued preparation; GRUB's baseline checksum still matches. Preparation was
observed running, not yet complete. Evidence:
`build/kernel-update-vm/install-corrected-candidate.log` and
`build/kernel-update-vm/corrected-queue-progress.log`. Tools `0.2.0-3`, carrying
the maintenance integration described in the update compatibility audit, are
built and archive-tested locally but not yet installed in this VM.

## HP audio coverage correction

The installed VM's legacy ownership audit found a separate firmware contributor:
`oma-snap-audio-hp 0.1.0-1` owns
`qcom/x1e80100/X1E80100-HP-ELITEBOOK-ULTRA-G1Q-tplg.bin` below the release-specific
firmware directory. This file was absent from the four-package retained firmware
assembly. Binding that incomplete tree would hide the working HP topology, so
the metadata-corrected `72bed4bc...` candidate remains unsuitable for HP promotion
even if its VM boot preparation succeeds. Evidence:
`build/kernel-update-vm/legacy-migration-audit.log` and the HP audio PKGBUILD.

Assembly now includes the separately hash-pinned HP audio package as a fifth
input. New hardware identity:
`66fd1aeac79199ae7e9e9b126dc2d8b0c996cb6afe2562d3f94f93cd157587bc`, at
`build/kernel-sets/package-v020-audio`. Assembly inventory verification passes,
and the normalized topology matches the existing MVP package byte-for-byte:
SHA-256 `aa303397750f883ecaeed874d7547da658500596247676a6d405bf1ec43290b5`.
Evidence: `build/kernel-set-audio-prepare.log`. Package build is underway in
`build/kernel-set-audio-package.log`.

The stage-artifact test now requires this topology in the embedded firmware
namespace; earlier passing runs predate that added check. This does not replace
physical speaker validation. The legacy audio package's ALSA mappings must stay
installed until they are split from its exact legacy-kernel dependency during
migration; retaining private copies of its metadata/userspace files does not
install those ALSA mappings into the active system.

The audio-inclusive archive has built successfully; SHA-256:
`9053c63537932b913ee5b6c9eb82508a462cd301d3b620462fffd0a34a83290b`.
It and tools `0.2.0-3` are signed in `build/kernel-repo-v020-audio-test` and
transferred to the VM. Installation waits for the earlier preparation job to
finish. A second build in `build/kernel-sets/package-v020-audio-repro` completed
with byte-identical output (the same SHA-256 above, confirmed by cmp). Evidence:
`build/kernel-set-audio-repro.log`. This is repeatability with the same pinned
inputs, toolchain and fixed makepkg working directory.

A complete, non-dereferencing comparison of the VM's legacy release-specific
firmware against the earlier `72bed4bc...` set found only the missing HP topology:
`build/kernel-update-vm/legacy-firmware-coverage-links.log` (diff exit 1 for that
one difference). An earlier dereferencing comparison exited 2 on existing
dangling firmware symlinks and is not treated as a clean comparison. This checks
the carried release-specific tree; it is not physical firmware validation.

## Stable provider package prototype

`packages/kernel-provider/PKGBUILD` builds the stable-name `oma-snap-kernel`
package. The local integration version is `7.0.0.31.31-1`, recording Ubuntu's
`7.0.0-31.31` meta-package version and depending on the exact audio-inclusive
hardware package plus tools `>=0.2.0-3`. Its only installed file records the
candidate identity with status **unvalidated**. There are no activation scriptlets,
replacement declarations or claims of promotion.

This supplies the stable dependency that future `pacman -Syu` transactions can
upgrade to pull a different content-addressed hardware package. It does not yet
prove a real repository upgrade or solve retained-package orphan handling.
Build succeeded in `build/kernel-provider-v020-test`; archive metadata was checked
against its recorded candidate. The three-package signed integration repository
has been assembled and its signatures verified at
`build/kernel-repo-v020-provider-test` (`build/kernel-repo-provider-signing.log`). Automated generation
from promotion evidence, monotonic revision policy, installation and upgrade
tests remain pending; the checked-in recipe is an explicitly pinned test candidate.

`tests/kernel-provider-pacman.sh` now validates the dependency transition with
real ARM pacman, the production provider recipe and production queue hook. In a
network-disabled disposable container, an unsigned synthetic repository upgrades
the provider from revision 1 (set A) to revision 2 (set B). `pacman -Syu` pulls in
B, leaves A installed and queues both package events without inline preparation.
The installed candidate record changes to B. This test passes:
`build/kernel-provider-pacman-test.log`. Synthetic payloads isolate the package
transition; signature tests and installed-VM boot tests remain separate evidence.
Orphan pruning and end-to-end promoted-release updates remain unfinished.

The VM's provider-repository checksum check caught two stale detached signatures
when unchanged archive bytes were reused from the prior repository. The new
repository had re-signed those archives, so their old signature files did not
match its checksums. Archive and database checksums passed. After replacing those
signatures, the complete repository checksum check passes in the VM:
`build/kernel-update-vm/provider-repo-checksums-final.log`. The original failed
check remains at `build/kernel-update-vm/provider-repo-checksums.log`.

The first installed-VM preparation completed successfully for set `72bed4bc…`,
publishing entry `27aa0490f7501c8969801157b038982a1ad858896ba76c6bef2f0ca21b8ce4b1`.
This proves queued preparation and publication, not a boot of that entry. That
set lacks the subsequently restored HP audio topology and is not a promotion
candidate.

During the user's review pause, the following provider installation was
interrupted during package integrity checks, before package changes; pacman's
lock was confirmed cleared. After the user resumed kernel-update work, the
same guarded script was restarted. It requires the earlier completed job,
an inactive preparation service and an absent pacman lock before installing
`oma-snap-kernel` from the signed repository. Dependencies must pull the
audio-inclusive set and tools revision 3. Evidence/script:
`build/kernel-update-vm/install-provider-candidate-resumed.log` and
`build/kernel-update-vm/install-provider-candidate.sh`. The original interrupted
log remains available. The resumed installation completed successfully: the
stable provider, audio-inclusive set and tools revision 3 are installed, the
legacy GRUB checksum is unchanged, and the cleanup service uses the maintenance
override. The new set's preparation service started automatically. This proves
signed installation and queue activation, not a boot of the new entry.

Hardware fixes are deferred while this integration proceeds. Migration remains
on GRUB: retain the released boot payload and its package-owned modules and
firmware while introducing separate kernel-set entries. Switching to Limine is
not part of this work. A saved legacy configuration alone is insufficient
rollback protection if its module or firmware packages can be removed.

Tools revision 4 adds a separate pre-transaction legacy retention hook. While
`/boot/oma-snap/7.0.0-31-generic` exists (using the configured ESP), it rejects
removal or replacement of the released Ubuntu kernel, HP camera/audio, four
Snapdragon firmware packages and legacy boot tool. An incomplete payload
directory still protects these repair inputs. The guard requires a mounted FAT
ESP and rejects substituted paths. Unit tests cover every protected package,
retirement, malformed targets and symlink substitution. Tools revision 4 built
successfully and passed archive checks (`build/kernel-tools-legacy-check.log`).
`tests/kernel-legacy-retain-pacman.sh` passes real ARM pacman removal, reinstall,
upgrade and batch-removal rejection for all eight dependencies, with package
versions, fixture bytes, boot checksum and lock release checked after rejection.
After simulated explicit retirement, removal succeeds. Evidence:
`build/kernel-legacy-retain-pacman-final.log`. This uses unsigned synthetic
packages in a disposable container; the initial fixture lacked `mkfs.fat`, which
was supplied from the ARM builder before the successful run. The guard is not
yet installed in the full VM and does not implement migration or retirement by
itself. The current provider fixture still contains tools revision 3.

## Boot-entry publication behavior

Legacy migration preparation now includes an exact released-menu renderer and
a synced, retryable snapshot of the old GRUB configuration, recording hashes
of the still-in-place legacy kernel and initramfs. Tests reject altered payloads
or saved configuration, including retries after corruption. Source now exposes
`--migrate-legacy --select legacy --fallback ENTRY_ID`; initial migration retains
the released boot as default. Subsequent `--select ENTRY_ID --fallback legacy`
and the reverse select between the two. It requires released recovery packages
and the packaged retention hook. Unit tests cover migration, explicit selection
and rollback, and corruption preserving the menu. No loader migration or boot
with this path has run in a VM yet. The initial revision 5 build includes this
command; source revision 6 also audits pacman's configured hook directories for
overrides and checks the guard's required transaction settings. Actual generated
menus pass the ARM builder's `grub-script-check` through
`tests/boot-publish-grub.sh` (`build/boot-publish-legacy-grub-check.log`). This is
syntax validation, not proof of boot. Built revision 4 predates migration.
Physical validation targets HP first
once VM upgrade/rollback and the v0.2.0 image are ready. The user authorized
`/dev/sda`; reidentify the device before writing.

`tests/kernel-migration-installed.sh` provides explicit `migrate`, `activate`,
`check-candidate`, `rollback` and `check-legacy` phases for the installed ARM
QEMU guest. Reboots occur separately. It requires completed preparation and
released locks, preserves original boot checksums, and checks runtime entry/set
identity and read-only mounts after candidate boot, then their absence after
legacy rollback. Shell syntax is checked; these phases have not run yet. The
audio-inclusive preparation remains active in the VM, so no second preparation
or migration has been started against its package lock.

Revision 6 built and passed package checks, then was signed in the isolated
local-test repository `build/kernel-repo-v020-migration-tools-test`. All transferred
repository checksums pass in the VM
(`build/kernel-update-vm/migration-tools-checksums.log`). A guarded continuation
(`build/kernel-update-vm/install-migration-tools.sh`, output `.log`) waits on the
existing preparation service, requires the audio-inclusive completed job and
released lock, then installs the signed tools and runs only the initial
legacy-default migration phase. It does not select the candidate or reboot.
The continuation remains waiting; no completed migration is claimed.

Updater integration must join preparation immediately after package-changing
phases, not only before the reboot prompt. The pinned `omarchy-update` runs
`omarchy-migrate`, post-update hooks, AUR updates and orphan cleanup after
`omarchy-update-system-pkgs`; these can invoke further pacman transactions while
the asynchronous preparation worker owns the database lock. Waiting only at
the end would still allow intermediate transaction failures. Keep the existing
Stay Awake inhibitor active during preparation. The restart helper also needs
selected-versus-running entry identity instead of its current search for
package-owned `/usr/lib/modules/*/vmlinuz`.

Patch `0005-quattro-kernel-preparation-wait.patch` now adds a service join after
keyring, system packages, migrations, post-update hooks, AUR and orphan phases.
Its helper waits for systemd and runs the new queue
`--check-provider-prepared` operation. The latter requires a valid completed job
for the installed provider and rejects its pending/running/failed state, while
ignoring unrelated historical failures. Service success alone is insufficient
because the worker records candidate failures without restarting indefinitely.
Go race tests cover provider states and pending refresh; the controlled helper
test `tests/quattro-kernel-wait.sh` verifies that readiness is not checked before
the service returns and that both kinds of failures stop the helper. These
source changes require tools revision 7 and a rebuilt Omarchy package; neither
has been installed yet. This is not full-update integration validation, and the
reboot identity and approved-candidate selection work remains unfinished.

Source revision 7 now also exposes `oma-snap-boot-publish --reboot-status`,
reporting `current` or `required` under the boot/package locks. It compares the
selected GRUB entry against `/run/oma-snap/booted-entry`, recognizes the exact
released legacy menu, and errors on unknown menus or malformed identity. Unit
tests cover equal kernel releases with different entries, the released boot,
foreign kernel release and invalid state. Patch
`0006-quattro-kernel-reboot-identity.patch` uses this status in Omarchy's restart
helper when Snapdragon tools exist and preserves stock detection otherwise.
Shell syntax and patch application checks pass. This source has not been
packaged or exercised through the full update flow; approved-candidate
activation is still unfinished.

The actual restart helper passes the isolated command test
`tests/quattro-kernel-reboot.sh`: selected/current identity controls the kernel
prompt, and unknown or failed status prevents prompting. Profile regression
checks pass in `build/quattro-updater-profile-check-final.log`. The first profile
run exposed an outdated exact-match assertion for `install/user/all.sh`; its
only difference is the already-shipped T14s TrackPoint setup line. The check now
requires exactly one such line and byte-for-byte stock content otherwise,
preserving the cloud-tool setup check. Tools revision 7 packaging is in progress
at `build/kernel-tools-v020-updater`; the VM continuation still targets the
already-signed revision 6 migration tools.

Tools revision 7 has now built and passed package checks
(`build/kernel-tools-updater-check.log`). A separate update-aware Omarchy pair
is building through `scripts/build-quattro-update-profile.sh` under
`build/quattro-v020-updater`, using package release 1.5 and an ARM dependency on
tools >=0.2.0-7. The published MVP package directory and manifest are untouched.
The preparation check exposed four camera userspace packages already present
in `packages.extra` but absent from the patched upstream install list; patch
0002 now includes them, and the profile test requires an exact match to the
generated list. Profile checks pass after reconciliation. This preserves
existing camera support; it is not new hardware work or a completed ISO build.

The complete pinned `omarchy-update` script also passes a controlled execution
test (`tests/quattro-update-kernel-flow.sh`, evidence
`build/quattro-update-kernel-flow.log`). It verifies six package-phase/service/
provider-check sequences and confirms that a failed preparation check stops
before later package work and reboot prompting while releasing the Stay Awake
inhibitor. Commands are isolated fixtures; actual pacman/systemd integration
remains to be exercised in the installed VM.

The update-aware `omarchy-4.0.3-1.5` runtime archive has finished. Its build
logged a fakeroot diagnostic; an explicit numeric-ownership audit confirms every
archive entry is root:root (`build/quattro-v020-updater/omarchy-ownership.log`).
The settings package is still building. `tests/quattro-update-packages.sh` will
check the completed pair's hashes, ownership, version, tools dependency, runtime
helpers and camera-inclusive install list before the pair is used in a VM.

The Omarchy pair is now complete and passes those checks in
`build/quattro-update-packages-check.log`: all archive entries are root:root,
both packages are 4.0.3-1.5, the runtime requires tools >=0.2.0-7, tested update
helpers match source, and the camera package list matches the generated policy.
Archive hashes are recorded in `build/quattro-v020-updater/packages.sha256`.
The pair remains a local integration build, not an installed or published update.

`tools/boot-publish` adds the next bounded step after initramfs staging. Run the
ARM binary as root with `--stage /var/lib/oma-snap/staging/BUILD_DIRECTORY` and
an optional `--esp /boot` (also accepts `/efi` or `/boot/efi`). It requires an
actual mounted FAT filesystem with a UUID and uses the same operation lock as
staging. It re-verifies the retained hardware inventory and checks the staging
identity before copying the kernel and initramfs while checking their hashes.

Copies and the generated GRUB entry go into an incomplete directory, with files
and directory synced before renaming to `/oma-snap/entries/BOOT_ENTRY_ID` on the
ESP. It refuses an existing entry and does not write the main GRUB configuration
or change the selected default. Failed copies remove the incomplete directory;
an abrupt kill can leave an ignored `.incomplete-*` directory. The resulting
manifest explicitly says `published-unselected-unvalidated`. Publication is not
candidate promotion or activation. FAT power-loss recovery is not yet tested,
and this is not a claim of atomic multi-filesystem updates.

Go tests cover preserving the old default and entry, failure after the kernel
copy when the initramfs is missing/corrupt/substituted, and rejecting mismatched
identity or GRUB command injection. ARM cross-compilation and Go vet pass.
`tests/kernel-boot-publish-fat.sh` exercises byte-preserving publication on a
512 MiB FAT image and failure on a 128 MiB FAT image too small for the initramfs.
These are disposable files, not physical USB disks or laptop ESPs.
Both FAT cases passed with the actual staged payload, including the expected
`no space left on device` error during the second initramfs copy; no partial
entry remained and the default bytes were unchanged. Evidence:
`build/kernel-publish-fat-test-native-mount.log`. The initial ARM userspace
mount attempt could not set up a loop device; the passing run uses native
mount tools and emulated ARM Go binaries. It does not prove native ARM boot.

The current tools cover discovery, offline verification, extraction, candidate
camera builds, retained-set initramfs and unselected boot-entry publication,
not a finished updater. Connecting entries to the loader, default selection,
transaction guards, full installed-system rollback and promotion remain open.

The next selection prototype adds `--select BOOT_ENTRY_ID --fallback OTHER_ID`
as an alternative to `--stage`. It verifies both ESP payload hashes and retained
hardware sets before writing a menu containing both entries. It preserves the
Snapdragon memory workaround and generates entries from current root arguments,
without executing saved `entry.cfg` text. The default is selected by full entry
ID, so two initramfs builds of the same kernel release remain distinguishable.
Both menu files and their directories are synced before/after replacement.

Selection only creates a new menu or replaces one bearing its managed marker.
It refuses the released v0.1.2 legacy menu; explicit migration that preserves the
working legacy boot is still required before using this on existing laptops.
Go tests cover A/B/A menu selection and unchanged defaults on corrupted fallback,
missing retained set and legacy-loader rejection. These are menu-generation
tests, not successful reboot/rollback evidence. The second real initramfs build
completed successfully for FAT selection and component VM boot tests. Its entry
ID is `948271b473a64772276251d0c470d3d44326b4acc7e83df149bdda2fd6d02eca`,
with initramfs SHA-256
`1c24fa661e37cf0809b2deff6bba5962f4c6edd8bcff7a1d7fba9e15250761a9`.
The hardware set, kernel release and wrapped kernel hash match the first build;
the independently embedded entry identity is different. Evidence:
`build/kernel-stage-second-build.log` and `build/kernel-stage-second-built.json`.

The reproducible follow-on commands are:

```bash
bash scripts/test-kernel-boot-select.sh FIRST_BUILD_BASENAME SECOND_BUILD_BASENAME NEW_SELECTION_NAME
bash scripts/test-kernel-rollback-vm.sh NEW_SELECTION_NAME EXISTING_COMPONENT_ROOT NEW_BOOT_PREFIX
```

The first command creates a new 1 GiB FAT file, publishes both staged builds,
tests menu changes and corrupted-fallback rejection, then adds a standalone
ARM GRUB loader that reads the generated menu. The second selects A/B/A using
the real publisher before each QEMU boot. Each boot uses a disposable copy of
the component root with its expected test identity updated and read back using
debugfs. The retained hardware payload is unchanged. Each serial log must
report its exact expected entry identity and read-only module/firmware mounts.
This tests same-release initramfs rollback; it does not test different kernel
ABIs, pacman transactions, persistent systemd state or encrypted root. Those
remain part of the full acceptance requirements.

The second build's extracted-artifact checks passed in
`build/kernel-stage-second-artifact-test.log`. The real FAT selection test also
passed: A/B/A menus retained both entries, corrupting B's wrapped kernel caused
the expected hash-mismatch rejection and the menu stayed byte-identical. The
fixture restored B's verified kernel afterward. `grub-script-check` accepts the
generated menu. Evidence: `build/kernel-select-fat-test.log`; bootable test image
`build/kernel-select-vm/boot.img`. The three-boot QEMU sequence completed
successfully under `scripts/test-kernel-rollback-vm.sh`: A, B, then A each reached
test PID 1 with its exact expected embedded identity, checked read-only retained
modules/firmware and powered down. The orchestrator exited zero and reported
`PASS: same-release A/B/A initramfs boot selection and rollback`.
Evidence: `build/kernel-rollback-vm.log` and each
`build/kernel-rollback-{1,2,3}/serial.log`. These are actual ARM UEFI/GRUB/kernel
boots, beyond menu-generation tests, with the component-root limitations above.

## Offline extraction and HP camera build

```bash
bash scripts/prepare-kernel-set.sh ubuntu-20260913-v020 NEW_SET_NAME
bash scripts/build-kernel-set-camera.sh NEW_SET_NAME
```

Extraction runs without network access. It independently verifies the saved
InRelease signatures against the external policy, rechecks signed index hashes,
resolves the dependency closure again and checks every downloaded artifact.
Editing `candidate.json` cannot establish a different trusted package set.
`dpkg-deb` extracts payloads and retains control files for inspection; it does
not execute maintainer scripts. Output directories must be new.

Offline verification currently applies the same metadata freshness policy as
discovery. Historical rebuilds after that freshness window are not supported
yet; do not bypass verification to rebuild an old release. Archival replay
needs a separately authenticated acceptance record and explicit policy.

The camera wrapper uses the extracted candidate's ARM64 headers and dtc in
the existing `oma-snap-root` build container, compiles all three HP modules,
and verifies their release vermagic. Kernel modpost checks imported symbols
against the candidate headers' Module.symvers. This is build/ABI evidence;
it does not replace a physical camera test. The compiler currently differs
from Ubuntu's (GCC 16.1.1 versus 15.2.0), and BTF generation is skipped because
the header package does not contain vmlinux. These warnings are retained in
the build log and need review before promotion.

The network-disabled integration test `tests/kernel-candidate-offline.sh`
runs in the candidate builder with the saved inputs and external policy mounted
read-only. It confirms rejection of edited candidate identity, signed metadata,
package indexes, package payloads and symlink payload substitution. Evidence:
`build/kernel-candidate-offline-tests.log`. Extracted input evidence is in
`build/kernel-sets/ubuntu-7.0.0-31/extracted.json`; the candidate camera build
passed in `build/kernel-set-camera.log`.

A second extraction and camera build in `ubuntu-7.0.0-31-repro` produced
byte-identical modules despite different build paths (all three checked with
`cmp`). Both builds used the same container toolchain; cross-toolchain
reproducibility is not established. Resulting SHA-256 values:

```text
ca82993c6d3bee9aadb38a0366526c48967bca14791c01fda52a45a6753eb749  hp_camera_children.ko
c4c7838983899897c464e022cf7d1ae1dd22d1e9cf518993c5dfa2c78b34f222  hp_camera_overlay.ko
a6e215fb1f6ed45d83e0f2a253d34935020d11c4a6a73945fdd70944c7613097  ov05c10.ko
```

## September 13 discovery evidence

The live authenticated run in `build/kernel-candidates/ubuntu-20260913-v020/`
selects `7.0.0-31-generic`. All eight downloaded package sizes and SHA-256
hashes were independently checked again after download. This includes the
image and header meta-packages, signed image, matching common/ARM64 headers,
modules, and separately signed ZFS module package. The latter has its own
`7.0.0-31.31+2` package revision and explicitly depends on the selected image
ABI. The supported signed-image/unsigned-image alternative is resolved to the
signed image; arbitrary alternatives still fail rather than guessing.

Tests pass in the candidate builder, including Debian epoch/tilde ordering,
missing/mismatched payloads, conflicting pocket hashes, malformed control data,
unsafe paths, metadata freshness and archive identity. Modifying signed
InRelease content produces a BAD signature and is rejected by gpgv. Evidence:
`build/kernel-candidate-tests.log` and `build/kernel-candidate-discovery-v020.log`.
Initial failed discovery directories remain separate and are not promotion inputs.

No package has been installed on the physical laptops, no boot entry changed,
and no v0.2.0 ISO or update repository has been published. The release, module,
firmware and rollback integration work listed above remains open.
