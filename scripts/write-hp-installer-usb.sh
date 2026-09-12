#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# == 1 || ( $# == 2 && $2 == --verify-only ) ]] || { echo "Usage: $0 /dev/sdX [--verify-only]" >&2; exit 1; }
device=$1
[[ $device =~ ^/dev/sd[a-z]+$ ]]
node=${device##*/}
[[ $EUID == 0 && -b $device ]]
[[ $(cat /sys/class/block/$node/removable) == 1 ]]
[[ $(lsblk -dn -o TRAN $device) == usb ]]
[[ -z $(lsblk -n -o MOUNTPOINTS $device | tr -d '[:space:]') ]]
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
udevadm info -q property -n $device | rg '^(ID_SERIAL=|ID_MODEL=|ID_BUS=)' > "$identity"
lsblk -b -dn -o SIZE $device >> "$identity"
cmp build/hp-installer-usb-identity.txt "$identity"
[[ ! -e $automount_rule ]]
mkdir -p /run/udev/rules.d
printf '%s\n' "SUBSYSTEM==\"block\", KERNEL==\"$node*\", ENV{ID_BUS}==\"usb\", ENV{UDISKS_IGNORE}=\"1\"" > "$automount_rule"
owns_rule=true
udevadm control --reload-rules
udevadm trigger --subsystem-match=block --sysname-match="$node*"
udevadm settle --timeout=20
iso=dist/oma-snap-installer-thinkpad-hp-audio-arm64.iso
sha256sum -c "$iso.sha256"
iso_bytes=$(stat -c %s "$iso")
[[ $(blockdev --getsize64 $device) -gt $iso_bytes ]]
expected=$(cut -d' ' -f1 "$iso.sha256")
if [[ ${2:-} != --verify-only ]]; then
  dd if="$iso" of=$device bs=4M conv=fsync status=progress
fi
blockdev --flushbufs $device
actual=$(dd if=$device bs=4M iflag=direct,count_bytes count="$iso_bytes" status=progress | sha256sum)
printf 'Readback SHA-256: %s\n' "${actual%% *}"
[[ ${actual%% *} == "$expected" ]]
printf 'PASS: complete HP installer USB readback matches %s (%s bytes)\n' "$expected" "$iso_bytes"
blockdev --rereadpt $device
udevadm settle --timeout=20
[[ $(blkid -p -s LABEL -o value ${device}3) == OMADIAG ]]
echo "PASS: writable OMADIAG partition detected on ${device}3"
