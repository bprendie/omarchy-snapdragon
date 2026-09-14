#!/bin/bash
# Run inside the isolated staging builder after boot-stage exits successfully.
set -euo pipefail
work=${1:?Usage: kernel-stage-artifact.sh STAGING_DIRECTORY}
[[ $work == /var/lib/oma-snap/staging/* && -s $work/built.json ]] || exit 1
mapfile -t identity < "$work/boot-set"
[[ ${#identity[@]} == 3 && ${identity[0]} =~ ^[a-f0-9]{64}$ && ${identity[2]} =~ ^[a-f0-9]{64}$ ]] || exit 1
release=${identity[1]}
[[ $release =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-generic$ ]] || exit 1
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
(cd "$scratch" && lsinitcpio -x "$work/initramfs.img" >/dev/null)
cmp "$work/boot-set" "$scratch/etc/oma-snap/boot-set"
cmp /usr/lib/initcpio/hooks/oma_snap_set "$scratch/hooks/oma_snap_set"
[[ -x $scratch/hooks/oma_snap_set && -x $scratch/hooks/encrypt ]]
echo 'PASS: boot identity and executable retained-set/encryption hooks preserved'
for model in LENOVO/21N1 hp/elitebook-ultra-g1q ASUSTeK/zenbook-a14; do
  for file in qccdsp8380.mbn cdsp_dtbs.elf; do
    original=/usr/lib/oma-snap/sets/${identity[0]}/firmware/$release/qcom/x1e80100/$model/$file
    cmp "$original" "$scratch/usr/lib/firmware/$release/qcom/x1e80100/$model/$file"
  done
  echo "PASS: initramfs preserves $model cDSP pair"
done
topology=qcom/x1e80100/X1E80100-HP-ELITEBOOK-ULTRA-G1Q-tplg.bin
cmp "/usr/lib/oma-snap/sets/${identity[0]}/firmware/$release/$topology" "$scratch/usr/lib/firmware/$release/$topology"
echo 'PASS: HP speaker topology preserved in the retained firmware namespace'
for module in msm panel-edp panel-samsung-atna33xc20 gpio-sbu-mux; do
  match=$(find "$scratch/usr/lib/modules/$release" -type f -name "$module.ko*" -print -quit)
  [[ -n $match ]] || { echo "Missing early module: $module" >&2; exit 1; }
  echo "PASS: early module $module present"
done
for kind in modules firmware; do
  if findmnt -rn -M "/usr/lib/$kind/$release" >/dev/null; then
    echo 'FAIL: worker bind mount leaked into parent namespace' >&2; exit 1
  fi
done
echo 'PASS: staging mounts did not change the parent namespace'
