# Secrets and keys

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
  `user.agentSigningKeys` lists keys that sandboxed agents sign with; Git trusts
  them for signatures only and no host accepts them for logins. The Hermes key
  lives alone in the `Hermes` vault. `modules.apps.proton-pass.sshAgent` runs
  `pass-cli ssh-agent` on `~/.ssh/proton-pass-agent.sock`; run `pass-cli login`
  once per host. On NixOS, the CLI uses GNOME Keyring's persistent Secret
  Service (`dbus`), not the default kernel keyring that is cleared on reboot.
- **SSH access.** amarna accepts inbound SSH only on `tailscale0`; connect
  through the tailnet. Password, keyboard-interactive and root login are
  disabled.
- **fnox** reads project secrets from Proton Pass (`config/fnox/config.toml`).
- **solforge-theme** is a private flake input. Locking or updating it needs
  `--option access-tokens "github.com=$(gh auth token)"`.
