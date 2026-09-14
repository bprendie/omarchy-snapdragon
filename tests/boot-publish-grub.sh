#!/bin/bash
# Check the actual Go-generated migration menus with the ARM builder's GRUB.
set -euo pipefail
cd "$(dirname "$0")/.."
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
cat > "$scratch/check-grub" <<'EOF'
#!/bin/bash
set -euo pipefail
docker exec -i oma-snap-root grub-script-check < "$1"
EOF
chmod 755 "$scratch/check-grub"
cd tools/boot-publish
OMA_SNAP_GRUB_CHECK="$scratch/check-grub" go test -count=1 -run '^Test(LegacyMigrationAndSelection|RetainedPairPreservesLegacy)$' -v .
