#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
sha256sum -c manifests/bootstrap.sha256
bash scripts/verify-kernel-update.sh
(cd tools/inspect-kernel && go run . ../../build/ubuntu-kernel-7.0.0-31/boot/vmlinuz-7.0.0-31-generic) > build/kernel-inspection.json
for module in msm pinctrl-x1e80100 gcc-x1e80100 dwc3-qcom panel-edp pwm_bl leds-qcom-lpg; do
  rg -q "/$module\.ko" build/initramfs-contents.txt || { echo "Missing module: $module" >&2; exit 1; }
done
rg -q 'usr/lib/firmware/7.0.0-31-generic/qcom/x1e80100/LENOVO/21N1/qcadsp8380.mbn' build/initramfs-contents.txt
rg -q 'hooks/archiso' build/initramfs-contents.txt
rg -q 'usr/lib/modules/7.0.0-31-generic/modules.dep' build/initramfs-contents.txt
[[ $(wc -l < tools/inventory/main.go) -le 300 ]]
[[ $(wc -l < tools/package-audit/main.go) -le 300 ]]
[[ $(wc -l < tools/inspect-kernel/main.go) -le 300 ]]
./tests/platform.sh
printf 'PASS: bootstrap hashes, LCD DTB, target modules/firmware, archiso hook, module ceiling, platform regression\n'
