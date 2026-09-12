# Validation ledger

Updated 2026-09-11. PASS applies only to the stated scope. Physical target results require exact kernel/package versions and retained local evidence.

| Check | Status | Evidence / scope |
| --- | --- | --- |
| Development host identification | PASS | Inventory reports HP Dragonfly x86_64, non-target |
| Ubuntu ISO authentication | PASS | Canonical signature and pinned SHA-256 verified |
| Arch ARM root authentication | PASS | Official builder signature and pinned SHA-256 verified |
| ARM userspace execution | PASS | aarch64 pacman runs under QEMU user emulation in isolated Docker |
| Signed Arch console package transaction | PASS | Retained `build/arch-packages.log`; no general Ubuntu userspace added |
| Omarchy platform patch regression | PASS | Fork's existing arm64-platform tests; LCD fixture recognized |
| Hyprland dependency resolution | PASS | Official Omarchy ARM Hyprland 0.56.2 uses ABI 14; signed transaction and container linkage/version checks pass, superseding the earlier ABI 13 workaround; no graphical test yet |
| Live ISO assembly | PASS | Console prototype and checksum in dist; desktop/installer not embedded |
| UEFI virtual CD boot | PASS | ARM QEMU console, matching kernel/modules, overlay root, zero failed units |
| UEFI virtual USB boot | PASS | Same ISO boots from virtual USB; /dev/sda iso9660, expected kernel, zero failed units; no physical claim |
| Stock Quattro installer unit suite | PASS | Shell suite and 63 Python tests; build/quattro-upstream-tests.log; no end-to-end ARM installation |
| Stock Quattro ARM package build | PASS | Unmodified 4.0.3-1 runtime/settings archives and checksums; later installed with dependencies in ARM container, no desktop validation |
| Selected Quattro desktop packages | PASS | Signed package transactions including Herdr complete in ARM container; systemd module hook cannot operate in container; no physical service claim |
| Actual ARM archinstall adapter import | PASS | archinstall 4.4, aarch64, QUATTRO_ARM_IMPORT_PASS |
| ARM Node bundle | PASS | Pinned Node 26.8.2 checksum verified and ARM binary executes |
| ARM Node staging and stock provisioning | PASS | 65 installer Python tests plus shell suite; profile retains stock AI setup and passes provisioning regressions |
| Arch ARM GRUB / Ubuntu Stubble virtual boot | PASS | Root console, expected kernel, overlay, zero failed units; SB disabled; build/arch-grub-boot.log |
| Installed boot helper input tests | PASS | Go input rejection tests and vet; no disk installation yet |
| Patched Quattro boot adapter tests | PASS | 70 Python tests plus stock shell suite; metadata/payload checks only |
| Offline mirror dependency closure | PASS | 958 archive hashes and empty-database resolution; actual archinstall audio targets checked; upstream signatures retained, five unsigned local builds isolated |
| Installer ISO assembly | PASS | 6.4 GiB hardware-test candidate, ISO level 3, checksum in dist; user waived the original VM gate, then resumed VM testing after physical failures |
| ISO packaging reproducibility | PASS (same staged payload) | Two full images compare byte-for-byte after fixed timestamps/GPT seed, including different caller timezone; build/installer-repro-result.txt. Full root/initramfs rebuild and normalized-image boot untested |
| SquashFS reproducibility | PASS (same extracted root) | Fresh container and different source mount path produce byte-identical payload; build/installer-squash-repro-result.txt. Independent root reconstruction untested |
| Updated kernel boot validator | PASS (source tests only) | Removed stale kernel30 constant; missing/ambiguous payload rejection and kernel31 fixture pass, stock shell suite plus 72 Python tests. Not yet embedded in ISO |
| Installer candidate live boot | PASS | Large squashfs mounted in ARM VM; installation/desktop not yet verified |
| Live key-only SSH helper | PASS | Exact handed-off ISO under ARM VM: manually enabled helper, authenticated with dedicated key, zero failed live services; not yet tested in the physical hybrid |
| LCD modules in rebuilt initramfs | PASS | panel-edp, pwm_bl, leds-qcom-lpg included; offline checks and separate UEFI/USB console smoke pass, overlay root, zero failed services and clean shutdown; build/initramfs-smoke/serial.log; does not exercise physical LCD drivers |
| Ubuntu kernel update input authentication | PASS | 7.0.0-31.31 ARM64 packages verified through signed updates/security indexes |
| Kernel 31 installer live VM | PASS | UEFI virtual USB, 7.0.0-31-generic, overlay root, matching packages, zero failed services, SSH and clean poweroff; build/installer-live-kernel31/ |
| Expected LCD device-tree selection | PASS (offline lookup) | Target DMI/BOE0b66 IDs match actual kernel HWID table at Stubble priority 16; actual UEFI selection untested |
| Working Ubuntu inventory | PASS | Authenticated read-only SSH: Ubuntu 25.04 / kernel 6.14.0-15, type 21N10000US, BOE 1920x1200 LCD; raw data retained privately |
| Kernel31 physical live boot and SSH | PASS | User reached installer through final boot-validation phase; recovery USB SSH confirms 7.0.0-31/overlay, LCD DTB, msm initialization, zero failed live units. Installed boot still blackscreens after POST; investigation ongoing |
| First physical installed desktop boot | PASS with defect | Explicit firmware entry BootNext, user entered LUKS passphrase at black screen and reached Omarchy; IMG_0359.jpeg shows desktop and Wi-Fi scan results. Unlock prompt invisible; repeat boot, acceleration and connectivity not yet verified |
| Installed Wi-Fi / Bluetooth / brightness | PASS (user report) | User confirms all three work on installed ThinkPad; repeat/suspend behavior not measured |
| Installed audio basic functionality | PASS (user report) | User confirms audio works; speaker/headset/microphone endpoints and protection behavior not individually verified |
| Native hybrid USB boot | FAIL | First attempt: loop0/SquashFS I/O failures; copy-to-RAM attempt advanced then LCD backlight off/black screen; cause unconfirmed |
| Known-good Ubuntu recovery boot | UNTESTED | User says Ubuntu boots; project has not exercised recovery |
| Storage and root overlay | UNTESTED | Physical storage never modified |
| Keyboard, TrackPoint, touchpad | UNTESTED | Physical target required |
| Hybrid LCD / accelerated rendering | FAIL / UNTESTED | Black-screen symptom during physical boot; accelerated rendering untested. Working Ubuntu detects BOE panel and msm; see baseline |
| Wi-Fi and Bluetooth | UNTESTED | Physical target required |
| Speaker, headset, microphone | UNTESTED | Check speaker protection before stress tests |
| Camera | UNTESTED | Physical target required |
| External display / dock | UNTESTED | Dock model and target access required |
| Charging, battery, thermals | UNTESTED | Ubuntu single sample: Discharging, external supplies offline; charger attachment unconfirmed. Hybrid and controlled power tests pending |
| Suspend/resume and suspend drain | UNTESTED | Physical target required |
| Secure Boot | UNTESTED | Reused signed files are not a hybrid trust-chain test |
| Full installer VM | IN PROGRESS (prior failure retained) | Previous run passed base/zram/early/user/audio then lacked bundled package list. Corrected kernel31 image now running in build/install-vm-kernel31-next/; live boot/SSH and actual bundled list comparisons passed. Full install not yet proven |
| Installed boot / update / rollback | UNTESTED | No completed installation/boot or maintained update/recovery path claimed |
| Fingerprint / WWAN | UNTESTED | Determine whether fitted before marking N/A |

Power protocol: use the same brightness, power profile, workload, network and peripherals for Ubuntu/hybrid. Alternate repeated 5–10 minute active samples. Record current full-charge Wh, measured average watts, duration/order, uncertainty and workload duty cycle. Run a separate meaningful suspend-drain interval. Compute projected runtime as capacity Wh / mean W, clearly labeling estimates; report minutes lost using the Weazl formula. Never infer power savings from idle CPU or a single successful resume.

Initramfs build includes some unrelated generic controller firmware warnings (aic94xx, bfa, qed, qla1280/qla2xxx, wd719x and Renesas controllers) because the initial storage hook is intentionally broad. These are not silently counted as hardware failures or successes. Explicit checks require the T14s platform/display modules and versioned T14s firmware to be present. The optional `pv` warning means copy-to-RAM uses `cp`. The first build's missing kernel-image discovery warning arose because the custom package did not initially add Arch's module-directory `vmlinuz` symlink; the package recipe now supplies that symlink. The kernel release was always passed explicitly.

The console package transaction's OpenSSH pre-transaction restart hook reports no systemd bus in the build container. Pacman completes with status 0 and all package signatures checked; this is a container lifecycle limitation, not a successful service restart. SSH is explicitly masked in the resulting live profile. Physical service behavior remains untested.
