#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
project_root=$PWD
iso=${OMA_SNAP_TEST_ISO:-dist/oma-snap-installer-arm64.iso}
encrypted=${OMA_SNAP_VM_ENCRYPT:-0}
[[ $encrypted == 0 || $encrypted == 1 ]] || { echo 'OMA_SNAP_VM_ENCRYPT must be 0 or 1' >&2; exit 1; }
[[ $iso =~ ^dist/[A-Za-z0-9._-]+[.]iso$ ]] || { echo 'Fixture ISO must be directly in dist/' >&2; exit 1; }
export OMARCHY_INTEGRATION_ISO="$project_root/$iso"
# Reuse upstream's actual archinstall/cidata fixture generator, with ARM fields.
source sources/omarchy-iso/test/integration.d/base-test.sh
BASE_DIR="$project_root/${OMA_SNAP_VM_DIR:-build/install-vm}"
SSH_KEY="$BASE_DIR/id_ed25519"
CIDATA_IMG="$BASE_DIR/cidata.img"
mkdir -p "$BASE_DIR"
[[ -e $SSH_KEY ]] || ssh-keygen -q -t ed25519 -N '' -f "$SSH_KEY"
mcopy() {
  docker run --rm -v "$project_root:$project_root" -w "$project_root" \
    oma-snap-builder:local mcopy "$@"
}
detect_packages
build_cidata
configuration="$BASE_DIR/cidata/user_configuration.json"
jq '.bootloader_config.bootloader = "Grub" |
    .omarchy_install.boot.esp_path = "/EFI/oma-snap" |
    .omarchy_install.boot.efi_binary = "grubaa64.efi" |
    .omarchy_install.storage.kernel = "oma-snap-kernel-ubuntu" |
    .kernels = ["oma-snap-kernel-ubuntu"] |
    .mirror_config = null' "$configuration" > "$configuration.arm"
mv "$configuration.arm" "$configuration"
if [[ $encrypted == 1 ]]; then
  # Public disposable-VM passphrase; never used for a physical installation.
  jq '.disk_config.disk_encryption = {
      encryption_type: "luks", lvm_volumes: [], iter_time: 2000,
      partitions: [.disk_config.device_modifications[].partitions[] |
        select(.fs_type == "btrfs") | .obj_id],
      encryption_password: "omarchy-vm-only"
    }' "$configuration" > "$configuration.encrypted"
  mv "$configuration.encrypted" "$configuration"
  credentials="$BASE_DIR/cidata/user_credentials.json"
  jq '.encryption_password = "omarchy-vm-only"' "$credentials" > "$credentials.encrypted"
  mv "$credentials.encrypted" "$credentials"
  echo true > "$BASE_DIR/cidata/user_encrypt_installation.txt"
  mcopy -o -i "$CIDATA_IMG" "$credentials" "$BASE_DIR/cidata/user_encrypt_installation.txt" ::/
fi
mcopy -o -i "$CIDATA_IMG" "$configuration" ::/user_configuration.json
printf 'Disposable VM fixture only: %s\n' "$CIDATA_IMG"
