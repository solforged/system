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

## Shared agent policy

[`config/agents/AGENTS.md`](../config/agents/AGENTS.md) owns shared style,
worktree, cleanup, and intercom rules. Nix links OMP and Pi directly to it;
`config/omp/AGENTS.md` remains a compatibility symlink for existing activations.
Switch once to install the new links. Later policy edits need only a Pi reload
or OMP restart, not a rebuild.

Session worktrees default to
`${XDG_STATE_HOME:-$HOME/.local/state}/agent-worktrees/<repo-key>/<unique-task>`.
Harness-managed worker paths stay unchanged, with review and cleanup owned by
the parent session. This is an instruction policy, not automatic provisioning
or garbage collection.

## Herdr

Both options are enabled on amarna and hyperion:

- `modules.agents.herdr.enable` installs the `herdr` terminal workspace manager
  from the pinned `llm-agents` input.
- `modules.apps.herdr-desktop.enable` installs the official
  [Herdr desktop app](https://github.com/herdrdev/herdr-app), launched with
  `herdr-app` or the Herdr application entry, plus its `herdr-core` (`hc`) runtime.
  The desktop app and TUI use separate daemons and state. The desktop module also
  installs [Solforge light/dark themes](desktop.md#herdr-desktop) and sets the base
  theme pair without replacing other Herdr preferences.

Desktop and core releases are pinned in `packages/herdr-desktop.nix` and
`packages/herdr-core.nix`; update their versions and hashes, then rebuild.
Update the TUI with `nix flake update llm-agents`. Use Nix rebuilds rather than
the apps' self-updaters. Upstream desktop releases enable usage telemetry;
disable it in Settings → Privacy. On Linux, the core starts systemd user services
and may enable user lingering so terminals survive logout.

### Pi integration

Herdr Desktop uses `hc`, not the TUI's `herdr` CLI or socket API. Pi 1.4.0
already reports agent status through OSC 7501 after the terminal confirms
support; no extension install or forced `PI_PROGRAM_STATUS` setting is needed.
The TUI's `herdr integration install pi`, `pane report-metadata`, and TOML
sidebar tokens do not configure Desktop. Its version-matched guide is
`~/.config/herdr-app/AGENTS.md`; use `hc --skill` for the core's manual.

Desktop recognizes subagents started with `hc run` as child terminals. They
appear under their parent without taking a pane; peek opens one, and keep gives
it a pane. Ordinary headless Pi subprocesses are not core child terminals.
The core's delegation manual requires interactive agents, not `pi -p` jobs.
Closing Desktop leaves programs running, but lost kept terminals recover into
shells, not resumed agent sessions or replayed tasks.

When Pi and Herdr TUI are enabled, Home Manager also owns
`~/.config/pi/agent/extensions/herdr-agent-state.ts`. The file is extracted
from the pinned TUI package during a sandboxed build; activation only links it.
No installer runs against the real home, and no credentials or Pi settings are
changed. Set `modules.agents.pi.herdrTuiIntegration.enable = false` to opt out;
it defaults to the TUI's enable flag and is not needed for Desktop.

Home Manager uses the usual `.hm-backup` suffix when backing up a conflicting
manual installation. Resolve any pre-existing backup collision before
switching; do not force-replace it. Restart Pi or `/reload` after switching.
Once managed, update it through Nix rather than rerunning the TUI installer.
This manages the default XDG agent directory; a custom `PI_CODING_AGENT_DIR`
needs its own extension configuration.

Check extraction, option gating, and the hook's session/lifecycle reports with
`nix build .#checks.x86_64-linux.herdr-pi`. The check uses a private fake socket,
not a running Herdr server, credentials, or model calls.

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
