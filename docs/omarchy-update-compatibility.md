# Omarchy updater compatibility audit — v0.2.0

Audited September 13, 2026. This records source findings and required tests;
the protections below are not yet implemented or physically validated.

## Sources and scope

The shipped Snapdragon profile derives from Omarchy commit
`0534987009061cbe2dacdde4ad564092ab698d12`, with
`patches/0002-quattro-arm-profile.patch`. Also inspected current upstream
Quattro commit `6a89a39967e58451a5029d15e7aa3ef1aa8a613c` and package recipes
at `c31ef469c5f0dde2654770f5ce578e8b2e559193`.

- [Update orchestration](https://github.com/omacom/omarchy/blob/6a89a39967e58451a5029d15e7aa3ef1aa8a613c/bin/omarchy-update)
- [System package update](https://github.com/omacom/omarchy/blob/6a89a39967e58451a5029d15e7aa3ef1aa8a613c/bin/omarchy-update-system-pkgs)
- [Reboot detection](https://github.com/omacom/omarchy/blob/6a89a39967e58451a5029d15e7aa3ef1aa8a613c/bin/omarchy-update-restart)
- [Repository refresh](https://github.com/omacom/omarchy/blob/6a89a39967e58451a5029d15e7aa3ef1aa8a613c/bin/omarchy-refresh-pacman)
- [Channel switch](https://github.com/omacom/omarchy/blob/6a89a39967e58451a5029d15e7aa3ef1aa8a613c/bin/omarchy-channel-set)
- [ARM package dependencies](https://github.com/omacom/omarchy-pkgs/blob/c31ef469c5f0dde2654770f5ce578e8b2e559193/pkgbuilds/omarchy/PKGBUILD)

## What an ordinary update does

`omarchy-update` locks and logs the operation, prunes cached package versions
to two, attempts a snapshot (continues on failure), updates keyrings, runs a
full pacman system upgrade, then migrations, the user post-update hook, AUR
and mise updates, optional orphan removal, log/status checks and restart prompts.
A failed package-update command stops the later steps.

There is no unconditional kernel install in the inspected system-update command:
it runs `pacman -Syu`. Publishing a differently named kernel alone does not
install it. Dependencies, replacements, an already installed kernel, or a
migration explicitly requesting one can change that. The inspected ARM Omarchy
recipe does not depend on the x86 Limine stack or a kernel package. This is a
finding about these revisions, not a guarantee about future releases.

Current upstream wraps pacman in a systemd system scope to survive user-session
teardown during systemd upgrades. Our pinned release predates that wrapper.
Preserve this improvement when rebasing the profile; do not replace it with an
unprotected update subprocess.

## Integration hazards and required behavior

| Observed behavior | Requirement for Snapdragon |
| --- | --- |
| Reboot detection looks for a pacman-owned `/usr/lib/modules/*/vmlinuz` matching `uname -r`. | Compare the running boot-set identity against the successfully staged default. Keeping the old modules, or revising a package without changing `uname -r`, must still produce the correct reboot notice. |
| `omarchy-refresh-pacman` replaces both pacman configuration and mirrorlist, then runs `-Syyuu` (downgrades allowed). Channel switching also explicitly installs Omarchy packages. | Retain ARM repositories, the signed Snapdragon repository and compatibility policy across every channel. Test explicit installs as well as system upgrades; `IgnorePkg` is not a security boundary. |
| The shipped profile currently holds Omarchy/Hyprland packages and restricts the Omarchy repo to Sync/Search/Install. | These MVP restrictions are not a finished update solution. Lift them only with a tested coordinated profile; do not silently leave users with an indefinitely frozen desktop. |
| User pre-refresh and post-update hooks print failures and continue. | Do not rely on a user hook to enforce repository or boot safety. Enforce package compatibility before mutation with an ALPM pre-transaction check that aborts on failure. |
| Post-transaction work occurs after package files have changed. | Stage and validate new boot files without overwriting the last working set. A failed initramfs build must preserve the previous default and report an actionable error; a post-transaction failure cannot undo the package transaction. |
| Orphan review uses `pacman -Qtdq`, then optionally `-Rns`. Cache pruning retains only two archive versions. | Keep retained boot sets explicitly installed or referenced by a retention package, and block removal of the running/default/fallback sets. A cached archive is not a bootable fallback. |
| System update allows overwrites under `/usr/share/omarchy/*`; conflict recovery can take over unowned files. | Put Snapdragon boot tools and state outside that namespace, with package ownership. Maintain upstream changes through reviewed source patches, not edits to installed Omarchy files. |
| Migrations can change initramfs settings; inspected Limine migrations are mostly gated by command/config presence. | Audit each new migration set, preserve the Snapdragon initramfs configuration, and test settings-package upgrades. Do not install Limine merely to satisfy a desktop package transition. |
| Log analysis only recognizes particular initcpio messages and prints a warning. | Expose structured staging success/failure to restart handling. Never treat this log heuristic as proof that a Snapdragon boot set is usable. |

The existing raw-pacman guard only distinguishes Omarchy-owned system upgrades
from direct ones. It does not validate hardware kernel compatibility. A separate
Snapdragon transaction guard must apply to direct package installs and removals
as well as Omarchy updates. It should validate the resulting package set rather
than prohibit every package whose name starts with `linux`.

Rollback must retain matching modules and firmware as well as EFI images and
initramfs. Multiple package revisions can share one kernel release string;
boot-set identity therefore cannot be only `uname -r`. A root filesystem
snapshot alone also does not restore the separate ESP.

## Disposable-VM acceptance matrix

1. Ordinary Omarchy update with no hardware-package changes: keep boot selection.
2. Signed coordinated kernel/camera update: stage matching artifacts, retain the
   previous set and request reboot, including an unchanged kernel release string.
3. Unknown kernel dependency/replacement, mismatched camera module, or removal
   of a protected set: reject before modifying installed packages.
4. Initramfs failure, full/unmounted ESP, interrupted staging and systemd user
   manager reexecution: previous boot remains selectable; failure is visible.
5. Stable/rc/edge refresh and explicit Omarchy reinstall: repository policy and
   Snapdragon configuration survive; an unapproved downgrade is rejected.
6. Orphan cleanup and package-cache pruning after two updates: running, default
   and fallback sets remain usable without downloading anything.
7. Rollback boot followed by an ordinary update: the running old modules remain
   available and the reboot prompt accurately reflects the selected default.
8. Upstream settings/migration update: encryption splash, firmware, HP camera
   and boot assembly stay intact. Follow VM checks with HP/ThinkPad hardware
   validation; ASUS remains unvalidated on hardware.

No updater was executed on either physical laptop during this audit.

## Initial retained-package guard

`tools/kernel-retain` and
`profiles/snapdragon/alpm-hooks/01-oma-snap-retain.hook` are the first retention
prototype, not the complete transaction policy. The pre-transaction hook targets
removal and upgrade of `oma-snap-set-*`, requests package names on stdin and uses
`AbortOnFail`. The installed Pacman 7.1.0 `alpm-hooks(5)` manual was consulted for
these trigger semantics; upgrades include reinstalls and downgrades.

The guard requires `/etc/oma-snap/esp-path` to name a mounted FAT ESP and reads
the running hardware identity plus every published boot-entry manifest. It
rejects changing any referenced immutable hardware package. Protecting all
published entries also preserves manually selectable recovery entries; retiring
old entries must be an explicit coordinated operation before orphan cleanup can
remove their now-unreferenced packages. Malformed state, an unmounted ESP or
unexpected transaction targets cause failure rather than assuming no references.

Unit tests and ARM cross-compilation pass for running/published protection,
unused-set eligibility and missing/substituted/malformed-state rejection. The
hook is not packaged or installed on a laptop yet. Boot staging/publication now
coordinate with the package database lock as described below. Retained packages
also need explicit install reasons or filtering from Omarchy's orphan review;
the guard correctly aborts an entire orphan batch containing protected packages.
This guard does not yet reject foreign kernel dependencies, preserve repository
configuration, prevent incompatible desktop migrations or implement reboot
notices. Those remain explicit requirements of the full policy.

`tests/kernel-retain-pacman.sh` now passes in the native ARM installer VM using
a separate chroot, private mount namespace, package database and 16 MiB FAT file.
Synthetic unsigned packages exercise the real libalpm pre-transaction hook.
The production hook's Exec path is redirected into the fixture's test-tools
directory; its trigger and abort settings are unchanged. The initial fixture
used `--sysroot` with target paths interpreted incorrectly, failed before package
installation, and was corrected to invoke pacman inside the test chroot.

Verified behavior:

- Removal of the running set and an independently published set is rejected.
- Reinstalling or upgrading a protected package is rejected.
- Installing a conflicting replacement, after answering yes to remove the
  protected package, is rejected by the hook before the transaction commits.
- A real `-Qtdq`/`-Rns` orphan batch is rejected without removing the unprotected
  package in that same transaction. All original versions and marker files remain.
- Removing an unreferenced set succeeds and removes its payload.
- Unmounting the configured ESP blocks removal before mutation.

Both successful test roots were unmounted and removed; no fixture mounts remain
in the live installer namespace. Evidence:
`build/kernel-retain-pacman-test.log` and
`build/kernel-retain-pacman-replacement-test.log`. These validate retention hook
semantics, not signed repository promotion or the full coordinated kernel update.

## Package/boot-operation coordination

`tools/boot-lock` is shared by boot-stage and boot-publish. It asks the installed
`pacman-conf` for DBPath, requires an existing canonical directory and reserves
`db.lck` using exclusive creation for the entire boot operation. This serializes
staging, publication and selection against real pacman transactions, including
the period after the retention pre-hook returns. The staging worker uses its
parent's reservation rather than acquiring it again. Boot tools retain their
own operation lock as well. Future entry-retirement code must use this same
database reservation before changing the guard's reference state.

An existing lock is never removed automatically. Normal success or failure
removes only the reservation created by that invocation; if another file has
replaced it, cleanup refuses to delete the replacement. A killed process can
leave a stale lock, like pacman itself, requiring owner/process investigation
before manual removal. This is not automatic crash recovery.

The native ARM pacman fixture verified both directions: a process using the
production lock helper blocks a real pacman removal, and a real pacman
transaction paused in a pre-hook blocks both production boot-stage and
boot-publish binaries. Failed tool attempts preserve pacman's lock bytes;
normal release allows the transaction to finish. Evidence:
`build/kernel-pacman-coordination-test.log`. Go tests additionally cover
exclusive acquisition and refusing to delete a replaced lock.

This means post-transaction hooks cannot directly call staging while pacman
still holds its lock. Update integration must queue the work and execute it
after lock release, preserving visible pending/failure state and the old boot
default. That orchestration remains unimplemented; the new lock must not be
bypassed to make an inline post-hook appear to work. The Ubuntu FAT-only test
containers use an explicit test substitute for `pacman-conf` because they do
not contain pacman; real configuration lookup and transaction exclusion are
covered by the native ARM fixture above.

With locking enabled, the FAT publication/selection regression passed again in
`build/kernel-select-coordinated-test.log`: both payloads were published,
A/B/A menus were generated, and corrupt-fallback rejection preserved the menu.
The same kernel/initramfs bytes and entry generation were used; the already
passing three-boot sequence was not repeated for this locking-only change.

The final native ARM run also verifies that production staging and selection
release their own reservation after failure. Staging rejects an absent set;
publication rejects the minimal chroot's FAT mount because its loop-device node
is not exposed for UUID probing. An initial test expected the later missing-entry
error instead; diagnostics identified and corrected that fixture expectation.
Both operations leave no `db.lck` after failing. All retention and mutual-exclusion
cases pass together in `build/kernel-pacman-coordination-final-test.log`, and no
fixture mounts remain in the live namespace.

Boot staging and publication now accept `--wait-lock=DURATION` (zero by default,
at most 30 minutes). `tools/boot-lock/wait.go` registers an inotify watch before
attempting exclusive acquisition, waits on filesystem events, and retries only
when an event arrives. It has no periodic polling loop. Cancellation/deadline
closes the event reader and leaves the existing owner's lock untouched; an
invalidated watch fails rather than deleting a lock or waiting indefinitely.

Race-enabled tests cover release/wakeup, timeout, already-cancelled contexts and
invalid wait bounds. The native ARM pacman test also holds a real transaction,
checks a bounded timeout, then releases it and verifies that waiting production
staging resumes, rejects its deliberately absent payload and removes its own
reservation. The complete test passes in `build/kernel-pacman-event-wait-test.log`.
This supplies the waiting primitive for deferred work; persistent job queuing,
service activation, retry/failure presentation and promoted-candidate selection
still need implementation.

## Persistent preparation queue

`tools/kernel-queue` now implements `--enqueue` (ALPM targets on stdin),
`--process`, `--retry HARDWARE_ID` and JSON-lines `--status`. Jobs live under
`/var/lib/oma-snap/jobs/{pending,running,failed,complete}`. State transitions use
renames within that filesystem with synced records/directories. An existing job
deduplicates package events, including failed jobs; retry is explicit. Interrupted
running jobs become recorded failures on the next worker start, preserving their
work directories instead of automatically repeating uncertain boot operations.

The queue mutex protects only short state changes. A separate worker lock
serializes preparation, so enqueueing from a package hook cannot deadlock behind
a worker waiting for pacman. The worker drains available jobs and exits when
there is no work. It invokes staging with a bounded lock wait and a new structured
result file, then publishes an unselected entry. `complete` means boot preparation
completed, not that the candidate is hardware-validated, promoted or selected.
Successful queued preparation through both real commands remains to be tested
on the installed VM; the failure/activation paths below are validated.

`95-oma-snap-prepare.hook` records jobs in PostTransaction. The accompanying
`oma-snap-kernel-prepare.path` and oneshot service activate on pending/interrupted
jobs, with no persistent custom daemon or periodic polling. Recorded failed jobs
do not trigger automatic retries. Invalid queue state causes a service failure;
systemd's start limit bounds repeated activation until it is inspected.

Race-enabled Go tests cover duplicate requests, failure retention, explicit retry,
enqueueing during execution, worker exclusion and interruption recovery. In the
native ARM VM, the real systemd path unit automatically ran an absent-payload
job, recorded its failure and created a new logged attempt on explicit retry.
Its temporary units/tools were removed, and evidence was preserved under
`/var/tmp/kernel-queue-evidence.QKUQqn`. Both attempt logs confirm the expected
missing-set error. Host evidence: `build/kernel-queue-systemd-test.log`.

The real pacman fixture also installed the post-hook, queued a job after package
installation and verified that reinstallation did not duplicate it or create a
work directory. All retention/concurrency cases passed in that same run:
`build/kernel-pacman-queue-hook-test.log`. Queued preparation, release promotion,
automatic approved-default selection and Omarchy's user-facing update/restart
reporting still need end-to-end integration; none of these units/hooks has been
deployed on a physical laptop.

## Installed-system module cleanup gap

The full installed ARM VM has `kernel-modules-hook 0.1.7-3`. Its
`linux-modules-cleanup.service` runs at basic.target and moves unowned,
non-running `/usr/lib/modules/[0-9]*` directories into `.old` before removing
the original directory. Evidence: `build/kernel-update-vm/installed-cleanup-audit.log`.
The current retained packages own their private payload paths; staging creates
public module/firmware mountpoints, and the initramfs requires those mountpoints
to exist even when the root is read-only. Thus cleanup can remove a mountpoint
needed by a retained kernel with a different release. The currently running
release is exempt, so same-release A/B/A boots do not cover this risk.

Before different-release rollback is accepted, integrate retained-directory
protection with this service and test both package removal and reboot cleanup.
Preserve normal cleanup of unrelated obsolete modules. Do not add payload files
under active read-only bind mounts or assume the existing retention hook protects
filesystem operations outside pacman transactions. This remains unresolved.

An empty-directory ownership experiment is insufficient: real ARM pacman accepts
two synthetic packages owning the same directories beneath active read-only
module/firmware binds. After unmounting and removing one package, its stock
`60-depmod.hook` removes the empty module directory even though the second
package still lists it. The firmware directory remains. This is reproduced by
`tests/kernel-mountpoint-pacman.sh` in a disposable ARM container, with stock
hooks enabled and only the unrelated Arch kernel presets masked. Evidence:
`build/kernel-mountpoint-pacman-reproduction.log`. The test is a reproduction of
the unresolved gap, not an acceptance test claiming rollback protection. No
package recipe was changed to adopt this insufficient approach.

`tools/kernel-maintenance` now implements retained-aware maintenance. Its depmod
mode filters retained release targets before calling the stock depmod script,
then ensures module and firmware mountpoints exist. Its cleanup mode takes the
pacman database lock, preserves the running release, retained releases and
pacman-owned directories, and otherwise follows the existing rsync/archive
cleanup behavior. Manifest identity and canonical directories are checked before
maintenance; a dangling retained-root symlink is an error, not an empty set list.
Race-enabled tests cover selection and malformed/substituted state. The protected
mode of `tests/kernel-mountpoint-pacman.sh` passes with actual ARM pacman and the
production hook override: same-release package removal preserves mountpoints,
cleanup preserves unowned retained mountpoints and archives unrelated obsolete
modules, and a held pacman lock is rejected without modification. Evidence:
`build/kernel-maintenance-pacman-final.log`. The first attempt lacked rsync's
xxhash dependency; the completed fixture installs both cached dependencies.

Tools package `0.2.0-3` includes the maintenance binary, an override at
`/etc/pacman.d/hooks/60-depmod.hook`, and a drop-in replacing only the existing
cleanup service's command. It depends on rsync and kernel-modules-hook. Archive
checks pass (`build/kernel-tools-maintenance-package-test.log`); SHA-256:
`380f2d2a68faa68d34d84eacaf7dfa2ba2e7c220ae7b05425c62521258d9f6c1`.
The hook is a pacman backup file; a local override or pacnew requires review.
Installed-VM service activation, migration from legacy payload packages and
different-release reboot/rollback remain unverified. This is not yet a claim
that the full cleanup/update integration is complete.

## Rebuilding an unchanged hardware set

`oma-snap-kernel-queue --refresh ID` now explicitly moves a completed job back to
pending. The next worker allocates a new work directory and prepares a new boot
entry for the same hardware payload. Previous published entries and work
directories remain on disk. Pending/running/failed jobs are rejected by refresh;
failed attempts still require `--retry`. Ordinary duplicate package events stay
deduplicated. Race-enabled tests cover a successful new entry, failed refresh
with old evidence preserved, and rejection of duplicate/failed refresh requests.

This is the manual primitive needed for changed initramfs configuration or tools.
It does not yet detect those changes or schedule refresh automatically, and it
does not change the selected boot default. Tools `0.2.0-2`, now installed in the
VM, include the command; successful refresh through real staging remains pending.

## Omarchy orphan review integration

`0004-quattro-retained-kernel-orphans.patch` excludes content-addressed
`oma-snap-set-` packages from Omarchy's general orphan review. Other orphaned
packages keep the existing review/removal flow. Retained hardware requires a
coordinated boot-entry retirement path; the ALPM guard still protects direct
removal attempts. Filtering does not implement retirement or automatic pruning.

The profile preparation script applies this patch after the existing ARM profile
patch, and the profile test checks its presence. In a disposable ARM container,
the provider upgrade leaves set A as a real pacman orphan. The patched Omarchy
helper omits A while still listing an independently installed ordinary orphan.
This passes together with the provider upgrade/queue test:
`build/kernel-provider-orphan-test.log`. The patch is applied to the source
worktree and committed locally; the installed VM and built ISO do not yet carry
a rebuilt Omarchy package containing it.
