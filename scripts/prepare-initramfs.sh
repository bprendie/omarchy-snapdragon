#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker cp profiles/t14s-lcd/initcpio/oma_snap_qcom oma-snap-root:/usr/lib/initcpio/install/oma_snap_qcom
docker cp profiles/t14s-lcd/mkinitcpio.conf oma-snap-root:/etc/mkinitcpio-oma-snap.conf
docker exec oma-snap-root bash -ec '
  depmod 7.0.0-31-generic
  mkinitcpio -c /etc/mkinitcpio-oma-snap.conf -k 7.0.0-31-generic -g /output/initramfs.img
  lsinitcpio /output/initramfs.img > /output/initramfs-contents.txt
  chmod 644 /output/initramfs.img /output/initramfs-contents.txt
'
