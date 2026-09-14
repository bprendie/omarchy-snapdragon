#!/bin/bash
# Integrate one approved signed snapshot into the verified, staged release base.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# == 2 ]] || { echo 'Usage: assemble-v020-installer.sh REPOSITORY_BUILD_NAME PINNED_PRIMARY_FINGERPRINT' >&2; exit 1; }
name=$1 key=$2
[[ $name =~ ^[a-zA-Z0-9_-]+$ && $key =~ ^[A-F0-9]{40}$ ]]
repo=$PWD/build/$name
stage=build/snapdragon-v020
iso=omarchy-snapdragon-v0.2.0.iso
[[ -d $stage/root && -f $stage/base-iso.sha256 && ! -e $iso && ! -e $stage/integration-started ]]
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
chmod 700 "$scratch"
gpg --homedir "$scratch" --batch --import "$repo/repository-key.gpg"
gpg --homedir "$scratch" --batch --export "$key" > "$scratch/pinned.gpg"
test -s "$scratch/pinned.gpg"
gpgv --keyring "$scratch/pinned.gpg" "$repo/SHA256SUMS.sig" "$repo/SHA256SUMS"
(cd "$repo" && sha256sum -c SHA256SUMS)
[[ $(cat "$repo/repository-key.fingerprint") == "$key" ]]
jq -e '.schema == 1 and .status == "approved" and (.channel == "testing" or .channel == "stable")' "$repo/approval.json" > /dev/null
channel=$(jq -er .channel "$repo/approval.json")
shopt -s nullglob
trust_packages=("$repo"/oma-snap-repository-*.pkg.tar.xz)
[[ ${#trust_packages[@]} == 1 ]]
bsdtar -xOf "${trust_packages[0]}" usr/share/oma-snap/repository.json > "$scratch/repository.json"
jq -e --arg key "$key" '
  .schema == 1 and .fingerprint == $key and
  ((.mode == "release" and (.server | startswith("https://"))) or
   (.mode == "--local-test" and .server == "file:///var/cache/oma-snap/repository"))
' "$scratch/repository.json" > /dev/null
if [[ $channel == stable ]]; then jq -e '.mode == "release"' "$scratch/repository.json" > /dev/null; fi
sha256sum -c "$stage/base-iso.sha256" build/boot-v020-provider/package.sha256
[[ -f $stage/diagnostic.img && -f $stage/boot-images/gpt_part2_efi.img ]]
patch --fuzz=0 -o "$stage/phases_impl.py" "$stage/root/usr/share/omarchy-iso/orchestrator/phases_impl.py" < profiles/snapdragon/installer-kernel-update.patch
date -u +%FT%TZ > "$stage/integration-started"
sed 's/Omarchy Snapdragon v0\.1\.2 -/Omarchy Snapdragon v0.2.0 -/' \
  "$stage/iso/boot/grub/grub.cfg" > "$stage/grub-live.cfg"
docker run --rm --network none -v "$PWD/build:/work" oma-snap-builder:local bash -ec '
  root=/work/snapdragon-v020/root
  install -m644 /work/snapdragon-v020/grub-live.cfg /work/snapdragon-v020/iso/boot/grub/grub.cfg
  install -m644 /work/snapdragon-v020/phases_impl.py "$root/usr/share/omarchy-iso/orchestrator/phases_impl.py"
  printf "%s\n" "$2" > "$root/usr/share/omarchy-iso/kernel-channel"
  mkdir -p "$root/var/cache/oma-snap"
  cp -a "/work/$1" "$root/var/cache/oma-snap/repository"
  chown -R 0:0 "$root/var/cache/oma-snap"
  chmod 755 "$root/var/cache/oma-snap/repository"
  offline="$root/var/cache/omarchy/mirror/offline"
  rm "$offline/oma-snap-boot-0.1.0-6-aarch64.pkg.tar.xz"
  cp /work/boot-v020-provider/oma-snap-boot-0.1.0-7-aarch64.pkg.tar.xz "$offline/"
  chown -R 1000:1000 "$offline"
  count=$(find "$offline" -maxdepth 1 -name "*.pkg.tar.*" ! -name "*.sig" | wc -l)
  printf "%s\n" "$count" > "$root/usr/share/omarchy-iso/expected-packages"
' bash "$name" "$channel"
repo-add "$stage/root/var/cache/omarchy/mirror/offline/oma-snap-local.db.tar.gz" \
  build/boot-v020-provider/oma-snap-boot-0.1.0-7-aarch64.pkg.tar.xz
# The signed repository takes precedence over the unchanged legacy offline DBs.
awk '
  /^\[oma-snap-local\]/ {
    print "[oma-snap]"
    print "SigLevel = PackageRequired DatabaseRequired TrustedOnly"
    print "Server = file:///var/cache/oma-snap/repository\n"
  }
  {print}
' "$stage/root/etc/pacman.conf" > "$stage/pacman-live.conf"
[[ $(grep -c '^\[oma-snap\]$' "$stage/pacman-live.conf") == 1 ]]
docker run --rm --network none -v "$PWD/build:/work" oma-snap-builder:local \
  install -m644 /work/snapdragon-v020/pacman-live.conf /work/snapdragon-v020/root/etc/pacman.conf
# Only the public repository key enters the live image's pacman trust store.
docker exec oma-snap-root pacman-key --gpgdir /output/snapdragon-v020/root/etc/pacman.d/gnupg --init
docker exec oma-snap-root pacman-key --gpgdir /output/snapdragon-v020/root/etc/pacman.d/gnupg \
  --add "/output/$name/repository-key.gpg"
docker exec oma-snap-root pacman-key --gpgdir /output/snapdragon-v020/root/etc/pacman.d/gnupg --lsign-key "$key"
docker run --rm --network none -v "$PWD/build:/work" oma-snap-builder:local bash -ec '
  stage=/work/snapdragon-v020
  rm "$stage/iso/oma_snap/aarch64/airootfs.sfs"
  mksquashfs "$stage/root" "$stage/iso/oma_snap/aarch64/airootfs.sfs" -noappend -comp zstd -Xcompression-level 3 -processors 4 -no-progress
  chown 1000:1000 "$stage/iso/oma_snap/aarch64/airootfs.sfs"
'
chmod u+w "$stage/iso/oma_snap/aarch64/airootfs.sha512"
(cd "$stage/iso/oma_snap/aarch64" && sha512sum airootfs.sfs > airootfs.sha512)
xorriso -as mkisofs -iso-level 3 -r -V OMA_SNAP -o "$iso" \
  -append_partition 2 0xef "$stage/boot-images/gpt_part2_efi.img" \
  -append_partition 3 0x0c "$stage/diagnostic.img" -appended_part_as_gpt \
  -e '--interval:appended_partition_2:all::' -no-emul-boot -partition_cyl_align off "$stage/iso"
sha256sum "$iso" > "$iso.sha256"
echo "Assembled $iso from approved $channel snapshot; boot and install validation still required"
