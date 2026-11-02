# system

NixOS and nix-darwin configuration for personal machines. One flake builds every
host; hosts mostly turn on `modules.*` flags.

| Host     | Platform                  | Role                                          |
| -------- | ------------------------- | --------------------------------------------- |
| amarna   | NixOS, x86_64             | Desktop: GNOME, Ryzen 9 9950X, RTX PRO 6000   |
| hyperion | nix-darwin, Apple silicon | Personal Mac                                  |
| atlas    | nix-darwin, Apple silicon | Work Mac; base tools only, no personal agents |

## Install

Keep the checkout at `~/src/system`; dotfiles are linked live from `config/`.

- **NixOS:** [Install or reinstall amarna](docs/install-amarna.md).
- **macOS:** [Set up a Mac](docs/install-mac.md).

On an already configured host, rebuild and activate as your normal user:

```sh
nh os switch     # NixOS
nh darwin switch # macOS
```

## Develop

- Select host features in `hosts/<name>/default.nix`.
- Change shared options in `modules/common/`; platform implementations live in
  `modules/nixos/` and `modules/darwin/`.
- Edit live dotfiles under `config/` without rebuilding.

```sh
nix fmt     # format Nix files
nh os build # build NixOS without activating; use nh darwin build on macOS
```

Stage new files with `git add` so the flake can see them. See the
[development guide](docs/development.md) for layout, module conventions, checks
and documentation guidelines.

## Docs

- [System maintenance](docs/maintenance.md): bootstrap, rebuilds, updates and garbage collection.
- [Desktop](docs/desktop.md): GNOME, Tern, Solforge themes, monitor brightness and fingerprints.
- [Agent tools](docs/agents.md): omp, Herdr and Claude Desktop.
- [Wiki](docs/wiki.md): how the omp-wiki checkout is linked in.
- [Hermes sandbox](docs/hermes-sandbox.md): mounts, signing and security boundaries.
- [Local inference](modules/nixos/ai/README.md): enable and operate llama.cpp or Ollama.
- [Secrets and keys](docs/secrets.md): agenix, Proton Pass and SSH access.
