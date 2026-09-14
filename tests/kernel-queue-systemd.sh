#!/bin/bash
# Disposable ARM VM only. Test automatic job activation with an absent payload;
# preserve evidence and remove the temporary units/tools after the test.
set -euo pipefail
input=${1:?Missing input directory}
[[ $EUID == 0 && $(uname -m) == aarch64 ]]
for path in /usr/bin/oma-snap-kernel-queue /usr/bin/oma-snap-boot-stage /var/lib/oma-snap/jobs /etc/systemd/system/oma-snap-kernel-prepare.path /etc/systemd/system/oma-snap-kernel-prepare.service; do
  [[ ! -e $path ]] || { echo "Refusing existing test target $path" >&2; exit 1; }
done
id=$(printf 'e%.0s' {1..64})
test ! -e "/usr/lib/oma-snap/sets/$id"
evidence=$(mktemp -d /var/tmp/kernel-queue-evidence.XXXXXX)
cleanup() {
  systemctl disable --now oma-snap-kernel-prepare.path >/dev/null 2>&1 || true
  systemctl stop oma-snap-kernel-prepare.service || true
  journalctl -u oma-snap-kernel-prepare.service --no-pager > "$evidence/journal.log"
  if [[ -d /var/lib/oma-snap/jobs ]]; then mv /var/lib/oma-snap/jobs "$evidence/jobs"; fi
  rm -f /etc/systemd/system/oma-snap-kernel-prepare.{path,service}
  rm -f /usr/bin/oma-snap-kernel-queue /usr/bin/oma-snap-boot-stage
  systemctl daemon-reload
  echo "Queue test evidence: $evidence"
}
trap cleanup EXIT
install -m755 "$input/oma-snap-kernel-queue" /usr/bin/oma-snap-kernel-queue
install -m755 "$input/oma-snap-boot-stage-queued" /usr/bin/oma-snap-boot-stage
install -m644 "$input/oma-snap-kernel-prepare."{path,service} /etc/systemd/system/
systemd-analyze verify /etc/systemd/system/oma-snap-kernel-prepare.{path,service}
systemctl daemon-reload
systemctl enable --now oma-snap-kernel-prepare.path
wait_failed() {
  for attempt in {1..200}; do
    [[ -f /var/lib/oma-snap/jobs/failed/$id.json ]] && return 0
    sleep 0.1
  done
  echo 'FAIL: queued job did not reach failed state within test deadline' >&2
  return 1
}
printf 'oma-snap-set-%s\n' "$id" | oma-snap-kernel-queue --enqueue
wait_failed
cp "/var/lib/oma-snap/jobs/failed/$id.json" "$evidence/first.json"
oma-snap-kernel-queue --status
test ! -e /var/lib/pacman/db.lck
echo 'PASS: systemd path automatically starts preparation and retains its failure'
oma-snap-kernel-queue --retry "$id"
wait_failed
cp "/var/lib/oma-snap/jobs/failed/$id.json" "$evidence/retry.json"
if cmp -s "$evidence/first.json" "$evidence/retry.json"; then
  echo 'FAIL: retry did not create a new attempt' >&2; exit 1
fi
oma-snap-kernel-queue --status
systemctl is-active oma-snap-kernel-prepare.path
test ! -e /var/lib/pacman/db.lck
echo 'PASS: explicit retry gets a new logged attempt without selecting a boot entry'
