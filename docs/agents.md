# Agent tools

## Oh My Pi

`modules.agents.omp.enable` installs omp and the
[`solforged/omp-intercom`](https://github.com/solforged/omp-intercom) extension.
It is enabled on every host; atlas's work-only additions come from the private
work flake ([atlas](atlas.md)). omp lives in its own home, `~/.omp/agent`. Home
Manager links the pinned extension to `~/.omp/agent/extensions/intercom.ts`,
where omp discovers it automatically. No separate `omp install` is needed.

After switching the system configuration, restart omp sessions to load it. Use
`/intercom list` to find other listening sessions on the same machine. Update
the extension's pin with `nix flake update omp-intercom`, then rebuild.

For the memory wiki, see the [wiki guide](wiki.md).

### Slash commands

Each command is a prompt file in `config/omp/commands/`, linked into
`~/.omp/agent/commands/` by `modules/common/agents/omp.nix`. Edits apply
to the next omp process. A new file also needs an entry in that module's list
and a switch. Command directories are not watched, so start a fresh omp process
after a link is first installed.

| Command          | Does                                                                                   | Never does without asking       |
| ---------------- | -------------------------------------------------------------------------------------- | ------------------------------- |
| `/clickaround`   | Drives the app on a data copy, off screen; numbered, verified findings report          | Fix, commit, touch live data    |
| `/fix-findings`  | Fixes chosen findings with owned-file lanes, re-QA rounds, area commits                | Push, land, change defaults     |
| `/audit`         | Compares a subject with a spec, docs, or another app; ranked proposals                 | Edit anything                   |
| `/take-stock`    | Reconciles the board, repo state, and session recaps; next passes in order             | Edit the board                  |
| `/commit-groups` | Splits uncommitted (or `unpushed`) work into logical signed commits; `plan` to propose | Push, sweep in peers' hunks     |
| `/review-commits` | Proposes a more logical split of the last N (or all unpushed) commits                 | Rewrite history                 |
| `/land`          | Rebases, verifies, and lands by the repo's rule (`ts-land` or fast-forward)            | Merge, force-push main, ship    |
| `/reconcile`     | Brings the checkout up to date with upstream, keeping unique local commits linear      | Push, land, update flake inputs |
| `/tidy`          | Surveys worktrees, branches, servers, and `/tmp`; deletes an approved list             | Touch live peers' work          |
| `/curate-skills` | Audits managed skills, then applies an approved keep/merge/delete list                 | Mutate on the first pass        |

The commands are generic. Project specifics, such as Tessera's ports, seed
notebook, and landing flow, stay in repository-local skills, which the commands
read alongside relevant global skills.

### UI audit and mockup artifacts

`/audit`, `/clickaround`, `/fix-findings` and `/tidy` carry this artifact
policy. It takes precedence over older skill instructions about output
locations or retaining every render; project build and isolation recipes remain
unchanged. An explicit user destination overrides the default.

New runs default to `~/artifacts/<project>/<YYYY-MM-DD>-<topic>/`. Use the stable
repository/project name, not a temporary worktree name, and choose a fresh path
when a prior run already exists. Never overwrite that run. Create only the
parts of this layout relevant to the work:

| Path | Purpose |
| ---- | ------- |
| `evidence/` | Report-cited finding evidence |
| `mockups/` | Editable HTML/CSS/SVG alternatives and required assets |
| `plates/` | Selected captioned renders for readers |
| `report.md` | Severity-ordered findings with stable finding IDs |
| `index.html` | Editorial reading order when there are visual deliverables |

Use relative links within durable output. Keep gallery order separate from
finding IDs and severity order. Diagnostic screenshots, retries, and intermediate
states belong in a task-owned temporary directory: inspect freely, but preserve
only useful evidence. Retain one canonical image per finding; several findings
may share one image. Extra images should establish a meaningful transition,
theme, or viewport difference. Verifiers record results and reuse that evidence,
keeping their own captures only when they add different evidence.

Preserve editable alternatives rather than every render. An ordinary design
story aims for 4–8 reader-facing plates, not a hard limit or a cap on necessary
audit evidence. A retrospective gallery follows **problem → alternatives
considered → chosen direction → implemented result → remaining questions**.
Include only stages that actually exist; a mockup must not stand in for an
implemented result. Use numbered descriptive filenames and captions explaining
what changed and why. Clearly distinguish mockups from the running app, and use
the same viewport, theme, and data state for matched before/after comparisons.

Existing artifacts are not migrated, deleted, or reorganized. Leave existing
`~/Documents` material untouched; it remains usable by explicit path, but is not a
default discovery fallback. Discover new reports under `~/artifacts/<project>/`.
Only temporary captures owned by the current session may be removed, after all
cited evidence, mockup sources, and selected plates are durably preserved. Keep
unfinished work on interruption. This policy is an instruction to agents, not an
automatic provisioning, migration, or cleanup service.

The command files are source-linked. Start a new omp process to pick up command
edits; existing source-linked files need no Nix rebuild or system switch.

### Managed skills

omp writes the skills it learns to `~/.omp/agent/managed-skills`, which Home
Manager leaves alone. Authored skills that Pi and omp share live in
`config/agents/skills/` and link into `~/.agents/skills/`
(`modules/common/agents/skills.nix`), beside the memory skill from the wiki
checkout and the skills Rex and terminal-browser install there.

Keep each procedure in one place: skills point to slash commands for shared
workflows and to other skills for reusable project recipes. Move dated host,
device, and build facts to memory before removing them from a skill.

Project-specific procedures belong in `<repo>/.agents/skills/<name>/SKILL.md`,
not the global managed directory. omp discovers them from the repository root
and nested working directories. Existing `.omp/skills` are also supported; do
not duplicate or overwrite their authored skills. Global skills should cover
cross-project workflows and techniques without a single repository owner.

`/curate-skills` can propose moving a managed skill into its owning repository.
It checks local references and name collisions, creates and verifies the
approved destination, and only then removes the global copy. These files are
ordinary repository content; the managed-skill writer no longer owns them.

## Shared agent policy

[`config/agents/AGENTS.md`](../config/agents/AGENTS.md) owns the shared style
and working rules. The commit rules live in `~/.config/git/commit-style.md`
(`config/git/commit-style.md`). Nix links OMP and Pi directly to the policy, and
`config/omp/AGENTS.md` remains a compatibility symlink. Policy edits take effect
after a Pi reload or OMP restart.

Private worktrees go in `${OMP_WORKTREE_DIR:-$HOME/.omp/wt}/<repo-key>--<task>`,
the layout `ga` creates. It rejects relative roots and occupied paths, including
dangling symlinks. `gd` confirms the target and refuses dirty trees or forced
branch deletion. A new worktree needs `direnv allow` before its devenv shell loads.
Harness-managed worker paths stay unchanged, with review and cleanup owned by
the parent session.

## Pi

`modules.agents.pi.enable` installs Pi from the pinned `llm-agents` input and
links the shared policy to `~/.pi/agent/AGENTS.md`. Its extensions and roles
come from the live `~/src/pi-mono` checkout. Run `pi-setup` once per host, and
again after pulling pi-mono or the wiki: it clones both when missing, along
with the wiki's home bundle on personal hosts, builds the wiki tool, and runs
pi-mono's `scripts/install.ts`, which links the extensions into `~/.pi/agent`.
Activation reminds you while any of these are missing; see the
[wiki guide](wiki.md). Update Pi itself with `system-bump llm-agents`.

The Nous Portal subscription is pi-mono's `nous-portal` provider: run
`/login nous-portal`, then pick a model with `/model`. See pi-mono's
`docs/providers.md`. omp no longer has it.

## Herdr

Both options are enabled on amarna and hyperion:

- `modules.agents.herdr.enable` installs the `herdr` terminal workspace manager
  from the pinned `llm-agents` input.
- `modules.apps.herdr-desktop.enable` installs the official
  [Herdr desktop app](https://github.com/herdrdev/herdr-app), launched with
  `herdr-app` or the Herdr application entry, plus its `herdr-core` (`hc`)
  runtime. The desktop app and TUI use separate daemons and state. The desktop
  module also installs [Solforge light/dark themes](desktop.md#herdr-desktop)
  and sets the base theme pair without replacing other Herdr preferences.

Desktop and core releases are pinned in `packages/herdr-desktop.nix` and
`packages/herdr-core.nix`; update their versions and hashes, then rebuild.
Update the TUI with `nix flake update llm-agents`. Use Nix rebuilds rather than
the apps' self-updaters. Upstream desktop releases enable usage telemetry;
disable it in Settings → Privacy. On Linux, the core starts systemd user
services and may enable user lingering so terminals survive logout.

### Pi integration

Herdr Desktop uses `hc`, not the TUI's `herdr` CLI or socket API. Pi 1.4.0
already reports agent status through OSC 7501 after the terminal confirms
support; no extension install or forced `PI_PROGRAM_STATUS` setting is needed.
The TUI's `herdr integration install pi`, `pane report-metadata`, and TOML
sidebar tokens do not configure Desktop. Its version-matched guide is
`~/.config/herdr-app/AGENTS.md`; use `hc --skill` for the core's manual.

Desktop recognizes subagents started with `hc run` as child terminals. They
appear under their parent without taking a pane; peek opens one, and keep gives
it a pane. Ordinary headless Pi subprocesses are not core child terminals. The
core's delegation manual requires interactive agents, not `pi -p` jobs. Closing
Desktop leaves programs running, but lost kept terminals recover into shells,
not resumed agent sessions or replayed tasks.

When Pi and Herdr TUI are enabled, Home Manager also owns
`~/.pi/agent/extensions/herdr-agent-state.ts`. The file is extracted from
the pinned TUI package during a sandboxed build; activation only links it. No
installer runs against the real home, and no credentials or Pi settings are
changed. Set `modules.agents.pi.herdrTuiIntegration.enable = false` to opt out;
it defaults to the TUI's enable flag and is not needed for Desktop.

Home Manager uses the usual `.hm-backup` suffix when backing up a conflicting
manual installation. Resolve any pre-existing backup collision before switching;
do not force-replace it. Restart Pi or `/reload` after switching. Once managed,
update it through Nix rather than rerunning the TUI installer. This manages
`~/.pi/agent`; a custom `PI_CODING_AGENT_DIR` needs its own extension
configuration.

Check extraction, option gating, and the hook's session/lifecycle reports with
`nix build .#checks.x86_64-linux.herdr-pi`. The check uses a private fake
socket, not a running Herdr server, credentials, or model calls.

## Claude Desktop

`modules.apps.claude-desktop.enable` installs the `claude` cask on Macs, which
updates itself. On NixOS it installs `claude-desktop` from the
[`numtide/llm-agents.nix`](https://github.com/numtide/llm-agents.nix) flake
input, which keeps its own nixpkgs pin to use the Numtide binary cache. Upstream
bumps the package from Anthropic's apt repository several times a day. The app
does not update itself on Linux and shows "update available" as soon as
Anthropic publishes a release; pick it up with `nix flake update llm-agents`,
then rebuild.

The package runs the app in a bubblewrap FHS environment. That sandbox sets
no_new_privs, so `sudo` fails in the app's terminal and in Claude Code sessions
it starts; run privileged commands from another terminal. The module also puts
`bubblewrap` and `socat` on `PATH` for Claude Code's sandbox.

`cowork.enable` (NixOS only, on for amarna) sets up Cowork's local VM: QEMU on
the user's `PATH`, the `kvm` group for `/dev/kvm` and `/dev/vhost-vsock`, and
the `vhost_vsock` module. The FHS environment supplies the UEFI firmware and
virtiofsd at the Debian paths the app probes. Log out and back in after the
first switch so the new group applies.
