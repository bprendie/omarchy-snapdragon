FROM ubuntu:26.04@sha256:513c074113a871b51a8d16ab445c88779d6452d937a164fb5cc479f32668a41d
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends squashfs-tools xorriso qemu-system-arm qemu-efi-aarch64 mtools dosfstools cpio kmod file zstd xz-utils ca-certificates gnupg curl && rm -rf /var/lib/apt/lists/*
