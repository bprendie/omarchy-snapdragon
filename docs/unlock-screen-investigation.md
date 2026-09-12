# Invisible unlock prompt — 2026-09-12

Priority: prove a visible LUKS prompt on the installed physical ThinkPad before
rebuilding the end-to-end installer ISO. Charging experiments are paused.

The installed boot helper uses `/usr/share/oma-snap/mkinitcpio-installed.conf`,
not the distribution's default `/etc/mkinitcpio.conf`. Its BusyBox `encrypt`
hook accepts the passphrase while the LCD is black. After root unlock the
native desktop works, with tty0 active and msmdrmfb registered.

The recovered installed initramfs listing includes panel-edp, pwm_bl and
leds-qcom-lpg but omits several drivers loaded in the running system. The boot
journal records deferred GPU probing for the QFPROM fuse, SMEM waiting for a
hardware spinlock, ADSP waiting for SMEM, and DP bridges waiting for downstream
bridges. MSM framebuffer registration occurs after root userspace starts.
This supports an incomplete early display dependency graph as the working
hypothesis, not yet a hardware-verified fix.

The shared Qualcomm initcpio hook now adds nvmem_qfprom,
nvmem_qcom_spmi_sdam, qcom_hwspinlock, qrtr_smd, ps883x, gpio_shared_proxy,
reset_gpio, display_connector and simple_bridge. The exact kernel device tree
links external DP paths through PS8830 retimers and an RTD2171 HDMI bridge;
those paths can delay the shared display driver even when only the LCD is used.
Boot package release is incremented to 0.1.0-3. No UCSI blacklist or charging
workaround is introduced.

Hardware candidate is built in `build/unlock-test/`, using the existing
kernel31 and installed-root initramfs configuration. The deployment helper
`scripts/apply-unlock-test.sh` checks the original GRUB configuration and input
checksums, stages a separate initramfs, and adds a test menu entry selected by
default. The original image and menu entry remain available. The test remains
selected until explicitly restored; it is not a one-boot GRUB selection.
The helper's `restore` argument restores the original configuration after
checking that the active file is still the test configuration.

Validation: boot helper Go tests/vet and package build passed. Initramfs build
passed; content checks confirm the added modules, encrypt hook and cryptsetup.
GRUB syntax check and shell syntax check passed. Optional unrelated firmware
warnings and an unset console font were reported by mkinitcpio.
Candidate SHA-256:
`7e8d1230410284b9df1ab0c2f9277dba176734db184b0411ab13c36379adf374`.
Staged as `~/unlock-test/` on the installed ThinkPad, with checksums verified
again after transfer. No ISO rebuild or target boot change has occurred yet.

Next user step, after saving work:
`sudo bash ~/unlock-test/apply.sh && sudo reboot`.
Confirm the visible prompt before typing the passphrase, then verify desktop
and kernel journal over SSH. The original entry is named `Omarchy Snapdragon`;
the selected candidate is `Omarchy unlock test`. If rollback is needed from
the desktop: `sudo bash ~/unlock-test/apply.sh restore`.

## Physical text-prompt result: PASS

User ran the helper and rebooted. They saw the passphrase prompt among kernel
output, entered the passphrase, and reached the Omarchy desktop. SSH journal
confirms MSM/framebuffer registration before root userspace begins, replacing
the prior deferred-display behavior. Evidence is saved privately as
`unlock-test-boot.txt`. This validates the combined dependency addition; it
does not establish which individual missing module was the final blocker.

The user expected the Omarchy logo. The installed Plymouth package and Omarchy
theme already exist, but the prototype initramfs omitted the Plymouth hook and
boot arguments. Its current encrypt hook supports Plymouth password entry.
Preparing a second physical test adding that hook plus `quiet splash`, while
retaining the verified text-prompt image. Boot package release 4 captures those
changes; release 3 retains the tested display-only change. ISO work follows the
physical test; no new ISO is being built yet.

Graphical candidate built successfully, with the Omarchy logo/script, DRM
renderer, Plymouth and encrypt hooks verified in the archive. SHA-256:
`0915d1c33912ce9dcf8915d1c30f6d692100f77f66b041008823a3bb10cdc998`.
Staged in `~/splash-test/`; transferred checksums, shell syntax and GRUB syntax
verified on target. Deployment command is
`sudo bash ~/splash-test/apply.sh && sudo reboot` after saving work.
It requires the current text-test GRUB configuration to match exactly, retains
both prior images/entries and selects `Omarchy graphical unlock test`.
Fallback with the verified visible text prompt is `Omarchy unlock test`.
`sudo bash ~/splash-test/apply.sh restore` restores that prior configuration.
Physical graphical unlock validation is pending; deployed boot package is
still release 2 because test images are staged independently of pacman.

## Physical graphical result: PASS

User confirms the Omarchy graphical unlock worked. Subsequent SSH shows
`quiet splash`, msmdrmfb, the LCD device tree and zero failed system units.
Saved `private/thinkpad-live/graphical-unlock-boot.txt`. The accepted fixes are
the early display dependency graph and the stock Plymouth hook/theme integration.
The project is now returning to ISO assembly and end-to-end installation tests.
