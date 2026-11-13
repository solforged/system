# Local login

## Macs

hyperion accepts its password, Touch ID, or either YubiKey with its PIV PIN.

| Where                         | Password | Touch ID | YubiKey and PIN                       |
| ----------------------------- | -------- | -------- | ------------------------------------- |
| FileVault, at boot            | Yes      | No       | Primary (tested); backup untested     |
| Login, screen unlock, dialogs | Yes      | Yes      | Both paired                           |
| sudo                          | Yes      | Yes      | Both (`pam_smartcard`, after Touch ID) |

- **Pairing.** A YubiKey's slot 9a identity is paired to the account; 9d
  unwraps the login keychain. Plug the key in, then `sc_auth identities` lists
  the hash, and `sc_auth pair -u admin -h <hash>` (or the dialog macOS shows
  for an unpaired card) pairs it. `sc_auth list -u admin` shows the pairings:
  `B53FE36E…` is the primary, `F4E5ED48…` the backup.
- **FileVault.** Pairing gave the primary a FileVault unlock record. For a key
  that does not unlock at boot:
  `sudo sc_auth filevault -o enable -u admin -h <hash>`. Test with a full
  shutdown; a restart can skip the FileVault screen.
- **Keep the password.** Don't turn on smart-card-only login: a mistake locks
  the Mac. A personal recovery key exists for FileVault.

## amarna

- LUKS asks for its passphrase at boot.
- GDM, sudo and polkit accept the password, the fingerprint reader, or a
  YubiKey touch (`pam_u2f`, `sufficient`; `modules/nixos/security/authentication.nix`).
  `pamu2fcfg` enrolls a key into `~/.config/Yubico/u2f_keys`.
