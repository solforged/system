# Hermes sandbox (amarna)

Off for now, along with Hermes itself; amarna sets both options to false.

`modules.agents.hermes.sandbox.enable` prepares a rootless Podman sandbox for
Hermes' Docker terminal backend, so terminal, file and code tools never touch
the rest of the home directory. Hermes creates and reuses the container itself
from its default `nousresearch/hermes-sandbox:desktop` image; Hermes still owns
`~/.hermes/config.yaml`, where `terminal:` sets `backend: docker`, CPU and
memory limits, and these mounts:

| Host                                       | Container                             | Purpose                             |
| ------------------------------------------ | ------------------------------------- | ----------------------------------- |
| `~/src`                                    | `/home/sol/src`                       | Projects, read-write, at host paths |
| `~/src/system`                             | same path, read-only                  | This repo becomes root on rebuild   |
| `~/.local/share/wiki`                      | same path (`$LLM_WIKI_DIR`)           | The wiki                            |
| `~/.local/share/hermes-sandbox/nix`        | `/nix`                                | The sandbox's own Nix store         |
| `~/.local/share/hermes-sandbox/profile.sh` | `/etc/profile.d/zz-hermes-sandbox.sh` | `PATH`, Nix and git settings        |
| `$XDG_RUNTIME_DIR/hermes-ssh-agent`        | `/mnt/hermes-ssh-agent`               | Signing agent                       |

The `hermes-sandbox-store` user service seeds that store with Nix and mise from
the host. The container never sees the host's nix-daemon socket: the user is a
trusted Nix user, so the socket would give the agent root. `hermes-ssh-agent`
runs a second `ssh-tpm-agent` that serves only the key in
`~/.local/state/hermes-signing`, which signs the sandbox's git commits. The
sandbox has no push or login credentials.

## Signing

The key is sealed to amarna's TPM, so neither the sandbox nor anything else can
copy it off the machine. Make it once (press Enter twice, for no passphrase):

```sh
mkdir -p -m 700 ~/.local/state/hermes-signing
ssh-tpm-keygen -C hermes-amarna -f ~/.local/state/hermes-signing/id_ecdsa
```

Add `~/.local/state/hermes-signing/id_ecdsa.pub` as `hermes-amarna` in
`user.agentSigningKeys` (`modules/common/default.nix`) and switch; until then
the sandbox commits unsigned and `hermes-ssh-agent` does not exist.

Anything the sandbox can write, the host later runs: Git hooks and
`core.fsmonitor` in `.git/config`, `mise.toml` tasks, build scripts. Review what
Hermes changed before running a project on the host. Changing the mounts or
image makes Hermes start a fresh container and leave the old one running; remove
it with `podman rm -f` (Hermes labels its containers `hermes-agent=1`). Tool
updates need no new container: the store service switches the profile in place.
