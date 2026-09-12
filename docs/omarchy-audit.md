# Omarchy ARM integration audit

Pinned candidate: `579f15c699dab01e2b3b12e2c4d2503873359be9`, branch `arm64`, selected because it preserves Arch ARM repositories, gates x86 hardware leaves, seeds Omarchy's actual Lua/Quickshell config, and includes platform/package tests. The checkout is development source, not this HP's installed Omarchy.

## Reusable

- `install/arm/pacman.sh` preserves ARM repository server configuration.
- `install/arm/platform.sh` gates x86 leaves and records skips.
- `install/arm/settings.sh` is a file-map reference for a native settings package; it excludes bootloader/initramfs directories.
- Hardware detection is extended by `patches/0001-identify-t14s-lcd.patch`. LCD compatible matching is exact; OLED and partial matches do not select this profile. Existing fork platform regression tests pass.
- The desktop's current configuration is Lua, and the panel/menu is Quickshell. Do not generate old Hyprland INI or Waybar replacements.

## Must adapt before shipping desktop

- The older fork installer tolerates some required AUR failures and directly copies files that should be owned by pacman. Stock Quattro packaging is now the selected integration path.
- Replace direct source deployment/settings copying with native packages. Avoid copying `/etc/nsswitch.conf`, generic USB power overrides, or boot settings without explicit review against the working baseline.
- User override (2026-09-11): retain stock AI/cloud tools, Herdr, agent invitations, and optional Electron applications wherever ARM-compatible. The directive now explicitly supersedes the earlier Weazl-based exclusions. Most `omarchy-mise-install` calls create launchers; they fetch the tools when the user first runs them. Obsidian remains absent from the selected ARM repositories, which is a packaging gap rather than a policy exclusion.
- `omarchy-provision-first-run` installs an agent setup hook and runs first-login unit activation and speaker tuning. Review these separately. Keep T14s audio testing behind a known speaker-protection baseline.
- Stock first-run includes a crash watcher offering AI diagnosis and Taildrop integration. The user approved retaining stock cloud integrations. Image builds must not authenticate accounts or upload private data.
- `omarchy-update` runs system package updates, migrations, AUR updates and mise updates. Preserve ARM repositories and the Snapdragon boot stack through updates. Cloud-tool updates are permitted by the user.
- Review shell plugin defaults, app/keybinding entries and theme-generated state so unavailable optional programs are explicit and core launcher/session behavior stays functional.

## Actual package evidence

`docs/package-audit.json` resolves base names against downloaded core/extra/alarm metadata. It intentionally says metadata availability rather than successful build. The subsequent real pacman transaction rejects Hyprland 0.56.1-3 because it needs `libaquamarine.so=13-64`, while Aquamarine 0.15.0-2 provides ABI 14.

Aquamarine 0.14.0's pinned source declares ABI 13. Guest compilation failed, but native cross-compilation against the Arch ARM sysroot succeeded. `oma-snap-aquamarine13` packages the genuine versioned ABI 13 runtime alongside official ABI 14. The full desktop dependency transaction now passes; Hyprland/Quickshell version checks and Hyprland ABI 13 linkage pass in the ARM container. A graphical session remains untested.

The user's subsequent preference is maximum stock Quattro installer reuse. The fork audit above remains reference material; `docs/quattro-installer.md` records the primary upstream installer and packaging decision. Current stock ARM PKGBUILDs already separate x86 boot dependencies, superseding the earlier need to invent runtime/settings packaging.

The initial console ISO contains no Omarchy desktop and is labeled accordingly. It proves only the bridge milestones actually tested. Optional-app exclusions do not justify omitting core Omarchy behavior from the final ISO.
