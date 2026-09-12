#!/usr/bin/env bash
# Bounded native charger-firmware trace; no persistent system changes.
# Disabled after hardware test exposed a GLINK driver-removal deadlock.
echo 'Disabled: see docs/charging-investigation.md for the unload deadlock.' >&2
exit 1
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
[[ $(uname -m) == aarch64 ]] || { echo 'Run on the ThinkPad.' >&2; exit 1; }
trace_root=/sys/kernel/tracing
[[ -d $trace_root/instances ]] || { echo 'Tracefs is not mounted.' >&2; exit 1; }
capture_dir=$(mktemp -d /var/tmp/oma-charge.XXXXXXXX)
instance=$trace_root/instances/oma-charge-$$
loaded_here=0
cleanup() {
  local result=$?
  trap - EXIT
  if [[ -d $instance ]]; then
    echo 0 > "$instance/tracing_on" || result=1
    echo 0 > "$instance/events/enable" || result=1
    rmdir "$instance" || result=1
  fi
  if (( loaded_here )); then
    modprobe -r pmic_pdcharger_ulog || result=1
  fi
  if [[ ${SUDO_UID:-} =~ ^[0-9]+$ && ${SUDO_GID:-} =~ ^[0-9]+$ ]]; then
    chown -R "$SUDO_UID:$SUDO_GID" "$capture_dir" || result=1
  fi
  echo "Capture: $capture_dir (exit $result)"
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if [[ ! -d /sys/module/pmic_pdcharger_ulog ]]; then
  modprobe pmic_pdcharger_ulog
  loaded_here=1
fi
mkdir "$instance"
echo 0 > "$instance/tracing_on"
echo 256 > "$instance/buffer_size_kb"
echo 1 > "$instance/events/pmic_pdcharger_ulog/pmic_pdcharger_ulog_msg/enable"
snapshot() {
  date --iso-8601=seconds
  for supply in /sys/class/power_supply/*; do
    echo "${supply##*/}"
    cat "$supply/uevent"
  done
}
snapshot > "$capture_dir/before.txt"
echo 1 > "$instance/tracing_on"
echo 'Capturing charger firmware for 20 seconds; leave the cable connected.'
sleep 20
echo 0 > "$instance/tracing_on"
cat "$instance/trace" > "$capture_dir/firmware-trace.txt"
snapshot > "$capture_dir/after.txt"
journalctl -b -k --no-pager -o short-monotonic > "$capture_dir/kernel.txt"
