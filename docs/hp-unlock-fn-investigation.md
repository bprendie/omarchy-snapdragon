# HP unlock screen and Fn investigation — 2026-09-12

The user reports a black encrypted-disk prompt on the HP, despite the existing
ThinkPad unlock fix. They also report no media-key response after changing the
BIOS Fn setting (Fn indicator now lit). User explicitly rejected mapping plain
F3/F4 to brightness; preserve normal function keys and investigate Fn delivery.
The user has since authorized the next image write to `/dev/sda` (reidentify
before writing) and restored SSH access after reinstalling the HP.

## Physical retest and reset

On September 12, the user confirmed that a fresh install from the combined
ThinkPad/HP audio ISO boots successfully and the disk-unlock boot screen now
functions. This physically validates the HP early-display fix below.

The raw keyboard capture printed F3, F4, F6, F7 and F8 with zero modifiers,
and no consumer reports in the output supplied by the user. The individual
presses were subsequently clarified by the user: bare keys produced these
F-key reports, while holding Fn produced no output from the observer. BIOS
"Launch hotkeys without fn keypress" is Disabled, with the Fn LED lit.
This suggests Fn changes firmware handling, but does not establish where
the missing hotkey action is routed. The observer covers only the keyboard
hidraw interface, not every possible vendor interface. The user reported
a spontaneous hard reset after the capture.
Do not repeat the capture until crash evidence has been assessed; a causal
connection to the read-only observer is not established.

SSH was restored after reboot. The previous journal ends abruptly with no
recorded orderly shutdown or kernel panic. `/var/lib/systemd/pstore` is empty;
the protected `/sys/fs/pstore` requires a privileged read. Evidence is retained
locally in `build/hp-fn-reset/`. Firmware is F.34, dated June 26, 2026; kernel
is 7.0.0-31-generic. The expected `~/hp-fn.log` was absent after reboot, so
the user's pasted output is the available capture evidence.

## Unlock candidate

The installed HP uses kernel31 and `quiet splash`. Its boot journal reports
PMIC GLINK altmode waiting for the port-1 mode switch and the display bridge
graph deferring before root userspace. MSM registers its framebuffer afterward.
The previous HP initramfs includes ps883x and the ThinkPad display prerequisites,
but omits gpio_sbu_mux. The live HP DT identifies its port-1 SBU mux as
`onnn,fsusb42`, `gpio-sbu-mux`; the running system binds it to gpio_sbu_mux.

The [upstream HP shared DT](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/x1-hp-omnibook-x14.dtsi)
also connects this mux to PMIC GLINK. The
[mux driver](https://github.com/torvalds/linux/blob/master/drivers/usb/typec/mux/gpio-sbu-mux.c)
registers the missing Type-C switch/mux interfaces. This supports adding
gpio_sbu_mux to the shared early boot hook, without removing ThinkPad modules.
Boot package 0.1.0-5 carries that addition. No DT rewrites or driver blacklists.

Candidate: `build/hp-unlock-test/initramfs.img`, built from the installed-root
Plymouth/encrypt config with HP GPU/DSP and audio firmware present. VM test
fixture: `scripts/test-hp-unlock-vm.sh`, disposable LUKS2 file, public test-only
passphrase `oma-test-only`. It tests graphical prompt/unlock plumbing on ARM
UEFI; QEMU does not emulate the HP display graph. The subsequent fresh physical
install confirmed the HP boot-screen fix, as recorded above.

VM result: **visible text prompt and decryption PASS** with the exact candidate
initramfs. Virtual keyboard entry of the fixture passphrase creates dm-0 and
`/dev/mapper/root`; the expected subsequent filesystem check/mount failure
occurs because the fixture contains no root filesystem. Screenshot evidence:
`build/hp-unlock-vm/prompt.png`, `unlocked.png`, plus serial.log. The Omarchy
theme is packaged but the VM falls back to text (no virtio_gpu module in this
hardware-targeted initramfs); graphical rendering is not claimed validated.
The first serial-console fixture used a newline in its key file and rejected
the typed password. The corrected fixture uses no newline and a cheap test-only
PBKDF for emulation. The VM has been stopped after capturing the result.

## Fn evidence

Follow-up after BIOS change: setting **Launch hotkeys without fn keypress**
to Enabled turns the Fn LED off, but the user still gets no brightness/volume
action. Several bare F-keys produce terminal escape-sequence tails (`~`).
SSH inspection confirms the same 92-byte HID descriptor, hid-generic binding,
and no separate HP hotkey input device. `/sys/firmware/acpi` is absent on this
device-tree boot. Stock Omarchy XF86 media bindings remain present. This
supports investigating firmware/platform event delivery rather than remapping
plain function keys, but does not establish an EC defect or a specific fix.

The upstream shared HP device description exposes a generic I2C keyboard and
no named EC hotkey device. A September 1 upstream patch series separately
proposes reserving EC reset GPIO 65 on these boards:
https://lkml.iu.edu/2609.0/00466.html . That is a reset-line protection change,
not a hotkey fix; there is no evidence tying it to this machine's reset.
No GPIO accesses or driver reloads were performed during this inspection.

The latest boot also logs a panel-edp probe warning (retained in
`build/hp-fn-reset/latest-boot.log`); this is a boot-time warning, not a crash
record from the earlier unexpected reset. The privileged pstore inspection
was authorized but its saved user journal has no listing or completion output;
do not treat the protected store as confirmed empty.

Keyboard: I2C HID 0416:C300, bound to hid-generic. Its 92-byte report descriptor
declares keyboard report ID 8 and consumer-control report ID 9. Consumer usages
span 0–0x023c, including brightness/volume usages; there is no separate Fn input
declared. Descriptor SHA-256:
`e7e5003401ce366e9121a99fda51a852e974fef919511e2bbcdf55d9b0df1579`.
This means Fn may be handled inside firmware; lack of a standalone Fn event
is not by itself a defect.

User's evdev capture contains F3/F4 only. Stock Omarchy media bindings exist,
and brightness through the widget works. The capture did not distinguish raw
consumer report delivery from Linux input translation, so it does not establish
an EC fault. No speculative EC register writes or I2C scans were performed.

`tools/hp-keycheck` builds a bounded raw-report observer, staged on the HP as
`~/hp-audio-candidate/hp-raw-keycheck`. It discovers the exact keyboard hidraw
node, observes for 60 seconds without grabbing input, prints consumer usages
and function keys, and omits ordinary letter/digit reports. The user ran it
after reinstalling; partial results and the subsequent reset are recorded above.

[HP's keyboard specification](https://support.hp.com/in-en/document/ish_10692928-10692729-16)
maps F3/F4 to brightness, F6 to mute, F7/F8 to volume, F9 to microphone mute,
and F10 to play/pause. This confirms the legends, not their Linux event path.

## Audio after reboot

The corrected card-long-name UCM link is installed. Following the BIOS reboot,
WirePlumber exposes speakers and microphone nodes without a temporary UCM
environment. The user confirmed audible speaker playback before reboot.
The new offline package includes identical topology bytes under the versioned
firmware directory so the boot hook also includes them early.
