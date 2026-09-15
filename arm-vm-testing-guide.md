# Omarchy Dragon Project: ARM VM testing guide

Developer handoff, 15 September 2026. This describes the working Omarchy
Snapdragon test environment, including the experimental v0.3.0-dev Limine work.
It is a guide to the current scripts and the debugging workflow, not a claim
that the repository already has a single, unattended CI pipeline.

The useful result of this setup is that an x86_64 development machine can build
ARM packages, execute the real ARM kernel through UEFI, exercise the installer,
and test boot failures without repeatedly installing a physical laptop. We
still use physical machines for Qualcomm hardware behavior and the final
encrypted-unlock/desktop checks. Secure Boot is outside this project's scope.

For the distribution architecture and artifact origins, start with
[maintainer-handoff.md](maintainer-handoff.md). For the retained-kernel design,
see [the kernel update pipeline](docs/kernel-update-pipeline.md).

## 1. What runs where

There are three distinct execution environments. Keeping them separate avoids
several misleading kinds of “successful ARM test.”

| Environment | Implementation | What it establishes |
| --- | --- | --- |
| Packaging and VM host | Native Docker image `oma-snap-builder:local`, built from Ubuntu | Image extraction, SquashFS/ISO/FAT assembly, and execution of QEMU |
| ARM package/build environment | Arch Linux ARM root imported as `oma-snap-arch-base:local`; persistent container `oma-snap-root`; QEMU user emulation on x86_64 | ARM executables, pacman transactions, package construction and initramfs generation |
| Booted ARM machine | `qemu-system-aarch64`, `virt`, Cortex-A72, AArch64 UEFI | The guest kernel, initramfs, filesystems, service startup and bootloader handoff actually execute |

QEMU user emulation translates individual ARM processes while they use the
development host's kernel. Running `pacman` or `mkinitcpio` in that container
does not boot the Snapdragon kernel. Even `uname -m` reporting `aarch64` in
the build container is not proof of a guest-kernel boot.

Full-system QEMU executes a guest kernel and emulates its machine. Docker is
only the wrapper that supplies QEMU and its dependencies. On our x86_64 host,
these ARM guests use software CPU emulation; adding more guest CPUs does not
make this equivalent to native ARM hardware or enable x86 KVM acceleration.

The `virt` machine is not an emulated ThinkPad, HP or ASUS board. It has virtio
storage/network/graphics and generic UEFI hardware. A working virtual desktop
does not validate Qualcomm display, camera, audio, radio, NPU, EC, battery or
suspend behavior. Similarly, finding a firmware file or matching module
`vermagic` establishes a prerequisite, not a functioning peripheral.

## 2. Choose the smallest test that answers the question

| Question | Test layer | Typical resources and limits |
| --- | --- | --- |
| Does manifest validation, selection or command-line rendering work? | Go/unit tests | Host process; no boot required |
| Do ARM packages resolve and contain the required files? | ARM container and offline checks | No guest boot; preserve package signatures and repository inputs |
| Can this kernel/initramfs mount the intended root and retained hardware set? | Small component VM | Usually 4 GiB RAM, four vCPUs, small FAT loader plus a disposable root image |
| Can Limine launch the existing Stubble EFI image? | Bootloader component VM | Existing kernel and initramfs; no package installation |
| Can a read-only Btrfs snapshot reach a writable overlay root? | Snapshot component VM | 4 GiB RAM, 128 MiB FAT loader, 512 MiB Btrfs fixture in the recent experiment |
| Does the complete ISO reach its live environment? | Live ISO smoke test | Usually 8 GiB RAM, four vCPUs; no target disk |
| Does Quattro install correctly? | Installer VM and a separate installed boot | 40 GiB sparse target; 8–16 GiB RAM depending on copy-to-RAM requirements |
| Does an installed update select and reboot into the right kernel? | Existing installed VM | Preserve its disk; compare boot IDs and retained-set identities across actual reboots |
| Does the laptop unlock visibly and reach its desktop? | Physical smoke test | Required before making a physical-support claim |

The bootloader experiment once expanded into installing hundreds of desktop
packages under ARM emulation. That added hours without improving the evidence
for Limine's EFI handoff. Use a full installation when the installer or installed
system is the subject of the test. A mount hook should normally be debugged in
a tiny root fixture first.

## 3. Host preparation and artifact provenance

Commands below assume Bash and execution from the repository root. The host
needs Docker, Git, Python 3, OpenSSH, `jq`, checksum tools and enough storage for
the chosen test. Go tests currently declare Go 1.24 in the relevant modules.
Some preparation scripts also use host `xorriso`, `mkfs.fat`, `mkfs.ext4`,
`debugfs`, `socat`, `tar` and `xz`; installing the Docker builder does not make
those commands available directly on the host.

Build the native packaging/QEMU image:

```bash
docker build -t oma-snap-builder:local -f containers/Dockerfile.builder .
docker run --rm --network none oma-snap-builder:local \
  qemu-system-aarch64 --version
docker run --rm --network none oma-snap-builder:local \
  test -r /usr/share/qemu-efi-aarch64/QEMU_EFI.fd
```

[Dockerfile.builder](containers/Dockerfile.builder) pins an Ubuntu base-image
digest, but its apt package versions are not all pinned by that digest. Record
the image ID and actual QEMU/firmware versions with test evidence. A previously
cached image can also lack utilities added to a newer Dockerfile; check the
image you are actually running.

The ARM container needs working AArch64 `binfmt_misc`/QEMU user-emulation support
on an x86_64 host. Provision that through the development host's container or
OS tooling. An `Exec format error` when starting the ARM container is a host
emulation setup problem, not a Snapdragon kernel regression.

The original ARM bootstrap is implemented in
[create-arch-root.sh](scripts/create-arch-root.sh):

1. Verify the bootstrap signatures/checksums and selected repository metadata.
2. Import the authenticated Arch Linux ARM root archive as an ARM64 Docker image.
3. Start `oma-snap-root`, with `downloads/` and `sources/` read-only and `build/`
   mounted at `/output`.
4. Initialize the ARM keyring and prepare the build/package environment.

For a fresh bootstrap with the required inputs already fetched:

```bash
bash scripts/verify-inputs.sh
sha256sum -c manifests/repository-metadata.sha256
bash scripts/create-arch-root.sh
docker exec oma-snap-root /usr/bin/pacman --version
```

This is a historical bootstrap workflow, not a small prerequisite to every VM
run. It checks the Ubuntu bootstrap inputs as well as the ARM root archive and
performs a package transaction inside the new container. It intentionally
refuses to overwrite an existing `oma-snap-root` container.

[fetch-inputs.sh](scripts/fetch-inputs.sh),
[verify-inputs.sh](scripts/verify-inputs.sh), the `manifests/` directory and
[fetch-quattro.sh](scripts/fetch-quattro.sh) describe the original source and
input acquisition. Some URLs name rolling artifacts while manifests identify
a particular historical input; if a freshly downloaded artifact no longer
matches, recover the matching input or deliberately update the baseline and
its provenance. Do not disable verification to get the bootstrap to pass.

### Relationship to upstream's `dragon` branch

During this handoff, upstream requested contributions against
[`omacom/omarchy-iso:dragon`](https://github.com/omacom/omarchy-iso/tree/dragon).
At inspection its tip was `cac0cc26f8f295f5cfa94f1427aa2e90454814d0`, which
already merges ARM/Snapdragon support, platform profiles, live UKI/DSP setup,
ARM build configuration and additional unit tests. Its ancestor
`a23f8d464dcb0616a61bfaa8026e23d0533da209` is the installer revision pinned by
our original Quattro input manifest.

This guide documents our standalone lab and its prototypes. It does not imply
that upstream uses our Ubuntu-derived kernel provider, retained-set packaging,
or directory layout. When contributing, start from the current upstream
`dragon` branch, compare existing ARM behavior, and port only the missing
changes. The standalone repository's history is separate from omarchy-iso;
its entire history should not be rebased into the installer repository. Some
changes belong in kernel/hardware packages or Omarchy itself rather than the
ISO repository. Likewise, some scripts described here are still uncommitted
local development files and must accompany any documentation that depends on
them before a clean checkout can run those examples.

For routine testing, reuse authenticated baseline ISOs, known hardware sets,
and an existing builder. We do not need to re-extract Ubuntu on every iteration.
We do need the original package/source provenance when rebuilding the hardware
set itself. See [reproducibility.md](docs/reproducibility.md) for the distinction
between repeatable ISO packaging and a complete independent rebuild.

Useful read-only inventory before working in an existing checkout:

```bash
docker ps -a --format '{{.Names}} {{.Status}}'
docker image inspect oma-snap-builder:local --format '{{.Id}}'
docker inspect oma-snap-root --format '{{json .Mounts}}'
du -sh build downloads
```

## 4. The development test loop

Use this sequence for each bounded change:

1. **Write the question and stop condition.** For example: “The selected
   read-only snapshot reaches PID 1 with a writable overlay, and its retained
   module/firmware directories are mounted.” Define the expected PASS marker.
2. **Record the inputs.** Kernel release alone is insufficient: record the
   hardware-set ID, boot-entry ID, kernel and initramfs hashes, runtime package
   versions, bootloader configuration and source revision/local diff.
3. **Run the relevant fast checks.** Test the changed parser or state machine;
   check package contents and dependencies when those changed.
4. **Build one candidate.** Preserve the working boot assets. Use a new staging
   directory and a separate candidate manifest.
5. **Inspect the produced artifact.** Extract the actual initramfs, verify
   embedded hooks and identity, then validate the EFI/ESP copy. A correct source
   tree does not prove that the packaging step selected those files.
6. **Run the smallest full-system VM.** Capture serial output from startup.
   For regressions, first demonstrate the old failure, then run the changed
   candidate against the same fixture.
7. **Classify the result.** Pass only if the expected postconditions appear.
   An emergency shell, reboot, exited container or successful build is not
   equivalent to passing a boot test.
8. **Escalate only when needed.** Move to the installed VM or physical machine
   once the smaller test resolves the software question. Stop and review when
   the agreed test has answered it.

There is no reason to rerun an unchanged full package transaction after every
hook edit. Conversely, a VM fixture that omits the relevant target runtime is
not sufficient evidence just because it passes quickly.

### Fast suites

The Go tools are separate modules. Run the module associated with the change:

```bash
(cd tools/limine-feasibility && go test ./...)
(cd tools/boot-stage && go test ./...)
(cd tools/boot-publish && go test ./...)
(cd tools/kernel-set && go test ./...)
```

These are examples, not a required four-module sequence for every edit. For a
deliberate broad source regression pass, iterate the modules in separate
subshells rather than assuming the repository root is one Go module:

```bash
set -euo pipefail
for module in tools/*/go.mod; do
  directory=${module%/go.mod}
  printf '\nTesting %s\n' "$directory"
  (cd "$directory" && go test ./...)
done
```

The pinned Quattro checkout has a VM-free entry point:

```bash
bash sources/omarchy-iso/test/all
```

It runs the upstream shell unit tests and Python unittest discovery. Use the
checkout containing the actual installer changes when testing a patched fork;
a pass in an untouched upstream checkout does not cover a different packaged
orchestrator. Upstream `test/integration` is a separate, broader workflow and
must not be assumed to have our ARM machine/firmware configuration.

Our scripts named `test-*.sh` are not all unit tests. Several create disk images,
run privileged loop mounts or reboot a VM. Select them individually after
checking their inputs; do not execute every shell script in a blanket test loop.

For package work, the version-specific offline checks use `pacman -Sp` against
the staged repository/database to resolve the transaction without installing
it. For example, [verify-v022-offline.sh](scripts/verify-v022-offline.sh) requires
the v0.2.2 root and package lists and a fresh output directory. Dependency
closure, package-signature checks and `pacman -Qkk` integrity checks answer
different questions; none substitutes for a boot test.

## 5. Boot the complete ISO without installing it

For an existing numeric release ISO at the repository root:

```bash
bash scripts/smoke-snapdragon-iso.sh 0.2.2
```

This checks the ISO checksum and launches the complete ISO as read-only virtual
USB storage. It attaches no install target and provides no guest network. The
default is 8 GiB RAM; `OMA_SNAP_VM_RAM` adjusts this launcher. It refuses to
overwrite an existing serial log in its version-specific test directory.

This launcher accepts numeric versions such as `0.2.2`, not `0.3.0-dev`.
For the development image, use the parameterized live harness with a `dist/`
path, or make a narrowly scoped launcher copy. Do not quietly change its version
argument validation and assume other hard-coded paths also changed.

An SSH-capable live smoke test can use:

```bash
OMA_SNAP_TEST_ISO=omarchy-snapdragon-v0.2.2.iso \
OMA_SNAP_VM_DIR=build/live-review-01 \
OMA_SNAP_SSH_PORT=2326 \
  bash scripts/smoke-installer-live.sh
```

That harness uses restricted QEMU user networking. A localhost port forward
allows host-to-guest SSH if sshd is running, but `restrict=on` isolates ordinary
outbound guest traffic. It is appropriate for offline tests; it is not an online
package-update test. Docker's `--network host` alone does not remove this guest
network restriction.

The live test should check the intended kernel, root filesystem, installation
medium, and failed services, then capture the welcome screen if relevant. A
welcome screen proves live userspace startup, not installation completion.

## 6. Installer VM and installed boot

[test-installer-vm.sh](scripts/test-installer-vm.sh) creates a new 40 GiB sparse
target and attaches the ISO plus a CIDATA configuration disk. It reuses stock
Quattro's fixture generation through [make-install-fixture.sh](scripts/make-install-fixture.sh),
then patches ARM kernel/boot fields and optionally encryption.

The harness requires an ISO directly under `dist/`. To use a release ISO already
at the repository root, stage a copy without consuming a second full allocation
where reflinks are supported, and write a checksum that names that copy:

```bash
mkdir -p dist build
test ! -e dist/dragon-review.iso
sha256sum -c omarchy-snapdragon-v0.2.2.iso.sha256
cp --reflink=auto --sparse=always \
  omarchy-snapdragon-v0.2.2.iso dist/dragon-review.iso
sha256sum dist/dragon-review.iso > dist/dragon-review.iso.sha256
```

Then, with a new test directory/name/port:

```bash
set -o pipefail
OMA_SNAP_TEST_ISO=dist/dragon-review.iso \
OMA_SNAP_VM_DIR=build/install-review-01 \
OMA_SNAP_VM_NAME=oma-snap-install-review-01 \
OMA_SNAP_SSH_PORT=2325 \
OMA_SNAP_VM_ENCRYPT=1 \
  bash scripts/test-installer-vm.sh 2>&1 | tee build/install-review-01-launch.log
```

The disposable fixture uses the synthetic user/password `omarchy`/`omarchy`.
The encryption passphrase is `omarchy-vm-only`. These are public test values;
they are not credentials for a physical machine. The fixture creates its own
SSH key in the run directory.

The generic installer harness uses 8 GiB RAM and `-no-reboot`, so an installer
reboot ends that QEMU invocation. Its fixture explicitly configures GRUB and
the original ARM kernel provider. It is not a generic Limine migration test.
Confirm the image's installer overlay is the one the experiment expects.

Once installation has completed and that QEMU process exits, boot only the
target disk:

```bash
OMA_SNAP_VM_DIR=build/install-review-01 \
OMA_SNAP_VM_NAME=oma-snap-installed-review-01 \
OMA_SNAP_SSH_PORT=2325 \
  bash scripts/test-installed-vm.sh
```

The installed harness does not attach the ISO or CIDATA, and it allows in-guest
reboots. This distinction matters: success with the installer medium attached
can hide a missing installed bootloader or an accidental boot into the live ISO.

For encrypted installed roots, perform the unlock before expecting SSH. Check
`cat /proc/cmdline`, `findmnt /`, `uname -r`, and `/proc/sys/kernel/random/boot_id`
inside the guest. During an update/reboot test, require a new boot ID and the
expected selected hardware-set/boot-entry identities. An SSH response alone may
be the old session or a different VM using the same forwarded port.

The dedicated `scripts/test-limine-v030-vm.sh` (not yet published) is a local
prototype using 16 GiB RAM, port 2330, and fixed `build/limine-v030*` paths. Its
larger RAM allowance accommodates the live copy-to-RAM configuration. It relies
on prebuilt loader assets and CIDATA; it is not a clean-checkout bootstrap.
Its networking differs from the restricted generic harness. Preserve the
existing paused installation experiment instead of launching over its disk.

## 7. Observe the guest: serial, SSH and QMP

Three independent channels are useful:

* **Serial log:** durable text from firmware/kernel/initramfs and console.
* **Serial socket:** input to the guest console even if the launcher has no stdin.
* **QMP socket:** machine control and framebuffer capture, independent of guest SSH.

For the generic installer run:

```bash
tail -n 80 build/install-review-01/serial.log
socat -,rawer,escape=0x1d UNIX-CONNECT:build/install-review-01/serial.sock
```

The second command is an interactive console; Ctrl-] exits socat. A socket
existing on disk does not establish that a live process is listening. Serial
input also does not guarantee a usable emergency shell: we encountered shells
without working keyboard/TTY access on physical hardware.

Live sshd may need activation from the console with the image's
`oma-snap-live-ssh` helper. That helper uses a build-specific live key. The
original development checkout has private keys, but those are not a dependency
we can hand to another maintainer. Configure a disposable live key for your
own image or use the serial console. The CIDATA key is a separate credential
for the synthetic installed user:

```bash
ssh -i build/install-review-01/id_ed25519 -p 2325 \
  -o IdentitiesOnly=yes \
  -o UserKnownHostsFile=build/install-review-01/known_hosts \
  omarchy@127.0.0.1
```

Check source fixtures if using another scenario: some installed update tests
explicitly use root and different ports. Do not reuse physical-host known-host
files to hide VM host-key changes.

The generic installer QMP socket is `qmp.sock`; the generic installed harness
uses `installed.sock` for QMP and `installed-serial.sock` for serial. The Limine
prototype uses `install-qmp.sock` or `installed-qmp.sock`. Read the launcher to
avoid sending JSON to a console socket.

This short host-side QMP example queries status and captures the framebuffer:

```bash
python3 - <<'PY'
import json
import socket

with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
    sock.settimeout(10)
    sock.connect('build/install-review-01/qmp.sock')
    stream = sock.makefile('rwb')
    print(json.loads(stream.readline()))  # QMP greeting

    def command(name, arguments=None):
        message = {'execute': name, 'id': name}
        if arguments is not None:
            message['arguments'] = arguments
        stream.write(json.dumps(message).encode() + b'\n')
        stream.flush()
        while True:
            reply = json.loads(stream.readline())
            if reply.get('id') == name:
                if 'error' in reply:
                    raise RuntimeError(reply['error'])
                return reply['return']

    command('qmp_capabilities')
    print(command('query-status'))
    command('screendump', {'filename': '/work/install-review-01/screen.ppm'})
PY
```

The screenshot filename is interpreted inside the QEMU container. In this
launcher `/work` maps the host `build/` directory; another launcher may map only
one run directory there. A graphical device must be present for a useful
framebuffer. Convert the PPM to PNG with your normal image tooling if needed.

After the capability handshake, QMP `stop` pauses guest CPUs and `cont` resumes
them. A Docker container can be “running” while its QEMU guest is paused. SSH
will not respond during that pause. A paused guest's RAM is not made durable
merely because `target.img` is persistent: stopping the QEMU process loses that
in-memory state. `system_powerdown` requests guest shutdown; `quit` exits QEMU
and should be used only after deciding what state can be discarded.

Collect installer logs before shutting down a failed live session:
`/var/log/omarchy-install.log`, `/run/omarchy-install/state.json`, relevant
archinstall logs, `journalctl -b`, and `systemctl --failed`. Data in the live
RAM overlay is not necessarily saved in the target disk.

## 8. Retained-kernel component and rollback fixtures

The retained-kernel pipeline deliberately distinguishes a **hardware-set ID**
from a **boot-entry ID**. The same kernel release and hardware set can have
different initramfs builds. A regression check based only on `uname -r` will
miss a wrong-initramfs selection.

[prepare-kernel-set-boot-vm.sh](scripts/prepare-kernel-set-boot-vm.sh) consumes a
completed staging build with `built.json`, `initramfs.img` and `boot-set`.
It copies the retained set, checks its hashes, creates a small root with a
BusyBox PID 1, and packages a UEFI loader. The paired
[test-kernel-set-boot-vm.sh](scripts/test-kernel-set-boot-vm.sh) requires:

```text
OMA_SET_BOOT_PASS: <hardware-set-id> <boot-entry-id>
```

Its [PID 1 assertions](tests/kernel-set-boot-init) inspect the running release,
embedded identities, writable root, read-only module/firmware mounts, module
indexes and selected firmware prerequisites. It rejects explicit FAIL markers
and refuses a pre-existing serial log, preventing a stale success from being
mistaken for the current boot.

Important current limitations: the preparation script accepts historical
`*-generic` releases, not `*-qcom-x1e`, hard-codes `oma-snap-root` for one GRUB
build step even though it accepts a builder argument, and assumes specific
staging artifacts. The PID 1 firmware checks also target the older model set.
Treat it as a useful component pattern, not an unmodified v0.2.2 launcher.

Other retained-kernel tests have separate scopes:

| Script | Scope and prerequisites |
| --- | --- |
| [test-kernel-boot-select.sh](scripts/test-kernel-boot-select.sh) | FAT publication/selection using two staged builds; uses a privileged container for loop mounting a file-backed ESP |
| [test-kernel-rollback-vm.sh](scripts/test-kernel-rollback-vm.sh) | Same-release A/B/A initramfs selection, separate root copies and actual component boots |
| [test-installed-abi-rollback.sh](scripts/test-installed-abi-rollback.sh) | Historical installed ABI30 → ABI31 → ABI30 test; requires prepared `build/kernel-update-vm`, specific scripts/logs, root SSH and a running installed VM |

The last script is not a generic “test my latest ISO” command. It deliberately
changes boot selection and reboots the existing disposable guest. Its readiness
check compares boot IDs, which is the right pattern to preserve when adapting it.

## 9. The Limine snapshot test: construction and lessons

The latest work proved two different things on the HP:

1. The v0.3.0-dev installation booted through Limine into the encrypted normal
   root and Omarchy desktop, retaining a GRUB recovery menu entry.
2. A separately built snapshot candidate booted snapshot 2 into the desktop;
   `/etc/snapshot_001` existed, `/etc/snapshot_002` did not, and `findmnt` reported
   `overlay` for `/`.

That is evidence for snapshot **boot**, not automatic menu maintenance or
permanent restore. Those integrations are still unfinished. Presence of the
GRUB entry is also not evidence of a separately executed GRUB recovery boot.

### Why the snapshot image differs from the normal image

The normal feasibility menu chainloads the existing Stubble EFI kernel using
Limine `protocol: efi`, with an external initramfs named in `initrd=`. This is
not Limine's native Linux loading protocol.

The inspected `limine-snapper-sync` 1.31.0 code tracks image paths such as
`path:` and `module_path:`, but does not collect the file referenced by our
external `initrd=` command-line argument. For the snapshot experiment, we added
the initramfs as a `.initrd` section to a copy of the existing Stubble image.
The resulting single EFI file retains the kernel, device-tree sections and
initramfs together. The snapshot menu omits the external `initrd=` argument.

The builder uses Stubble's own `stubblify` PE-section implementation, with
`pefile`, and checks that the original PE sections are preserved and the embedded
initramfs hash matches. Sources and pinned revisions are recorded in the local,
not yet published `docs/limine-v0.3.0-dev.md` development notes.

### Small Btrfs fixture

The local prototype artifacts are under `build/limine-snapshot-vm/`. They are
ignored, not included in a clean Git checkout. Its `run.sh` and `package.py` are
development artifacts; promote a parameterized version before treating them as
shared CI infrastructure. Local supporting files include
`tests/snapshot-fixture-hook`, `tests/snapshot-root-init`, the retained-set hook,
and the overlay compatibility patch. The snapshot fixture files and latest
hook changes are not yet published with this guide.

To reconstruct the fixture, the meaningful steps are:

1. Prepare a tiny `seed/` root with BusyBox, its ARM dynamic loader/libraries,
   `/sbin/init` from `tests/snapshot-root-init`, `/etc/snapshot_001`, the usual
   mountpoint directories, and fixture retained module/firmware directories.
   BusyBox here is dynamically linked; copying the executable alone is not
   enough. The marker files in the retained directories contain `retained`.
2. Make a 512 MiB Btrfs image using `mkfs.btrfs --rootdir`. The top-level seed
   initially contains ordinary files; the early fixture hook creates real Btrfs
   subvolumes once the guest kernel is running.
3. Build an initramfs with virtio block/PCI, Btrfs and overlay modules, BusyBox,
   udev, the fixture hook, `btrfs-overlayfs`, and `oma_snap_set`. Embed a
   three-line `boot-set` identity: hardware-set ID, release, boot-entry ID.
4. Bundle that initramfs into the existing Stubble kernel. Put it and Limine's
   `BOOTAA64.EFI` in a 128 MiB FAT image.
5. Attach the loader first and the Btrfs root second as virtio block devices.
   In this exact layout the root is `/dev/vdb`. Use `snapshot=on` on the root
   drive so the fixture base file survives a test run unchanged.
6. The early hook mounts `/dev/vdb`, creates `@`, copies `seed/` into it, takes
   a read-only snapshot at `@/.snapshots/2/snapshot`, adds `snapshot_002` only to
   the current root, and unmounts the setup mount.
7. The real initramfs mounts the selected snapshot, applies the overlay, runs
   the retained-set late hook and switches into the tiny PID 1 test.

The minimal configuration used in the local fixture is:

```bash
MODULES=(virtio_pci virtio_blk btrfs overlay)
BINARIES=()
FILES=()
HOOKS=(base udev oma_snapshot_fixture btrfs-overlayfs oma_snap_set)
COMPRESSION="zstd"
COMPRESSION_OPTIONS=(-1 -T2)
```

Its Limine command line is specific to the two-disk fixture:

```text
root=/dev/vdb rootfstype=btrfs rootflags=subvol=@/.snapshots/2/snapshot ro console=ttyAMA0,115200 clk_ignore_unused pd_ignore_unused arm64.nopauth
```

The PID 1 program checks the first marker exists and the second does not, root
has filesystem type `overlay`, fixture module/firmware content is accessible,
and a root-overlay write succeeds. It emits `SNAPSHOT_VM_PASS` and powers off.
The placeholder retained set is intentionally not the full hardware payload.
This VM does not test LUKS, a full desktop, automatic snapshots or restore; the
subsequent physical HP test supplies the encrypted desktop evidence.

The current prototype should be hardened before CI: its FAIL handler relies on
`poweroff -f` succeeding; bind-mount validation should explicitly inspect mount
tables as the retained-kernel fixture does; and its runtime layout must be
constructed faithfully from the target version. Do not turn a marker check into
a stronger claim than its assertions support.

### The regression that escaped the first fixture

Two independent issues mattered:

* **Runtime layout:** newer mkinitcpio mounts `/sysroot` and supplies
  `/new_root` as a compatibility symlink. Our retained-set hook compared a
  canonicalized path with a literal `/new_root/...` string and rejected the
  difference as `substituted set directory`. The corrected hooks select and
  canonicalize the root mountpoint before validating paths below it. Preserve
  checks against substituted retained-set directories; the root alias is the
  part that needed compatibility handling.
* **Packaging selection:** the uploaded hooks were mode `0644`; installed
  legacy hooks were executable. Bash `type -P`, used by mkinitcpio, preferred
  executable installed copies later in PATH. The local VM did not have the
  same competing installed hook, so a passing fixture did not prove the HP
  candidate actually contained the changed source.

The candidate builder now sets all four custom build/runtime hooks to `0755`,
verifies their resolved paths before building, extracts the finished initramfs,
and compares embedded hook hashes to the staged inputs. It also verifies the
expected root directory exists. These checks caught an incorrect candidate
before another physical reboot.

Match the target's `init`, `init_functions`, base layout, hook implementations,
runtime binaries and libraries. In this investigation the HP and builder
BusyBox hashes were identical; a suspected BusyBox-version difference was not
the cause. Copying only the HP's init script into an older base layout was not
an exact reproduction either. The permission/selection check was the decisive
missing packaging test.

Useful inspection commands in the ARM build environment are:

```bash
lsinitcpio -c /path/to/candidate/initramfs.img
mkdir /path/to/fresh-inspection-directory
cd /path/to/fresh-inspection-directory
lsinitcpio -x /path/to/candidate/initramfs.img
sha256sum hooks/oma_snap_set hooks/btrfs-overlayfs
ls -ld sysroot new_root
cat etc/oma-snap/boot-set
```

Use the actual selected entry's initramfs. `/etc/mkinitcpio.conf` on the installed
HP was a stock systemd-hook configuration; our retained-entry builder instead
uses `/usr/share/oma-snap/kernel-update/mkinitcpio.conf`, appending
`oma_snap_set`. Inspecting the wrong config would have sent debugging in the
wrong direction.

Also, the partial message “root device is not configured to be mounted” was
part of a warning about a read-only root and possible later fsck. It was not
the fatal retained-set error. Capture the complete error sequence rather than
diagnosing from the last memorable line on screen.

## 10. Physical handoff after a VM pass

For the snapshot experiment we copied a small candidate bundle to the HP over
SSH, then the owner ran privileged commands locally because passwordless sudo
was not available. A new ISO was unnecessary.

The local, not yet published `scripts/build-limine-snapshot-candidate.py`
is currently an HP/snapshot-2 experiment, not a general release builder. It
requires the sibling pinned `stubblify`, `pefile` wheel and custom `initcpio/`
hooks; the installed retained set; an intact snapshot 2; and the expected marker.
It verifies inputs, creates a fresh `/var/tmp/limine-snapshot-*` directory,
builds and inspects the image, and emits `candidate.json` without changing the ESP.

The local, not yet published `scripts/install-limine-snapshot-test.py`
checks that manifest and its hashes, snapshot state and ESP space, backs up
`limine.conf`, copies the candidate to a separate ESP path, and appends or
replaces the temporary test entry. The normal boot remains first; GRUB recovery
is retained. Replaced experimental images remain on the ESP for review.

Select the temporary snapshot explicitly. The default normal boot produces
`btrfs` with both markers; the snapshot boot produces `overlay` with only
`snapshot_001`. This distinction caught an accidental default boot during the
physical test. `/home` is excluded from the root snapshots, so markers under
`~/` do not test root rollback.

Writes to the root overlay disappear on reboot; separate mounts such as home
remain persistent. Return to the normal entry before routine use or package
updates. Automatic snapshot-menu synchronization and permanent restoration
are still separate next steps, and the temporary menu can be replaced by the
normal menu refresh path.

## 11. Evidence, disk usage and lifecycle discipline

Save a small evidence bundle per run:

```text
run-directory/
  inputs.txt              # source revisions, image ID, package/runtime versions
  candidate.json          # boot/hardware identity and payload hashes
  limine.conf or grub.cfg  # exact selected paths and command line
  launch.log
  serial.log
  screen.png              # if visual behavior is part of the test
  guest-checks.txt         # markers, mounts, boot ID, failed services
  result.md               # question, result, limitation, next step
```

Record timestamps and whether evidence came from a component VM, complete live
image, installed VM or physical machine. For an A/B comparison keep separate
logs and assets, and verify the command line in the guest. We hit a local
fixture race when two packagers wrote one shared `limine.conf`: one loader
referred to the other candidate's absent EFI file. Mode-specific config paths
fixed it. Parallel VM runs need distinct configs, disks, container names, ports,
QMP sockets and serial sockets—not just different log names.

Keep private machine captures and credentials out of the public evidence bundle.
`build/`, `downloads/`, `sources/`, `dist/` and `private/` are ignored by Git.
The repository deliberately permits root release ISO filenames, so inspect the
staged file list explicitly before committing documentation or code.

Sparse disks can have a large apparent size without that much physical use:

```bash
ls -lh build/install-review-01/target.img
du -h build/install-review-01/target.img
```

Use fresh test directories. Preserve useful disks with sparse/reflink-aware
copies before a test that changes them. A QEMU `snapshot=on` drive discards
guest changes when that QEMU process exits; it is not a persistent installed
baseline and is unrelated to the Btrfs snapshots being tested inside the guest.

Stop only the containers you created for the test. The development environment
has previously retained a partially installed VM paused through QMP; do not
stop or remove it merely because it appears idle. Avoid blanket Docker pruning.
When reclaiming space, retain firmware/source provenance, required build inputs,
one useful baseline and the small diagnostic evidence; disposable duplicate
images and scratch extraction trees are the first candidates to remove.

## 12. What remains before this becomes shared CI

The immediate reusable assets are the Go suites, Quattro's VM-free suite, the
file-backed VM patterns, component PID 1 assertions, build-artifact validation,
and the physical-test protocol. The next engineering work is to:

1. Promote the ignored snapshot fixture packager/launcher into parameterized,
   tracked tooling with explicit inputs and bounded completion checks.
2. Pin or record build-runtime packages and assert the generated root layout,
   hook selection and hashes, including a deliberately competing legacy hook.
3. Remove historical release/path assumptions from the relevant launchers;
   make network mode, memory and unique run directories explicit.
4. Export machine-readable results with complete artifact identities and retain
   failure evidence automatically before ending a live VM.
5. Integrate stock snapshot menu generation and test update → reboot → snapshot
   boot → permanent restore as separate, staged acceptance checks.

The latest HP result is a useful milestone: the selected encrypted snapshot
reached the Omarchy desktop. It is not a reason to expand every edit into a
complete installation. Preserve that evidence, and select the next test by the
specific behavior that changed.
