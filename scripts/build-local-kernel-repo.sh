#!/bin/bash
# Local signed integration fixture, not a release-promotion command.
set -euo pipefail
cd "$(dirname "$0")/.."
name=${1:?Usage: build-local-kernel-repo.sh NEW_NAME KEY_HOME FINGERPRINT PACKAGE...}
key_home=${2:?Missing isolated GnuPG directory}
key=${3:?Missing signing fingerprint}
shift 3
[[ $name =~ ^[a-zA-Z0-9_-]+$ && $key =~ ^[A-F0-9]{40}$ && $# -gt 0 ]]
[[ $key_home == /* && -d $key_home ]]
destination=$PWD/build/$name
[[ ! -e $destination ]]
mkdir -p "$destination"
gpg --homedir "$key_home" --batch --export "$key" > "$destination/repository-key.gpg"
test -s "$destination/repository-key.gpg"
printf '%s\n' "$key" > "$destination/repository-key.fingerprint"
packages=()
for source in "$@"; do
  [[ -f $source && ! -L $source ]]
  file=${source##*/}
  [[ $file =~ ^[a-zA-Z0-9][a-zA-Z0-9@._+-]*\.pkg\.tar\.(xz|zst|gz)$ ]]
  [[ ! -e $destination/$file ]]
  cp --reflink=auto "$source" "$destination/$file"
  cmp "$source" "$destination/$file"
  gpg --homedir "$key_home" --batch --yes --local-user "$key!" \
    --output "$destination/$file.sig" --detach-sign "$destination/$file"
  gpgv --keyring "$destination/repository-key.gpg" "$destination/$file.sig" "$destination/$file"
  packages+=("$destination/$file")
done
GNUPGHOME="$key_home" repo-add --sign --key "$key" --include-sigs \
  "$destination/oma-snap-test.db.tar.gz" "${packages[@]}"
gpgv --keyring "$destination/repository-key.gpg" \
  "$destination/oma-snap-test.db.tar.gz.sig" "$destination/oma-snap-test.db.tar.gz"
(cd "$destination" && sha256sum *.pkg.tar.* *.db.tar.gz* *.files.tar.gz* > SHA256SUMS)
cat > "$destination/LOCAL-TESTING-ONLY.txt" <<'EOF'
Local integration repository, not a promoted release.
Signatures establish integrity under the supplied test key, not hardware validation.
Vendor firmware redistribution rights must be established before publication.
EOF
echo "Built signed local test repository: $destination"
