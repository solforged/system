# system

NixOS and nix-darwin configuration for personal machines. One flake builds every
host; hosts mostly turn on `modules.*` flags.

| Host     | Platform                  | Role                                          |
| -------- | ------------------------- | --------------------------------------------- |
| amarna   | NixOS, x86_64             | Desktop: GNOME, Ryzen 9 9950X, RTX PRO 6000   |
| hyperion | nix-darwin, Apple silicon | Personal Mac                                  |
| atlas    | nix-darwin, Apple silicon | Work Mac; base tools only, no personal agents |

## Layout

```
flake.nix          inputs; nixosConfigurations and darwinConfigurations from hosts/
lib/               `my`: mkOpt, module walkers, mapHosts
modules/common/    every modules.* option, plus settings valid on both platforms
modules/nixos/     NixOS-only implementations of the same flags
modules/darwin/    nix-darwin-only implementations
hosts/<name>/      default.nix (flags), hardware.nix and disko.nix on NixOS
config/            raw dotfiles, linked live into $HOME
packages/          local derivations; each becomes pkgs.<name>
secrets/           agenix files and their recipients
installer/         custom NixOS installer image for amarna
docs/              install runbook
```

## Conventions

- **Hosts are attrsets, not modules.** `hosts/<name>/default.nix` returns
  `{ system; modules; config; }`. `system` picks the builder: a `-darwin` suffix
  means nix-darwin. `config` is an ordinary module for host-only settings. See
  `lib/hosts.nix`.
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

## Use

```sh
sudo nixos-rebuild switch --flake ~/src/system#amarna   # amarna
sudo darwin-rebuild switch --flake ~/src/system         # Macs
nix fmt                                                 # nixfmt-tree
nix build .#installer-iso                               # amarna installer
```

New files must be `git add`ed before the flake can see them.

## Secrets and keys

- **agenix** decrypts `secrets/*.age` at activation with each host's
  `/etc/ssh/ssh_host_ed25519_key`. Recipients are in `secrets/agenix-rules.nix`.
- **Admin key.** An age key stored as the password of the `agenix admin` item in
  the Proton Pass `Personal` vault. `secrets-edit <file.age>` and
  `secrets-rekey` fetch it through fnox for a single agenix run.
- **Adding a host.** Read its `/etc/ssh/ssh_host_ed25519_key.pub` (on macOS,
  create it first with `sudo ssh-keygen -A`), add it to the rules file, then run
  `secrets-rekey`. hyperion and atlas are not recipients yet.
- **SSH keys** live in Proton Pass. `user.sshKeys` in
  `modules/common/default.nix` lists each host's public key. Every key
  authorizes SSH logins, and each host signs commits with its own key.
  `modules.apps.proton-pass.sshAgent` runs `pass-cli ssh-agent` on
  `~/.ssh/proton-pass-agent.sock`; run `pass-cli login` once per host.
- **fnox** reads project secrets from Proton Pass (`config/fnox/config.toml`).
- **solforge-theme** is a private flake input. Locking or updating it needs
  `--option access-tokens "github.com=$(gh auth token)"`.

## New Mac

1. Install Nix, then `sudo ssh-keygen -A`.
2. Clone this repo to `~/src/system`.
3. Add the host key to `secrets/agenix-rules.nix` and run `secrets-rekey` from a
   host that has the admin key.
4. `sudo nix run nix-darwin -- switch --flake ~/src/system#<host>`.
5. `pass-cli login`.

Homebrew `cleanup` is `"none"`: switch it to `"zap"` only once the host's brew
and cask lists cover everything installed.

## Reinstalling amarna

See [docs/install-amarna.md](docs/install-amarna.md).
