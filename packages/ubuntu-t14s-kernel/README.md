# Binary kernel bridge

This package copies the signed Stubble-wrapped kernel unchanged and installs the exact extracted matching modules into their native release directory. It writes no ESP, bootloader configuration, default entry or initramfs preset. Generic module-index hooks may run within the disposable build root.

The current kernel input is Ubuntu's authenticated 7.0.0-31.31 ARM64 image/modules update, extracted under `/output/ubuntu-kernel-7.0.0-31`. Run `scripts/verify-kernel-update.sh` before extraction/build; manifests and provenance are in `docs/kernel-current.md`. The firmware input remains the verified Ubuntu ISO in `manifests/bootstrap.sha256`. The package is a prototype; package signing, corresponding source archival and an installed-system update hook remain release requirements. Module/EFI signatures and their enforcement need physical testing.
