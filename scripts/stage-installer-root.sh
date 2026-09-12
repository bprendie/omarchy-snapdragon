#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/prepare-quattro-profile.sh
bash scripts/fetch-node.sh
cp dist/oma-snap-inventory-arm64 build/
cp scripts/configure-live-root.sh build/
cp profiles/t14s-lcd/live-ssh.pub build/live-ssh.pub
cp scripts/live-ssh.sh build/live-ssh.sh
docker exec oma-snap-root bash -ec '
  test "$(uname -m)" = aarch64
  test -e /.dockerenv
  test ! -e /var/lib/pacman/db.lck
  bash /output/configure-live-root.sh
  printf "LANG=C.UTF-8\n" > /etc/locale.conf
  printf "KEYMAP=us\n" > /etc/vconsole.conf
  install -d -m700 /root/.ssh
  install -m600 /output/live-ssh.pub /root/.ssh/authorized_keys
  install -Dm755 /output/live-ssh.sh /usr/local/bin/oma-snap-live-ssh
  mkdir -p /etc/ssh/sshd_config.d
  cat > /etc/ssh/sshd_config.d/00-oma-snap-live.conf <<EOF
PermitRootLogin prohibit-password
PasswordAuthentication no
KbdInteractiveAuthentication no
AuthenticationMethods publickey
AllowUsers root
EOF
  cp -a /sources/omarchy-iso-snap/configs/airootfs/usr/. /usr/
  install -m755 /sources/omarchy-iso-snap/configs/airootfs/root/configurator /root/configurator
  install -m755 /sources/omarchy-iso-snap/configs/airootfs/root/.automated_script.sh /root/.automated_script.sh
  install -m644 /usr/share/omarchy/install/provisioning/setup-form.sh /usr/share/omarchy-iso/setup-form.sh
  for list in omarchy-base.packages omarchy-other.packages; do
    install -m644 "/usr/share/omarchy/install/$list" "/usr/share/omarchy-iso/$list"
    cmp "/sources/omarchy-snap/install/$list" "/usr/share/omarchy-iso/$list"
  done
  printf "stable\n" > /root/omarchy_iso_ref
  printf "edge\n" > /root/omarchy_mirror
  printf "OMARCHY_RUNTIME_PACKAGE=omarchy\nOMARCHY_SETTINGS_PACKAGE=omarchy-settings\nOMARCHY_NVIM_PACKAGE=omarchy-nvim\n" > /usr/share/omarchy-iso/package-targets
  cat > /etc/issue <<EOF
oma_snap: Quattro ARM installer development candidate.
Installation is not yet validated on physical hardware.
The stock installer runs on tty1. Other consoles provide a recovery shell.
EOF
  cat > /root/.bash_profile <<EOF
export OMARCHY_PATH=/usr/share/omarchy
if [[ \$(tty) == /dev/tty1 ]]; then
  bash /root/.automated_script.sh
else
  cat /etc/issue
fi
EOF
  systemctl enable NetworkManager.service
  systemctl disable sddm.service || true
  systemctl set-default multi-user.target
  mkdir -p /opt/packages
  cp /inputs/node-v26.8.2-linux-arm64.tar.gz /opt/packages/
'
[[ ! -e build/installer-root.tar ]] || { echo 'Installer root export exists; preserve it before exporting again' >&2; exit 1; }
docker export oma-snap-root -o build/installer-root.tar
sha256sum build/installer-root.tar > manifests/installer-root-export.sha256
