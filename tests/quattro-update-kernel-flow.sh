#!/bin/bash
# Execute the actual update orchestrator with isolated commands, checking where
# kernel preparation is joined and that failure stops subsequent update phases.
set -euo pipefail
cd "$(dirname "$0")/.."
source_root=$PWD/sources/omarchy-snap
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
export KERNEL_FLOW_TEST=$work
cat > "$work/command" <<'EOF'
#!/bin/bash
name=${0##*/}
printf '%s\n' "$name $*" >> "$KERNEL_FLOW_TEST/calls"
case "$name" in
  sudo) exec "$@" ;;
  oma-snap-kernel-queue)
    if [[ ${KERNEL_FLOW_FAIL:-0} == 1 ]]; then exit 1; fi ;;
esac
exit 0
EOF
for name in omarchy-update-lock omarchy-update-stay-awake omarchy-update-requires-free-space \
  omarchy-update-pkg-prune omarchy-snapshot omarchy-update-dev omarchy-update-keyring \
  omarchy-update-system-pkgs omarchy-migrate omarchy-hook omarchy-update-aur-pkgs \
  omarchy-update-mise omarchy-update-orphan-pkgs omarchy-update-analyze-logs \
  omarchy-update-status omarchy-update-restart sudo systemctl oma-snap-kernel-queue; do
  cp "$work/command" "$work/bin/$name"
  chmod 755 "$work/bin/$name"
done
cp "$source_root/bin/omarchy-update-snapdragon-kernel" "$work/bin/"
for fail in 0 1; do
  : > "$work/calls"
  result=0
  PATH="$work/bin:/usr/bin" OMARCHY_UPDATE_LOGGED=1 KERNEL_FLOW_FAIL=$fail \
    /bin/bash "$source_root/bin/omarchy-update" -y > "$work/output" 2>&1 || result=$?
  if [[ $fail == 1 ]]; then
    [[ $result != 0 ]]
    ! grep -q '^omarchy-update-system-pkgs ' "$work/calls"
    grep -Fx 'omarchy-update-stay-awake stop' "$work/calls"
    ! grep -q '^omarchy-update-restart ' "$work/calls"
  else
    [[ $result == 0 ]]
    awk '/^(omarchy-update-keyring|omarchy-update-system-pkgs|omarchy-migrate|omarchy-hook|omarchy-update-aur-pkgs|omarchy-update-orphan-pkgs|systemctl|oma-snap-kernel-queue) / {print $1}' "$work/calls" > "$work/actual"
    : > "$work/expected"
    for phase in omarchy-update-keyring omarchy-update-system-pkgs omarchy-migrate omarchy-hook omarchy-update-aur-pkgs omarchy-update-orphan-pkgs; do
      printf '%s\nsystemctl\noma-snap-kernel-queue\n' "$phase" >> "$work/expected"
    done
    cmp "$work/expected" "$work/actual"
    grep -q '^omarchy-update-restart ' "$work/calls"
  fi
done
echo 'PASS: Omarchy update joins each package phase and stops before further work on preparation failure'
