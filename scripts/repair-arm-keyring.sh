#!/bin/bash
set -euo pipefail
# One-time bootstrap for MVP installations missing the ARM trust package.
# Place the verified package and its detached signature beside this script.
[[ $EUID == 0 ]] || { echo 'Run this script with sudo.' >&2; exit 1; }
[[ $(uname -m) == aarch64 ]] || { echo 'Expected the ARM target.' >&2; exit 1; }
cd "$(dirname "$0")"
pkg=archlinuxarm-keyring-20240419-2-any.pkg.tar.xz
printf '%s  %s\n' \
  3cb36869edfe413672a6e932cc55d7f8386e1a9d3b38663cfb3bc6fe0d146e21 "$pkg" \
  ab95689f59593510ab044a127bf466f8aad0284f5c3d3755705aa91a8da28be7 "$pkg.sig" | sha256sum -c -

# This exact package was verified against the trusted build keyring, with
# signer 68B3537F39A313B3E574D06777193F152BDBE6A6 (official ALARM build key).
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
tar -xf "$pkg" -C "$stage" \
  usr/share/pacman/keyrings/archlinuxarm.gpg \
  usr/share/pacman/keyrings/archlinuxarm-trusted \
  usr/share/pacman/keyrings/archlinuxarm-revoked
install -m 644 "$stage"/usr/share/pacman/keyrings/archlinuxarm* /usr/share/pacman/keyrings/
pacman-key --init
pacman-key --populate archlinuxarm
pacman-key --verify "$pkg.sig"
# Adopt the three bootstrap files into normal package ownership.
pacman -U --noconfirm --overwrite 'usr/share/pacman/keyrings/archlinuxarm*' "$pkg"
pacman -Q archlinuxarm-keyring
pacman -S --needed --noconfirm alacritty
pacman -Q alacritty
echo 'ARM package trust repaired; Alacritty installed successfully.'
