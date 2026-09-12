# Installer rebuild after physical unlock validation

User confirmed both the visible text unlock and stock Omarchy graphical unlock
on the installed LCD ThinkPad, with successful desktop boots. The next artifact
is `dist/oma-snap-installer-kernel31-unlock-arm64.iso` (built).

Payload changes from the kernel31-lists ISO:

- Boot package 0.1.0-4 includes missing early display dependencies, the Plymouth
  hook for installed roots and `quiet splash` in the generated boot entry.
- Installer source includes the corrected packaged-kernel validator, replacing
  the stale kernel30 expectation that stopped the physical install at 99%.
- Live initramfs gets the same early display dependency coverage.
- Kernel, firmware, stock Omarchy runtime/settings and signed upstream package
  inputs remain pinned to the existing hardware-tested set.

The old ISO remains in dist. Previous assembly/root export/live initramfs,
superseded boot packages and mirror index are preserved in
`build/pre-unlock-iso/`. Historical manifests copied there retain their original
paths as provenance; they are not checks for the relocated files. Current
manifests identify current staging. The old partial installation VM stays paused;
the new full-install test uses a separate container, directory and SSH port.

Checks completed before assembly: stock installer shell suite and 72 Python
tests, boot-helper Go tests/vet and build, physical graphical unlock/desktop,
offline package hashes and dependency closure. Whole-ISO installation and
installed-system boot checks are pending. Do not describe this as a verified
end-to-end installation until those checks actually finish.

ISO size: 6,865,119,232 bytes. SHA-256:
`23c9f8ae542e7ad65a2bd66d70b9335cab1d547415fb4c28a1d1b0ab8944b67e`.
User reauthorized `/dev/sda`; reidentified on HP Dragonfly as unmounted,
115.5 GiB removable USB DISK 3.0. Wrote with pkexec dd/conv=fsync, then read
the full image length with direct I/O. Readback SHA matches the ISO exactly.
USB powered off with udisksctl. Evidence: `build/usb-unlock-*`.

Fresh VM: `oma-snap-install-unlock-test`,
`build/install-vm-kernel31-unlock/`, SSH port 2327. New ISO boots its live
system and starts stock unattended installation via the fixture. Live SSH was
enabled through the serial console with `oma-snap-live-ssh`; project diagnostic
key works, and the guest reports boot package 0.1.0-4. Installation is still in
progress; no completed installation or installed-VM boot is claimed yet.

User has started a physical installation from the newly written USB and reports
a gcc-x1e80100 clock-controller sync_state message. Similar `pending due to`
messages exist in the prior successful graphical-unlock boot journal (PCIe,
GMU, video and camera suppliers). Exact new line is not yet provided. Do not
infer installation failure or change clock parameters from that message alone;
physical completion/first boot are still pending.

## Physical installation: PASS

User reports the new USB installation completed and displayed the Omarchy
completion splash with elapsed time **3m30s**. This clears the previous 99%
installer failure on the actual ThinkPad. The sync_state warning did not block
installation. First boot of this fresh installation (graphical disk unlock and
desktop) remains to be confirmed; earlier graphical unlock validation was on
the previous installation, not this freshly installed root. Factory snapshot
creation has not been independently inspected on the new installation.

## Fresh installed boot: PASS

User rebooted after the completed installation, was asked for the passphrase,
and reached the Omarchy desktop. Combined with the preceding completion report,
this validates the current ISO's physical installation and first installed boot
end-to-end on this Snapdragon X Elite / 32 GB / LCD ThinkPad. No manual boot
repair was reported for this fresh install. This is the working installer MVP.

Charging still requires unplug/replug and is explicitly deferred. Repeated
boots, suspend/resume, update/rollback, independent factory snapshot inspection
and full rebuild reproducibility remain separate validation tasks. Do not
extend the physical success claim to other Snapdragon models or panels.
