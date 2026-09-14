#!/bin/bash
# Read-only, bounded report; run on the target. No privilege escalation or changes.
set -uo pipefail
umask 077
out="asus-a16-report-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir "$out" || exit 1
capture() {
  local name=$1
  shift
  timeout 15 "$@" > "$out/$name.txt" 2>&1 || true
}
capture kernel uname -a
capture model cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name /sys/class/dmi/id/product_version
capture devicetree bash -c 'tr "\0" "\n" < /proc/device-tree/compatible'
capture packages pacman -Q
capture pci lspci -nnk
capture usb lsusb
capture audio-cards cat /proc/asound/cards
capture audio-playback aplay -l
capture audio-capture arecord -l
capture pipewire wpctl status
capture camera cam -l
capture graphics eglinfo -B
capture services systemctl --failed --no-pager
capture kernel-log journalctl -b -k --no-pager -n 2500
capture devices bash -c '
  for p in /sys/class/power_supply/*/{type,status,capacity,online,voltage_now,current_now,energy_now,energy_full} /sys/class/backlight/*/{brightness,actual_brightness,max_brightness} /sys/class/remoteproc/*/{name,state,firmware}; do
    [[ -f $p ]] || continue
    printf "%s: " "$p"
    cat "$p"
  done
'
printf 'Report saved to %s. Review device identifiers before public sharing.\n' "$out"
