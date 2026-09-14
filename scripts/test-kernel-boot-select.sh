#!/bin/bash
# FAT publication/selection fixture; no physical block device is used.
set -euo pipefail
cd "$(dirname "$0")/.."
first=${1:?Usage: test-kernel-boot-select.sh FIRST_BUILD SECOND_BUILD NEW_NAME}
second=${2:?Missing second build basename}
name=${3:?Missing new fixture name}
[[ $first =~ ^[a-f0-9]{64}-[0-9]+$ && $second =~ ^[a-f0-9]{64}-[0-9]+$ ]]
[[ $name =~ ^[a-zA-Z0-9_-]+$ ]]
dir=build/$name
[[ ! -e $dir ]]
mkdir -p "$dir"
printf '%s\n' 'root=LABEL=SETROOT rw console=ttyAMA0,115200' > "$dir/cmdline"
truncate -s 1G "$dir/boot.img"
mkfs.fat -n SELBOOT "$dir/boot.img"
docker run --rm --privileged --network none --name oma-snap-select-test \
  -v "$PWD/$dir:/output" \
  -v "$PWD/build/oma-snap-boot-publish:/usr/bin/oma-snap-boot-publish:ro" \
  -v "$PWD/build/oma-snap-kernel-set:/usr/bin/oma-snap-kernel-set:ro" \
  -v "$PWD/tests/kernel-test-pacman-conf:/usr/bin/pacman-conf:ro" \
  -v "$PWD/build/kernel-stage-input:/usr/lib/oma-snap/sets:ro" \
  -v "$PWD/build/kernel-stage-output:/var/lib/oma-snap/staging:ro" \
  -v "$PWD/$dir/cmdline:/etc/kernel/cmdline:ro" \
  -v "$PWD/tests/kernel-boot-select-fat.sh:/test.sh:ro" \
  oma-snap-builder:local bash -ec '
    mkdir -p /boot /var/lib/pacman
    mount -o loop /output/boot.img /boot
    trap "umount /boot" EXIT
    bash /test.sh "$1" "$2"
  ' bash "/var/lib/oma-snap/staging/$first" "/var/lib/oma-snap/staging/$second"
cat > "$dir/grub.cfg" <<'EOF'
search --no-floppy --label SELBOOT --set=root
configfile /oma-snap/grub/grub.cfg
EOF
docker exec oma-snap-root grub-mkstandalone -O arm64-efi \
  -o "/output/$name/BOOTAA64.EFI" "boot/grub/grub.cfg=/output/$name/grub.cfg"
docker run --rm --network none --user "$(id -u):$(id -g)" \
  -v "$PWD/$dir:/work" oma-snap-builder:local bash -ec '
    mmd -i /work/boot.img ::/EFI ::/EFI/BOOT
    mcopy -i /work/boot.img /work/BOOTAA64.EFI ::/EFI/BOOT/BOOTAA64.EFI
  '
echo "Prepared selectable UEFI boot image: $dir/boot.img"
