# Recovery

Lines below go in `modules/common/default.nix` unless named otherwise. GitHub
keys are listed and deleted with `gh ssh-key list` and `gh ssh-key delete <id>`
after `gh auth refresh -h github.com -s admin:public_key,admin:ssh_signing_key`;
drop the scopes afterwards with `--remove-scopes`.

## A new host

1. Bootstrap it ([Mac](../install-mac.md), [amarna](../install-amarna.md)).
   Add its `/etc/ssh/ssh_host_ed25519_key.pub` to `secrets/host-keys.nix` and
   the rules, and run `secrets-rekey` on a host with a YubiKey.
2. On NixOS, switch and log in again for the `tss` group.
3. With only the primary plugged in, run `ssh-enroll`; before its first switch,
   `nix run github:solforged/system#ssh-enroll`. Add its two lines; add the host
   to `user.sshLoginHosts` if it may log in to the others.
4. Pair the YubiKeys for login, on a Mac ([local login](local-auth.md)).

## A host is reinstalled or compromised

- Reinstalled with its host key restored: run `ssh-enroll` again if its home
  was wiped, and replace its lines.
- Compromised: delete its lines (not into `retiredSigningKeys`: its old
  signatures can't be trusted), delete its keys on GitHub, give it a new host
  key, and `secrets-rekey`. Its secrets were readable there, so change any that
  matter. Its FIDO2 handle is useless without the YubiKey.

## The primary YubiKey is lost or broken

The backup does everything meanwhile, with its PIN:

- SSH and GitHub: `cd ~/.ssh && ssh-keygen -K` on a host without the handle.
- Secrets: `secrets-edit` and `secrets-rekey` work with it.
- Login: the Mac accepts it, or use the password.

Then set up a replacement ([YubiKeys](yubikeys.md#setting-up-a-replacement))
and, with only it plugged in:

1. Replace the old admin recipient in `secrets/agenix-rules.nix` with the new
   one and run `secrets-rekey`.
2. On every host: delete `~/.ssh/id_ed25519_sk*`, run `ssh-enroll`, and replace
   the `user.authKeys` lines. Delete the old keys on GitHub.
3. On the Mac: `sudo sc_auth unpair -u admin -h <old hash>`, pair the new key,
   and check FileVault.

## The backup is lost

Set up a replacement ([YubiKeys](yubikeys.md#setting-up-a-replacement)) and,
with only it plugged in:

1. Replace its admin recipient in `secrets/agenix-rules.nix` and run
   `secrets-rekey` with the primary.
2. On hyperion, delete `~/.ssh/id_ed25519_sk_rk_backup*`, run
   `ssh-enroll --backup`, and replace `user.backupAuthKey`. Delete the old key
   on GitHub.
3. Unpair the old hash and pair the new one.

## Both YubiKeys are lost

- Secrets: set up new YubiKeys and put their admin recipients in place of the
  old ones. Type the paper key into a private temporary file, run
  `SECRETS_IDENTITY=<file> secrets-rekey`, and delete the file.
- GitHub: sign in on the web or with `gh` (the account's own 2FA is separate
  from these keys) and replace the SSH keys.
- Hosts: log in with passwords at the console; amarna has its LUKS passphrase.

## A signing key stops working

Most likely the enclave certificate expired (see [signing](signing.md)). Delete
the handle and identity, then enroll again:

```sh
rm ~/.ssh/id_ecdsa_sk_signing*
sc_auth delete-ctk-identity -h "$(sc_auth list-ctk-identities | awk '$4 == "git-signing" { print $2 }')"
ssh-enroll
```

Move the old `user.signingKeys` line to `user.retiredSigningKeys`. On NixOS, a
reset TPM needs the same: delete `~/.ssh/id_ecdsa_signing.*` and enroll again.

## PINs

- PIV PIN blocked after 3 tries: `ykman piv access unblock-pin` with the PUK.
  With the PUK blocked too, `ykman piv reset` wipes the applet; set it up again.
- FIDO2 PIN blocked after 8 tries: `ykman fido reset` wipes every FIDO2 key on
  it; enroll again as for a lost key.
