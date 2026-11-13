# Secrets and keys

- **agenix** decrypts `secrets/*.age` at activation with each host's
  `/etc/ssh/ssh_host_ed25519_key`. Recipients are in `secrets/agenix-rules.nix`.
- **Admin key.** An age key stored as the password of the `agenix admin` item in
  the Proton Pass `Personal` vault. `secrets-edit <file.age>` and
  `secrets-rekey` fetch it through fnox for a single agenix run.
- **Adding a host.** Read its `/etc/ssh/ssh_host_ed25519_key.pub` (on macOS,
  create it first with `sudo ssh-keygen -A`), add it to the rules file, then run
  `secrets-rekey`.
- **SSH keys.** Each host has its own passphrase-less `~/.ssh/id_ed25519` that
  never leaves it. `ssh-enroll` creates it if missing and registers it on
  GitHub for push and signing, then prints the line to add to `user.sshKeys` in
  `modules/common/default.nix`. A host in `user.sshKeys` signs commits with its
  key, and only hosts in `user.sshLoginHosts` may log in to the others; atlas
  signs but does not log in. `config/ssh/config` uses the key for GitHub and
  personal hosts and reads `~/.ssh/config.local` first.
- **Verifying old signatures.** `user.retiredSigningKeys` keeps replaced keys in
  Git's and jj's allowed signers; they authorize nothing.
  `user.agentSigningKeys` lists keys that sandboxed agents sign with; Git trusts
  them for signatures only. The Hermes key lives alone in the `Hermes` Proton
  Pass vault and is served by the sandbox's own agent. Run `pass-cli login` once
  per host that uses it. On NixOS, the CLI uses GNOME Keyring's persistent
  Secret Service (`dbus`), not the default kernel keyring that is cleared on
  reboot.
- **SSH access.** amarna accepts inbound SSH only on `tailscale0`; connect
  through the tailnet. Password, keyboard-interactive and root login are
  disabled.
- **fnox** decrypts project secrets, stored as age ciphertext, with this host's
  `~/.config/fnox/age-identity.txt` (`config/fnox/config.toml`). Create the
  identity by hand on a new host and add its recipient there.
- **solforge-theme** is a private flake input. `system-bump` and `bootstrap`
  pass `gh auth token`; CI uses the `SOLFORGE_THEME_TOKEN` secret (see
  [system maintenance](maintenance.md#updating-inputs)). By hand, add
  `--option access-tokens "github.com=$(gh auth token)"`.
