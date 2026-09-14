#!/bin/bash
# Run only in a disposable ARM container, in a private mount namespace.
# Synthetic unsigned packages test directory ownership, not authentication.
# This reproduces why empty-directory ownership alone is NOT a retention fix.
set -euo pipefail
mode=${1:-reproduce}
[[ $mode == reproduce || $mode == protected ]]
[[ $(uname -m) == aarch64 && $EUID == 0 ]]
[[ -f /.dockerenv ]]
[[ $(readlink /proc/self/ns/mnt) != "$(readlink /proc/$PPID/ns/mnt)" ]]
# Preserve ALPM hooks, but omit the unrelated base image's Arch kernel preset.
mount -t tmpfs tmpfs /etc/mkinitcpio.d
release=9.99.0-999-generic
work=$(mktemp -d /var/tmp/mountpoint-pacman.XXXXXX)
for kind in modules firmware; do
  [[ ! -e /usr/lib/$kind/$release ]]
  mkdir -p "$work/$kind" "/usr/lib/$kind/$release"
  printf '%s\n' "$kind retained bytes" > "$work/$kind/retained"
  mount --bind "$work/$kind" "/usr/lib/$kind/$release"
  mount -o remount,bind,ro "/usr/lib/$kind/$release"
done
cleanup() {
  for kind in modules firmware; do
    if mountpoint -q "/usr/lib/$kind/$release"; then
      umount "/usr/lib/$kind/$release"
    fi
  done
}
trap cleanup EXIT
cat > "$work/pacman.conf" <<'EOF'
[options]
Architecture = aarch64
SigLevel = Never
LocalFileSigLevel = Never
EOF
pm() { pacman --config "$work/pacman.conf" "$@"; }
if [[ $mode == protected ]]; then
  pm -U --noconfirm /input/rsync.pkg.tar.xz /input/xxhash.pkg.tar.xz
  install -m755 /input/oma-snap-kernel-maintenance /usr/bin/oma-snap-kernel-maintenance
  mkdir -p /etc/pacman.d/hooks
  cp /input/60-depmod.hook /etc/pacman.d/hooks/
fi
for name in a b; do
  source=$work/pkg-$name
  mkdir -p "$source/usr/lib/"{modules,firmware}/"$release"
  if [[ $mode == protected ]]; then
    id=$(printf "$name%.0s" {1..64})
    mkdir -p "$source/usr/lib/oma-snap/sets/$id"
    printf '{"schema":1,"id":"%s","kernel_release":"%s"}\n' "$id" "$release" > "$source/usr/lib/oma-snap/sets/$id/set.json"
  fi
  cat > "$source/.PKGINFO" <<EOF
pkgname = oma-mountpoint-fixture-$name
pkgver = 1-1
pkgdesc = Empty mountpoint ownership fixture
arch = aarch64
size = 0
builddate = 1
EOF
  tar -C "$source" -cf "$work/$name.pkg.tar" .PKGINFO usr
  pm -U --noconfirm "$work/$name.pkg.tar"
done
for kind in modules firmware; do
  [[ $(cat "/usr/lib/$kind/$release/retained") == "$kind retained bytes" ]]
  findmnt -n -o OPTIONS "/usr/lib/$kind/$release" | grep -qw ro
  pm -Qo "/usr/lib/$kind/$release"
done
echo 'PASS: two packages share empty directories beneath active read-only binds'
cleanup
# The installed cleanup service skips pacman-owned non-running module dirs.
# Exercise its ownership decision without touching unrelated container modules.
if ! pm -Qo "/usr/lib/modules/$release"; then
  echo 'FAIL: cleanup would remove retained mountpoint' >&2; exit 1
fi
pm -R --noconfirm oma-mountpoint-fixture-a
pm -Ql oma-mountpoint-fixture-b | grep -F "/usr/lib/modules/$release/"
[[ -d /usr/lib/firmware/$release ]]
if [[ $mode == protected ]]; then
  [[ -d /usr/lib/modules/$release ]]
  # Exercise the exact command used by the service drop-in. The two unrelated
  # unowned directories must still be archived; the retained one must remain.
  for old in 9.98.0-1-obsolete 9.98.0-2-obsolete; do
    mkdir "/usr/lib/modules/$old"
    printf '%s\n' "$old" > "/usr/lib/modules/$old/evidence"
  done
  # Actual retained packages own private payloads, not public mountpoints.
  private_id=$(printf 'c%.0s' {1..64})
  private_release=9.97.0-1-generic
  mkdir -p "/usr/lib/oma-snap/sets/$private_id"
  printf '{"schema":1,"id":"%s","kernel_release":"%s"}\n' "$private_id" "$private_release" > "/usr/lib/oma-snap/sets/$private_id/set.json"
  oma-snap-kernel-maintenance --cleanup
  [[ -d /usr/lib/modules/$release ]]
  for kind in modules firmware; do
    [[ -d /usr/lib/$kind/$private_release ]]
    if pm -Qo "/usr/lib/$kind/$private_release"; then
      echo 'FAIL: supposedly unowned fixture directory is owned' >&2; exit 1
    fi
  done
  for old in 9.98.0-1-obsolete 9.98.0-2-obsolete; do
    [[ ! -e /usr/lib/modules/$old ]]
    [[ $(cat "/usr/lib/modules/.old/$old/evidence") == "$old" ]]
  done
  [[ ! -e /var/lib/pacman/db.lck ]]
  printf 'held fixture lock\n' > /var/lib/pacman/db.lck
  if oma-snap-kernel-maintenance --cleanup; then
    echo 'FAIL: cleanup ignored pacman lock' >&2; exit 1
  fi
  [[ $(cat /var/lib/pacman/db.lck) == 'held fixture lock' ]]
  rm /var/lib/pacman/db.lck
  rm "/usr/lib/oma-snap/sets/$private_id/set.json"
  rmdir "/usr/lib/oma-snap/sets/$private_id"
  echo 'PASS: retained mountpoints survive package removal and cleanup; unrelated modules archived'
else
  [[ ! -e /usr/lib/modules/$release ]]
  echo 'REPRODUCED: depmod removes the empty module directory still owned by the other set'
fi
pm -R --noconfirm oma-mountpoint-fixture-b
for kind in modules firmware; do [[ ! -e /usr/lib/$kind/$release ]]; done
echo "PASS: $mode fixture removed"
