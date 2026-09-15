# Chromium launch failure on v0.2.2

On 15 September 2026, a fresh physical HP EliteBook Ultra G1q install running
`7.2.0-18-qcom-x1e` and Chromium `153.0.8010.36-1` crashed at startup with
SIGTRAP and `sandbox/linux/services/credentials.cc:130: Permission denied`.
The kernel audit log explicitly denied Chromium's `userns_create` because it
could not find the `unprivileged_userns` AppArmor profile. `unshare -Ur true`
also failed. The system had no AppArmor userspace package installed.

The Ubuntu-derived kernel defaults
`kernel.apparmor_restrict_unprivileged_userns` to 1. Our Arch ARM userspace does
not include Ubuntu's corresponding policy stack. This is a kernel/userspace
integration bug, not evidence of a display-driver failure.

The compatibility fix is installed by `oma-snap-kernel-tools` 0.2.2-2 at
`/usr/lib/sysctl.d/60-oma-snap-userns.conf`:

```ini
-kernel.apparmor_restrict_unprivileged_userns = 0
```

This removes the Ubuntu-specific gate for all unprivileged applications, so
they can create user namespaces for their own sandboxes. It does not disable
AppArmor as a whole or turn off Chromium's sandbox. It does remove Ubuntu's
additional user-namespace restriction; an installation that later deploys
AppArmor policy can override this setting under `/etc/sysctl.d/`.
The leading minus tolerates kernels without this Ubuntu-specific sysctl.

For the existing HP, the same file was installed and applied immediately with
`sysctl -p /usr/lib/sysctl.d/60-oma-snap-userns.conf`. Afterwards,
`unshare -Ur true` passed and Chromium launched `chrome://sandbox`, with a
running renderer, without any sandbox-disabling launch flags. No reboot was
needed for that test. Persistence is configured but has not yet been reboot-tested.

The owner subsequently confirmed that the HP browser fix worked.

The v0.2.2-1 hotfix ISO includes this change; the published v0.2.2 ISO
is unchanged. Future ISO assembly must include the updated kernel-tools package. The live
system and the installed system should both be checked for the effective
sysctl, followed by a Chromium launch and an installed reboot test. This
compatibility setting belongs with our Ubuntu kernel integration; the separate
upstream `dragon` PR uses a different kernel and should not receive it blindly.

References: [Chromium's explanation and remedies](https://chromium.googlesource.com/chromium/src/+/main/docs/security/apparmor-userns-restrictions.md),
[Ubuntu's user-namespace restriction design](https://ubuntu.com/blog/ubuntu-23-10-restricted-unprivileged-user-namespaces).
