#!/bin/bash
# Runs inside the named disposable ARM container, never on the development host.
set -euo pipefail
[[ $(uname -m) == aarch64 && -f /.dockerenv && -d /output ]] || { echo 'Run only in the oma_snap ARM build container' >&2; exit 1; }
: > /etc/fstab
: > /etc/crypttab
: > /etc/machine-id
rm -f /var/lib/dbus/machine-id /etc/ssh/ssh_host_*
# Docker binds resolv.conf; replace it in the exported root, after container work.
passwd -l root
if id alarm >/dev/null 2>&1; then
  passwd -l alarm
  usermod -s /usr/bin/nologin alarm
fi
for service in sshd systemd-networkd systemd-networkd-wait-online systemd-resolved; do
  systemctl disable "$service.service" || true
done
systemctl mask sshd.service
systemctl set-default multi-user.target
for tty in getty@tty1 serial-getty@ttyAMA0; do
  mkdir -p "/etc/systemd/system/$tty.service.d"
  cat > "/etc/systemd/system/$tty.service.d/live.conf" <<'DROPIN'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
DROPIN
done
cat > /etc/issue <<'ISSUE'
oma_snap: Arch ARM console prototype, Ubuntu kernel bridge.
Ephemeral RAM overlay. Local root console; SSH disabled. No automatic installation.
Hardware validation and Omarchy desktop integration are incomplete.
ISSUE
cat > /root/.bash_profile <<'PROFILE'
cat /etc/issue
printf '\nKernel: '; uname -r
printf 'Root: '; findmnt -n -o FSTYPE /
printf '\nRun oma-snap-inventory for a redacted report.\n'
PROFILE
install -Dm755 /output/oma-snap-inventory-arm64 /usr/local/bin/oma-snap-inventory
rm -f /root/.bash_history
