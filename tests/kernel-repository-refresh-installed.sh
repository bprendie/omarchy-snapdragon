#!/bin/bash
# Installed ARM QEMU only. Exercise packaged refresh with isolated local mirrors.
set -euo pipefail
[[ $EUID == 0 && $(uname -m) == aarch64 && $(systemd-detect-virt) == qemu ]]
[[ $(findmnt -n -o SOURCE /boot) == /dev/vda1 ]]
[[ ! -e /var/lib/pacman/db.lck ]]
repo=/var/tmp/kernel-repo-v020-deployment-test
work=/var/tmp/oma-snap-repository-refresh-test
mode=${1:-install}
if [[ $mode == install ]]; then
[[ ! -e $work ]]
mkdir -p "$work/home/.config/omarchy/hooks"
cp /etc/pacman.conf "$work/pacman-before.conf"
cp /etc/pacman.d/mirrorlist "$work/mirrorlist-before"
sha256sum /boot/oma-snap/grub/grub.cfg > "$work/grub-before.sha256"
cat > "$work/bootstrap.conf" <<CONF
[options]
Architecture = aarch64
CheckSpace
GPGDir = /var/tmp/kernel-installed-package-test-2/gnupg
SigLevel = PackageRequired DatabaseRequired TrustedOnly
[oma-snap-test]
Server = file://$repo
CONF
env OMARCHY_UPDATE_PACMAN=1 pacman --config "$work/bootstrap.conf" -Syu --noconfirm
elif [[ $mode == resume ]]; then
  [[ -f $work/grub-before.sha256 && -f $work/snapdragon-mirror-before ]]
  env OMARCHY_UPDATE_PACMAN=1 pacman -Syu --noconfirm
else
  echo 'Expected install or resume' >&2; exit 2
fi
[[ $(pacman -Q oma-snap-kernel-tools) == 'oma-snap-kernel-tools 0.2.0-8' ]]
[[ $(pacman -Q omarchy) == 'omarchy 4.0.3-1.7' ]]
[[ $(pacman -Q omarchy-settings) == 'omarchy-settings 4.0.3-1.7' ]]
[[ $(pacman -Q oma-snap-repository) == 'oma-snap-repository 0.2.0-1' ]]
export OMARCHY_PATH=/usr/share/omarchy
export PATH="$OMARCHY_PATH/bin:$PATH"
omarchy-update-snapdragon-kernel
# Use the supported pre-refresh hook only to redirect upstream mirrors into
# empty local fixture repositories. The installed Snapdragon include is intact.
cat > "$work/home/.config/omarchy/hooks/pre-refresh-pacman" <<'HOOK'
#!/bin/bash
set -euo pipefail
printf 'Server = file:///var/tmp/kernel-repo-v020-deployment-test/upstream/$repo\n' > /etc/pacman.d/mirrorlist
sed -i 's|^Server = https://pkgs.omarchy.org/edge/\$arch$|Server = file:///var/tmp/kernel-repo-v020-deployment-test/upstream/omarchy|' /etc/pacman.conf
HOOK
if [[ $mode == install ]]; then
  printf '\n# local mirror annotation must survive refresh\n' >> /etc/pacman.d/oma-snap-mirrorlist
  cp /etc/pacman.d/oma-snap-mirrorlist "$work/snapdragon-mirror-before"
fi
for channel in stable rc edge; do
  HOME="$work/home" omarchy-refresh-pacman "$channel"
  [[ $(pacman-conf --repo-list) == $'oma-snap\ncore\nextra\nalarm\nomarchy' ]]
  [[ $(pacman-conf --repo oma-snap Server) == "file://$repo" ]]
  [[ $(pacman-conf --repo oma-snap SigLevel) == $'PackageRequired\nPackageTrustedOnly\nDatabaseRequired\nDatabaseTrustedOnly' ]]
  [[ $(pacman-conf IgnorePkg) == $'hyprland\nhyprtoolkit\nhyprland-guiutils' ]]
  cmp "$work/snapdragon-mirror-before" /etc/pacman.d/oma-snap-mirrorlist
  [[ ! -e /var/lib/pacman/db.lck ]]
done
omarchy-update-system-pkgs
omarchy-update-snapdragon-kernel
[[ $(oma-snap-boot-publish --reboot-status) == current ]]
sha256sum -c "$work/grub-before.sha256"
test ! -e /var/lib/pacman/db.lck
echo 'PASS: installed refresh preserves signed Snapdragon updates across all templates and subsequent package update'
