# Development

## Layout

```text
flake.nix          inputs; nixosConfigurations and darwinConfigurations from hosts/
lib/               `my`: mkOpt, module walkers, mkHost, mapHosts
modules/common/    every modules.* option, plus settings valid on both platforms
modules/nixos/     NixOS-only implementations of the same flags
modules/darwin/    nix-darwin-only implementations
hosts/<name>/      default.nix (flags), hardware.nix and disko.nix on NixOS
config/            raw dotfiles, linked live into $HOME
packages/          local derivations; each becomes pkgs.<name>
secrets/           agenix files and their recipients
installer/         custom NixOS installer image for amarna
docs/              setup, operations and development guides
```

## Conventions

- **Hosts are attrsets, not modules.** `hosts/<name>/default.nix` returns
  `{ system; modules; config; }`. `system` picks the builder: a `-darwin` suffix
  means nix-darwin. `config` is an ordinary module for host-only settings. See
  `lib/hosts.nix`. The flake exports `lib.mkHost`, so another flake can build a
  host from these modules plus its own.
- **Modules are auto-imported.** Every `.nix` file under `modules/common` and
  the host's platform directory is loaded; names starting with `_` are skipped.
- **Platform split.** NixOS and nix-darwin have different option trees, and
  setting a missing option fails even inside `mkIf`. A flag is declared once in
  `modules/common/`; anything platform-specific goes in `modules/nixos/` or
  `modules/darwin/` under the same flag.
- **home-manager through `hm`.** Write `hm.programs.x = ...` from any module;
  `hm = hm: { ... }` gets home-manager's own arguments.
- **Live config links.** `modules.dotfiles.configLink` and `homeLink` make
  out-of-store symlinks into `config/` of the checkout at `~/src/system`, so
  editing nvim, helix, zed, ghostty and the like needs no rebuild.
- **Profiles.** `modules.profiles.role` and `modules.profiles.hardware` (strings
  such as `"gpu/nvidia"`) select modules under `modules/nixos/profiles/`.
- **Language runtimes** come from `modules.dev.{python,node,go,rust,android}`.
  mise only serves repos that ship a `mise.toml`.

## Checks

Run commands from the checkout on the target platform:

```sh
nix fmt                              # format Nix files
nh os build                          # build NixOS without activating
nh darwin build                      # build macOS without activating
nix build .#checks.x86_64-linux.solforge # Linux theme checks
nix build .#installer-iso             # amarna installer image
```

New files must be staged with `git add` before the flake can see them. Home
Manager is part of the system build, not a separate activation. See
[system maintenance](maintenance.md) for activation and input updates.

## Documentation

Keep READMEs as entry points: what the component is, how to install or enable it,
how to develop it, and links to important docs. Put operational procedures,
option reference and troubleshooting in topic guides under `docs/`, linked from
the relevant README. Update the existing guide rather than adding a feature
section to a README. Keep current model selections and other configuration
snapshots in their source files, not in the overview.
