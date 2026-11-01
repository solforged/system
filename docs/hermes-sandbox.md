# Hermes sandbox (amarna)

`modules.agents.hermes.sandbox.enable` prepares a rootless Podman sandbox for
Hermes' Docker terminal backend, so terminal, file and code tools never touch the
rest of the home directory. Hermes creates and reuses the container itself from
its default `nousresearch/hermes-sandbox:desktop` image; Hermes still owns
`~/.hermes/config.yaml`, where `terminal:` sets `backend: docker`, CPU and
memory limits, and these mounts:

| Host                                       | Container                             | Purpose                             |
| ------------------------------------------ | ------------------------------------- | ----------------------------------- |
| `~/src`                                    | `/home/sol/src`                       | Projects, read-write, at host paths |
| `~/src/system`                             | same path, read-only                  | This repo becomes root on rebuild   |
| `~/wiki`                                   | `/home/sol/wiki`                      | The wiki                            |
| `~/.local/share/hermes-sandbox/nix`        | `/nix`                                | The sandbox's own Nix store         |
| `~/.local/share/hermes-sandbox/profile.sh` | `/etc/profile.d/zz-hermes-sandbox.sh` | `PATH`, Nix and git settings        |
| `$XDG_RUNTIME_DIR/hermes-ssh-agent`        | `/mnt/hermes-ssh-agent`               | Signing agent                       |

The `hermes-sandbox-store` user service seeds that store with Nix and mise from
the host. The container never sees the host's nix-daemon socket: the user is a
trusted Nix user, so the socket would give the agent root. `hermes-ssh-agent`
runs a second `pass-cli ssh-agent` limited to the Proton Pass `Hermes` vault,
whose only key signs the sandbox's git commits. The sandbox has no push or
login credentials.

Anything the sandbox can write, the host later runs: Git hooks and
`core.fsmonitor` in `.git/config`, `mise.toml` tasks, build scripts. Review
what Hermes changed before running a project on the host. Changing the mounts
or image makes Hermes start a fresh container and leave the old one running;
remove it with `podman rm -f` (Hermes labels its containers `hermes-agent=1`).
Tool updates need no new container: the store service switches the profile in
place.
