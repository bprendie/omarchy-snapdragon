#!/bin/bash
# Run the actual restart helper with isolated commands; never reboot or restart
# a real service. Ordinary host state files are read but cannot be changed.
set -euo pipefail
cd "$(dirname "$0")/.."
helper=$PWD/sources/omarchy-snap/bin/omarchy-update-restart
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export KERNEL_REBOOT_TEST=$work
mkdir "$work/bin"
for tool in bash basename sed; do ln -s "$(command -v "$tool")" "$work/bin/$tool"; done
cat > "$work/bin/sudo" <<'EOF'
#!/bin/bash
exec "$@"
EOF
cat > "$work/bin/oma-snap-boot-publish" <<'EOF'
#!/bin/bash
[[ $* == '--reboot-status --wait-lock=30m' ]] || exit 90
[[ $KERNEL_STATUS != error ]] || exit 1
printf '%s\n' "$KERNEL_STATUS"
EOF
cat > "$work/bin/gum" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$KERNEL_REBOOT_TEST/prompts"
exit 1
EOF
for tool in pgrep readlink omarchy-state omarchy-restart-shell; do
  printf '#!/bin/bash\nexit 0\n' > "$work/bin/$tool"
done
for tool in sudo oma-snap-boot-publish gum pgrep readlink omarchy-state omarchy-restart-shell; do
  chmod 755 "$work/bin/$tool"
done
for status in current required invalid error; do
  : > "$work/prompts"
  result=0
  PATH="$work/bin" KERNEL_STATUS=$status /bin/bash "$helper" > "$work/output" 2>&1 || result=$?
  case "$status" in
    current) [[ $result == 0 ]]; ! grep -q 'Linux kernel' "$work/prompts" ;;
    required) [[ $result == 0 ]]; grep -Fx 'confirm Linux kernel has been updated. Reboot?' "$work/prompts" ;;
    invalid|error) [[ $result == 1 && ! -s $work/prompts ]] ;;
  esac
done
echo 'PASS: restart helper prompts only for changed boot identity and stops on status errors'
