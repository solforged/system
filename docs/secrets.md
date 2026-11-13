# Secrets and keys

Every credential the hosts use, what it unlocks, and what it asks for. Details
are in [keys/](keys/): [YubiKeys](keys/yubikeys.md), [SSH](keys/ssh.md),
[signing](keys/signing.md), [local login](keys/local-auth.md) and
[recovery](keys/recovery.md).

| Credential                                          | Lives in                                       | Unlocks                                                      | Asks for                 |
| --------------------------------------------------- | ---------------------------------------------- | ------------------------------------------------------------ | ------------------------ |
| Host key, `/etc/ssh/ssh_host_ed25519_key`           | Each host, root only                           | Its agenix secrets at activation; pinned as the host's key   | Nothing                  |
| Host FIDO2 key, `~/.ssh/id_ed25519_sk`              | Primary YubiKey; the handle is on the host     | GitHub; hyperion and amarna log in to each other             | Touch                    |
| Backup FIDO2 key                                    | Backup YubiKey, resident                       | What every host FIDO2 key unlocks                            | PIN and touch            |
| Commit signing key                                  | The host's Secure Enclave or TPM               | Signatures only                                              | Nothing                  |
| Hermes signing key                                  | amarna's TPM                                   | The sandbox's commit signatures                              | Nothing                  |
| agenix admin                                        | PIV slot 82 on both YubiKeys; a paper key      | Editing and rekeying every secret                            | PIN once, touch per file |
| PIV login identity (slots 9a and 9d)                | Both YubiKeys                                  | Mac login, unlock, sudo, dialogs; FileVault (primary tested) | PIN                      |
| fnox identity, `~/.config/fnox/age-identity.txt`    | Each host, plaintext                           | Project secrets                                              | Nothing                  |
| gh token                                            | Keychain                                       | GitHub's API, and push over HTTPS (`repo` scope)             | Nothing                  |

No private key that reaches GitHub or another host sits in a file. The gh token
is the soft spot: anything running as you can use it, including to push over
HTTPS. It carries no `admin:public_key` or `admin:ssh_signing_key` scope, so it
cannot add keys; `ssh-enroll` adds those for one run and removes them.

## agenix

- Activation decrypts `secrets/*.age` with the host key. Recipients are in
  `secrets/agenix-rules.nix`; host keys are in `secrets/host-keys.nix`.
- Every file is also encrypted to the `admins`: the age-plugin-yubikey identity
  in each YubiKey's PIV slot 82, and an offline paper key. On hosts with
  `modules.secrets.admin` (hyperion, amarna), `secrets-edit <file.age>` and
  `secrets-rekey` use whichever YubiKey is plugged in;
  `SECRETS_IDENTITY=<file>` points them at the paper key instead. Never keep
  the paper key on a disk longer than one run.
- A new host's key goes in `secrets/host-keys.nix` and the rules, then
  `secrets-rekey` ([recovery](keys/recovery.md#a-new-host)).

## fnox

fnox decrypts project secrets, stored as age ciphertext, with this host's
`~/.config/fnox/age-identity.txt` (`config/fnox/config.toml`). Create the
identity by hand on a new host and add its recipient there.

## solforge-theme

A private flake input. `system-bump` and `bootstrap` pass `gh auth token`; CI
uses the `SOLFORGE_THEME_TOKEN` secret (see
[system maintenance](maintenance.md#updating-inputs)). By hand, add
`--option access-tokens "github.com=$(gh auth token)"`.
