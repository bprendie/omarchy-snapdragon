#!/bin/bash
# Disposable network-disabled ARM container only; /repo and /test are read-only.
set -euo pipefail
[[ -e /.dockerenv && $(uname -m) == aarch64 && $EUID == 0 ]]
fingerprint=${1:?Missing independent expected fingerprint}
[[ $fingerprint =~ ^[A-F0-9]{40}$ ]]
mkdir -p /work/bootstrap
chmod 700 /work/bootstrap
actual=$(gpg --homedir /work/bootstrap --batch --with-colons --show-keys /repo/repository-key.gpg 2>/dev/null |
  awk -F: '$1 == "fpr" {print $10; exit}')
[[ $actual == "$fingerprint" ]]
pacman-key --init
if gpg --homedir /etc/pacman.d/gnupg --list-keys "$fingerprint" >/dev/null 2>&1; then
  echo 'Test requires initially absent repository key' >&2; exit 1
fi
pacman-key --gpgdir /work/bootstrap --init
pacman-key --gpgdir /work/bootstrap --add /repo/repository-key.gpg
pacman-key --gpgdir /work/bootstrap --lsign-key "$fingerprint"
cat > /work/bootstrap.conf <<'CONF'
[options]
Architecture = auto
GPGDir = /work/bootstrap
SigLevel = PackageRequired DatabaseRequired TrustedOnly
LocalFileSigLevel = Required TrustedOnly
CONF
pacman --config /work/bootstrap.conf -U --noconfirm /repo/oma-snap-repository-0.2.0-1-any.pkg.tar.xz
# Package scriptlet must have populated the normal keyring from packaged files.
gpg --homedir /etc/pacman.d/gnupg --batch --list-keys "$fingerprint"
cat > /work/repository.conf <<'CONF'
[options]
Architecture = auto
SigLevel = PackageRequired DatabaseRequired TrustedOnly
[oma-snap-test]
Server = file:///repo
CONF
pacman --config /work/repository.conf -Syyw --noconfirm oma-snap-repository
printf '\n# locally selected mirror preserved\n' >> /etc/pacman.d/oma-snap-mirrorlist
cp /etc/pacman.d/oma-snap-mirrorlist /work/mirror-before
pacman --config /work/repository.conf -S --noconfirm oma-snap-repository
cmp /work/mirror-before /etc/pacman.d/oma-snap-mirrorlist
test ! -e /var/lib/pacman/db.lck
echo 'PASS: signed repository package populates fresh system trust and preserves mirror edits on reinstall'
