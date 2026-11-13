# Installing a Mac

Macs run Determinate Nix. The `determinate` nix-darwin module turns off
nix-darwin's own Nix management; `determinateNix.customSettings` writes
`/etc/nix/nix.custom.conf`, and determinate-nixd handles garbage collection.

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

Then log out and back in, and run `pass-cli login`.

To make a new host's secrets decrypt, add its key to `secrets/agenix-rules.nix`,
run `secrets-rekey` on a host with the admin key, pull, and rerun `bootstrap`.
The bootstrap skill in `.agents/skills` covers first-switch failures.

Homebrew `cleanup` defaults to `"none"`, so activation leaves extra formulae and
casks installed. hyperion sets `"uninstall"`, which removes formulae and casks
that are no longer listed. `"zap"` also deletes the files a cask owns.

For subsequent activations and input updates, see
[system maintenance](maintenance.md).
