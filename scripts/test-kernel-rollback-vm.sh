#!/bin/bash
# Same-release initramfs rollback component test. Each boot gets a disposable
# root copy; only its expected test identity changes, not the retained payload.
set -euo pipefail
cd "$(dirname "$0")/.."
fixture=${1:?Usage: test-kernel-rollback-vm.sh SELECTION_FIXTURE ROOT_FIXTURE NEW_PREFIX}
root_fixture=${2:?Missing known component root fixture}
prefix=${3:?Missing new test prefix}
for name in "$fixture" "$root_fixture" "$prefix"; do [[ $name =~ ^[a-zA-Z0-9_-]+$ ]]; done
base=build/$fixture
mapfile -t a < "$base/first-boot-set"
mapfile -t b < "$base/second-boot-set"
[[ ${a[0]} == "${b[0]}" && ${a[1]} == "${b[1]}" && ${a[2]} != "${b[2]}" ]]
cmp "$base/first-boot-set" "build/$root_fixture/root/etc/oma-test-expected"
for index in 1 2 3; do [[ ! -e build/$prefix-$index ]]; done
for index in 1 2 3; do
  identity=first
  selected=${a[2]}
  fallback=${b[2]}
  if [[ $index == 2 ]]; then
    identity=second
    selected=${b[2]}
    fallback=${a[2]}
  fi
  docker run --rm --privileged --network none --name oma-snap-select-test \
    -v "$PWD/$base:/output" \
    -v "$PWD/build/oma-snap-boot-publish:/usr/bin/oma-snap-boot-publish:ro" \
    -v "$PWD/build/oma-snap-kernel-set:/usr/bin/oma-snap-kernel-set:ro" \
    -v "$PWD/tests/kernel-test-pacman-conf:/usr/bin/pacman-conf:ro" \
    -v "$PWD/build/kernel-stage-input:/usr/lib/oma-snap/sets:ro" \
    -v "$PWD/$base/cmdline:/etc/kernel/cmdline:ro" \
    oma-snap-builder:local bash -ec '
      mkdir -p /boot /var/lib/pacman
      mount -o loop /output/boot.img /boot
      trap "umount /boot" EXIT
      oma-snap-boot-publish --select "$1" --fallback "$2"
    ' bash "$selected" "$fallback"
  name=$prefix-$index
  dir=build/$name
  mkdir -p "$dir/root/etc"
  cp --reflink=auto --sparse=always "$base/boot.img" "$dir/boot.img"
  cp --reflink=auto --sparse=always "build/$root_fixture/root.img" "$dir/root.img"
  cp "$base/$identity-boot-set" "$dir/root/etc/oma-test-expected"
  debugfs -w -R 'rm /etc/oma-test-expected' "$dir/root.img"
  debugfs -w -R "write $dir/root/etc/oma-test-expected /etc/oma-test-expected" "$dir/root.img"
  debugfs -R "dump /etc/oma-test-expected $dir/expected-readback" "$dir/root.img"
  cmp "$dir/root/etc/oma-test-expected" "$dir/expected-readback"
  bash scripts/test-kernel-set-boot-vm.sh "$name"
  echo "PASS: real boot $index selected $selected"
done
echo 'PASS: same-release A/B/A initramfs boot selection and rollback'
