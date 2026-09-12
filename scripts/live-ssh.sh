#!/bin/bash
# Opt-in SSH for the ephemeral installer, never the installed target.
set -euo pipefail
[[ $EUID == 0 && -d /run/archiso && $(findmnt -n -o FSTYPE /) == overlay ]] || {
  echo 'Run this from the live installer root console.' >&2
  exit 1
}
ssh-keygen -A
systemctl unmask sshd.service
systemctl start sshd.service
echo 'Live SSH enabled with the dedicated public key. Network addresses:'
ip -brief address show scope global
echo 'SSH host fingerprint:'
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
