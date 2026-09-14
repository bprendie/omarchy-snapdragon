#!/bin/bash
# Exercise the production helper with controlled service completion/failure.
set -euo pipefail
cd "$(dirname "$0")/.."
helper=$PWD/sources/omarchy-snap/bin/omarchy-update-snapdragon-kernel
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
export KERNEL_WAIT_TEST=$work
cat > "$work/bin/sudo" <<'EOF'
#!/bin/bash
exec "$@"
EOF
cat > "$work/bin/systemctl" <<'EOF'
#!/bin/bash
[[ $* == 'start --wait oma-snap-kernel-prepare.service' ]] || exit 90
echo ready > "$KERNEL_WAIT_TEST/ready"
read -r result < "$KERNEL_WAIT_TEST/release"
exit "$result"
EOF
cat > "$work/bin/oma-snap-kernel-queue" <<'EOF'
#!/bin/bash
[[ $* == --check-provider-prepared ]] || exit 91
touch "$KERNEL_WAIT_TEST/checked"
exit "${KERNEL_CHECK_RESULT:-0}"
EOF
cat > "$work/bin/oma-snap-boot-publish" <<'EOF'
#!/bin/bash
[[ $* == '--activate-provider --wait-lock=30m' ]] || exit 92
[[ -e $KERNEL_WAIT_TEST/checked ]] || exit 93
touch "$KERNEL_WAIT_TEST/activated"
exit "${KERNEL_ACTIVATION_RESULT:-0}"
EOF
chmod 755 "$work/bin/"*
mkfifo "$work/ready" "$work/release"
for service_result in 0 1; do
  for check_result in 0 1; do
   for activation_result in 0 1; do
    rm -f "$work/checked" "$work/activated"
    PATH="$work/bin:$PATH" KERNEL_CHECK_RESULT=$check_result KERNEL_ACTIVATION_RESULT=$activation_result bash "$helper" &
    worker=$!
    read -r ready < "$work/ready"
    [[ $ready == ready && ! -e $work/checked ]]
    echo "$service_result" > "$work/release"
    result=0
    wait "$worker" || result=$?
    if (( service_result == 0 )); then
      [[ -e $work/checked ]]
      if (( check_result == 0 )); then
        [[ -e $work/activated && $result == "$activation_result" ]]
      else
        [[ ! -e $work/activated && $result == "$check_result" ]]
      fi
    else
      [[ ! -e $work/checked && ! -e $work/activated && $result == "$service_result" ]]
    fi
  done
  done
done
git -C sources/omarchy-snap apply --reverse --check "$PWD/patches/0005-quattro-kernel-preparation-wait.patch"
bash -n "$helper" sources/omarchy-snap/bin/omarchy-update
echo 'PASS: update helper waits for preparation and propagates service/provider/activation failures'
