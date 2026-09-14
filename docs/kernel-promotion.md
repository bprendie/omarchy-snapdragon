# Maintainer approval and provider generation

`tools/kernel-promotion` binds an explicit maintainer decision to one hardware
package and a set of reviewed evidence files. It does not infer that a log proves
success. The reviewer must inspect the evidence and confirm that it describes
the exact candidate, hardware payload and tested update path before approving.
The signed repository and provider package will authenticate that decision to
installed systems; this local JSON is not itself a signature or a trust anchor.

Create an approval JSON alongside copies of the reviewed evidence. Required
fields are `schema: 1`, `status: "approved"`, `channel` (`testing` or `stable`),
positive integer `sequence`, nonempty `reviewer`, `hardware_set`,
`kernel_release`, `package_sha256`, `hardware_validation` and `evidence`.
Hardware validation has exactly the keys `t14s`, `hp-g1q`, and
`asus-ux3407ra`, each `validated` or `untested`. Stable requires ThinkPad and HP
validation. A testing approval may precede physical testing, but must retain
the untested labels. ASUS remains untested until a physical result exists.

Each evidence item contains `kind`, `path` relative to the approval document,
and `sha256`. Exactly one of each kind is required:

- `source-verification`: authenticated Ubuntu metadata and payload verification.
- `package-reproducibility`: repeat package build comparison.
- `camera-build`: ABI-matched HP module build and checks.
- `vm-rollback`: actual installed upgrade and rollback with matching private payloads.
- `vm-encrypted-boot`: successful encrypted-root boot through the candidate path.

Hardware claims are the maintainer's reviewed attestations; preserve their
physical test logs with the release evidence as well. Do not manufacture successful evidence for a pending test.

For an explicitly authorized **testing** candidate, `deferred_tests` may contain
`vm-encrypted-boot` with a nonempty explanation of the owner's decision and the
remaining work. That test must then be absent from `evidence`; it is deferred,
not passed. Stable approvals reject deferrals, and source authentication,
reproducibility, camera build and rollback evidence remain required. This
exception was added at the owner's explicit request to build v0.2.0 immediately
instead of waiting for further VM tests.

```bash
bash scripts/build-kernel-provider-package.sh NEW_BUILD_NAME \
  /absolute/path/to/approval.json /absolute/path/to/hardware.pkg.tar.xz \
  PREVIOUS_PUBLISHED_SEQUENCE
```

The generator checks evidence hashes, archive hash, actual `.PKGINFO` name,
version and architecture, and the packaged set ID/kernel release. It writes a
new PKGBUILD and the full decision as `candidate.json`; the builder uses a fixed
makepkg path and verifies the packaged decision byte for byte. Existing output
directories are rejected. No candidate is approved or published by default.

Provider versions use `epoch=1`, `pkgver=SEQUENCE`, `pkgrel=1`. This sorts after
the unversioned prototype's Ubuntu-shaped version and allows a newer provider
release to select an older kernel deliberately. Sequences must increase across
testing and stable releases, including firmware-only changes. Obtain the prior
sequence from the authenticated published release record; the generator checks
the supplied floor but does not query a remote repository. Do not reuse a
sequence with different contents. The initial hardware package version is
currently fixed at `0.2.0-1`; its content-addressed name changes with its payload.

The builder does not sign, publish or activate the result. Production repository
assembly must include this exact approved hardware archive and the coordinated
tools/Omarchy packages. The generic local test repository builder is still a
fixture; use the approval-gated assembly command below for release preparation.
Production publication and the ISO
bootstrap remain integration work. No real candidate has been approved through
this command yet.

## Signed repository assembly

```bash
bash scripts/build-promoted-kernel-repo.sh NEW_REPOSITORY_NAME \
  /absolute/private/key-home PRIMARY_FINGERPRINT \
  /absolute/path/to/approval.json HARDWARE_PACKAGE PROVIDER_PACKAGE PREVIOUS_SEQUENCE \
  TOOLS_PACKAGE OMARCHY_PACKAGE SETTINGS_PACKAGE REPOSITORY_PACKAGE
```

This command rechecks the decision and evidence, verifies that the provider
contains that exact decision, and accepts exactly the coordinated six-package
set. It requires matching Omarchy/settings versions, tools at least revision 10,
the update-aware Omarchy pair at least revision 1.9, and a repository trust
package identifying the supplied signer. Stable requires a release-mode HTTPS
repository configuration. It creates signed `oma-snap` database/package files
and a signed checksum manifest in a new local directory. It never uploads.

Do not add `oma-snap-boot` to this update repository while legacy retention
guards remain active: upgrading that package on migrated systems is deliberately
blocked. Boot revision 7 belongs in the fresh installer's offline package set;
the normal updater uses the separately owned kernel tools.

The reviewer must also validate the coordinated tools/Omarchy/keyring packages
and retain their build/archive test results. Version checks cannot prove their
contents are correct. Signer/key provisioning and the public endpoint remain
release operations, not automatic discovery actions. Preserve the private key
outside the image and public checkout.

`tests/promoted-kernel-repo.sh KEY_HOME FINGERPRINT` exercises actual signing,
database generation, signature/checksum validation and rejection of changed
rollback evidence using clearly marked synthetic packages. Its fixture output
must never be installed or published. The successful run is recorded in
`build/kernel-promoted-repo-synthetic-test.log`; a real approved repository has
not yet been assembled.

## Installed activation

Tools revision 10 adds `oma-snap-boot-publish --activate-provider`. The Omarchy
4.0.3-1.9 helper calls it after the preparation service and completed-provider
check succeed. Missing providers and the historical `unvalidated` prototype
remain inactive. Approved providers must match `/etc/oma-snap/kernel-channel`,
whose default when absent is `stable`; testing requires explicitly setting that
file to `testing` in the test image or machine.

Under the existing pacman and boot-operation locks, activation checks the
completed job, published entry, package payload verification and running boot
identity. It selects the approved entry with the currently running entry as
fallback. A legacy running system must have undergone the explicit GRUB
migration first; activation does not silently migrate a custom boot layout.
Legacy dependency guards and payload hash checks remain enforced.

`/var/lib/oma-snap/provider-activation.json` records the applied sequence and
approval hash. Repeating the same approval leaves the selection alone, preserving
a user's deliberate rollback. Regressing a sequence or changing its contents
is rejected. A newer approved sequence can select a new candidate. Refreshing
an initramfs under an already-applied sequence does not automatically reselect
it; deliberate refresh/selection remains a maintainer operation for now.

The menu is committed before the activation record. A failure writing the
record is reported, but may leave the new menu selected; inspect the menu and
record before retrying after disk-full or interrupted writes. The running
fallback remains in the menu. Full power-loss recovery is a documented follow-up.
These source checks pass unit tests for retained and legacy boot selection,
manual rollback persistence, channel isolation and failures that occur before
selection. Installed signed-package activation still requires the VM run.

Tests in `tools/kernel-promotion` use synthetic archives and evidence, covering
tampering, identity mismatch, absent evidence, sequence rejection, stable
hardware requirements, and preserved ASUS status. These validate the gate's
mechanics and do not stand in for candidate validation.

## Experimental Concept candidates (v0.2.2)

The testing channel can explicitly defer package reproducibility, VM rollback,
and encrypted boot, with a nonempty reason for each absent result. It cannot
defer source authentication or the ABI-matched HP camera build. Stable promotion
still rejects all deferrals. A16 can be recorded as a fourth hardware profile;
its presence does not change the existing ThinkPad/HP stable-validation gates.
The 0.2.2 candidate records all hardware as untested on this new kernel. Earlier
7.0 hardware results must not be reported as 7.2 results.

The Concept provider requires `oma-snap-kernel-tools>=0.2.2-1`, whose release-name
handling includes `-qcom-x1e`. This prevents activating a Concept provider with
the older tools that accept only `-generic` releases.
