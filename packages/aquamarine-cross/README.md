# Cross-built ABI compatibility package

The signed Arch ARM snapshot's Hyprland 0.56.1-3 requires Aquamarine ABI 13; its Aquamarine 0.15.0-2 provides ABI 14. Do not fake a library symlink or disable pacman dependency checks.

Aquamarine v0.14.0, commit `a79fb21b2e2a82dd061a6d071802bcf38bd5c383`, declares SONAME 13. The ordinary ARM build failed twice in guest `cc1plus` while compiling DRM.cpp under QEMU user emulation, including a single-job/64 MiB-stack retry. No root cause has been proven.

`scripts/cross-aquamarine.sh` builds the same source with a native x86-hosted AArch64 GNU compiler, using the exported Arch root as sysroot. All target dependencies come from that sysroot; only the build compiler/tools come from the isolated Ubuntu container. The small protocol generator still executes via QEMU with the target library path. Compilation and a dynamic-loader dependency check succeeded. Compiler and builder package versions are in `manifests/cross-compiler.txt` and `manifests/cross-builder-packages.txt`.

Package the staged `usr/` tree with the tracked PKGBUILD. Its source tar checksum pins the exact staging artifact; upstream source identity and the build recipe remain necessary for rebuilding that artifact. `manifests/aquamarine-cross.sha256` records the built library. Runtime Hyprland and hardware rendering checks are separate requirements.

This is a temporary snapshot compatibility package. Keep the compositor and Aquamarine in a coherent tested update set; accept a future normal repository pair only after its full dependency transaction and runtime tests pass.

The complete dependency graph also has Hyprtoolkit requiring ABI 14. Therefore the final local package is **`oma-snap-aquamarine13`**, containing only the genuine `libaquamarine.so.13` and its 0.14.0 implementation. The official Aquamarine 0.15.0 package continues to own ABI 14, headers and the unversioned development symlink. Each ABI is implemented by its matching library; no compatibility is fabricated by redirecting a soname. Pacman now resolves the complete desktop transaction with both libraries present.
