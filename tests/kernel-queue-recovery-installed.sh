#!/bin/bash
# Recover the earlier fixture's start-limit failure and verify automatic watching.
set -euo pipefail
[[ $EUID == 0 && $(uname -m) == aarch64 && $(systemd-detect-virt) == qemu ]]
[[ $(pacman -Q oma-snap-kernel-tools) == 'oma-snap-kernel-tools 0.2.0-8' ]]
id=$(printf 'v020-idle-activation-audit-2' | sha256sum | cut -d' ' -f1)
[[ ! -e /usr/lib/oma-snap/sets/$id ]]
for state in pending running complete failed; do
  [[ ! -e /var/lib/oma-snap/jobs/$state/$id.json ]]
done
work=$(mktemp -d /var/tmp/oma-snap-queue-recovery.XXXXXX)
sha256sum /boot/oma-snap/grub/grub.cfg > "$work/grub.sha256"
systemctl reset-failed oma-snap-kernel-prepare.path oma-snap-kernel-prepare.service
systemctl start oma-snap-kernel-prepare.path
printf 'oma-snap-set-%s\n' "$id" | oma-snap-kernel-queue --enqueue
for attempt in {1..120}; do
  [[ -f /var/lib/oma-snap/jobs/failed/$id.json ]] && break
  sleep 1
done
jq -e '(.error // "") != "" and (.boot_entry // "") == ""' "/var/lib/oma-snap/jobs/failed/$id.json"
systemctl start --wait oma-snap-kernel-prepare.service
systemctl is-active oma-snap-kernel-prepare.path
oma-snap-kernel-queue --check-provider-prepared
sha256sum -c "$work/grub.sha256"
test ! -e /var/lib/pacman/db.lck
echo 'PASS: watcher recovers, records missing-payload failure automatically and preserves installed provider and boot'
