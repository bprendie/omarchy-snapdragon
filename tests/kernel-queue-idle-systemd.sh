#!/bin/bash
# Actual systemd condition/start-limit behavior in a disposable ARM QEMU guest.
set -euo pipefail
input=${1:?Missing candidate service file}
[[ $EUID == 0 && $(uname -m) == aarch64 && $(systemd-detect-virt) == qemu ]]
unit=oma-snap-queue-condition-test.service
path=/etc/systemd/system/$unit
[[ ! -e $path ]]
work=$(mktemp -d /var/tmp/oma-snap-queue-condition.XXXXXX)
mkdir "$work/pending" "$work/running"
cleanup() {
  systemctl stop "$unit" || true
  journalctl -u "$unit" --no-pager > "$work/journal.log"
  rm -f "$path"
  systemctl daemon-reload
  systemctl reset-failed "$unit" 2>/dev/null || true
  echo "Condition test evidence: $work"
}
trap cleanup EXIT
sed -e "s|/var/lib/oma-snap/jobs/|$work/|g" \
  -e "s|^ExecStart=.*|ExecStart=/usr/bin/touch $work/executed|" "$input" > "$path"
systemd-analyze verify "$path"
systemctl daemon-reload
# These are more calls than the configured burst of three. None may launch.
for attempt in {1..8}; do systemctl start --wait "$unit"; done
[[ ! -e $work/executed ]]
[[ $(systemctl show "$unit" -p ConditionResult --value) == no ]]
# Both possible work states independently permit the worker to start.
for state in pending running; do
  touch "$work/$state/job"
  systemctl start --wait "$unit"
  [[ -e $work/executed ]]
  rm "$work/executed" "$work/$state/job"
done
for attempt in {1..8}; do systemctl start --wait "$unit"; done
[[ ! -e $work/executed ]]
[[ $(systemctl show "$unit" -p Result --value) == success ]]
echo 'PASS: repeated idle waits skip worker starts; pending and interrupted jobs both activate'
