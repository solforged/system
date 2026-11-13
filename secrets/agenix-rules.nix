# secrets/agenix-rules.nix
#
# Recipients for agenix. Hosts decrypt with their SSH host key at activation.
# The admin identities below are the only way to edit or rekey; see
# modules/common/secrets.nix. The flake does not import this file.
#
# A new host: read /etc/ssh/ssh_host_ed25519_key.pub (on macOS, create it first
# with `sudo ssh-keygen -A`), add it below, then run `secrets-rekey`.
let
  admins = [
    # Primary YubiKey 5C Nano, serial 35904923, PIV slot 82.
    "age1yubikey1qww822xc5uux2uxgmrqpxmnaemyum3xt5djknl5rt275326z0f2z6ascq4s"
    # Backup YubiKey: added at enrollment.
    # Paper key, offline: added at enrollment.
  ];

  amarna = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKZvfZCi4oa8t+rQZeQz/fhzC9JfadSFRcU5NVTcy2Mm";
  hyperion = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJwRPLR9b88m47AjZdWO1uEEvOIUz9cSwheSyHkCrKLO";
  atlas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKP1VxJ1WmNU+P8RVE0Rp9v+5IZJZkCPcOK/zHnd7uhk";

  everywhere = admins ++ [
    amarna
    hyperion
    atlas
  ];
  work = admins ++ [ atlas ];
in
{
  "berkeley-mono-variable.otf.age".publicKeys = everywhere;
  "gitleaks.toml.age".publicKeys = everywhere;
  "gitleaks-allowlist.toml.age".publicKeys = everywhere;
  "gitleaks-work-remote.age".publicKeys = everywhere;
  "git-work-identity.age".publicKeys = work;
}
