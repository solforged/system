# secrets/agenix-rules.nix
#
# Recipients for agenix. Hosts decrypt with their SSH host key at activation.
# The admin identities below are the only way to edit or rekey; see
# modules/common/secrets.nix. The flake does not import this file.
#
# A new host: read /etc/ssh/ssh_host_ed25519_key.pub (on macOS, create it first
# with `sudo ssh-keygen -A`), add it to host-keys.nix and below, then run
# `secrets-rekey`.
let
  hosts = import ./host-keys.nix;

  admins = [
    # Primary YubiKey 5C Nano, serial 35904923, PIV slot 82.
    "age1yubikey1qww822xc5uux2uxgmrqpxmnaemyum3xt5djknl5rt275326z0f2z6ascq4s"
    # Backup YubiKey 5C Nano, serial 27235456, PIV slot 82.
    "age1yubikey1qwhj4d6n9j528z6d3ujy79dd0qxf4fuzeflr7593ngt254uy9t08y43zxx7"
    # Paper key, kept offline.
    "age1ccseaks2lau78jayhnallessfhwhmlehcx6qy4j46ma82r2mxv2sv7yule"
  ];

  everywhere = admins ++ [
    hosts.amarna
    hosts.hyperion
    hosts.atlas
  ];
  work = admins ++ [ hosts.atlas ];
in
{
  "berkeley-mono-variable.otf.age".publicKeys = everywhere;
  "gitleaks.toml.age".publicKeys = everywhere;
  "gitleaks-allowlist.toml.age".publicKeys = everywhere;
  "gitleaks-work-remote.age".publicKeys = everywhere;
  "git-work-identity.age".publicKeys = work;
}
