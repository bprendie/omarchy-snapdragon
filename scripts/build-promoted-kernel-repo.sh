#!/bin/bash
# Assemble a signed release directory locally. No upload or remote mutation.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# -ge 11 ]] || { echo 'Usage: build-promoted-kernel-repo.sh NEW_NAME KEY_HOME FINGERPRINT APPROVAL HARDWARE_PACKAGE PROVIDER_PACKAGE PREVIOUS_SEQUENCE TOOLS OMARCHY SETTINGS REPOSITORY_PACKAGE' >&2; exit 1; }
name=$1 key_home=$2 key=$3 approval=$4 hardware=$5 provider=$6 previous=$7
shift 7
[[ $name =~ ^[a-zA-Z0-9_-]+$ && $key =~ ^[A-F0-9]{40}$ && $previous =~ ^[0-9]+$ ]]
[[ $key_home == /* && -d $key_home && ! -e build/$name ]]
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
(cd tools/kernel-promotion && go build -trimpath -o ../../build/kernel-promotion .)
# Recheck the original decision and its evidence immediately before signing.
build/kernel-promotion --approval "$approval" --package "$hardware" \
  --previous-sequence "$previous" --output "$scratch/approved"
bsdtar -xOf "$provider" usr/share/oma-snap/kernel-provider/candidate.json |
  cmp - "$scratch/approved/candidate.json"
sequence=$(jq -er .sequence "$scratch/approved/candidate.json")
channel=$(jq -er .channel "$scratch/approved/candidate.json")
set_id=$(jq -er .hardware_set "$scratch/approved/candidate.json")
declare -A versions archives
for source in "$hardware" "$provider" "$@"; do
  [[ -f $source && ! -L $source ]]
  bsdtar -xOf "$source" .PKGINFO > "$scratch/pkginfo"
  pkgname=$(sed -n 's/^pkgname = //p' "$scratch/pkginfo")
  pkgver=$(sed -n 's/^pkgver = //p' "$scratch/pkginfo")
  arch=$(sed -n 's/^arch = //p' "$scratch/pkginfo")
  [[ $pkgname =~ ^[a-zA-Z0-9@._+-]+$ && -n $pkgver && $pkgver != *$'\n'* && ( $arch == aarch64 || $arch == any ) ]]
  [[ ! -v versions[$pkgname] ]]
  case "$pkgname" in
    oma-snap-set-"$set_id"|oma-snap-kernel|oma-snap-kernel-tools|omarchy|omarchy-settings|oma-snap-repository) ;;
    *) echo "Unexpected package in coordinated kernel repository: $pkgname" >&2; exit 1 ;;
  esac
  versions[$pkgname]=$pkgver
  archives[$pkgname]=$source
done
[[ ${#versions[@]} == 6 && ${versions[oma-snap-kernel]} == "1:$sequence-1" ]]
[[ ${versions[omarchy]} == "${versions[omarchy-settings]}" ]]
(( $(vercmp "${versions[oma-snap-kernel-tools]}" 0.2.0-10) >= 0 ))
(( $(vercmp "${versions[omarchy]}" 4.0.3-1.9) >= 0 ))
bsdtar -xOf "${archives[oma-snap-repository]}" usr/share/oma-snap/repository.json > "$scratch/repository.json"
jq -e --arg key "$key" --arg channel "$channel" \
  '.schema == 1 and .fingerprint == $key and
   (if $channel == "stable" then .mode == "release" and (.server | startswith("https://")) else true end)' \
  "$scratch/repository.json" > /dev/null
destination=$PWD/build/$name
mkdir "$destination"
gpg --homedir "$key_home" --batch --export "$key" > "$destination/repository-key.gpg"
test -s "$destination/repository-key.gpg"
printf '%s\n' "$key" > "$destination/repository-key.fingerprint"
cp "$scratch/approved/candidate.json" "$destination/approval.json"
packages=()
for source in "$hardware" "$provider" "$@"; do
  file=${source##*/}
  [[ $file =~ ^[a-zA-Z0-9][a-zA-Z0-9@._+-]*\.pkg\.tar\.(xz|zst|gz)$ && ! -e $destination/$file ]]
  cp --reflink=auto "$source" "$destination/$file"
  cmp "$source" "$destination/$file"
  if [[ $source == "$hardware" ]]; then
    [[ $(sha256sum "$destination/$file" | cut -d' ' -f1) == "$(jq -er .package_sha256 "$destination/approval.json")" ]]
  elif [[ $source == "$provider" ]]; then
    bsdtar -xOf "$destination/$file" usr/share/oma-snap/kernel-provider/candidate.json | cmp - "$destination/approval.json"
  fi
  gpg --homedir "$key_home" --batch --yes --local-user "$key!" \
    --output "$destination/$file.sig" --detach-sign "$destination/$file"
  gpgv --keyring "$destination/repository-key.gpg" "$destination/$file.sig" "$destination/$file"
  packages+=("$destination/$file")
done
GNUPGHOME="$key_home" repo-add --sign --key "$key" --include-sigs \
  "$destination/oma-snap.db.tar.gz" "${packages[@]}"
gpgv --keyring "$destination/repository-key.gpg" "$destination/oma-snap.db.tar.gz.sig" "$destination/oma-snap.db.tar.gz"
(cd "$destination" && sha256sum *.pkg.tar.* *.db.tar.gz* *.files.tar.gz* approval.json repository-key.* > SHA256SUMS)
gpg --homedir "$key_home" --batch --yes --local-user "$key!" \
  --output "$destination/SHA256SUMS.sig" --detach-sign "$destination/SHA256SUMS"
gpgv --keyring "$destination/repository-key.gpg" "$destination/SHA256SUMS.sig" "$destination/SHA256SUMS"
echo "Assembled signed $channel repository sequence $sequence: $destination; not uploaded"
