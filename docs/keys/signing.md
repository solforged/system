# Commit signing

Each host signs Git and jj commits with its own key, which can't be copied off
it and signs without a prompt. Anything running as you can sign, but a signing
key opens no logins and no GitHub access. `ssh-enroll` makes it, registers it on
GitHub as a signing key, and prints its `user.signingKeys` line.

| Host type | Key                                                              | Signs through                                   |
| --------- | ---------------------------------------------------------------- | ----------------------------------------------- |
| Mac       | Secure Enclave identity `git-signing`; `~/.ssh/id_ecdsa_sk_signing` is its handle | Apple's `/usr/lib/ssh-keychain.dylib`           |
| NixOS     | `~/.ssh/id_ecdsa_signing.tpm`, sealed to the TPM                 | `ssh-tpm-agent` (needs the `tss` group)         |

- Git and jj sign through one wrapper (`signingProgram` in
  `modules/common/shell/vcs/_common.nix`), and pick the key from the type of
  the host's `user.signingKeys` line. A host whose line is still a plain
  `ssh-ed25519` key signs with `~/.ssh/id_ed25519` until its new line lands.
- `user.retiredSigningKeys` keeps replaced keys in the allowed signers, so old
  commits still verify. They authorize nothing. GitHub keeps commits it already
  verified marked verified after their key is deleted there.
- `user.agentSigningKeys` lists keys sandboxed agents sign with; Git trusts them
  only for its own signature namespace. Hermes' key is sealed to amarna's TPM
  and served by the sandbox's own agent ([Hermes sandbox](../hermes-sandbox.md#signing)).
- **The enclave identities' certificates expire a year after creation**
  (hyperion and atlas: 13 November 2027). OpenSSH ignores the date, so signing
  should continue. If it stops, see [recovery](recovery.md#a-signing-key-stops-working).
