# ARM package trust repair — 2026-09-12

The fresh physical installation omitted `archlinuxarm-keyring`. It installed
`archlinux-keyring` and `omarchy-keyring`, and initialized only those trust
sets. Alacritty downloaded but failed with the ALARM build key at unknown
trust. The terminal wrapper's “Done!” message did not mean installation passed.

## Repair

`scripts/repair-arm-keyring.sh` bootstraps the official ARM trust files from a
pinned, authenticated keyring package, populates the pacman trust database,
installs the package to establish file ownership, then retries Alacritty.
It leaves signature policy enabled and does not refresh repository databases
or request a system upgrade. Existing desktop package holds are unchanged.

Package: `archlinuxarm-keyring-20240419-2-any.pkg.tar.xz`.
SHA-256: `3cb36869edfe413672a6e932cc55d7f8386e1a9d3b38663cfb3bc6fe0d146e21`.
Downloaded from the official mirror over HTTP after its HTTPS hostname check
failed; authenticated independently with the existing trusted ARM build
container's `pacman-key --verify`, which reported a good fully trusted signature.
Signer: `68B3537F39A313B3E574D06777193F152BDBE6A6`, matching the
[official ALARM signing-key publication](https://archlinuxarm.org/about/package-signing).

Artifacts and script are staged in `~/keyring-repair/` on the ThinkPad.
The user ran `sudo bash ~/keyring-repair/repair-arm-keyring.sh` successfully.
Physical repair **PASS**: SSH independently confirmed ARM keyring 20240419-2,
zero altered keyring package files, and Alacritty 0.17.0-1 installed.
`alacritty --version` runs successfully; a graphical launch was not tested.
Pacman logged both completed transactions at 11:30 EDT on 2026-09-12.
Repository signatures remain required and the existing desktop package holds
remain in place. This resolves the observed trust failure, not the broader
coordinated system-update/recovery work.

## Prevention and validation

- Added ARM keyring to the hardware package list and ARM early bootstrap.
  Its package install script populates the target trust database.
- Updated the source Omarchy keyring refresh command to refresh/populate the
  ARM keyring on aarch64 and stop on errors before reporting success.
- Regenerated tracked profile and installer patches; reverse-application checks
  passed and the generated package list matches the source profile.
- Clean disposable ARM container: removed keyring package and trust database,
  ran the trust-repair portion, verified package ownership (zero altered files)
  and fully trusted detached signature. Log: `build/keyring-repair-test.log`.
- Existing installer tests: all shell checks and 72 Python tests passed.
- Stubbed updater checks: ARM selects/populates ARM keys, x86 does not, and
  a failed package transaction returns failure without “Keys are correct”.

The subsequent [keyring ISO rebuild](installer-keyring-build.md) includes these
changes with runtime/settings 4.0.3-1.3 and passed VM live boot. The older working
kernel31-unlock ISO still contains the omission.

TrackPoint investigation is paused at the user's request. It sends scrolling
input, and pressing/releasing the middle button did not restore pointer motion.
No input configuration or charging settings were changed.
