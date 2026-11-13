---
name: system-mac-determinate-bootstrap
description: "Bootstrap a Mac (hyperion, atlas) on the ~/src/system nix-darwin flake (or another nix-darwin flake) with the Determinate Nix installer: install, first switch, agenix rekey, and first-switch failures"
---

# Bootstrap a Mac on ~/src/system with Determinate Nix

~/src/system already carries the Determinate wiring (commit c7da067):
`determinate` flake input, module added for darwin hosts in `lib/hosts.nix`,
`determinateNix.customSettings` in `modules/darwin/default.nix` (writes
`/etc/nix/nix.custom.conf`), nix-darwin `nix.gc`/`nix.optimise` replaced (they
assert `nix.enable`). Shared `nix.settings` live only in
`modules/nixos/default.nix`.

## Start with bootstrap

For ~/src/system, run `bootstrap [host]` from the checkout (or the curl line in
`docs/install-mac.md`) in a pty. It covers Install, the GitHub token, the
account-name check, the host key, removing `~/src/dotfiles` links, moving
`nix.custom.conf` aside, installing Homebrew and the first switch through `nh`.
It is idempotent; rerun it after fixing a failure. The steps below are the
manual path, for another flake or when diagnosing a failed run.

## Preflight

- Check `/nix`, `/etc/nix` and `/usr/local/bin/determinate-nixd` for leftovers
  from an earlier install.
- Real account name: `id -un` or `dscl . -list /Users UniqueID`. If it isn't
  `sol`, set `user.name` in `hosts/<host>/default.nix` `config` (hyperion =
  `admin`).
- `sudo -v` in a pty first; the installer and the switch escalate via sudo.

## Install

1. `curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm`
   (pty).
   - Error `encrypt_apfs_volume` / "keychain has an existing password for a
     non-existing Nix Store volume": loop
     `sudo security delete-generic-password -a "Nix Store" -s "Nix Store" -l "diskN encryption password" -D "Encrypted volume password"`
     (e.g. `disk3`) until it fails, rerun.
   - Self-test "cannot connect to socket" warning right after install is
     transient; verify with a trivial `nix build --expr 'derivation{...}'`.
2. In the current shell:
   `. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`.

## Wiring a flake that lacks it (not needed for ~/src/system)

- Input
  `determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3"`;
  add `inputs.determinate.darwinModules.default` for darwin hosts only.
- Set `determinateNix.enable = true` and move `trusted-users`, `warn-dirty` etc.
  into `determinateNix.customSettings`. Do not set experimental-features
  (Determinate enables nix-command flakes) or disallowed keys (netrc-file,
  ssl-cert-file, extra-nix-path, ...).
- Remove `nix.gc`/`nix.optimise.automatic` on darwin. determinate-nixd does GC;
  optional weekly `launchd.daemons.nix-optimise` running
  `/nix/var/nix/profiles/default/bin/nix-store --optimise`.
- Shared `nix.settings` in a common module must move to the NixOS-only module
  (nix-darwin's `nix.settings` throws when nix.enable is off).
- `nix flake lock` after adding the input.

## Build, then first switch

1. Every nix command on ~/src/system needs
   `--option access-tokens "github.com=$(gh auth token)"` (private
   solforge-theme input).
2. Build first:
   `nix build .#darwinConfigurations.<host>.system --no-link --print-out-paths`.
   buildEnv `conflicting subpath` collisions in home-manager-path →
   `lib.hiPrio`/`lib.lowPrio` on the duplicate package.
3. Move the installer's comment-only `/etc/nix/nix.custom.conf` to
   `.before-nix-darwin` (else "Unexpected files in /etc").
4. First switch:
   `sudo env PATH="/nix/var/nix/profiles/default/bin:$PATH" <outpath>/sw/bin/darwin-rebuild switch --flake ~/src/system#<host> --option access-tokens ...`
   - Home-manager activation failures don't show in darwin-rebuild's exit
     output; read the switch log.
   - "would be clobbered" = foreign symlinks (old `~/src/dotfiles` links);
     backupFileExtension only moves plain files (they get `.hm-backup`), not
     symlinks. Check the link targets are tracked in git, delete them (Sol
     approved clobbering safe files), rerun the switch. Don't run
     activation-<user> directly (no nix-build on PATH); rerun darwin-rebuild
     instead.
   - brew "existing App is different" → `brew install --cask --force <cask>`.
   - Remove a stale `~/.zshenv` link to ~~/src/dotfiles; `/etc/zshenv` sets
     ZDOTDIR=~~/.config/zsh.

## Secrets

- `sudo ssh-keygen -A` if there is no host key; add
  `/etc/ssh/ssh_host_ed25519_key.pub` to `secrets/agenix-rules.nix`
  `everywhere`.
- Rekey with an admin key: Sol plugs in an admin YubiKey and runs
  `secrets-rekey` (PIN, then a touch per file; user action), then switch again; `org.nixos.activate-agenix` exits 1 until
  then.
- Rekey without the admin key: on amarna (host key is a recipient),
  `sudo rage -d -i /etc/ssh/ssh_host_ed25519_key f.age | rage -e -r <each recipient the rules list for f.age> -r <newhost> -o f.age.new`
  (encrypting to `age1yubikey1…` admins needs `age-plugin-yubikey` on PATH)
  per file in a 700 tmp dir; Sol runs it (`ssh -t amarna script`) for sudo. Copy
  back, verify with `sudo rage -d -i /etc/ssh/ssh_host_ed25519_key`, switch,
  check `launchctl print system/org.nixos.activate-agenix` last exit 0 and
  `/run/agenix`.
- `git-work-identity.age` is admin-only; skip it.

## Commit

The gitleaks pre-commit hook refuses commits until `/run/agenix/gitleaks-policy`
exists, so commit only after the rekey and switch; until then stage the changes
and hand Sol the commit messages. Use `git --no-pager`/avoid the pager in a pty.

## Verify

`readlink /run/current-system`; `ls -la /etc/nix` (custom.conf -> /etc/static);
`nix config show | grep trusted-users`; `readlink ~/.config/<x>` points into
`*-home-manager-files`; `launchctl print system/org.nixos.activate-agenix` last
exit code (1 = host not yet a recipient). After touching shared modules, also
eval amarna:
`nix eval .#nixosConfigurations.amarna.config.system.build.toplevel.drvPath`.

## Gotchas

