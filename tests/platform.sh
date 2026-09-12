#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
testroot=$(mktemp -d)
trap 'rm -rf "$testroot"' EXIT
check() {
  local compatible=$1 expected=$2
  printf '%s\0qcom,x1e78100\0' "$compatible" > "$testroot/compatible"
  actual=$(OMARCHY_ARCH=aarch64 OMARCHY_DEVICETREE="$testroot" bash sources/omarchy-arm/bin/omarchy-hw-platform)
  [[ $actual == "$expected" ]] || { echo "Expected $expected, got $actual" >&2; exit 1; }
}
check lenovo,thinkpad-t14s-lcd snapdragon-t14s-lcd
check lenovo,thinkpad-t14s-oled generic-aarch64
check lenovo,thinkpad-t14s-lcd-other generic-aarch64
printf 'PASS: LCD match, OLED exclusion, whole-compatible match\n'
