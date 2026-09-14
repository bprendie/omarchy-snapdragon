#!/bin/bash
# Run the actual refresh script with isolated filesystem/package operations.
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
export REFRESH_TEST=$work OMARCHY_PATH=/fixture/omarchy
cat > "$work/bin/dispatch" <<'SH'
#!/bin/bash
name=${0##*/}
if [[ $name == sudo ]]; then exec "$@"; fi
printf '%s %s\n' "$name" "$*" >> "$REFRESH_TEST/events"
[[ $name != "${FAIL_COMMAND:-}" ]] || exit 23
SH
chmod 755 "$work/bin/dispatch"
for name in sudo cp omarchy-hook pacman omarchy-update-snapdragon-kernel; do
  ln -s dispatch "$work/bin/$name"
done
script=$PWD/sources/omarchy-snap/bin/omarchy-refresh-pacman
for failure in none cp omarchy-hook pacman omarchy-update-snapdragon-kernel; do
  : > "$work/events"
  result=0
  PATH="$work/bin:$PATH" FAIL_COMMAND=$failure bash "$script" stable > "$work/output" 2>&1 || result=$?
  if [[ $failure == none ]]; then
    [[ $result == 0 ]]
    [[ $(tail -2 "$work/events") == $'pacman -Syyuu --noconfirm\nomarchy-update-snapdragon-kernel ' ]]
    grep -Fx 'cp -f /fixture/omarchy/default/pacman/pacman-stable.conf /etc/pacman.conf' "$work/events"
  else
    [[ $result == 23 ]]
    [[ $(tail -1 "$work/events") == "$failure "* ]]
  fi
done
git -C sources/omarchy-snap apply --reverse --check "$PWD/patches/0007-quattro-refresh-kernel-wait.patch"
bash -n "$script"
echo 'PASS: repository refresh waits after pacman and stops on copy, hook, transaction or preparation failure'
