#!/bin/bash
# Assemble only the local fixture consumed by the installed refresh test.
set -euo pipefail
cd "$(dirname "$0")/.."
key_home=${1:?Usage: kernel-repository-refresh-fixture.sh ISOLATED_KEY_HOME FINGERPRINT}
fingerprint=${2:?Missing test signer}
[[ $key_home == /* && -d $key_home && $fingerprint =~ ^[A-F0-9]{40}$ ]]
bash tests/quattro-update-packages.sh build/quattro-v020-repository 4.0.3-1.7 0.2.0-7
bash tests/kernel-repository-package.sh build/kernel-repository-v020-deployment-test \
  "$fingerprint" file:///var/tmp/kernel-repo-v020-deployment-test --local-test
bash scripts/build-local-kernel-repo.sh kernel-repo-v020-deployment-test "$key_home" "$fingerprint" \
  build/kernel-tools-v020-queue-conditions/oma-snap-kernel-tools-0.2.0-8-aarch64.pkg.tar.xz \
  build/quattro-v020-repository/omarchy/omarchy-4.0.3-1.7-aarch64.pkg.tar.xz \
  build/quattro-v020-repository/omarchy-settings/omarchy-settings-4.0.3-1.7-aarch64.pkg.tar.xz \
  build/kernel-repository-v020-deployment-test/oma-snap-repository-0.2.0-1-any.pkg.tar.xz
repo=$PWD/build/kernel-repo-v020-deployment-test
ln -s oma-snap-test.db.tar.gz "$repo/oma-snap.db"
ln -s oma-snap-test.db.tar.gz.sig "$repo/oma-snap.db.sig"
# Upstream mirrors stay offline. Empty databases model no available upstream
# upgrades, while every configuration directive still comes from the package.
for upstream in core extra alarm omarchy; do
  directory=$repo/upstream/$upstream
  mkdir -p "$directory"
  bsdtar -czf "$directory/$upstream.db" -T /dev/null
  gpg --homedir "$key_home" --batch --yes --local-user "$fingerprint!" \
    --output "$directory/$upstream.db.sig" --detach-sign "$directory/$upstream.db"
  gpgv --keyring "$repo/repository-key.gpg" "$directory/$upstream.db.sig" "$directory/$upstream.db"
done
(cd "$repo" && sha256sum oma-snap.db oma-snap.db.sig upstream/*/*.db* >> SHA256SUMS)
echo 'PASS: local installed-refresh repository fixture assembled and signed'
