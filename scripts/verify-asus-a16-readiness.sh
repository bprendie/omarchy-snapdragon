#!/bin/bash
# Check known A16 prerequisites. This never claims a hardware boot or device PASS.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# == 3 ]] || { echo 'Usage: verify-asus-a16-readiness.sh SET_BUILD DTB INITRAMFS_LIST'; exit 1; }
[[ $1 =~ ^[a-zA-Z0-9._-]+$ ]]
set_dir=build/kernel-sets/$1
release=$(jq -er .kernel_release "$set_dir/set.json")
payload=$set_dir/payload
fw=$payload/firmware/$release
listing=$3
test -s "$listing"
inspection=$(mktemp)
trap 'rm -f "$inspection"' EXIT
(cd tools/inspect-kernel && go run . "../../$payload/vmlinuz.efi") > "$inspection"
hash=$(sha256sum "$2" | cut -d' ' -f1)
jq -e --arg hash "$hash" '.architecture == "ARM64" and (.device_trees | any(.sha256 == $hash and (.compatible | index("asus,zenbook-a16-ux3607oa"))))' "$inspection" >/dev/null
[[ $(fdtget "$2" /sound model) == GLYMUR-ASUS-Zenbook-A16-UX3607OA ]]
for file in \
  ath12k/QCC2072/hw1.0/board-2.bin ath12k/QCC2072/hw1.0/firmware-2.bin \
  qcom/glymur/GLYMUR-ASUS-Zenbook-A16-UX3607OA-tplg.bin \
  qcom/glymur/ASUSTeK/UX3607OA/qcadsp8480.mbn \
  qcom/glymur/ASUSTeK/UX3607OA/adsp_dtbs.elf \
  qcom/glymur/ASUSTeK/UX3607OA/qccdsp8480.mbn \
  qcom/glymur/ASUSTeK/UX3607OA/cdsp_dtbs.elf \
  qcom/glymur/ASUSTeK/UX3607OA/qcdxkmsuc8480.mbn \
  qcom/gen80100_sqe.fw.zst qcom/gen80100_gmu.bin.zst \
  qca/ornbtfw11.tlv.zst qca/ornnv11.bin.zst; do
  test -s "$fw/$file"
  grep -Fxq "usr/lib/firmware/$release/$file" "$listing"
done
for module in msm panel-samsung-atna33xc20 pinctrl-glymur gcc-glymur \
  dispcc-glymur gpucc-glymur qnoc-glymur scmi_pm_domain hid-asus \
  i2c-hid-of qcom_q6v5_pas; do
  grep -Eq "/${module}\.ko(\.zst)?$" "$listing"
done
printf 'PASS: exact embedded A16 tree, known firmware files and early display/input/power modules\n'
printf 'NOTE: SoCCP node status: %s\n' "$(fdtget "$2" /soc@0/remoteproc-soccp@d00000 status)"
printf 'UNTESTED: panel/unlock, Wi-Fi calibration, GPU rendering, audio, hotkeys, battery, NPU and suspend\n'
printf 'GAP: no enabled A16 sensor/CCI/CAMSS capture graph in this candidate\n'
