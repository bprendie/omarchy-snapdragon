#!/bin/bash
# Disposable privileged ARM container only; unsigned synthetic packages isolate
# ALPM retention behavior from the separately tested repository trust chain.
set -euo pipefail
[[ $(uname -m) == aarch64 && $EUID == 0 && -f /.dockerenv ]]
[[ $(readlink /proc/self/ns/mnt) != "$(readlink /proc/$PPID/ns/mnt)" ]]
work=$(mktemp -d /var/tmp/legacy-retain.XXXXXX)
mkdir -p /boot /etc/oma-snap /etc/pacman.d/hooks
truncate -s 16M "$work/esp.img"
mkfs.fat "$work/esp.img" >/dev/null
mount -o loop "$work/esp.img" /boot
trap 'umount /boot' EXIT
printf '%s\n' /boot > /etc/oma-snap/esp-path
install -m755 /input/oma-snap-kernel-retain /usr/bin/oma-snap-kernel-retain
cp /input/02-oma-snap-retain-legacy.hook /etc/pacman.d/hooks/
cat > "$work/pacman.conf" <<'EOF'
[options]
Architecture = aarch64
SigLevel = Never
LocalFileSigLevel = Never
EOF
pm() { pacman --config "$work/pacman.conf" "$@"; }
mkdir -p /boot/oma-snap/7.0.0-31-generic
printf 'legacy kernel\n' > /boot/oma-snap/7.0.0-31-generic/vmlinuz.efi
sha256sum /boot/oma-snap/7.0.0-31-generic/vmlinuz.efi > "$work/boot.sha256"
mapfile -t names < <(sed -n 's/^Target = //p' /input/02-oma-snap-retain-legacy.hook)
for name in "${names[@]}"; do
  for version in 1-1 2-1; do
    source=$work/$name-$version
    mkdir -p "$source/opt/legacy-retain-test"
    printf '%s\n' "$version" > "$source/opt/legacy-retain-test/$name"
    cat > "$source/.PKGINFO" <<EOF
pkgname = $name
pkgver = $version
pkgdesc = Synthetic legacy retention fixture
arch = aarch64
size = 4
builddate = 1
EOF
    tar -C "$source" -cf "$source.pkg.tar" .PKGINFO opt
  done
  pm -U --noconfirm "$work/$name-1-1.pkg.tar" >/dev/null
done
reject() {
  if pm "$@" > "$work/rejection.log" 2>&1; then
    echo "FAIL: accepted protected transaction: $*" >&2; exit 1
  fi
  grep -F 'released legacy boot remains' "$work/rejection.log"
  grep -q 'failed to commit transaction' "$work/rejection.log"
  test ! -e /var/lib/pacman/db.lck
  sha256sum -c "$work/boot.sha256"
}
for name in "${names[@]}"; do
  reject -R --noconfirm "$name"
  reject -U --noconfirm "$work/$name-1-1.pkg.tar"
  reject -U --noconfirm "$work/$name-2-1.pkg.tar"
  [[ $(pm -Q "$name") == "$name 1-1" ]]
  [[ $(cat "/opt/legacy-retain-test/$name") == 1-1 ]]
done
reject -R --noconfirm "${names[@]}"
echo 'PASS: retained legacy boot rejects removal, reinstall, upgrade and batch removal of all eight dependencies'
# Simulate explicit retirement; production retirement is a separate operation.
mv /boot/oma-snap/7.0.0-31-generic "$work/retired"
pm -R --noconfirm "${names[@]}"
echo 'PASS: retired legacy boot permits dependency removal'
