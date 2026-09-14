#!/bin/bash
# Run only in a disposable container with a private mount namespace and SYS_ADMIN.
set -euo pipefail
source /hook
oma_snap_set_fail() { printf 'rejected: %s\n' "$*" >&2; exit 87; }
release=$(uname -r)
id_a=$(printf 'a%.0s' {1..64})
id_b=$(printf 'b%.0s' {1..64})
mkdir -p /etc/oma-snap /run/oma-snap
for id in "$id_a" "$id_b"; do
  base=/new_root/usr/lib/oma-snap/sets/$id
  mkdir -p "$base/modules/$release" "$base/firmware/$release"
  printf '{}\n' > "$base/set.json"
  printf '%s\n' "$id" > "$base/modules/$release/identity"
  printf '%s\n' "$id" > "$base/firmware/$release/identity"
done
for kind in modules firmware; do
  mkdir -p "/new_root/usr/lib/$kind/$release"
  printf 'legacy\n' > "/new_root/usr/lib/$kind/$release/identity"
done
for id in "$id_a" "$id_b" "$id_a"; do
  printf '%s\n%s\n%s\n' "$id" "$release" "$id_b" > /etc/oma-snap/boot-set
  run_latehook
  [[ $(cat /run/oma-snap/booted-set) == "$id" ]]
  [[ $(cat /run/oma-snap/booted-entry) == "$id_b" ]]
  for kind in modules firmware; do
    path=/new_root/usr/lib/$kind/$release
    [[ $(cat "$path/identity") == "$id" ]]
    if (printf 'changed' > "$path/identity") 2>/dev/null; then
      echo "FAIL: $kind mount is writable" >&2; exit 1
    fi
    umount "$path"
    [[ $(cat "$path/identity") == legacy ]]
  done
done
echo 'PASS: A/B/A selects matching trees at the same uname; mounts are read-only'
reject() {
  if (run_latehook) >/dev/null 2>&1; then
    echo "FAIL: accepted $1" >&2; exit 1
  else
    [[ $? == 87 ]]
  fi
  for kind in modules firmware; do
    ! mountpoint -q "/new_root/usr/lib/$kind/$release"
  done
  echo "PASS: rejected $1 before mounting"
}
printf '%s\nwrong-kernel\n%s\n' "$id_a" "$id_b" > /etc/oma-snap/boot-set
reject 'kernel mismatch'
printf '%s\n%s\n%s\nextra\n' "$id_a" "$release" "$id_b" > /etc/oma-snap/boot-set
reject 'extra identity data'
printf '%s\n%s\n%s\n' "$id_a" "$release" "$id_b" > /etc/oma-snap/boot-set
mv "/new_root/usr/lib/firmware/$release" /new_root/saved-firmware
reject 'missing firmware mountpoint'
ln -s /new_root/saved-firmware "/new_root/usr/lib/firmware/$release"
reject 'symlink mountpoint substitution'
