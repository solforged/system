# YubiKeys

Two YubiKey 5C Nanos (firmware 5.7.4). The primary stays in hyperion; the
backup is stored away and comes out for enrolling and recovery.

| Applet             | Primary, serial 35904923                         | Backup, serial 27235456                                 |
| ------------------ | ------------------------------------------------ | ------------------------------------------------------- |
| FIDO2              | One non-resident SSH key per host; uses no slots | Resident `ssh:backup` key, `verify-required`            |
| PIV 9a, 9d         | ECC P-256, `CN=sol primary`: Mac login, FileVault | ECC P-256, `CN=sol backup`: Mac login                   |
| PIV 82 (age slot 1) | agenix admin; PIN once, touch always             | agenix admin; PIN once, touch always                    |
| PIV 83 (age slot 2) | Unused; no PIN policy                            | Empty                                                   |
| OpenPGP            | Unused keys from an abandoned signing setup      | Not used                                                |

- **Three PINs.** The FIDO2 PIN (8 tries) guards resident keys and the backup's
  SSH key. The PIV PIN (3 tries, then the PUK) guards login, FileVault and the
  admin identities. OpenPGP has its own, unused here.
- **Management key.** TDES, stored on the key and unlocked by the PIV PIN, on
  both. age-plugin-yubikey 0.5.1 cannot use a PIN-protected AES key
  ([str4d/age-plugin-yubikey#92](https://github.com/str4d/age-plugin-yubikey/issues/92)),
  so set a new key's with
  `ykman piv access change-management-key -a TDES --generate --protect`.
- **One at a time.** Tools that create a key use whichever YubiKey they find, so
  plug in only the one meant.
- **Run ykman commands one after another.** Two at once (for example through
  `<(...)`) fail to open the device.

## Clearing the unused applets on the primary

```sh
ykman piv keys delete 83 && ykman piv certificates delete 83
ykman openpgp reset   # wipes all OpenPGP keys and PINs
```

## Setting up a replacement

With only the new key plugged in:

1. `ykman fido access change-pin`, then `ykman piv access change-pin` and
   `change-puk`, then the management key above.
2. The admin identity:
   `age-plugin-yubikey --generate --slot 1 --name <name> --pin-policy once --touch-policy always`.
3. The login identity:

   ```sh
   for s in 9a 9d; do
     ykman piv keys generate --algorithm ECCP256 --pin-policy ONCE --touch-policy NEVER $s /tmp/$s.pub
     ykman piv certificates generate --subject "CN=sol <name>" $s /tmp/$s.pub
   done; rm -f /tmp/9a.pub /tmp/9d.pub
   ```

Then follow [recovery](recovery.md) for what to register where.
