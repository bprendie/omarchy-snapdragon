#!/bin/bash
# Run as root in a private mount namespace of a disposable native ARM VM.
# Inputs: directory containing the ARM guard and production hook. Test packages
# are deliberately unsigned synthetic fixtures; this is not a trust-chain test.
set -euo pipefail
input=${1:?Missing test input directory}
[[ $(uname -m) == aarch64 && $EUID == 0 ]]
[[ $(readlink /proc/self/ns/mnt) != "$(readlink /proc/$PPID/ns/mnt)" ]]
root=$(mktemp -d /var/tmp/oma-retain-pacman.XXXXXX)
cleanup() {
  if umount -R "$root"; then rm -rf "$root"; else
    echo "Preserved mounted test root for inspection: $root" >&2
  fi
}
mount --bind "$root" "$root"
trap cleanup EXIT
mkdir -p "$root"/{usr,proc,dev,boot,run/oma-snap,etc/oma-snap,etc/pacman.d/hooks,var/lib/pacman,var/log,tmp,test-tools}
mknod -m 666 "$root/dev/null" c 1 3
mount --bind /usr "$root/usr"
mount -o remount,bind,ro "$root/usr"
# Mask the VM's own hooks only in this test namespace/root.
mount -t tmpfs tmpfs "$root/usr/share/libalpm/hooks"
mount -t proc proc "$root/proc"
for path in bin sbin lib lib64; do ln -s "usr/$path" "$root/$path"; done
ln -s /proc/self/mounts "$root/etc/mtab"
cp "$input/oma-snap-kernel-retain" "$root/test-tools/guard"
truncate -s 16M "$root/esp.img"
mkfs.fat "$root/esp.img" >/dev/null
mount -o loop "$root/esp.img" "$root/boot"
printf '%s\n' /boot > "$root/etc/oma-snap/esp-path"
cat > "$root/etc/pacman.conf" <<'EOF'
[options]
Architecture = aarch64
SigLevel = Never
LocalFileSigLevel = Never
HookDir = /etc/pacman.d/hooks
EOF
pm() { chroot "$root" /usr/bin/pacman --config /etc/pacman.conf "$@"; }
a=$(printf 'a%.0s' {1..64})
b=$(printf 'b%.0s' {1..64})
c=$(printf 'c%.0s' {1..64})
d=$(printf 'd%.0s' {1..64})
make_package() {
  local id=$1 version=$2 source
  source=$(mktemp -d "$root/tmp/pkg.XXXXXX")
  mkdir -p "$source/opt/retention-test"
  printf '%s\n' "$version" > "$source/opt/retention-test/$id"
  cat > "$source/.PKGINFO" <<EOF
pkgname = oma-snap-set-$id
pkgver = $version
pkgdesc = Synthetic retention test fixture
arch = aarch64
builddate = 1
size = 16
license = custom
EOF
  if [[ -n ${3:-} ]]; then printf 'conflict = oma-snap-set-%s\n' "$3" >> "$source/.PKGINFO"; fi
  tar -C "$source" -cf "$root/tmp/$id-$version.pkg.tar" .PKGINFO opt
  rm -rf "$source"
}
for id in "$a" "$b" "$c"; do
  make_package "$id" 0.2.0-1
  pm -U --asdeps --noconfirm "/tmp/$id-0.2.0-1.pkg.tar" >/dev/null
done
make_package "$a" 0.2.0-2
make_package "$d" 0.2.0-1 "$a"
mkdir -p "$root/boot/oma-snap/entries/$b"
printf '{"schema":1,"boot_entry":"%s","hardware_set":"%s"}\n' "$b" "$b" > "$root/boot/oma-snap/entries/$b/entry.json"
printf '%s\n' "$a" > "$root/run/oma-snap/booted-set"
# Only Exec's location changes because /usr is the VM's read-only userspace.
sed 's@Exec = /usr/bin/oma-snap-kernel-retain@Exec = /test-tools/guard@' \
  "$input/01-oma-snap-retain.hook" > "$root/etc/pacman.d/hooks/01-oma-snap-retain.hook"
reject() {
  if pm "$@" > "$root/tmp/rejection.log" 2>&1; then
    echo "FAIL: transaction unexpectedly succeeded: $*" >&2; exit 1
  fi
  cat "$root/tmp/rejection.log"
  grep -q 'Snapdragon retention guard:' "$root/tmp/rejection.log"
  grep -q 'failed to commit transaction' "$root/tmp/rejection.log"
}
reject -R --noconfirm "oma-snap-set-$a"
reject -R --noconfirm "oma-snap-set-$b"
reject -U --noconfirm "/tmp/$a-0.2.0-1.pkg.tar"
reject -U --noconfirm "/tmp/$a-0.2.0-2.pkg.tar"
if printf 'y\ny\n' | pm -U "/tmp/$d-0.2.0-1.pkg.tar" > "$root/tmp/replacement.log" 2>&1; then
  echo 'FAIL: conflicting replacement unexpectedly succeeded' >&2; exit 1
fi
cat "$root/tmp/replacement.log"
grep -q 'Snapdragon retention guard:' "$root/tmp/replacement.log"
grep -q 'failed to commit transaction' "$root/tmp/replacement.log"
test ! -e "$root/opt/retention-test/$d"
echo 'PASS: real pacman blocks a conflicting replacement before mutation'
mapfile -t orphans < <(pm -Qtdq)
[[ ${#orphans[@]} == 3 ]]
reject -Rns --noconfirm "${orphans[@]}"
for id in "$a" "$b" "$c"; do
  pm -Q "oma-snap-set-$id" | grep -Fx "oma-snap-set-$id 0.2.0-1"
  [[ $(cat "$root/opt/retention-test/$id") == 0.2.0-1 ]]
done
echo 'PASS: real pacman blocks protected removal, reinstall, upgrade and orphan batch before mutation'
pm -R --noconfirm "oma-snap-set-$c" >/dev/null
test ! -e "$root/opt/retention-test/$c"
echo 'PASS: real pacman removes an unreferenced hardware set'
pm -U --noconfirm "/tmp/$c-0.2.0-1.pkg.tar" >/dev/null
umount "$root/boot"
reject -R --noconfirm "oma-snap-set-$c"
test -e "$root/opt/retention-test/$c"
echo 'PASS: unmounted ESP blocks removal before mutation'
mount -o loop "$root/esp.img" "$root/boot"
for tool in lock-probe oma-snap-boot-stage-coordinated oma-snap-boot-publish-coordinated; do
  cp "$input/$tool" "$root/test-tools/$tool"
done
mkfifo "$root/tmp/control" "$root/tmp/ready"
exec 9<> "$root/tmp/control"
chroot "$root" /test-tools/lock-probe < "$root/tmp/control" > "$root/tmp/ready" 9>&- &
holder=$!
IFS= read -r marker < "$root/tmp/ready"
[[ $marker == LOCK_HELD ]]
if pm -R --noconfirm "oma-snap-set-$c" > "$root/tmp/locked.log" 2>&1; then
  echo 'FAIL: pacman bypassed boot-operation lock' >&2; exit 1
fi
grep -q 'unable to lock database' "$root/tmp/locked.log"
exec 9>&-
wait "$holder"
test ! -e "$root/var/lib/pacman/db.lck"
echo 'PASS: production boot lock excludes real pacman and releases cleanly'
cat > "$root/test-tools/hold-hook" <<'EOF'
#!/bin/bash
echo PACMAN_LOCKED > /tmp/ready
read -r ignored < /tmp/control || true
EOF
chmod 755 "$root/test-tools/hold-hook"
cat > "$root/etc/pacman.d/hooks/99-test-hold.hook" <<'EOF'
[Trigger]
Operation = Upgrade
Type = Package
Target = oma-snap-set-*
[Action]
When = PreTransaction
Exec = /test-tools/hold-hook
AbortOnFail
EOF
exec 9<> "$root/tmp/control"
pm -U --noconfirm "/tmp/$c-0.2.0-1.pkg.tar" > "$root/tmp/held-transaction.log" 2>&1 9>&- &
transaction=$!
IFS= read -r marker < "$root/tmp/ready"
[[ $marker == PACMAN_LOCKED ]]
cp "$root/var/lib/pacman/db.lck" "$root/tmp/lock-before"
for tool in stage publish; do
  args=(--set "$a")
  [[ $tool != publish ]] || args=(--select "$a" --fallback "$b")
  if chroot "$root" "/test-tools/oma-snap-boot-$tool-coordinated" "${args[@]}" > "$root/tmp/tool-locked.log" 2>&1; then
    echo "FAIL: boot $tool bypassed pacman transaction" >&2; exit 1
  fi
  grep -q 'cannot reserve pacman database' "$root/tmp/tool-locked.log"
  cmp "$root/tmp/lock-before" "$root/var/lib/pacman/db.lck"
done
if chroot "$root" /test-tools/oma-snap-boot-stage-coordinated --wait-lock=100ms --set "$a" > "$root/tmp/wait-timeout.log" 2>&1; then
  echo 'FAIL: bounded wait bypassed held transaction' >&2; exit 1
fi
grep -q 'context deadline exceeded' "$root/tmp/wait-timeout.log"
cmp "$root/tmp/lock-before" "$root/var/lib/pacman/db.lck"
chroot "$root" /test-tools/oma-snap-boot-stage-coordinated --wait-lock=30s --set "$a" > "$root/tmp/wait-resume.log" 2>&1 9>&- &
waiter=$!
exec 9>&-
wait "$transaction"
if wait "$waiter"; then
  echo 'FAIL: resumed staging accepted an absent set' >&2; exit 1
fi
grep -q 'missing or substituted set directory' "$root/tmp/wait-resume.log"
test ! -e "$root/var/lib/pacman/db.lck"
pm -Q "oma-snap-set-$c" >/dev/null
echo 'PASS: real pacman transaction excludes boot staging/selection and keeps its lock intact'
echo 'PASS: bounded event wait times out safely and resumes staging after pacman releases its lock'
mkdir -p "$root/etc/kernel"
printf '%s\n' root=LABEL=TEST > "$root/etc/kernel/cmdline"
for tool in stage publish; do
  args=(--set "$a")
  expected='missing or substituted set directory'
  if [[ $tool == publish ]]; then
    args=(--select "$a" --fallback "$b")
    # This minimal chroot intentionally exposes no loop-device node for UUID
    # probing, so publication fails its ESP check after acquiring the lock.
    expected='ESP must be a mounted FAT filesystem with UUID'
  fi
  if chroot "$root" "/test-tools/oma-snap-boot-$tool-coordinated" "${args[@]}" > "$root/tmp/tool-failure.log" 2>&1; then
    echo 'FAIL: missing boot payload unexpectedly accepted' >&2; exit 1
  fi
  cat "$root/tmp/tool-failure.log"
  grep -q "$expected" "$root/tmp/tool-failure.log"
  test ! -e "$root/var/lib/pacman/db.lck"
done
echo 'PASS: failed boot staging/selection release their own database reservation'
rm "$root/etc/pacman.d/hooks/99-test-hold.hook"
cp "$input/oma-snap-kernel-queue" "$root/test-tools/queue"
sed 's@Exec = /usr/bin/oma-snap-kernel-queue@Exec = /test-tools/queue@' \
  "$input/95-oma-snap-prepare.hook" > "$root/etc/pacman.d/hooks/95-oma-snap-prepare.hook"
f=$(printf 'f%.0s' {1..64})
make_package "$f" 0.2.0-1
pm -U --noconfirm "/tmp/$f-0.2.0-1.pkg.tar" >/dev/null
test -f "$root/var/lib/oma-snap/jobs/pending/$f.json"
chroot "$root" /test-tools/queue --status | grep -F '"state":"pending"'
cp "$root/var/lib/oma-snap/jobs/pending/$f.json" "$root/tmp/queued-before.json"
pm -U --noconfirm "/tmp/$f-0.2.0-1.pkg.tar" >/dev/null
cmp "$root/tmp/queued-before.json" "$root/var/lib/oma-snap/jobs/pending/$f.json"
[[ -z $(find "$root/var/lib/oma-snap/jobs/work" -mindepth 1 -print -quit) ]]
echo 'PASS: real pacman post-hook queues and deduplicates preparation without staging inline'
