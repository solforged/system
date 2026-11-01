# Agent tools

## Oh My Pi

`modules.agents.omp.enable` installs omp and the
[`solforged/omp-intercom`](https://github.com/solforged/omp-intercom) extension.
Both are enabled on amarna and hyperion; atlas keeps personal agents disabled.
Home Manager links the pinned extension to
`~/.config/omp/agent/extensions/intercom.ts`, where omp discovers it automatically.
No separate `omp install` is needed.

After switching the system configuration, restart omp sessions to load it.
Use `/intercom list` to find other listening sessions on the same machine.
Update the extension's pin with `nix flake update omp-intercom`, then rebuild.

For notes and background drafting, see the [wiki guide](wiki.md).

## Claude Desktop

`modules.apps.claude-desktop.enable` installs the `claude` cask on Macs, which
updates itself. On NixOS it installs `claude-desktop` from the
[`numtide/llm-agents.nix`](https://github.com/numtide/llm-agents.nix) flake
input, which keeps its own nixpkgs pin to use the Numtide binary cache. Upstream
bumps the package from Anthropic's apt repository several times a day. The app
does not update itself on Linux and shows "update available" as soon as Anthropic
publishes a release; pick it up with `nix flake update llm-agents`, then rebuild.

The package runs the app in a bubblewrap FHS environment. That sandbox sets
no_new_privs, so `sudo` fails in the app's terminal and in Claude Code sessions
it starts; run privileged commands from another terminal. The module also puts
`bubblewrap` and `socat` on `PATH` for Claude Code's sandbox.

`cowork.enable` (NixOS only, on for amarna) sets up Cowork's local VM: QEMU on
the user's `PATH`, the `kvm` group for `/dev/kvm` and `/dev/vhost-vsock`, and
the `vhost_vsock` module. The FHS environment supplies the UEFI firmware and
virtiofsd at the Debian paths the app probes. Log out and back in after the
first switch so the new group applies.
