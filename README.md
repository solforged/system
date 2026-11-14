# system

NixOS and nix-darwin configuration for personal machines. One flake builds every
host; hosts mostly turn on `modules.*` flags.

| Host     | Platform                  | Role                                          |
| -------- | ------------------------- | --------------------------------------------- |
| amarna   | NixOS, x86_64             | Desktop: GNOME, Ryzen 9 9950X, RTX PRO 6000   |
| hyperion | nix-darwin, Apple silicon | Personal Mac                                  |
| atlas    | nix-darwin, Apple silicon | Work Mac; shared tools and work-safe agents   |
| aster    | nix-darwin, Apple silicon | Personal Mac; base tools, agents, Tailscale   |

## Install

Keep the checkout at `~/src/system`; dotfiles are linked live from `config/`.

- **NixOS:** [Install or reinstall amarna](docs/install-amarna.md).
- **macOS:** [Set up a Mac](docs/install-mac.md):
  `curl -fsSL https://raw.githubusercontent.com/solforged/system/main/bootstrap | bash`.

On an already configured host, rebuild and activate as your normal user:

```sh
nh os switch     # NixOS
nh darwin switch # macOS
system-bump      # update inputs, build, commit flake.lock
```

A weekly workflow also bumps every input and pushes the lock once every host
evaluates; see [system maintenance](docs/maintenance.md#updating-inputs).

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

- [System maintenance](docs/maintenance.md): bootstrap, rebuilds, updates and
  garbage collection.
- [Terminals and editors](docs/terminals.md): Rex, Nushell, Mitos and Neovim.
- [Desktop](docs/desktop.md): GNOME, Tern, Solforge themes, monitor brightness
  and fingerprints.
- [Agent tools](docs/agents.md): Pi, omp, shared skills, Herdr and Claude Desktop.
- [Local dictation](docs/voice.md): the Parakeet service on hyperion.
- [Memory wiki](docs/wiki.md): the notes repository Pi and omp share.
- [atlas](docs/atlas.md): the work Mac and its private work flake.
- [Hermes sandbox](docs/hermes-sandbox.md): mounts, signing and security
  boundaries.
- [Local inference](modules/nixos/ai/README.md): enable and operate llama.cpp or
  Ollama.
- [Secrets and keys](docs/secrets.md): agenix, YubiKeys, signing keys and SSH access.
