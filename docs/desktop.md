# Desktop guide

## GNOME (amarna)

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

| Shortcut                | Action                                       |
| ----------------------- | -------------------------------------------- |
| Super (Windows key)     | Open Start menu; type to search              |
| Super+Tab               | GNOME overview                               |
| Alt+Tab / Alt+Shift+Tab | Switch individual windows forward / backward |
| Super+1…9               | Launch or switch taskbar apps                |
| Super+arrows            | Snap, maximize or restore windows            |
| Super+D                 | Show / restore desktop                       |
| Super+E                 | Open Files                                   |

Apply with `nh os switch`, then **log out and back in** so the Wayland shell
discovers the new extensions. Right-click Start for ArcMenu and taskbar
settings, or run `gnome-extensions prefs <UUID>`. Extension packages and the
settings above are managed by Nix; change the module for persistent tweaks
(rebuilding reapplies its settings).

## Tern on NixOS

On NixOS, `modules.apps.tern.enable` installs a `tern` launcher using
`steam-run-free` and manages its desktop, URL and file-opening entries. The
executable stays at `config/tern/local/tern` in the live checkout configured by
`modules.dotfiles.dir`; that directory is Git-ignored and is not copied into the
flake source or Nix store. Provision it separately on a fresh checkout:

```sh
install -Dm755 /path/to/downloaded/tern ~/src/system/config/tern/local/tern
nh os switch
```

The launcher uses the runtime pinned by this flake, not a floating `nix run`.
Home Manager replaces Tern's Downloads-based `~/.local/bin/tern` symlink and
keeps desktop entries read-only so Tern cannot point them at the unwrapped
binary. Tern may log read-only registration warnings; the managed entries
already provide those launch commands. An existing login entry is migrated
without enabling autostart. The writable settings merge is unchanged.

## Tern and the shells

Tern opens `nu` (`shell` in `config/tern/settings.json`) and draws the prompt
itself in the `tern` style. The settings file is merged into Tern's writable
copy on every switch, so the repository's keys win over changes made in the app.

`/etc/zshenv` keeps an inherited `ZDOTDIR` on both NixOS and macOS, including
the temporary shell-integration directory a terminal points it at; PAM and
launchd still supply `~/.config/zsh` as the default. Overwriting `ZDOTDIR` there
skips Tern's zsh hooks, which costs zsh the native prompt and command lenses.
After changing this, switch and open a fresh terminal; existing shells keep the
startup hooks they already loaded.

Tern ships no Nushell integration, so `config/nushell/config.nu` speaks its
protocol itself when `TERM_PROGRAM=tern`. Before each command it reports the
command line (aliases with their expansion) and exports the pager variables
Tern's other integrations set (`GIT_PAGER=cat` for `git log`, `GH_PAGER`,
`MANPAGER` and the rest), which is what lets command lenses render the output.
Before each prompt it reports the native prompt's state and, for a preset style,
replaces the prompt with blank columns for Tern to draw over. Nushell does not
expose the line editor's vi mode, so Tern's prompt character always shows insert
mode.

Outside Tern's native prompt (Ghostty, ssh, the `imported` style) nu and zsh
draw the same small prompt, from the Prompt section of `config.nu` and from
`config/zsh/config.d/prompt.zsh`: host, directory and git state, `>` (or `<` in
vi normal mode) coloured by the last status, and the duration and failing status
on the right. There is no Starship.

## Solforge themes

amarna enables `modules.desktop.solforge.enable` alongside GNOME. The module in
`modules/nixos/desktop/solforge.nix` reads colors and notebook wallpapers
directly from the existing, pinned **solforge-theme** input; no palette or
artwork is copied into this repo and no additional theme input is needed.

- **GTK 3:** adw-gtk3 with Solforge's color roles, as the `Solforge-dark` and
  `Solforge-light` themes.
- **GTK 4 / libadwaita:** user CSS overrides named colors and modern CSS
  variables for both palettes, selected by `prefers-color-scheme`, retaining the
  toolkit's native widgets and layout. No global `GTK_THEME` hack.
- **GNOME Shell:** User Themes loads a small overlay on the installed GNOME's
  stock stylesheet, including Quick Settings, notifications and the overview.
  Dash to Panel and ArcMenu receive matching colors without changing the layout.
- **Wallpaper:** the forge drawing (`00-fucina.png`), with both light and dark
  background URIs installed. GNOME's built-in accent is yellow as a fallback for
  apps that don't read user CSS. Icons, cursors and GDM remain stock.

The desktop follows **Settings → Appearance → Style** (or the Quick Settings
dark-style toggle) and starts dark until you pick one. The dark default lives in
a system dconf database, so a rebuild never overrides your choice. GTK 4 apps
switch by themselves. The `solforge-appearance` user service watches the setting
and loads the matching GTK 3 theme, Shell overlay, Dash to Panel and ArcMenu
colors; `systemctl --user status solforge-appearance` shows whether it runs. To
choose another drawing, set it in `hosts/amarna/default.nix` and rebuild:

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

| App              | Selection                                                                |
| ---------------- | ------------------------------------------------------------------------ |
| Ghostty          | Solforge Dark / Light, follows system appearance                         |
| Zed              | Solforge Dark / Light, follows system appearance                         |
| Herdr desktop    | `solforge-dark` / `solforge-light`, follows system appearance by default |
| Helix            | `solforge-dark`; change `theme` in `config/helix/config.toml` for light  |
| Neovim / LazyVim | `solforge`; follows Neovim's `background` (`:set background=light`)      |
| omp / Tern       | Existing dark/light Solforge selections remain in place                  |

Ghostty and Helix link individual config files, not whole directories, so Home
Manager can own their sibling theme files without writing into the checkout. A
guarded activation step removes the old whole-directory links on the first
switch; real directories and unrelated links are left alone. Neovim's color
scheme lives in the data runtime for the same reason. Edit Solforge's upstream
generator to change the palette, then update just that input:

```sh
system-bump solforge-theme --no-commit
nix build .#checks.x86_64-linux.solforge
nh os switch
```

The check evaluates both desktop variants, parses their CSS with the pinned GTK
3/4 and GNOME Shell versions, and checks wallpapers, extension merging, app
theme files and safe migration of the old directory links. Herdr's native theme
parser, terminal palette, UI contrast and settings merge have a separate check:
`nix build .#checks.x86_64-linux.herdr-themes`.

### Herdr desktop

`modules.apps.herdr-desktop.enable` installs both Solforge variants at
`~/.config/herdr-app/themes/` on Linux and macOS. They are generated from the
pinned input, not a second hand-maintained palette. Terminals use Ghostty's
exact ANSI colors, selection and gold cursor; the interface adds oxblood/vellum
surfaces, gilt focus rings and buttons, and yellow/red/green agent states for
working/blocked/done. Fonts and layout are unchanged.

On activation, only the base `theme` pair in Herdr's writable `settings.json` is
managed. Fonts, zoom, sounds, telemetry, appearance and other preferences
survive rebuilds. With Appearance set to **System** in **Settings → Look**, the
default Herdr layout follows the desktop's light/dark choice. Explicit
appearance choices are respected. Per-layout theme picks override the base pair
and are left alone; select `solforge-dark` and `solforge-light` in Settings →
Look for a layout with its own look or a previous theme pick. Herdr reloads the
files live; no daemon or terminal restart is needed.

## External-monitor brightness

The GNOME module enables I²C access, installs `ddcutil`, and enables
**Brightness control using ddcutil** (GNOME 50 compatible). Its
hardware-brightness sliders appear in Quick Settings; the extension's default
shortcuts are Ctrl+Brightness Up / Down. The active local session gets device
access through udev, without running `ddcutil` as root.

After rebuilding and logging out and back in, check the monitor connection with:

```sh
ddcutil detect
ddcutil getvcp 10
```

If the monitor is not detected or brightness is unsupported, check that
**DDC/CI** is enabled in the monitor's own menu. Some monitors also restrict
brightness adjustment in HDR or other picture modes. An empty
`/sys/class/backlight` is normal for an external monitor; these controls use
DDC/CI instead.

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
verification, lock the screen with Super+L to test unlocking. `fprintd` starts
on demand over D-Bus, so an idle `fprintd.service` is normal. Terminal PAM
prompts try the reader before falling back to a password, so a password prompt
may be delayed until the scan times out.

Keep your account and disk-encryption passwords: fingerprints do not unlock LUKS
at boot, and a fingerprint-only login cannot automatically unlock GNOME Keyring.
Enter the keyring password when prompted, or log in with your password to unlock
it for apps such as Proton Pass.
