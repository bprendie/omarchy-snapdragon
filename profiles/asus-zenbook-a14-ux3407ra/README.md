# ASUS Zenbook A14 UX3407RA preliminary profile

Target: X Elite / x1e80100, compatible `asus,zenbook-a14-ux3407ra`.
The user confirms X Elite but cannot supply physical access. UX3407RA is the
matching upstream model; the eventual tester must confirm their model code.
Do not apply this profile to UX3407QA (X/Plus) or substitute its firmware.

Kernel31 already embeds the UX3407RA DTB and provides the GPU, DSP, Wi-Fi,
Bluetooth, panel and USB-C bridge drivers. The base firmware package already
contains the Zenbook audio topology, and alsa-ucm-conf includes the Zenbook
model match. Five proprietary GPU/DSP files are supplied separately by
`oma-snap-firmware-asus-a14`; see its provenance and local-only restrictions.

The preliminary initramfs config adds the OLED panel module absent from the
ThinkPad/HP initramfs. It retains the shared Qualcomm hook, which includes all
versioned firmware, PS883x, and existing ThinkPad/HP prerequisites.

The combined `omarchy-snapdragon-v0.1.0.iso` integrates this firmware into
the live image and installer target package list. Boot package 0.1.0-6 adds
the OLED panel module to the shared hook for live and installed systems.
The previously written HP USB does not yet contain this ASUS firmware package.
VM tests establish package integrity, module loadability and generic ARM boot
regression only. They cannot validate ASUS display, audio, wireless, suspend,
charging or automatic firmware DT selection on the real machine.
