# Installing a Mac

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

For subsequent activations and input updates, see
[system maintenance](maintenance.md).
