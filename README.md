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
nh os switch                # amarna
nh darwin switch            # Macs
nh os switch --dry          # build and diff without activating
nix fmt                     # nixfmt-tree
nix build .#installer-iso   # amarna installer
```

nh finds the flake through `NH_FLAKE` (the checkout), picks the host by
hostname, asks for sudo itself, and prints the package diff. Plain
`nixos-rebuild` and `darwin-rebuild` still work, and the installer uses them.

New files must be `git add`ed before the flake can see them.

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

Apply with `nh os switch`, then **log out
and back in** so the Wayland shell discovers the new extensions. Right-click
Start for ArcMenu and taskbar settings, or run `gnome-extensions prefs <UUID>`.
Extension packages and the settings above are managed by Nix; change the module
for persistent tweaks (rebuilding reapplies its settings).

### Solforge themes

amarna enables `modules.desktop.solforge.enable` alongside GNOME. The module in
`modules/nixos/desktop/solforge.nix` reads colors and notebook wallpapers directly
from the existing, pinned **solforge-theme** input; no palette or artwork is
copied into this repo and no additional theme input is needed.

- **GTK 3:** adw-gtk3 with Solforge's color roles.
- **GTK 4 / libadwaita:** user CSS overrides named colors and modern CSS variables,
  retaining the toolkit's native widgets and layout. No global `GTK_THEME` hack.
- **GNOME Shell:** User Themes loads a small overlay on the installed GNOME's
  stock stylesheet, including Quick Settings, notifications and the overview.
  Dash to Panel and ArcMenu receive matching colors without changing the layout.
- **Wallpaper:** the forge drawing (`00-fucina.png`), with both light and dark
  background URIs installed. GNOME's built-in accent is yellow as a fallback
  for apps that don't read user CSS. Icons, cursors and GDM remain stock.

The desktop defaults to dark. To select the light desktop or another drawing,
set these flags in `hosts/amarna/default.nix`, then rebuild:

```nix
desktop.solforge = {
  enable = true;
  variant = "light"; # "dark" is the default
  wallpaper = "02-orologio.png"; # clock; other choices are in the option
};
```

Log out and back in after the first switch so Shell discovers User Themes;
restart GTK apps to reload user CSS. The desktop palette is declarative:
changing appearance in Settings alone does not switch the GTK overrides or
Shell overlay. Change `variant` and rebuild for a consistent desktop. Sandboxed
apps and apps with their own styles may not honor the overrides.

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
nh os switch
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
  `secrets-rekey`. atlas is not a recipient yet.
- **SSH keys** live in Proton Pass. `user.sshKeys` in
  `modules/common/default.nix` lists each host's public key. Every key
  authorizes SSH logins, and each host signs commits with its own key.
  `modules.apps.proton-pass.sshAgent` runs `pass-cli ssh-agent` on
  `~/.ssh/proton-pass-agent.sock`; run `pass-cli login` once per host. On
  NixOS, the CLI uses GNOME Keyring's persistent Secret Service (`dbus`), not
  the default kernel keyring that is cleared on reboot.
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
