#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
patch --fuzz=0 -o "$work/phases.py" build/snapdragon-v0_1_2-installer-root/usr/share/omarchy-iso/orchestrator/phases_impl.py < profiles/snapdragon/installer-kernel-update.patch
python3 - "$work/phases.py" <<'PY'
import ast
import hashlib
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace

source = Path(sys.argv[1]).read_text()
tree = ast.parse(source)
compile(tree, sys.argv[1], "exec")
# Execute the actual final validator and its real imports without importing
# archinstall or running any installer/disk operations on the development host.
nodes = [n for n in tree.body if
         (isinstance(n, ast.Import) and all(a.name in {"hashlib", "json", "re"} for a in n.names)) or
         (isinstance(n, ast.FunctionDef) and n.name == "validate_boot")]
namespace = {"InstallContext": object, "_uses_snapdragon_boot": lambda ctx: True,
             "_boot_intent": lambda ctx: {"esp_mount": "/boot", "enable_fallback": True}}
exec(compile(ast.Module(body=nodes, type_ignores=[]), sys.argv[1], "exec"), namespace)
hardware, entry, release = "a" * 64, "b" * 64, "7.0.0-31-generic"

for defect in (None, "unapproved", "channel", "menu", "payload", "identity"):
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        def write(name, value):
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(value)
        write(f"usr/lib/oma-snap/{release}/vmlinuz.efi", "kernel")
        write(f"boot/oma-snap/{release}/vmlinuz.efi", "kernel")
        write(f"boot/oma-snap/{release}/initramfs.img", "legacy initrd")
        write("boot/EFI/oma-snap/grubaa64.efi", "loader")
        write("boot/EFI/BOOT/BOOTAA64.EFI", "loader")
        write("etc/oma-snap/kernel-channel", "stable")
        provider = {"status": "approved", "channel": "stable", "hardware_set": hardware, "kernel_release": release}
        if defect == "unapproved": provider["status"] = "unvalidated"
        if defect == "channel": provider["channel"] = "testing"
        write("usr/share/oma-snap/kernel-provider/candidate.json", json.dumps(provider))
        write(f"var/lib/oma-snap/jobs/complete/{hardware}.json", json.dumps({"hardware_set": hardware, "boot_entry": entry}))
        manifest = {"hardware_set": hardware, "kernel_release": release,
                    "kernel_sha256": hashlib.sha256(b"new kernel").hexdigest(),
                    "initramfs_sha256": hashlib.sha256(b"new initrd").hexdigest()}
        if defect == "identity": manifest["hardware_set"] = "c" * 64
        write(f"boot/oma-snap/entries/{entry}/entry.json", json.dumps(manifest))
        write(f"boot/oma-snap/entries/{entry}/vmlinuz.efi", "new kernel")
        write(f"boot/oma-snap/entries/{entry}/initramfs.img", "broken" if defect == "payload" else "new initrd")
        write("boot/oma-snap/grub/grub.cfg", "old menu" if defect == "menu" else f"set default=oma-snap-{entry}\nmenuentry --id 'oma-snap-legacy'\n")
        try:
            namespace["validate_boot"](SimpleNamespace(target=root))
        except RuntimeError:
            if defect is None: raise
        else:
            if defect is not None: raise AssertionError(f"accepted {defect}")
print("PASS: actual patched installer validator accepts provider boot and rejects approval/channel/menu/payload/identity failures")
PY
