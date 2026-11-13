# Installing a Mac

Macs run Determinate Nix. The `determinate` nix-darwin module turns off
nix-darwin's own Nix management; `determinateNix.customSettings` writes
`/etc/nix/nix.custom.conf`, and determinate-nixd handles garbage collection.

If moving from dotfiles, complete the migration preflight below first.
From an interactive terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/solforged/system/main/bootstrap | bash
```

or, in an existing checkout, `~/src/system/bootstrap [host]`. The host defaults
to the Mac's LocalHostName. Rerun it at any time; finished steps are skipped.
It:

1. installs Determinate Nix and Homebrew, which nix-darwin drives but does not
   install;
2. clones this repo to `~/src/system` and signs in to GitHub for the private
   theme input;
3. checks that the host's `user.name` matches the macOS account;
4. creates the SSH host key and warns when it is not yet an agenix recipient;
5. removes links into `~/src/dotfiles` from the old mise setup, after asking,
   since Home Manager will not replace symlinks it did not make;
6. moves the installer's `/etc/nix/nix.custom.conf` aside and activates the host
   with `nh darwin switch`.

Then log out and back in, run `pi-setup`, and finish the
[Rex setup](terminals.md#rex-on-macs). Run `ssh-enroll` with the primary
YubiKey plugged in if the host has no `~/.ssh/id_ed25519_sk` yet, and add the
lines it prints.

To make a new host's secrets decrypt, add its key to `secrets/agenix-rules.nix`,
run `secrets-rekey` on a host with an admin YubiKey plugged in, pull, and rerun
`bootstrap`.
The bootstrap skill in `.agents/skills` covers first-switch failures.

Homebrew `cleanup` defaults to `"none"`, so activation leaves extra formulae and
casks installed. hyperion sets `"uninstall"`, which removes formulae and casks
that are no longer listed. `"zap"` also deletes the files a cask owns.

## Moving from dotfiles

Keep the old checkout and caches until the new setup is verified. The bootstrap
refuses to run while the old environment, container or voice launch agents
remain installed. They can overwrite Nix's environment or compete with its
services. Review them, then retire each installed job without deleting its plist:

```sh
backup="$HOME/.local/state/system/launchagents-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
for label in dev.mise.session-env dev.mise.container-system dev.mise.voice-stt; do
  launchctl bootout "gui/$(id -u)/$label" # Already-unloaded jobs report an error.
  plist="$HOME/Library/LaunchAgents/$label.plist"
  if [ -e "$plist" ]; then mv "$plist" "$backup/"; fi
done
```

Do this immediately before the switch: dictation stops until the new service
starts. Other user/project launch agents are left alone. Review
`dev.mise.cargo-sweep` separately; it is not replaced by this flake.

Keep `~/.pi/agent`, `~/.omp/agent`, `~/.ssh/id_ed25519*`,
`~/.config/fnox/age-identity.txt` and the memory wiki in place. The agent modules
now use their native homes, and the local keys continue to work. Back up any
older `~/.config/pi` or `~/.config/omp` state before deciding what to migrate;
this bootstrap does not merge credential stores or sessions.

On hyperion, Homebrew cleanup can uninstall apps omitted from the flake. Review
`hosts/hyperion/default.nix` and `brew leaves` / `brew list --cask` before the
first switch. The bootstrap's symlink removal prompt also includes links for
tools that were dropped, so review the full list.

For subsequent activations and input updates, see
[system maintenance](maintenance.md).
