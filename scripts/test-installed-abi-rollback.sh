#!/bin/bash
# Three real reboots of the existing disposable installed ARM VM; no VM restart.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# == 0 ]]
dir=build/kernel-update-vm
[[ $(docker inspect -f '{{.State.Running}}' oma-snap-installed-test) == true ]]
[[ ! -e $dir/abi-rollback-started ]]
grep -Fxq 'PASS: different-ABI test set prepared automatically without changing the installed provider or boot selection' "$dir/abi30-install-prepare.log"
grep -Fxq 'PASS: signed activation-aware updater installed; unapproved provider remains unselected' "$dir/activation-stack-install.log"
ssh_args=(-i "$dir/id_ed25519" -p 2340 -o BatchMode=yes -o ConnectTimeout=10
  -o UserKnownHostsFile="$dir/installed-known_hosts" root@127.0.0.1)
ssh "${ssh_args[@]}" 'bash /var/tmp/kernel-abi-rollback-installed.sh initialize' > "$dir/abi-rollback-initialize.log" 2>&1
date -u +%FT%TZ > "$dir/abi-rollback-started"
index=0
for phase in old new old; do
  index=$((index + 1))
  prefix=$dir/abi-rollback-$index-$phase
  ssh "${ssh_args[@]}" "bash /var/tmp/kernel-abi-rollback-installed.sh select-$phase" > "$prefix-selection.log" 2>&1
  before=$(ssh "${ssh_args[@]}" 'cat /proc/sys/kernel/random/boot_id')
  [[ $before =~ ^[a-f0-9-]{36}$ ]]
  printf '%s\n' "$before" > "$prefix-before-boot-id"
  ssh "${ssh_args[@]}" 'systemctl reboot' > "$prefix-reboot.log" 2>&1
  deadline=$((SECONDS + 1200))
  ready=0
  while (( SECONDS < deadline )); do
    if ssh "${ssh_args[@]}" 'cat /proc/sys/kernel/random/boot_id; systemctl is-active multi-user.target' > "$prefix-readiness.log" 2>/dev/null; then
      after=$(head -n1 "$prefix-readiness.log")
      if [[ $after =~ ^[a-f0-9-]{36}$ && $after != "$before" ]]; then ready=1; break; fi
    fi
    sleep 5
  done
  [[ $ready == 1 ]] || { echo "Boot $index did not reach a new multi-user session; inspect the still-running VM" >&2; exit 1; }
  ssh "${ssh_args[@]}" "bash /var/tmp/kernel-abi-rollback-installed.sh check-$phase" > "$prefix-check.log" 2>&1
  echo "PASS: different-ABI boot $index ($phase), new boot ID $after"
done
echo 'PASS: installed ABI30 -> ABI31 -> ABI30 boots with matching retained payloads and preserved legacy fallback'
