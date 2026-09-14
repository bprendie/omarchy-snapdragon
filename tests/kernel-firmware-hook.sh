#!/bin/bash
# Run in the ARM build root, where the baseline firmware is installed.
set -euo pipefail
source "${1:?Path to candidate oma_snap_qcom hook}"
add_module() { :; }
add_all_modules() { :; }
add_full_dir() { printf '%s\n' "$1"; }
KERNELVERSION=7.0.0-31-generic
result=$(build)
[[ $result == /usr/lib/firmware/7.0.0-31-generic ]]
KERNELVERSION=0.0.0-0-missing-test
if build >/dev/null 2>&1; then
  echo 'FAIL: missing candidate firmware was silently accepted' >&2
  exit 1
fi
unset KERNELVERSION
if build >/dev/null 2>&1; then
  echo 'FAIL: unset build kernel was silently accepted' >&2
  exit 1
fi
echo 'PASS: hook uses build kernel and refuses missing firmware namespaces'
