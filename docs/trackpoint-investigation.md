# ThinkPad T14s Gen 6 TrackPoint workaround

## Project integration after this handoff

The user subsequently authorized merging the workaround, suspecting an EC issue.
That suspicion is not a confirmed diagnosis. The recorded investigation below
is preserved as received.

The project patch now calls
`install/user/hardware/lenovo/t14s-trackpoint.sh` during stock user provisioning.
On aarch64 DMI product `21N10000US` it appends the suggested managed Lua block
(`no_scroll`, scroll-button lock off, exact 04F3 mouse name) to the user's input
configuration. Other settings are preserved, a pre-change backup is retained,
and repeat provisioning does not duplicate the block. It does not reset HID or
touch the live ThinkPad, and does not use experimental button code 279.

Local checks passed for insertion, backup/content preservation, repeat execution,
and exclusion of other models and x86. Patch preparation and shell syntax checks
passed. Reboot persistence and right/middle button functionality remain unverified.
This is merged source for the next 4.0.3-1.4 package build, not a change to the
already built kernel31-keyring ISO.

Recorded 2026-09-12 while troubleshooting this machine on Omarchy Quattro.

## Outcome and installer relevance

The red TrackPoint initially scrolled instead of moving the pointer. Pointer
movement returned after applying a live, device-specific scrolling override
and requesting a reconnect of its HID driver. Right and middle clicks remained
broken. This is a pointer-movement workaround, not a complete repair.

**The successful session used live `hyprctl eval` settings. They were not saved
to the user's config.** At the end of troubleshooting, `~/.config/hypr/input.lua`
contained only its original commented examples. A reload or fresh login may
therefore lose the workaround. This document records installer integration below;
writing this document did not install that integration.

We did not isolate which part of the final combination was necessary, and have
not verified persistence across reboot or a fresh installation.

## Machine and software

From `fastfetch` and `hyprctl version`:

- Lenovo ThinkPad T14s Gen 6, model 21N10000US.
- Qualcomm Snapdragon X Elite X1E-80-100, ARM64.
- Omarchy 4.0.3-1.2.
- Linux 7.0.0-31-generic.
- Hyprland 0.56.2, commit `efb50993780079460b0cbed1363e2166a2de1d9f`.
- Aquamarine 0.15.0.
- Hyprland configuration uses Lua.

The user reported that the TrackPoint had worked once on this build, and that
the trackpad had previously been replaced. The touchpad itself worked during
troubleshooting.

## Device identification

`hyprctl devices`, `/proc/bus/input/devices`, and `udevadm info` identified:

| Function | Hyprland name | Kernel event node during this session |
| --- | --- | --- |
| TrackPoint mouse interface | `hid-over-i2c-04f3:000d-mouse` | `/dev/input/event2` |
| Keyboard on the same HID interface | `hid-over-i2c-04f3:000d-keyboard` | `/dev/input/event1` |
| Touchpad mouse interface | `hid-over-i2c-06cb:ce67-mouse` | `/dev/input/event3` |
| Touchpad | `hid-over-i2c-06cb:ce67-touchpad` | `/dev/input/event4` |

TrackPoint HID device: `0018:04F3:000D.0001`.

Driver: `/sys/bus/hid/drivers/hid-generic`.

The TrackPoint and keyboard share this HID device. Rebinding it briefly
disconnects both. The separate Synaptics touchpad remained available.

Event numbers and the HID instance suffix can change. An installer must discover
the device rather than assuming `event2` or `.0001` on every installation.

## What we observed

1. The global Hyprland settings initially showed an empty `input:scroll_method`,
   `input:scroll_button_lock = false`, and `input:scroll_button = 0` (default).
   No user scrolling overrides were present.
2. Raw evdev input showed normal relative X/Y movement from the TrackPoint.
   This was not simply a device producing wheel events instead of movement.
3. An `EVIOCGKEY` query reported `BTN_RIGHT` (273) and `BTN_MIDDLE` (274) held.
4. A driver reconnect initially cleared those held bits, but they returned.
   Hyprland's log also showed `event2 - btnscroll: down` after reconnection.
5. Once pointer movement returned, a controlled click test monitored all three
   mouse/touchpad event nodes. The user performed four left, four right, and
   four middle clicks on the physical TrackPoint buttons:

   | Button | Raw events received |
   | --- | --- |
   | Left, 272 | Four DOWN and four UP events, all on event2 |
   | Right, 273 | No transitions |
   | Middle, 274 | No transitions |

   Right and middle were held at both the start and end of that test. Neither
   touchpad event node reported corresponding button events.

This places the missing button transitions below Hyprland's application input
handling. It does not prove an electrical fault: hardware, firmware, HID report
interpretation, or a kernel driver issue could cause the observed state.
The replaced trackpad/cable/button assembly is a reasonable hardware suspect,
but was not physically inspected or tested in another OS.

## Changes attempted, in order

### 1. Persistent no-scroll override alone: did not restore movement

We backed up the original config to:

`~/.config/hypr/input.lua.bak.20260912-113713`

Then appended:

```lua
hl.device({
  name = "hid-over-i2c-04f3:000d-mouse",
  scroll_method = "no_scroll",
  scroll_button_lock = false,
})
```

`hyprctl reload` succeeded and `hyprctl configerrors` was empty, but the user
reported that the TrackPoint still did not move the pointer. We subsequently
removed this block and reloaded successfully.

### 2. Live disable/enable: insufficient

```sh
hyprctl eval 'hl.device({name="hid-over-i2c-04f3:000d-mouse",enabled=false})'
hyprctl eval 'hl.device({name="hid-over-i2c-04f3:000d-mouse",enabled=true})'
```

Both commands returned `ok`. The raw right and middle held bits remained set.

### 3. HID driver reconnect alone: insufficient

We unbound and rebound `0018:04F3:000D.0001` from `hid-generic`.
Immediately afterward, the raw held-button list was empty. The user still
reported scrolling when using the stick, and the held state returned.

### 4. Live scrolling override followed by another reconnect: movement returned

The exact live command was:

```sh
hyprctl eval 'hl.device({name="hid-over-i2c-04f3:000d-mouse",scroll_method="no_scroll",scroll_button=279,scroll_button_lock=false})'
```

Hyprland returned `ok`. We then requested another driver reconnect, using the
Python procedure below via `pkexec`. That request initially waited for graphical
authentication. Its final tool output was not collected before the user reported
that pointer movement was now working. Therefore, the session confirms the
user-visible improvement after this sequence, but does not independently prove
completion of that final reconnect or identify the minimal necessary change.

**Important detail about `scroll_button=279`:** this was an experimental choice
of an unused mouse-button code, not a verified supported button on this device.
Libinput can reject unsupported button numbers, and Hyprland's `ok` response
does not prove that libinput accepted every setting. Do not rely on 279 as the
fix. With `scroll_method="no_scroll"`, the intended behavior is to disable
button scrolling regardless of the configured scroll button.

## Suggested installer integration

Apply this only to the affected device/machine, preferably as an opt-in workaround
for the stuck-button symptom. Disabling TrackPoint scrolling on healthy machines
would remove useful functionality.

In the target user's `~/.config/hypr/input.lua`, after Omarchy defaults have been
loaded, add one managed block:

```lua
-- Work around stuck TrackPoint button scrolling on this ThinkPad.
-- Touchpad scrolling is unaffected; physical button faults remain unresolved.
hl.device({
  name = "hid-over-i2c-04f3:000d-mouse",
  scroll_method = "no_scroll",
  scroll_button_lock = false,
})
```

This is the cleaner candidate configuration; it omits the unverified button 279.
It needs validation on a fresh login. The earlier test of this block alone while
the device was already stuck failed, so do not describe it as independently
proven without the reconnect/fresh-device initialization step.

Preserve other user settings and make insertion idempotent. Do not edit
`/usr/share/omarchy/`, which is package-owned. Back up the user config first.

For an already running desktop, apply as that desktop user:

```sh
hyprctl reload
hyprctl configerrors
```

Do not run `hyprctl` as root or assume a live compositor exists during an offline
installation. A new login should load the saved configuration; reboot/login
behavior has not yet been tested for this workaround.

### Optional live HID reconnect

Use this only when applying the workaround to an already stuck device. Avoid
making repeated driver resets a boot-time service without further evidence.
It momentarily interrupts the built-in keyboard as well as the TrackPoint.

The procedure used on this machine was:

```python
from pathlib import Path

driver = Path("/sys/bus/hid/drivers/hid-generic")
device = "0018:04F3:000D.0001"  # Discover and verify on the target machine.
device_path = Path("/sys/bus/hid/devices") / device

assert (device_path / "driver").resolve() == driver

try:
    (driver / "unbind").write_text(device)
finally:
    if not (device_path / "driver").exists():
        (driver / "bind").write_text(device)
```

This requires root. During this agent session we used `pkexec /usr/bin/python`
because authentication was graphical. A terminal-based installer can use its
normal root/sudo execution context. Discover candidate HID devices under
`/sys/bus/hid/devices/0018:04F3:000D.*` and verify the child input device names
before selecting one. Do not rebind unrelated devices or unload a shared HID
module globally.

## Verification and rollback

- Test pointer movement with the red stick while touching no buttons.
- Test touchpad movement and two-finger scrolling separately.
- Test all three physical TrackPoint buttons. Restored pointer movement does
  not establish that the buttons are healthy.
- Verify after a fresh login/reboot before incorporating this as a proven
  installer fix.
- Raw diagnostics can use `evtest` on the discovered mouse event node, without
  an exclusive grab. Movement should produce `EV_REL` X/Y events; clicks should
  produce paired `EV_KEY` 1/0 transitions for codes 272, 273, and 274.
- Our diagnostic used Python `os.read` and `EVIOCGKEY` instead because `evtest`
  and the libinput CLI were not installed. No diagnostic packages were installed.
- To undo the persistent workaround, remove only its managed `hl.device` block,
  then reload and check config errors. A HID rebind itself is not persistent.

## Documentation checked

- [Hyprland input options](https://wiki.hypr.land/Configuring/Basics/Variables/).
- [Hyprland 0.56.2 input configuration implementation](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/managers/input/InputManager.cpp).
- [Libinput device configuration API](https://wayland.freedesktop.org/libinput/doc/latest/api/group__config.html).
- [Lenovo T14s Gen 6 Snapdragon manual](https://download.lenovo.com/pccbbs/mobiles_pdf/t14s_gen6_hmm_en.pdf).
- [Lenovo Fn-key reference](https://support.lenovo.com/uu/en/solutions/HT503647).

Lenovo documents Fn+K as keyboard Scroll Lock and Fn+G as the TrackPoint Quick
Menu gesture toggle. We found no documented key combination that repairs this
stuck TrackPoint button state. No Windows settings or firmware were changed.
