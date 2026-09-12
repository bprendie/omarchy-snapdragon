# ThinkPad hardware-test handoff

Updated 2026-09-12: the next milestone is a stable, interactive Omarchy splash
or installer welcome screen on the Snapdragon X Elite T14s (32 GB, LCD), plus
live SSH for diagnostics. Full VM installation is not a prerequisite. This
is an experimental hardware-test candidate; full installation and installed
boot remain unproven. Do not start disk installation during this live-boot test.

## USB and first boot

Use `dist/oma-snap-installer-kernel31-lists-arm64.iso` and its adjacent SHA-256 file. Write it
as a disk image to the intended USB, rather than copying the ISO as a file.
The user identified `/dev/sda` as a candidate USB. Recheck the machine, model,
capacity and mounts before a write; that path is not a permanent device identity.
On 2026-09-12, the user authorized writing the development host's unmounted,
removable 115.5 GiB USB DISK 3.0 at `/dev/sda`. `dd` completed with `conv=fsync`;
a direct read of all 6,864,961,536 image bytes matched the ISO SHA-256. Readback
evidence: `build/usb-kernel31-lists-readback.sha256`. The ThinkPad's internal
storage was not modified. This verifies the write, not physical boot success.

Size: 6,864,961,536 bytes (about 6.4 GiB). SHA-256 reverified 2026-09-12:

```text
9a87a44cd944c87d2496e5a546e224553ba0d8c76a83801d8c3f64cad8825f1b
```

Boot the USB using the ThinkPad's one-time firmware boot menu. This build is
intended for testing with Secure Boot disabled; complete Secure Boot support
is unverified. Keep the working Ubuntu installation and its boot entry intact.
First establish a live session and inventory before choosing installation
storage. Returning to Ubuntu should require removing the USB and selecting
its existing boot entry; physical recovery is not yet tested.

## Enable live SSH

At the installer welcome screen, press **Ctrl+C** to return to its live root
shell. Connect Ethernet, or run `nmtui` to connect Wi-Fi. Then run:

```sh
oma-snap-live-ssh
```

Send the displayed LAN IP address and SSH host fingerprint to the assistant.
The development machine must be able to reach that network. No router port
forwarding is needed for access on the same LAN.

Only the dedicated public key is included in the image. The corresponding
private key stays in `private/thinkpad-live/id_ed25519` on this development
machine. SSH starts only when the command above is run, accepts public-key
authentication for live root, and generates host keys locally. It does not
configure SSH on the installed target. The live session and its changes are
discarded on reboot. To stop access, run `systemctl stop sshd`.

To return to the installer on that console, run `bash /root/.automated_script.sh`.

After the host fingerprint is verified, the development-side connection is:

```sh
ssh -i private/thinkpad-live/id_ed25519 \
  -o UserKnownHostsFile=private/thinkpad-live/known_hosts root@THINKPAD_IP
```

## Known limits

- This candidate has kernel 7.0.0-31, added LCD/backlight initramfs modules and
  corrected bundled package lists. The old default `oma-snap-installer-arm64.iso`
  was removed during authorized cleanup; use the explicit filename above.
- Prior physical attempts had USB-backed SquashFS errors and a black screen
  after forcing copy-to-RAM. Their causes and resolution remain unconfirmed.
  Live SSH currently requires reaching the shell and enabling it manually;
  a failure before that point may still require a diagnostic boot revision.

- Base installation succeeded in the VM. Later swap/audio package omissions
  were found and fixed in the offline mirror; the whole installation is unproven.
- The previous candidate's stock welcome screen rendered correctly with
  C.UTF-8 and zero failed live systemd units. This does not prove T14s graphics.
- Factory reset and automatic snapshot restore are disabled for this prototype
  because the stock implementations assume Limine. Kernel/desktop update holds
  remain until coordinated update and recovery behavior is implemented.
- Protected-ESP firmware entry selection, encryption, suspend, battery behavior,
  accelerated graphics, audio, Wi-Fi and other physical devices remain unverified.
- Stock cloud/AI provisioning is retained. Some optional packages remain absent
  from the selected ARM repositories; see the profile package exclusions.

If live boot fails, capture the last visible message or a photo. If it boots,
SSH lets us collect the actual kernel, devices, graphics and installer logs
before deciding the next remediation.
