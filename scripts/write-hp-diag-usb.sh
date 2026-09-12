#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# == 0 || ( $# == 1 && $1 == --verify-only ) ]]
[[ $EUID == 0 && -b /dev/sda ]]
[[ $(cat /sys/class/block/sda/removable) == 1 ]]
[[ $(lsblk -dn -o TRAN /dev/sda) == usb ]]
[[ -z $(lsblk -n -o MOUNTPOINTS /dev/sda | tr -d '[:space:]') ]]
identity=$(mktemp)
automount_rule=/run/udev/rules.d/99-oma-snap-diag-write.rules
owns_rule=false
cleanup() {
  rm -f "$identity"
  if $owns_rule; then
    rm -f "$automount_rule"
    udevadm control --reload-rules
  fi
}
trap cleanup EXIT
udevadm info -q property -n /dev/sda | rg '^(ID_SERIAL=|ID_MODEL=|ID_BUS=)' > "$identity"
lsblk -b -dn -o SIZE /dev/sda >> "$identity"
cmp build/hp-diag-usb-identity.txt "$identity"
[[ ! -e $automount_rule ]]
mkdir -p /run/udev/rules.d
printf '%s\n' 'SUBSYSTEM=="block", KERNEL=="sda*", ENV{ID_BUS}=="usb", ENV{UDISKS_IGNORE}="1"' > "$automount_rule"
owns_rule=true
udevadm control --reload-rules
udevadm trigger --subsystem-match=block --sysname-match='sda*'
udevadm settle --timeout=20
iso=dist/oma-snap-hp-diag-arm64.iso
sha256sum -c "$iso.sha256"
iso_bytes=$(stat -c %s "$iso")
[[ $(blockdev --getsize64 /dev/sda) -gt $iso_bytes ]]
expected=$(cut -d' ' -f1 "$iso.sha256")
if [[ ${1:-} != --verify-only ]]; then
  dd if="$iso" of=/dev/sda bs=4M conv=fsync status=progress
fi
blockdev --flushbufs /dev/sda
actual=$(dd if=/dev/sda bs=4M iflag=direct,count_bytes count="$iso_bytes" status=progress | sha256sum)
printf 'Readback SHA-256: %s\n' "${actual%% *}"
[[ ${actual%% *} == "$expected" ]]
printf 'PASS: complete diagnostic USB readback matches %s (%s bytes)\n' "$expected" "$iso_bytes"
blockdev --rereadpt /dev/sda
udevadm settle --timeout=20
[[ $(blkid -p -s LABEL -o value /dev/sda3) == OMADIAG ]]
echo 'PASS: writable OMADIAG partition detected on /dev/sda3'
