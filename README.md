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
lib/               `my`: mkOpt, module walkers, mkHost, mapHosts
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

## Use

`nh` is installed on every host. `NH_FLAKE` points to the live checkout configured
by `modules.dotfiles.dir`, so commands work from any directory and select the
local hostname.

For the first activation, before `nh` is installed:

```sh
nix run --inputs-from ~/src/system nixpkgs#nh -- os switch ~/src/system --ask
```

On Macs, replace `os` with `darwin`. Log out and back in after this first switch
to load `NH_FLAKE`, then use:

```sh
nh os switch --ask          # build, show the diff, confirm, activate (amarna)
nh os build                # build and show the diff without activating
nh os test --ask           # activate without changing the next-boot default
nh os boot --ask           # set the next-boot default without activating
nh os switch --update --ask # update all flake inputs, then rebuild and activate
nh darwin switch --ask      # Macs
nix fmt                    # nixfmt-tree
nix build .#installer-iso   # amarna installer
```

Run `nh` as your normal user; it elevates privileges when needed. Home Manager is
part of the system activation, so no separate `nh home switch` is needed.
On NixOS, `nh clean` runs weekly with a 14-day retention window and removes stale
gcroots. Determinate Nix manages garbage collection on Macs.

New files must be `git add`ed before the flake can see them.

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

Active model roles use Claude 5.5. The `openai` model preset retains Codex
`gpt-6.1-sol:xhigh` for the default role and `gpt-6-luna:high` for commits.

### On-demand wiki

`/wiki` is a Markdown command in `config/tern/plugins/wiki/wiki.md`, linked into
`~/.config/omp/agent/commands/` by Home Manager. Tern links the same directory into
`~/.config/tern/plugins/wiki`. Start a fresh omp process, including
the agent used by Tern, after installing it; command directories are not watched.
omp advertises the command over RPC as well as in its terminal interface.

The default wiki is `~/wiki`, independent of the working project and omp's
internal state. Notes are ordinary Markdown, browsable through `index.md` in
any editor. Home Manager does not own the notes or include them in this repo.

| Invocation | Behavior |
| --- | --- |
| `/wiki <question or topic>` | Research the topic and save a sourced note. |
| `/wiki write <topic or instructions>` | Create or surgically update a readable note and its index entry. With no topic, capture the current discussion. |
| `/wiki ask <question>` | Answer from relevant notes with source links; no writes. |
| `/wiki use <page or topic>` | Read selected notes as background for the current task; no writes. |
| `/wiki` or `/wiki help` | Show usage without accessing the wiki. |

For example: `/wiki write Explain what we learned about the Tern launcher,
including why its wrapper is necessary.` To use another directory, explicitly
name it as the wiki root in the request; that selection applies only to that
invocation.

Writes preserve human annotations, distinguish user decisions from model
recommendations, and record dates and sources. Profiles are ordinary pages;
they are not inferred or read implicitly. A missing wiki is created only by
research or `write`, never by `ask`, `use`, or help.

Mnemopi memory and skill autolearning are enabled separately from `/wiki`.
The wiki command adds no automatic recall, session mining, or background
maintenance. Its rules are model instructions, not a filesystem permission boundary.
Notes read through either `ask` or `use` remain in the conversation's context;
start a fresh session to work without that previously loaded context.

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

## Hermes sandbox (amarna)

`modules.agents.hermes.sandbox.enable` prepares a rootless Podman sandbox for
Hermes' Docker terminal backend, so terminal, file and code tools never touch the
rest of the home directory. Hermes creates and reuses the container itself from
its default `nousresearch/hermes-sandbox:desktop` image; Hermes still owns
`~/.hermes/config.yaml`, where `terminal:` sets `backend: docker`, CPU and
memory limits, and these mounts:

| Host | Container | Purpose |
| --- | --- | --- |
| `~/src` | `/home/sol/src` | Projects, read-write, at host paths |
| `~/src/system` | same path, read-only | This repo becomes root on rebuild |
| `~/wiki` | `/home/sol/wiki` | The wiki |
| `~/.local/share/hermes-sandbox/nix` | `/nix` | The sandbox's own Nix store |
| `~/.local/share/hermes-sandbox/profile.sh` | `/etc/profile.d/zz-hermes-sandbox.sh` | `PATH`, Nix and git settings |
| `$XDG_RUNTIME_DIR/hermes-ssh-agent` | `/mnt/hermes-ssh-agent` | Signing agent |

The `hermes-sandbox-store` user service seeds that store with Nix and mise from
the host. The container never sees the host's nix-daemon socket: the user is a
trusted Nix user, so the socket would give the agent root. `hermes-ssh-agent`
runs a second `pass-cli ssh-agent` limited to the Proton Pass `Hermes` vault,
whose only key signs the sandbox's git commits. The sandbox has no push or
login credentials.

Anything the sandbox can write, the host later runs: Git hooks and
`core.fsmonitor` in `.git/config`, `mise.toml` tasks, build scripts. Review
what Hermes changed before running a project on the host. Changing the mounts
or image makes Hermes start a fresh container and leave the old one running;
remove it with `podman rm -f` (Hermes labels its containers `hermes-agent=1`).
Tool updates need no new container: the store service switches the profile in
place.

## GNOME desktop (amarna)

`modules/nixos/desktop/gnome.nix` provides a Windows-like desktop without adding
desktop icons. The separate Solforge module supplies its colors and wallpaper:

- **Dash to Panel:** an always-visible, 48px bottom taskbar with grouped apps,
  window previews, tray icons, a clock and a Show Desktop button. Clicking a
  focused single-window app minimizes it; Shift-click or middle-click opens a
  new window. Existing pinned favorites are left alone.
- **ArcMenu:** a left-aligned, searchable Start menu using the Redmond layout.
- **Tiling Assistant:** edge snapping, quarter tiling and a popup to fill the
  remaining space with another window.
- **AppIndicator** and the personal-apps module's **GSConnect** remain enabled.
  Window titlebars gain minimize and maximize buttons; hot corners stay off.

| Shortcut | Action |
| --- | --- |
| Super (Windows key) | Open Start menu; type to search |
| Super+Tab | GNOME overview |
| Alt+Tab / Alt+Shift+Tab | Switch individual windows forward / backward |
| Super+1…9 | Launch or switch taskbar apps |
| Super+arrows | Snap, maximize or restore windows |
| Super+D | Show / restore desktop |
| Super+E | Open Files |

Apply with `nh os switch --ask`, then **log out and back in** so the Wayland
shell discovers the new extensions. Right-click
Start for ArcMenu and taskbar settings, or run `gnome-extensions prefs <UUID>`.
Extension packages and the settings above are managed by Nix; change the module
for persistent tweaks (rebuilding reapplies its settings).

### Local Tern binary

On NixOS, `modules.apps.tern.enable` installs a `tern` launcher using `steam-run-free`
and manages its desktop, URL and file-opening entries. The executable stays at
`config/tern/local/tern` in the live checkout configured by
`modules.dotfiles.dir`; that directory is Git-ignored and is not copied into the
flake source or Nix store. Provision it separately on a fresh checkout:

```sh
install -Dm755 /path/to/downloaded/tern ~/src/system/config/tern/local/tern
nh os switch --ask
```

The launcher uses the runtime pinned by this flake, not a floating `nix run`.
Home Manager replaces Tern's Downloads-based `~/.local/bin/tern` symlink and
keeps desktop entries read-only so Tern cannot point them at the unwrapped
binary. Tern may log read-only registration warnings; the managed entries
already provide those launch commands. An existing login entry is migrated
without enabling autostart. The writable settings merge is unchanged.

### Solforge themes

amarna enables `modules.desktop.solforge.enable` alongside GNOME. The module in
`modules/nixos/desktop/solforge.nix` reads colors and notebook wallpapers directly
from the existing, pinned **solforge-theme** input; no palette or artwork is
copied into this repo and no additional theme input is needed.

- **GTK 3:** adw-gtk3 with Solforge's color roles, as the `Solforge-dark` and
  `Solforge-light` themes.
- **GTK 4 / libadwaita:** user CSS overrides named colors and modern CSS variables
  for both palettes, selected by `prefers-color-scheme`, retaining the toolkit's
  native widgets and layout. No global `GTK_THEME` hack.
- **GNOME Shell:** User Themes loads a small overlay on the installed GNOME's
  stock stylesheet, including Quick Settings, notifications and the overview.
  Dash to Panel and ArcMenu receive matching colors without changing the layout.
- **Wallpaper:** the forge drawing (`00-fucina.png`), with both light and dark
  background URIs installed. GNOME's built-in accent is yellow as a fallback
  for apps that don't read user CSS. Icons, cursors and GDM remain stock.

The desktop follows **Settings → Appearance → Style** (or the Quick Settings
dark-style toggle) and starts dark until you pick one. The dark default lives in
a system dconf database, so a rebuild never overrides your choice. GTK 4 apps
switch by themselves. The `solforge-appearance` user service watches the setting
and loads the matching GTK 3 theme, Shell overlay, Dash to Panel and ArcMenu
colors; `systemctl --user status solforge-appearance` shows whether it runs.
To choose another drawing, set it in `hosts/amarna/default.nix` and rebuild:

```nix
desktop.solforge = {
  enable = true;
  wallpaper = "02-orologio.png"; # clock; other choices are in the option
};
```

Log out and back in after the first switch so Shell discovers User Themes.
Sandboxed apps and apps with their own styles may not honor the overrides.

The corresponding app modules also install themes from the same input on both
Linux and macOS, while their existing config files remain live links:

| App | Selection |
| --- | --- |
| Ghostty | Solforge Dark / Light, follows system appearance |
| Zed | Solforge Dark / Light, follows system appearance |
| Helix | `solforge-dark`; change `theme` in `config/helix/config.toml` for light |
| Neovim / LazyVim | `solforge`; follows Neovim's `background` (`:set background=light`) |
| omp / Tern | Existing dark/light Solforge selections remain in place |

Ghostty and Helix link individual config files, not whole directories, so Home
Manager can own their sibling theme files without writing into the checkout.
A guarded activation step removes the old whole-directory links on the first
switch; real directories and unrelated links are left alone. Neovim's color
scheme lives in the data runtime for the same reason. Edit Solforge's upstream
generator to change the palette, then update just that input:

```sh
nix flake update solforge-theme --option access-tokens "github.com=$(gh auth token)"
nix build .#checks.x86_64-linux.solforge
nh os switch --ask
```

The check evaluates both desktop variants, parses their CSS with the pinned
GTK 3/4 and GNOME Shell versions, and checks wallpapers, extension merging, app
theme files and safe migration of the old directory links.

### External-monitor brightness

The GNOME module enables I²C access, installs `ddcutil`, and enables **Brightness
control using ddcutil** (GNOME 50 compatible). Its hardware-brightness sliders
appear in Quick Settings; the extension's default shortcuts are Ctrl+Brightness
Up / Down. The active local session gets device access through udev, without
running `ddcutil` as root.

After rebuilding and logging out and back in, check the monitor connection with:

```sh
ddcutil detect
ddcutil getvcp 10
```

If the monitor is not detected or brightness is unsupported, check that **DDC/CI**
is enabled in the monitor's own menu. Some monitors also restrict brightness
adjustment in HDR or other picture modes. An empty `/sys/class/backlight` is
normal for an external monitor; these controls use DDC/CI instead.

## Fingerprint authentication (amarna)

`modules.security.authentication.{enable,fingerprint}` are already enabled on
amarna. They enable `fprintd`, its enrollment tools and PAM authentication for
GNOME login / screen unlock, `sudo` and polkit prompts, with password fallback.
The connected **DigitalPersona U.are.U 4500** (`05ba:000a`) is recognized by the
stock driver; no proprietary driver is needed.

Enroll a finger as your normal user (no `sudo`), then verify it:

```sh
fprintd-enroll -f right-index-finger
fprintd-list "$USER"
fprintd-verify -f right-index-finger
```

Follow the enrollment prompts, lifting and replacing the same finger between
scans. Alternatively, use **Settings → System → Users → Fingerprint Login**.
Enrollment is local to this machine, stored under `/var/lib/fprint`, not in Nix
or this repository. Re-enroll after reinstalling the system.

Support is already active on amarna; enrollment does not need a rebuild. After
verification, lock the screen with Super+L to test unlocking. `fprintd` starts on
demand over D-Bus, so an idle `fprintd.service` is normal. Terminal PAM prompts
try the reader before falling back to a password, so a password prompt may be
delayed until the scan times out.

Keep your account and disk-encryption passwords: fingerprints do not unlock
LUKS at boot, and a fingerprint-only login cannot automatically unlock GNOME
Keyring. Enter the keyring password when prompted, or log in with your password
to unlock it for apps such as Proton Pass.

## Secrets and keys

- **agenix** decrypts `secrets/*.age` at activation with each host's
  `/etc/ssh/ssh_host_ed25519_key`. Recipients are in `secrets/agenix-rules.nix`.
- **Admin key.** An age key stored as the password of the `agenix admin` item in
  the Proton Pass `Personal` vault. `secrets-edit <file.age>` and
  `secrets-rekey` fetch it through fnox for a single agenix run.
- **Adding a host.** Read its `/etc/ssh/ssh_host_ed25519_key.pub` (on macOS,
  create it first with `sudo ssh-keygen -A`), add it to the rules file, then run
  `secrets-rekey`.
- **SSH keys** live in Proton Pass. `user.sshKeys` in
  `modules/common/default.nix` lists each host's public key. Every key
  authorizes SSH logins, and each host signs commits with its own key.
  `user.agentSigningKeys` lists keys that sandboxed agents sign with; Git
  trusts them for signatures only and no host accepts them for logins. The
  Hermes key lives alone in the `Hermes` vault.
  `modules.apps.proton-pass.sshAgent` runs `pass-cli ssh-agent` on
  `~/.ssh/proton-pass-agent.sock`; run `pass-cli login` once per host. On
  NixOS, the CLI uses GNOME Keyring's persistent Secret Service (`dbus`), not
  the default kernel keyring that is cleared on reboot.
- **SSH access.** amarna accepts inbound SSH only on `tailscale0`; connect
  through the tailnet. Password, keyboard-interactive and root login are
  disabled.
- **fnox** reads project secrets from Proton Pass (`config/fnox/config.toml`).
- **solforge-theme** is a private flake input. Locking or updating it needs
  `--option access-tokens "github.com=$(gh auth token)"`.

## New Mac

Macs run Determinate Nix. The `determinate` nix-darwin module turns off
nix-darwin's own Nix management; `determinateNix.customSettings` writes
`/etc/nix/nix.custom.conf`, and determinate-nixd handles garbage collection.

1. Install Determinate Nix:
   `curl -fsSL https://install.determinate.systems/nix | sh -s -- install`.
   If it reports a keychain password for a non-existing "Nix Store" volume (a
   leftover from an earlier install), delete it with the `security` command it
   prints and rerun.
2. `sudo ssh-keygen -A`, then clone this repo to `~/src/system`.
3. Set `user.name` in the host's `config` if the macOS account is not `sol`.
4. Add the host key to `secrets/agenix-rules.nix` and run `secrets-rekey` from a
   host that has the admin key.
5. `sudo nix run nix-darwin -- switch --flake ~/src/system#<host>`.
6. `pass-cli login`.

Homebrew `cleanup` is `"none"`: switch it to `"zap"` only once the host's brew
and cask lists cover everything installed.

## Reinstalling amarna

See [docs/install-amarna.md](docs/install-amarna.md).
