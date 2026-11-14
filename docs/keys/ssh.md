# SSH

## Keys

- **Per host, on the primary.** `ssh-enroll` gives each host its own FIDO2 key:
  `~/.ssh/id_ed25519_sk` is a handle, useless without the YubiKey, so copying it
  gains nothing. It registers the key on GitHub and prints the
  `user.authKeys` line for `modules/common/default.nix`.
- **Backup.** `ssh-enroll --backup` made one resident key on the backup, which
  needs its FIDO2 PIN and a touch (`user.backupAuthKey`; sshd enforces the PIN
  with `verify-required`). Any host fetches its handle with
  `cd ~/.ssh && ssh-keygen -K`; hyperion already has it.
- **Who logs in where.** Only hosts in `user.sshLoginHosts` (hyperion, amarna)
  and the backup may log in to the others. atlas's key reaches GitHub and
  nothing else, and the work Mac's tooling cannot copy a key off the YubiKey.

## Using them

- `config/ssh/config` offers this host's handle, then the backup's, to GitHub
  and the personal hosts, and reads `~/.ssh/config.local` first.
- A touch opens a connection that later ones to the same host reuse for 10
  minutes (`ControlPersist`). Anything running as you can reuse it meanwhile.
- Only Nix's ssh speaks FIDO2. Git's `core.sshCommand` points at it, since GUI
  apps find `/usr/bin/ssh` first, which cannot use the keys. For the same
  reason, Rex reaches amarna over Tailscale rather than `ssh://`.
- There is no SSH agent for these keys and no agent forwarding.

## Hosts

- amarna accepts SSH only on `tailscale0`. The Macs' Remote Login
  (`modules.services.ssh`, on hyperion and aster) accepts only tailnet addresses
  (`AllowUsers`) and requires `modules.services.tailscale`. All take keys only,
  and only those the flake declares; the Macs ignore `~/.ssh/authorized_keys`.
  hyperion's [application firewall](../network-security.md) is separate from
  this login restriction.
- To pair a client such as Tern, add its key to the host's
  `users.users.<name>.openssh.authorizedKeys`. Rex for iOS pairs over
  Tailscale and needs no SSH.
- Every host pins GitHub's and the personal hosts' keys in
  `/etc/ssh/ssh_known_hosts` (`modules/common/shell/ssh.nix`). Hyperion uses
  `hyperion.ostrich-rigel.ts.net`; Amarna uses
  `amarna.ussuri-alphard.ts.net` while its migration is pending.
- `agent-vm` is outside the flake: its `authorized_keys` needs the FIDO2 keys
  added by hand.
