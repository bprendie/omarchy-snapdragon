# Local ARM installer testing

Only file-backed disposable disks are attached. The physical USB identified by
the user as `/dev/sda` is reserved for a later hardware test and is not part of
these commands. Re-identify it on the correct machine before any future write.

Start a fresh run with a previously unused direct child of `build/`:

```sh
OMA_SNAP_VM_DIR=build/install-vm-observed OMA_SNAP_SSH_PORT=2325 \
  bash scripts/test-installer-vm.sh > build/install-vm-observed-launch.log 2>&1
```

For the corrected kernel31 image, use a fresh directory and select it explicitly:

```sh
OMA_SNAP_TEST_ISO=dist/oma-snap-installer-kernel31-lists-arm64.iso \
  OMA_SNAP_VM_DIR=build/install-vm-kernel31 OMA_SNAP_SSH_PORT=2325 \
  bash scripts/test-installer-vm.sh > build/install-vm-kernel31-launch.log 2>&1
```

Substitute that test directory in the commands below. Its `iso.sha256` records
the image used. The `install-vm-observed` run failed at a missing bundled base
package list, with evidence saved before clean poweroff; its disk is retained.

The harness rejects an existing target, verifies the ISO checksum and reuses
stock Quattro's cidata fixture with ARM kernel/boot settings. QEMU stops at
reboot. It exposes only a localhost SSH forward with outbound networking
restricted. No physical disks are passed through.

`build/install-vm-observed/serial.log` persists console output. The matching
`serial.sock` accepts input independently of the launching shell's stdin:

```sh
printf '\noma-snap-live-ssh\n' | socat -t 3 - \
  UNIX-CONNECT:build/install-vm-observed/serial.sock
```

Run that after the live serial root shell starts. The helper enables the
image's dedicated live key, so live-root SSH uses
`private/thinkpad-live/id_ed25519`. The fixture's separate
`build/install-vm-observed/id_ed25519` is for the installed synthetic user.
Keep VM host keys in the test directory, separate from physical-host keys.

Collect `/var/log/omarchy-install.log`, `/run/omarchy-install/state.json` and
relevant archinstall logs before shutting down a failed live session. Its RAM
overlay is not preserved in `target.img`.

After confirmed installation completion and VM exit, boot the disk with no ISO
or cidata attached:

```sh
OMA_SNAP_VM_DIR=build/install-vm-observed OMA_SNAP_SSH_PORT=2325 \
  bash scripts/test-installed-vm.sh
```

This has a separate `installed-serial.sock` and `installed-serial.log`. QEMU's
disk locking prevents concurrent use. Reaching an installed desktop still
does not validate Qualcomm hardware, device-tree selection or physical power.

`scripts/smoke-initramfs.sh` separately tests a rebuilt 7.0.0-30 initramfs against
the preserved console ISO. It attaches no installation target or network and
retains a serial socket/log in `build/initramfs-smoke/`. This isolates the LCD
module-inclusion change from a kernel update; QEMU cannot exercise the LCD
drivers themselves.
