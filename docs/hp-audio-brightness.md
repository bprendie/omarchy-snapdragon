# HP installed audio and brightness investigation — 2026-09-12

The HP firmware RAM ISO installed and booted to the desktop on the EliteBook
Ultra G1q. User confirms Wi-Fi, Bluetooth and touchpad operation. Kernel is
7.0.0-31-generic, HP firmware package 7700.1-1; ADSP and CDSP run.

## Audio candidate

Kernel card registration fails with ENOENT loading
`qcom/x1e80100/X1E80100-HP-ELITEBOOK-ULTRA-G1Q-tplg.bin`.
There are no ALSA cards and PipeWire exposes Dummy Output. WCD938x and WSA884x
SoundWire codecs are bound. Installed alsa-ucm-conf 1.2.16.1-1 lacks an EliteBook
card-name mapping, although it includes the shared two-speaker T14s profile.

Live test: installing the topology and retrying the sound-card probe registers
ALSA card 0 successfully. Its long name is
`HP-HPEliteBookUltraG1q14inchNotebookAIPC-ConfigID-8CBE`, so a link named after
the DT sound model alone is not selected. A UCM link using that DMI long name
loads HiFi successfully. Restarting WirePlumber with a temporary UCM tree yields
Built-in Audio Speaker playback, internal microphones and headset microphone.
Two short pw-play samples completed successfully at 15% volume with no new
kernel audio errors. The user confirmed hearing playback when repeated at 70%.
The corrected privileged installer persisted the DMI-name link; a normal
alsaucm invocation now loads HiFi without environment overrides. The temporary
ALSA_CONFIG_UCM2 environment was removed from the user manager after launching
WirePlumber, so other user services do not inherit the test override.

Upstream [EliteBook DT](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/x1e80100-hp-elitebook-ultra-g1q.dts)
inherits the Omnibook DT and overrides the sound model, without changing audio
wiring. [AudioReach topology](https://github.com/linux-msm/audioreach-topology/blob/e7b20b2b16cdda18eb8ae143c8d95c4815c0288e/CMakeLists.txt)
builds the Omnibook topology from `X1E80100-LENOVO-Thinkpad-T14s.m4`.
This supports a candidate using that same source under the EliteBook filename,
plus a card-specific UCM link to the existing LENOVO-T14s.conf. Hardware playback
still requires validation; source compatibility alone is not an audible test.

Source revision: `e7b20b2b16cdda18eb8ae143c8d95c4815c0288e`, BSD-3-Clause.
Built locally with m4 and alsatplg; output is 31,892 bytes, SHA-256
`aa303397750f883ecaeed874d7547da658500596247676a6d405bf1ec43290b5`.
alsatplg exits successfully with unresolved backend route warnings; these routes
are supplied by the kernel machine driver. A repeat compilation matches exactly.

`scripts/hp-audio-live-test.sh` installs the staged topology and UCM link on the
exact HP model, backing up existing paths under `/var/lib/oma-snap/` and retrying
only the failed sound-card probe. It does not unload DSP or charging drivers.
Candidate and private logs are retained in ignored build/private directories.
No ISO integration yet.

## Brightness

Backlight exposes 0–100. A direct SSH brightnessctl call is denied; that alone
does not diagnose desktop controls because SSH is outside the active seat.
logind SetBrightness succeeds, as does brightnessctl launched by the user's
desktop service manager. The stock Omarchy brightness command also succeeds in
that context; the focused internal display is eDP-1. Tests changed the value
80 → 75 → 65 → 80. User confirms widget brightness works but keyboard keys do
not, including with Fn held. The user further reports all media keys fail,
including volume. Stock media key bindings are registered. A bounded 60-second
evdev capture utility is staged on the HP at `~/hp-audio-candidate/hp-keycheck`
to distinguish function-key events from media events or absent events. It
checks the expected keyboard name, prints numeric pressed-key codes and scan
codes, and does not grab input or modify any mappings. Hardware capture pending.
The returned capture contains only key 61 / scan 0x7003c (F3) and key 62 /
scan 0x7003d (F4). No brightness or volume key codes appear in that sample.
F3/F4 have no current compositor bindings; F9 is assigned to dictation.
Confirmation of which physical keys were pressed and the volume legends is
pending before choosing a workaround. Do not infer that missing events in this
sample prove a broken EC or that Fn-generated reports reach this input device.
No desktop configuration or brightness permissions have been changed.
