#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Generate the installer list from stock plus a small, explicit hardware policy.
awk '
  FILENAME ~ /packages.exclude$/ { if ($1 !~ /^#/ && NF) omit[$1]=1; next }
  FILENAME ~ /packages.replace$/ { if ($1 !~ /^#/ && NF) replace[$1]=$2; next }
  $1 !~ /^#/ && NF && !omit[$1] {
    name=($1 in replace) ? replace[$1] : $1
    if (!seen[name]++) print name
  }
' profiles/t14s-lcd/packages.exclude profiles/t14s-lcd/packages.replace \
  sources/omarchy-release/install/omarchy-base.packages profiles/t14s-lcd/packages.extra
