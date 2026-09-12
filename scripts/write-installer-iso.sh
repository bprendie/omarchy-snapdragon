#!/bin/bash
# Package an already validated staging tree; does not replace artifact validation.
set -euo pipefail
export TZ=UTC LC_ALL=C
cd "$(dirname "$0")/.."
iso_output=${OMA_SNAP_ISO_OUTPUT:-dist/oma-snap-installer-arm64.iso}
[[ $iso_output =~ ^(dist|build)/[A-Za-z0-9._-]+[.]iso$ ]] || { echo 'ISO output must be directly in dist/ or build/' >&2; exit 1; }
[[ ! -e $iso_output && ! -e $iso_output.sha256 ]] || { echo 'Preserve existing ISO and checksum before writing' >&2; exit 1; }
test -s build/efi.img
test -s build/installer-iso/oma_snap/aarch64/airootfs.sfs
test -s build/installer-iso/boot/grub/grub.cfg
# Same epoch as SquashFS assembly; GPT identifiers need an explicit seed too.
iso_date=$(date -u -d @1789084800 +%Y%m%d%H%M%S00)
payload_hash=$(
  (cd build/installer-iso
   LC_ALL=C find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum
   sha256sum ../efi.img) | sha256sum
)
xorriso -as mkisofs -iso-level 3 -r -V OMA_SNAP -o "$iso_output" \
  --modification-date="$iso_date" --set_all_file_dates "$iso_date" \
  --gpt_disk_guid "${payload_hash:0:32}" \
  -append_partition 2 0xef build/efi.img -appended_part_as_gpt \
  -e '--interval:appended_partition_2:all::' -no-emul-boot \
  -partition_cyl_align off build/installer-iso
sha256sum "$iso_output" > "$iso_output.sha256"
