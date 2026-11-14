# System maintenance

`nh` is installed on every host. `NH_FLAKE` points to the live checkout
configured by `modules.dotfiles.dir`, so commands work from any directory and
select the local hostname.

Macs get their first activation from [`bootstrap`](install-mac.md). On NixOS,
before `nh` is installed:

```sh
nix run --inputs-from ~/src/system nixpkgs#nh -- os switch ~/src/system
```

Log out and back in after the first switch to load `NH_FLAKE`, then use:

```sh
nh os switch             # build, show the diff, activate (amarna)
nh os build              # build and show the diff without activating
nh os test               # activate without changing the next-boot default
nh os boot               # set the next-boot default without activating
nh darwin switch         # Macs
nix fmt                  # nixfmt-tree
nix build .#installer-iso # amarna installer
```

Run `nh` as your normal user; it elevates privileges when needed. Home Manager
is part of the system activation, so no separate `nh home switch` is needed. On
NixOS, `nh clean` runs weekly with a 14-day retention window and removes stale
gcroots. Determinate Nix manages garbage collection on Macs.

New files must be `git add`ed before the flake can see them.

For the private theme input and host credentials, see
[secrets and keys](secrets.md).

## Updating inputs

`system-bump` updates flake inputs, builds this host, and commits `flake.lock`
as `chore(flake): bumped <inputs>` with one bullet per changed input. A failed
build restores the previous lock. It passes `gh auth token` for the private
theme input.

```sh
system-bump                       # every input; build, then commit
system-bump llm-agents --switch   # one input; build, commit, activate
system-bump --no-commit           # leave flake.lock for review
```

It commits with jj in a jj checkout, otherwise git.

GitHub keeps main current as well:

- **Bump** (`.github/workflows/bump.yml`) runs `system-bump --eval-only` every
  Monday. When every host and check evaluates, it pushes the new lock to main;
  otherwise it pushes nothing and the failed run is emailed. Pull before
  switching. Run it on demand from the Actions tab.
- **Check** (`.github/workflows/check.yml`) runs `system-bump --verify`, which
  evaluates every host, check and package, and `nix fmt -- --ci` on pull
  requests and pushes to main.
- **Dependabot** updates the pinned GitHub Actions.

Evaluation catches renamed options and missing packages, not build failures or
uncached derivations; `system-bump` locally, or `nh darwin build` after a pull,
covers those.

Both workflows fetch the private theme with the `SOLFORGE_THEME_TOKEN` secret: a
fine-grained token with read-only Contents access to `solforged/solforge-theme`.
Store it as an Actions secret, and also as a Dependabot secret, because runs
Dependabot starts see only Dependabot secrets:

```sh
gh secret set SOLFORGE_THEME_TOKEN --repo solforged/system
gh secret set SOLFORGE_THEME_TOKEN --repo solforged/system --app dependabot
```

## Package channels and binary caches

Linux hosts use `nixos-unstable` through the `nixpkgs` input. Macs use
`nixpkgs-unstable` through `nixpkgs-darwin`, since that channel's release gate
includes Darwin tests. Both use the official `cache.nixos.org` binary cache.

Nix needs a cached copy of the exact derivation, not just the same package
version. A channel update or a local package override can select an uncached
derivation, requiring a source build and its tests. The Darwin-tested channel
reduces that risk; it does not guarantee that every package is cached.

To update only the Mac package set and check the build before activation:

```sh
nix flake update nixpkgs-darwin
nh darwin build
nh darwin switch
```

## Hermes on macOS

`modules.agents.hermes.enable` installs both the CLI and desktop app. It is
off on every host for now. When it is on, Home Manager places the app at
`~/Applications/Home Manager Apps/Hermes.app` after `nh darwin switch`.

Disabling the module removes both packages and the app on the next switch.
Hermes' configuration and conversation data remain in `~/.hermes`; re-enabling
the module does not require resetting that directory.
