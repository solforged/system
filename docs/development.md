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
bootstrap          first-run setup for a Mac
.github/           checks on every push and the weekly input bump
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
  Projects bring their own with devenv or a flake `devShell`;
  `modules.dev.devenv` installs devenv and loads a project's `.envrc` through
  direnv in zsh and Nushell. mise only serves repos that ship a `mise.toml`.

## Checks

Run commands from the checkout on the target platform:

```sh
nix fmt                              # format Nix files
nh os build                          # build NixOS without activating
nh darwin build                      # build macOS without activating
nix flake check                      # build this platform's hosts and checks
system-bump --verify                 # evaluate every host and check (CI)
nix build .#checks.x86_64-linux.solforge # Linux theme checks
nix build .#checks.x86_64-linux.herdr-themes # Herdr themes and settings merge
nix build .#checks.x86_64-linux.herdr-pi # Pinned Herdr TUI integration for Pi
nix build .#installer-iso             # amarna installer image
vale --no-global --config config/vale/test.ini test --coverage config/vale/styles/Voice # prose rules
```

New files must be staged with `git add` before the flake can see them. Home
Manager is part of the system build, not a separate activation. See
[system maintenance](maintenance.md) for activation and input updates.

`config/vale` holds the shared prose style. `vale.ini` is the global Vale
configuration and `styles/Voice` the rules it enables, both linked live;
`styles/Voice/Brief.md` is the written house standard the rules enforce, and
`styles/Voice/NOTICE` records the upstream source of the vendored dictionary
and rules. Each rule carries its own test cases. Projects that gate on prose,
such as Tessera, commit a copy of `styles/Voice` and refresh it after a change
here.

## Documentation

Keep READMEs as entry points: what the component is, how to install or enable
it, how to develop it, and links to important docs. Put operational procedures,
option reference and troubleshooting in topic guides under `docs/`, linked from
the relevant README. Update the existing guide rather than adding a feature
section to a README. Keep current model selections and other configuration
snapshots in their source files, not in the overview.
