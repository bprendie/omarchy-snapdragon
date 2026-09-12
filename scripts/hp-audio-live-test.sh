#!/bin/bash
# Run from the staged candidate directory on the HP; preserves existing files.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
[[ $(cat /sys/class/dmi/id/product_name) == 'HP EliteBook Ultra G1q 14 inch Notebook AI PC' ]]
cd -- "$(dirname -- "$(readlink -f -- "$0")")"
name=X1E80100-HP-ELITEBOOK-ULTRA-G1Q
firmware=/usr/lib/firmware/qcom/x1e80100/$name-tplg.bin
ucm=/usr/share/alsa/ucm2/conf.d/x1e80100/HP-HPEliteBookUltraG1q14inchNotebookAIPC-ConfigID-8CBE.conf
[[ -s $name-tplg.bin ]]
[[ -f /usr/share/alsa/ucm2/Qualcomm/x1e80100/LENOVO-T14s.conf ]]
backup=/var/lib/oma-snap/hp-audio-backup/$(date +%Y%m%d-%H%M%S)
mkdir -p "$backup"
for file in "$firmware" "$ucm"; do
  if [[ -e $file || -L $file ]]; then
    cp -a --parents "$file" "$backup"
  else
    printf '%s\n' "$file" >> "$backup/new-files"
  fi
done
install -Dm644 "$name-tplg.bin" "$firmware"
ln -sfn ../../Qualcomm/x1e80100/LENOVO-T14s.conf "$ucm"
echo "Installed HP audio candidate; backup: $backup"
# Retry only the sound-card probe. Do not unload DSP or charging drivers.
if [[ ! -e /sys/bus/platform/devices/sound/driver ]]; then
  timeout 15 bash -c 'printf sound > /sys/bus/platform/drivers/snd-x1e80100/bind'
fi
cat /proc/asound/cards
