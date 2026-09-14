#!/bin/bash
# Read-only kmod resolution against an assembled ARM tree; never inserts modules.
set -euo pipefail
cd "$(dirname "$0")/.."
assembly=${1:?Usage: kernel-set-lookup.sh ASSEMBLY_DIRECTORY}
release=$(jq -er .kernel_release "$assembly/set.json")
[[ $release =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-generic$ ]] || exit 1
payload=$(realpath "$assembly/payload")
build/kernel-set --verify "$assembly"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir "$scratch/lib"
ln -s "$payload/modules" "$scratch/lib/modules"
for module in msm panel_edp panel_samsung_atna33xc20 gpio_sbu_mux ath12k fastrpc ov05c10 hp_camera_overlay hp_camera_children; do
  modprobe -C /dev/null -d "$scratch" -S "$release" --ignore-install --show-depends "$module" > "$scratch/dependencies"
  [[ -s $scratch/dependencies ]] || exit 1
  if [[ $module == ov05c10 ]]; then
    grep -F 'updates/oma-snap-camera-hp/ov05c10.ko' "$scratch/dependencies" >/dev/null
  fi
  echo "PASS: isolated module lookup $module"
done
for model in LENOVO/21N1 hp/elitebook-ultra-g1q ASUSTeK/zenbook-a14; do
  for file in qccdsp8380.mbn cdsp_dtbs.elf; do
    [[ -s $payload/firmware/$release/qcom/x1e80100/$model/$file ]] || exit 1
  done
  echo "PASS: firmware namespace contains $model cDSP pair"
done
