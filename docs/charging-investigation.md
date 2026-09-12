# Charging investigation — 2026-09-12

Status: PAUSED at user request, 2026-09-12. Unplug/replug is the accepted
temporary workaround. Boot-time failure remains unresolved. Do not resume
charging experiments without user steering. No boot-test configuration or
permanent power-setting change was applied.

Charging works after the user moved the cable to the lower USB-C port.
Moving it back to the original upper port also charges. Reconnection cleared
the observed failure; a persistent port defect is not reproduced.
Installed bobp SSH is now working after correcting a wrapped/malformed public
key. Host identity is verified separately from the USB. Sudo needs a password;
all charging diagnostics so far are unprivileged reads. No power settings changed.

## Port-switch result

Before the switch, installed kernel31 reported Discharging at about 8.57 W,
all external supplies offline, and charge thresholds 0/0. A Type-C partner
was present with power-delivery mode despite no online supply.

After the user moved the cable to the lower port, the 09:57:25 sample reports
Charging, USB online=1, about 45.57 W battery charging power, 47.99 Wh energy,
and UCSI supply 02 online with PD selected. UCSI voltage_now still reads zero,
so do not use that field as proof of a valid measured contract voltage.
Evidence: `private/thinkpad-live/charging-lower-port.txt` and the preceding
`installed-power-baseline.txt`. Physical port numbering has not been mapped
reliably to the kernel's port indices. Sustained energy gain, the original port
after reconnect, cable orientation, and reboot behavior remain to be tested.

Follow-up: energy increased from 47.99 to 48.47 Wh in 44 seconds on the lower
port. User confirms cable orientation remained fixed. At 09:58:52, after moving
back to the original upper port, battery reports Charging at 44.107 W and
48.95 Wh, USB online=1, UCSI supply 01 online with PD, and typec port0 in PD
sink mode. Supply02 becomes offline. Thus both physical ports charge after
hotplug. Preserve `charging-original-port-retest.txt` and
`charging-lower-port-followup.txt`. Next test: reboot with the cable left
attached to the upper port, with working firmware selection and SSH prepared,
to reproduce the boot-time loss without conflating it with cable orientation.

User also clarified the earlier Ubuntu failure occurred at 5% battery. Normal
full-battery behavior does not explain that failure.

## Reboot reproduction and driver reload

With the cable left in the original upper port, the user rebooted through
BootNext=0002 and reports charging stopped just before the desktop appeared.
The new boot's 10:02:03 sample confirms Discharging at 8.462 W and all supplies
offline. Saved full journal and supply state: `charging-reboot-journal.txt`
and `charging-reboot-baseline.txt` in the private target directory. This
reproduces the boot-associated failure; the visible timing does not prove
Hyprland is responsible.

User then ran `sudo modprobe -r ucsi_glink` and `sudo modprobe ucsi_glink`
(after correcting a command typo). At 10:04:27, the module is loaded but the
battery remains Discharging at 8.777 W, with USB/UCSI offline. A driver reload
alone did not recover charging. Evidence: `charging-after-ucsi-reload.txt`.
After reconnection restored charging, the user repeated the UCSI unload/load
with the cable untouched. Charging survived: at 10:07:18 the battery reported
35.753 W charging power and 51.01 Wh energy. The cable meter read 49 W including
system load; the user observed only a roughly 2 W change. At 10:11:59, SSH still
reported Charging with energy increased to 53.16 Wh. Evidence:
`charging-before-active-reload.txt` and `charging-after-active-reload.txt`.
UCSI initialization alone did not reproduce the loss in this test. Do not
deploy an automatic reload service from these results.

User identifies the supply as a Ugreen 230 W PD charger, with a Chubby cable
rated for 140 W PD and an integrated watt display. Exact charger model,
per-port allocation and other connected devices are not established. These
ratings are user-reported, not a measurement of the negotiated contract.
The next useful comparison is the same boot with a separate known-working
charger; also investigate early ADSP/charger firmware handoff and logging.
User has no alternate charger available, so the charger comparison is deferred.

The installed kernel contains `pmic_pdcharger_ulog.ko.zst`. Exact source shows
this diagnostic driver requests charger firmware logs on probe, polls every
second after responses, and emits trace events. It is intentionally not
autoloaded. Any later capture should be bounded, followed by module unload;
do not enable it permanently. It has not been loaded during this investigation.
The matching `PMIC_LOGS_ADSP_APPS` RPMsg channel is present on the target.
Prepared `scripts/capture-charger.sh`, staged as `~/charge-check.sh` on the
ThinkPad. It captures 20 seconds in a separate trace instance, snapshots supplies
and kernel journal, then removes the trace instance and unloads the diagnostic
module if it loaded it. Output stays private in a unique `/var/tmp/oma-charge.*`
directory owned by the sudo caller. Shell syntax checked; privileged execution
and useful firmware output remain untested. Next step: user runs
`sudo bash ~/charge-check.sh` with the present charging session undisturbed.

Actual execution: the 20-second capture completed, but cleanup hung in
`modprobe -r pmic_pdcharger_ulog` (PID 19912, D state, module refcnt -1).
Battery still reports Charging. This invalidates the assumption of bounded
cleanup: do not run this capture script again. Output exists at
`/var/tmp/oma-charge.75MIx4R9` but remains root-owned because unload preceded
the ownership handoff. No new kernel journal entries were visible over SSH.
Prepared a separate recovery script, `~/charge-logs.sh`, that only records
process state/kernel stack/journal and transfers capture ownership to the sudo
caller. It performs no module operations. Original executing script unchanged.

Recovery capture retrieved successfully into the ignored private target folder.
The firmware trace has zero events. The blocked stack runs from module removal
through rpmsg_dev_remove, qcom_glink_destroy_ept and
qcom_glink_remove_rpmsg_device into device_del. The subsequent hung-task report
explicitly identifies a mutex likely owned by the same modprobe task. This
matches the upstream GLINK endpoint-destroy self-deadlock described in the
[rpmsg v7.3 pull request](https://lkml.iu.edu/2608.3/04002.html) and its linked
fix, not evidence of the original boot-time charging fault. Battery remains
Charging at 55.48 Wh (10:19:14). Local capture helper disabled with an immediate
error exit; the executing remote copy was not modified. No persistent module
autoload configuration was added. Reboot needed to recover the blocked kernel
state, using the existing one-shot Boot0002 path; avoid this diagnostic module
on the current kernel. Capture driver cleanup was not actually bounded despite
the intended 20-second sample duration.

Shutdown subsequently hung on the same deadlocked modprobe. User recovered
by holding the power button and booting again. At 10:25:46, installed SSH works,
the diagnostic module is absent, battery is Discharging at 7.115 W with
56.53 Wh remaining, and USB/UCSI supplies are offline. User's meter reads 0 W.
Evidence: `private/thinkpad-live/charging-after-deadlock-reboot.txt`.
BootCurrent is the NVMe fallback (001D), with Omarchy Boot0002 still available.
A proposed next experiment was booting with `module_blacklist=ucsi_glink` to
isolate first initialization from later reloads. This was NOT applied or tested;
only a local copy of the pre-existing GRUB backup was extracted for planning.
The user paused investigation before any test helper or boot change was staged.

Reviewed https://github.com/PenguinzTech/x1e-pd-fix on 2026-09-12. Its author
reports an ASUS 6.17 slow-charge case and explicitly configures firmware USB
adapter type/current limits. That is not demonstrated as a fix for this
ThinkPad's offline-after-boot symptom, and our unmodified driver already
achieves roughly 45 W battery charging after reconnect. No patch was applied.

## Evidence

- User observed 45 W dropping to 0 W on the cable meter during Linux boot,
  with the charger still connected. Earlier Ubuntu also reportedly did not charge.
- Saved Ubuntu6.14 sample: battery Discharging, approximately 57.44/59.21 Wh;
  AC/USB/UCSI inputs all offline. Charger attachment at that earlier sample was
  not confirmed, so it cannot independently prove failed negotiation.
- Saved kernel31 live journal shows charger_pd service registration, panel/GPU
  initialization, and PMIC-GLINK device-link warnings. Those warnings alone do
  not prove charger failure. Both Ubuntu and live kernels booted at EL1; an
  EL2/virtualization boot workaround is not present in these observations.
- Selected kernel configuration includes QCOM_BATTMGR, PMIC_GLINK, UCSI_PMIC_GLINK,
  PD_MAPPER and PDR_HELPERS as modules. Compilation does not establish runtime
  binding or a negotiated power contract in the installed session.
- Exact cached Ubuntu kernel source was extracted for inspection under
  `build/charging-kernel/`; input provenance is in
  `manifests/ubuntu-kernel-source-7.0.0-31.sha256`.
  qcom_battmgr exposes charge-control start/end thresholds and reads their
  initialization from firmware-backed NVMEM. Read these before considering a
  threshold change. Source availability does not prove this is the cause.

## Next measurements once access works

1. Record battery capacity, status, energy/current/power and both charge thresholds;
   record all supply online states and UCSI voltage/current/USB type.
2. Record Type-C partner, power/data roles, negotiated capabilities and bound
   PMIC/UCSI/battery drivers, with the installed boot journal.
3. Establish charger make/rating, cable, chosen port, battery level and whether
   a dock/meter is involved. Record a controlled unplug/replug transition while
   monitoring logs and the external meter; test the alternate port/direct cable
   only after saving the original state.
4. Distinguish full-battery/threshold behavior, missing supply detection, wrong
   power role, failed PD negotiation, and charger-firmware communication before
   selecting a bounded fix. Confirm sustained charging with battery energy gain
   and external power, then repeat after reboot before claiming resolution.

The maintainer's [T14s support page](https://github.com/jhovold/linux/wiki/T14s)
documents ADSP service-registration and USB-C issues, but was last edited in
2025; it is background, not proof of a current 7.0.0-31 defect. No firmware flash,
remoteproc restart, driver unbind or speculative kernel-parameter change has
been performed.
