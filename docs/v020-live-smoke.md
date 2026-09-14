# v0.2.0 local live smoke — September 13

The local `omarchy-snapdragon-v0.2.0-smoke.iso` boots through ARM UEFI and
kernel 7.0.0-31 into the Omarchy welcome screen. Sending Return opened the
keyboard-layout selector, confirming that the installer UI accepts input.
The kernel explicitly reported `ima: secureboot mode disabled`.
Secure Boot support and testing are out of scope.

ISO SHA-256: `24569b275e324a943ab7d7523e3154beda5c9730aa347add2465338ab9f7a141`.

This is an **unpromoted live smoke image, not an installation handoff**. It
carries the current hardware set, tools 0.2.0-10, Omarchy/settings 4.0.3-1.9,
boot package 0.1.0-7, and local signed repository configuration. Its prototype
provider remains `unvalidated`; the installer will reject that provider during
boot finalization. No promotion evidence was fabricated and no release gate
was marked passed. The live kernel/initramfs and GRUB title are inherited from
v0.1.2; the old title needs updating for the final candidate. The approved
assembly staging directory remains untouched.

The run found and fixed a real assembly defect: the extracted pacman keyring
had no local master key, so adding a repository key succeeded but locally
signing its trust failed. Assembly now initializes the local pacman keyring
before importing and trusting the repository public key. The private repository
signing key remains outside the image. These package trust operations are
independent of Secure Boot.

The VM warned `file /boot/ not found` before displaying GRUB and timed out its
`ttyAMA0` serial getty. Both were nonfatal: the graphical console reached the
interactive installer. This smoke does not prove a clean service audit, an
end-to-end install, encrypted-root upgrade, physical hardware, or rollback.
No USB was written and nothing was pushed.

Local evidence:
- `build/assemble-v020-smoke.log`
- `build/v020-smoke-pacman-init.log`
- `build/boot-v020-smoke.log`
- `build/snapdragon-v0_2_0-smoke-vm/serial.log`
- `build/snapdragon-v0_2_0-smoke-vm/smoke-screen.png` (welcome)
- `build/snapdragon-v0_2_0-smoke-vm/smoke-interactive.png` (layout selector)

The temporary assembly scripts and signed smoke fixture are under `build/`.
The smoke VM was stopped after the interactive result to release host RAM;
the separate installed rollback and encrypted install jobs continue.
