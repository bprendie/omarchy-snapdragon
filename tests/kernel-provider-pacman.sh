#!/bin/bash
# Disposable ARM container only. Synthetic payloads and unsigned fixture repo;
# exercise the real provider recipe, pacman resolver and production queue hook.
set -euo pipefail
[[ $(uname -m) == aarch64 && $EUID == 0 && -f /.dockerenv ]]
work=$(mktemp -d /var/tmp/provider-pacman.XXXXXX)
mkdir "$work/repo"
a=$(printf 'a%.0s' {1..64})
b=$(printf 'b%.0s' {1..64})
archive() {
  local source=$1 name=$2 version=$3
  tar --owner=0 --group=0 -C "$source" -cf "$work/repo/$name-$version-aarch64.pkg.tar" .PKGINFO usr
}
for id in "$a" "$b"; do
  source=$work/$id
  mkdir -p "$source/usr/share/oma-provider-fixture"
  printf '%s\n' "$id" > "$source/usr/share/oma-provider-fixture/$id"
  cat > "$source/.PKGINFO" <<EOF
pkgname = oma-snap-set-$id
pkgver = 0.2.0-1
pkgdesc = Synthetic provider dependency fixture
arch = aarch64
size = 65
builddate = 1
EOF
  archive "$source" "oma-snap-set-$id" 0.2.0-1
done
source=$work/tools
mkdir -p "$source/usr/bin" "$source/usr/share/libalpm/hooks"
cp /input/oma-snap-kernel-queue "$source/usr/bin/"
cp /input/95-oma-snap-prepare.hook "$source/usr/share/libalpm/hooks/"
cat > "$source/.PKGINFO" <<'EOF'
pkgname = oma-snap-kernel-tools
pkgver = 0.2.0-3
pkgdesc = Production queue and hook in a synthetic dependency fixture
arch = aarch64
size = 1
builddate = 1
EOF
archive "$source" oma-snap-kernel-tools 0.2.0-3
cat > "$work/pacman.conf" <<EOF
[options]
Architecture = aarch64
SigLevel = Never
LocalFileSigLevel = Never
[oma-provider-test]
Server = file://$work/repo
EOF
pm() { pacman --config "$work/pacman.conf" "$@"; }
provider() (
  local id=$1 revision=$2
  # Only the chosen hardware identity and package revision differ. Run the
  # production recipe's package() function and dependency declarations.
  sed -e "s/^_set_id=.*/_set_id=$id/" -e "s/^pkgrel=.*/pkgrel=$revision/" /input/PKGBUILD > "$work/provider-$revision.recipe"
  source "$work/provider-$revision.recipe"
  pkgdir=$work/provider-$revision
  mkdir "$pkgdir"
  package
  {
    printf 'pkgname = %s\npkgver = %s-%s\narch = aarch64\npkgdesc = Provider transaction fixture\nsize = 190\nbuilddate = 1\n' "$pkgname" "$pkgver" "$pkgrel"
    printf 'depend = %s\n' "${depends[@]}"
  } > "$pkgdir/.PKGINFO"
  archive "$pkgdir" "$pkgname" "$pkgver-$pkgrel"
)
provider "$a" 1
repo-add "$work/repo/oma-provider-test.db.tar.gz" "$work/repo/"*.pkg.tar
pm -Sy --noconfirm oma-snap-kernel
pm -Q "oma-snap-set-$a"
[[ -f /var/lib/oma-snap/jobs/pending/$a.json ]]
provider "$b" 2
repo-add "$work/repo/oma-provider-test.db.tar.gz" "$work/repo/oma-snap-kernel-7.0.0.31.31-2-aarch64.pkg.tar"
pm -Syu --noconfirm
pm -Q oma-snap-kernel | grep -Fx 'oma-snap-kernel 7.0.0.31.31-2'
pm -Q "oma-snap-set-$a" "oma-snap-set-$b"
for id in "$a" "$b"; do
  [[ -f /var/lib/oma-snap/jobs/pending/$id.json ]]
  [[ $(cat "/usr/share/oma-provider-fixture/$id") == "$id" ]]
done
grep -F "$b" /usr/share/oma-snap/kernel-provider/candidate.json
[[ -z $(find /var/lib/oma-snap/jobs/work -mindepth 1 -print -quit) ]]
echo 'PASS: pacman -Syu follows the provider dependency, retains the old set and queues preparation without inline boot work'
# Review the real orphan query through the patched Omarchy helper. Keep an
# ordinary orphan in the fixture to prove the review still presents it.
source=$work/ordinary-orphan
mkdir -p "$source/usr/share/oma-provider-fixture"
printf 'ordinary\n' > "$source/usr/share/oma-provider-fixture/ordinary"
cat > "$source/.PKGINFO" <<'EOF'
pkgname = oma-provider-ordinary-orphan
pkgver = 1-1
pkgdesc = Ordinary orphan review fixture
arch = aarch64
size = 9
builddate = 1
EOF
archive "$source" oma-provider-ordinary-orphan 1-1
pm -U --asdeps --noconfirm "$work/repo/oma-provider-ordinary-orphan-1-1-aarch64.pkg.tar"
pacman -Qtdq | grep -Fx "oma-snap-set-$a"
bash /input/omarchy-update-orphan-pkgs > "$work/orphan-review.log"
cat "$work/orphan-review.log"
grep -q 'oma-provider-ordinary-orphan' "$work/orphan-review.log"
if grep -q 'oma-snap-set-' "$work/orphan-review.log"; then
  echo 'FAIL: general orphan review included a retained hardware package' >&2; exit 1
fi
echo 'PASS: Omarchy orphan review excludes retained sets and preserves ordinary orphan review'
