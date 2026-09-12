#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
iso=omarchy-snapdragon-v0.1.0.iso
root=build/snapdragon-v0_1_0-installer-root
stage=build/snapdragon-v0_1_0-installer-iso
[[ ! -e $root && ! -e $stage && ! -e $iso ]]
sha256sum -c manifests/hp-firmware-package.sha256 manifests/hp-firmware-input.sha256 manifests/hp-audio-package.sha256 manifests/asus-a14-firmware-package.sha256 manifests/boot-package.sha256
patch --fuzz=0 -o build/snapdragon-phases_impl.py build/installer-root-export/usr/share/omarchy-iso/orchestrator/phases_impl.py < profiles/snapdragon/installer-firmware.patch
(cd tools/hp-diag && CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -o ../../build/hp-diag-build/oma-snap-hp-diag .)
(cd tools/image-delta && go build -trimpath -o ../../build/image-delta .)
docker run --rm --network none -v "$PWD:/work" -w /work oma-snap-builder:local bash -ec '
  cp -a --reflink=auto build/installer-root-export build/snapdragon-v0_1_0-installer-root
  cp -a --reflink=auto build/installer-iso build/snapdragon-v0_1_0-installer-iso
  root=build/snapdragon-v0_1_0-installer-root
  chown 0:0 "$root/usr" "$root/usr/share"
  install -Dm755 build/hp-diag-build/oma-snap-hp-diag "$root/usr/local/bin/oma-snap-hp-diag"
  install -Dm644 profiles/hp-elitebook-ultra-g1q/oma-snap-diag.service "$root/etc/systemd/system/oma-snap-diag.service"
  ln -s ../oma-snap-diag.service "$root/etc/systemd/system/multi-user.target.wants/oma-snap-diag.service"
  cp "$root/root/.bash_profile" "$root/root/.bash_profile.installer"
  cat > "$root/root/.bash_profile" <<PROFILE
if grep -qw oma_snap_diag=1 /proc/cmdline; then
  echo "HP diagnostics running; logs save to OMADIAG, followed by poweroff."
else
  source /root/.bash_profile.installer
fi
PROFILE
  install -m644 build/snapdragon-phases_impl.py "$root/usr/share/omarchy-iso/orchestrator/phases_impl.py"
  cp build/hp-firmware-package/*.pkg.tar.xz build/hp-audio-package/*.pkg.tar.xz build/asus-a14-firmware-package/*.pkg.tar.xz "$root/var/cache/omarchy/mirror/offline/"
  rm "$root/var/cache/omarchy/mirror/offline/oma-snap-boot-0.1.0-4-aarch64.pkg.tar.xz"
  cp build/boot-package/oma-snap-boot-0.1.0-6-aarch64.pkg.tar.xz "$root/var/cache/omarchy/mirror/offline/"
  chown -R 1000:1000 "$root/var/cache/omarchy/mirror/offline"
  count=$(cat "$root/usr/share/omarchy-iso/expected-packages")
  echo $((count + 3)) > "$root/usr/share/omarchy-iso/expected-packages"
  chown -R 1000:1000 build/snapdragon-v0_1_0-installer-iso
'
repo-add "$root/var/cache/omarchy/mirror/offline/oma-snap-local.db.tar.gz" build/hp-firmware-package/*.pkg.tar.xz build/hp-audio-package/*.pkg.tar.xz build/asus-a14-firmware-package/*.pkg.tar.xz build/boot-package/oma-snap-boot-0.1.0-6-aarch64.pkg.tar.xz
# Pacman owns the added files in both the live image and the build container.
docker exec oma-snap-root bash -ec '
  pacman -U --noconfirm /output/hp-firmware-package/*.pkg.tar.xz /output/hp-audio-package/*.pkg.tar.xz /output/asus-a14-firmware-package/*.pkg.tar.xz /output/boot-package/oma-snap-boot-0.1.0-6-aarch64.pkg.tar.xz
  pacman --root /output/snapdragon-v0_1_0-installer-root -U --noconfirm /output/hp-firmware-package/*.pkg.tar.xz /output/hp-audio-package/*.pkg.tar.xz /output/asus-a14-firmware-package/*.pkg.tar.xz /output/boot-package/oma-snap-boot-0.1.0-6-aarch64.pkg.tar.xz
  mkinitcpio -c /etc/mkinitcpio-oma-snap.conf -k 7.0.0-31-generic -g /output/snapdragon-v0_1_0-initramfs.img
  lsinitcpio /output/snapdragon-v0_1_0-initramfs.img > /output/snapdragon-v0_1_0-initramfs-contents.txt
  chmod 644 /output/snapdragon-v0_1_0-initramfs.img /output/snapdragon-v0_1_0-initramfs-contents.txt
'
cp build/snapdragon-v0_1_0-initramfs.img "$stage/oma_snap/boot/initramfs.img"
cp profiles/snapdragon/grub-installer.cfg "$stage/boot/grub/grub.cfg"
docker run --rm --network none -v "$PWD:/work" -w /work oma-snap-builder:local bash -ec '
  rm build/snapdragon-v0_1_0-installer-iso/oma_snap/aarch64/airootfs.sfs
  mksquashfs build/snapdragon-v0_1_0-installer-root build/snapdragon-v0_1_0-installer-iso/oma_snap/aarch64/airootfs.sfs -noappend -comp zstd -Xcompression-level 3 -processors 4 -no-progress
  chown 1000:1000 build/snapdragon-v0_1_0-installer-iso/oma_snap/aarch64/airootfs.sfs
'
(cd "$stage/oma_snap/aarch64" && sha512sum airootfs.sfs > airootfs.sha512)
cp --reflink=auto build/hp-diag-logs.img build/snapdragon-v0_1_0-installer-logs.img
docker run --rm --network none --user "$(id -u):$(id -g)" -v "$PWD:/work" oma-snap-builder:local \
  mcopy -o -i /work/build/snapdragon-v0_1_0-installer-logs.img /work/profiles/snapdragon/USB-README.txt ::/README.txt
xorriso -as mkisofs -iso-level 3 -r -V OMA_SNAP -o "$iso" \
  -append_partition 2 0xef build/efi.img -append_partition 3 0x0c build/snapdragon-v0_1_0-installer-logs.img \
  -appended_part_as_gpt -e '--interval:appended_partition_2:all::' -no-emul-boot \
  -partition_cyl_align off "$stage"
sha256sum "$iso" > "$iso.sha256"
