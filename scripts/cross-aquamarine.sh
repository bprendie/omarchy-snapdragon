#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -d build/live-root-export/usr/include ]] || { echo 'Missing Arch ARM sysroot' >&2; exit 1; }
mkdir -p build/aquamarine-cross
[[ -d build/aquamarine-cross/source ]] || cp -a sources/aquamarine build/aquamarine-cross/source
docker run --rm --network none \
  -v "$PWD/build/live-root-export:/sysroot:ro" \
  -v "$PWD/build/aquamarine-cross:/work" \
  -v "$PWD/containers/aarch64-toolchain.cmake:/toolchain.cmake:ro" \
  -v /usr/bin/qemu-aarch64-static:/usr/local/bin/qemu-aarch64-static:ro \
  -w /work oma-snap-cross:local bash -ec '
  export PKG_CONFIG_LIBDIR=/sysroot/usr/lib/pkgconfig:/sysroot/usr/share/pkgconfig
  export PKG_CONFIG_SYSROOT_DIR=/sysroot
  printf "#!/bin/sh\nexec /usr/local/bin/qemu-aarch64-static -L /sysroot /sysroot/usr/bin/hyprwayland-scanner \"\$@\"\n" > /usr/local/bin/hyprwayland-scanner
  chmod 755 /usr/local/bin/hyprwayland-scanner
  for tree in wayland wayland-protocols hwdata; do ln -s /sysroot/usr/share/$tree /usr/share/$tree; done
  cmake -S source -B build -G Ninja -DCMAKE_TOOLCHAIN_FILE=/toolchain.cmake \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib
  cmake --build build --target aquamarine --parallel 4
  DESTDIR=/work/stage cmake --install build
  chown -R 1000:1000 /work/build /work/stage
'
