# Secrets and keys

- **agenix** decrypts `secrets/*.age` at activation with each host's
  `/etc/ssh/ssh_host_ed25519_key`. Recipients are in `secrets/agenix-rules.nix`.
- **Admin identities.** Every file is also encrypted to the `admins` in the
  rules file: an age-plugin-yubikey PIV key on each YubiKey (PIN once per
  session, a touch per file) and an offline paper key. On hosts with
  `modules.secrets.admin`, `secrets-edit <file.age>` and `secrets-rekey` use
  whichever YubiKey is plugged in; `SECRETS_IDENTITY=<file>` points them at the
  paper key instead. Never decrypt the paper key onto a host's disk for longer
  than one run.
- **Adding a host.** Read its `/etc/ssh/ssh_host_ed25519_key.pub` (on macOS,
  create it first with `sudo ssh-keygen -A`), add it to
  `secrets/host-keys.nix` and the rules file, then run `secrets-rekey`. Every
  host also pins it in `/etc/ssh/ssh_known_hosts`, with GitHub's keys.
- **SSH keys** live on the YubiKeys. With only the primary plugged in,
  `ssh-enroll` gives a host its own FIDO2 key, `~/.ssh/id_ed25519_sk`: a handle
  that is useless without the YubiKey, and needs a touch per connection.
  It registers the key on GitHub and prints the line for `user.authKeys` in
  `modules/common/default.nix`. Only hosts in `user.sshLoginHosts` may log in
  to the others; atlas reaches GitHub but logs in nowhere.
- **Backup YubiKey.** `ssh-enroll --backup`, run once, makes its resident key,
  which needs the PIN and a touch and logs in wherever the primary's keys do
  (`user.backupAuthKey`). On any host, `cd ~/.ssh && ssh-keygen -K` fetches its
  handle when the primary is gone. Then enroll a replacement primary on every
  host and remove the lost key's lines and GitHub keys.
- **Using the keys.** `config/ssh/config` offers both handles to GitHub and
  personal hosts and reads `~/.ssh/config.local` first. One touch serves
  every connection to that host for 10 minutes (`ControlPersist`). Only Nix's
  ssh speaks FIDO2, so Git's `core.sshCommand` points at it; `/usr/bin/ssh`,
  which GUI apps would find first, cannot use the keys.
- **Signing.** `ssh-enroll` also gives each host a commit signing key that
  cannot leave it and signs without a prompt, registered on GitHub and listed in
  `user.signingKeys`. On a Mac it lives in the Secure Enclave and
  `~/.ssh/id_ecdsa_sk_signing` is its handle, used through Apple's
  `/usr/lib/ssh-keychain.dylib`. On NixOS it is sealed to the TPM
  (`~/.ssh/id_ecdsa_signing.tpm`) and served by `ssh-tpm-agent`. Git and jj
  pick the setup from the type of the host's line, so a host still on the old
  `~/.ssh/id_ed25519` keeps signing with it until its new line lands. Signing
  keys authorize no logins and no GitHub access; anything running as you can
  sign, but nothing can copy the key.
- **Verifying old signatures.** `user.retiredSigningKeys` keeps replaced keys in
  Git's and jj's allowed signers; they authorize nothing.
  `user.agentSigningKeys` lists keys that sandboxed agents sign with; Git trusts
  them for signatures only. Hermes' key is sealed to amarna's TPM and served by
  the sandbox's own agent ([Hermes sandbox](hermes-sandbox.md#signing)).
- **SSH access.** amarna accepts inbound SSH only on `tailscale0`; hyperion's
  Remote Login lets in only tailnet addresses (`AllowUsers`). Both take keys
  only, and only the keys this flake declares; hyperion ignores
  `~/.ssh/authorized_keys`, so pair a client (such as Tern) by adding its key
  to the host's `users.users.<name>.openssh.authorizedKeys`. Rex for iOS pairs
  over Tailscale and needs no SSH.
- **gh's token** lives in the keychain, where any process can use it, so it
  carries no `admin:public_key` or `admin:ssh_signing_key` scope. `ssh-enroll`
  adds them for one run and removes them again.
- **fnox** decrypts project secrets, stored as age ciphertext, with this host's
  `~/.config/fnox/age-identity.txt` (`config/fnox/config.toml`). Create the
  identity by hand on a new host and add its recipient there.
- **solforge-theme** is a private flake input. `system-bump` and `bootstrap`
  pass `gh auth token`; CI uses the `SOLFORGE_THEME_TOKEN` secret (see
  [system maintenance](maintenance.md#updating-inputs)). By hand, add
  `--option access-tokens "github.com=$(gh auth token)"`.
