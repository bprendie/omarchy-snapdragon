# Reproducibility evidence

Updated 2026-09-12. End-to-end reproducibility remains incomplete.

`scripts/write-installer-iso.sh` packages an already validated
`build/installer-iso/` tree and `build/efi.img`. It fixes ISO file/volume dates
to the SquashFS epoch (1789084800), sets UTC/C locale, and derives the GPT disk
GUID from a sorted checksum stream of staged regular files plus the EFI image.
`scripts/assemble-installer-iso.sh` now calls this helper after its existing
validation and SquashFS creation steps. Calling the helper alone does not
validate package signatures or rebuild the live filesystem.

Two sequential builds from the unchanged staged tree passed full byte comparison:

```text
build/installer-repro-d.iso
build/installer-repro-e.iso
SHA-256: 60289addc3c997a83f4bfd4b272873bb79b50a06ce0d3b885257f7bd657c5069
```

The second invocation supplied `TZ=Pacific/Honolulu`; the helper's UTC setting
kept output identical. Logs are `build/installer-repro-{d,e}.log`; recorded
checksums are in `build/installer-repro-result.txt`. Earlier experiments a/b
fixed timestamps but differed in automatically generated GPT identifiers.
Those images and experiment c are retained as intermediate evidence.

These are packaging experiments, not a replacement for the running VM's
`dist/oma-snap-installer-kernel31-lists-arm64.iso`. The normalized images have
not been boot-tested. They use the same staged boot/root payload but different
ISO metadata and GPT identifiers.

A fresh SquashFS build from the same extracted root, mounted read-only at a
different path in a new native builder container, also passed full byte comparison
against the ISO staging payload. Both SHA-256 values are
`f8d99e62e38fcc043ce66570ac1a800b70f77de0bfe927175b73a2ec187afc53`.
Evidence: `build/installer-squash-repro.log` and
`build/installer-squash-repro-result.txt`. This tests repeated compression of
the same root, not an independent reconstruction of that root.

Remaining work includes independent root/package/initramfs rebuilds, generated
keyring and log contents, and build-container dependency retention. Existing
source/input/package manifests are necessary but do not prove these steps
produce identical bytes.
