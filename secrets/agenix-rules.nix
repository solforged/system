# secrets/agenix-rules.nix
#
# Recipients for agenix. Hosts decrypt with their SSH host key at activation.
# The admin key lives in Proton Pass and is the only way to edit or rekey;
# `secrets-edit` and `secrets-rekey` fetch it through fnox. The flake does not
# import this file.
#
# A new host: read /etc/ssh/ssh_host_ed25519_key.pub (on macOS, create it first
# with `sudo ssh-keygen -A`), add it below, then run `secrets-rekey`.
let
  admin = "age1csrnt75trax79llf7njd6kvsvxj2r4acszgs9dxegw7uc5wt5etqyqc3m2";
  amarna = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKZvfZCi4oa8t+rQZeQz/fhzC9JfadSFRcU5NVTcy2Mm";
  hyperion = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJwRPLR9b88m47AjZdWO1uEEvOIUz9cSwheSyHkCrKLO";
  atlas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKP1VxJ1WmNU+P8RVE0Rp9v+5IZJZkCPcOK/zHnd7uhk";

  everywhere = [
    admin
    amarna
    hyperion
    atlas
  ];
  work = [
    admin
    atlas
  ];
in
{
  "berkeley-mono-variable.otf.age".publicKeys = everywhere;
  "gitleaks.toml.age".publicKeys = everywhere;
  "gitleaks-allowlist.toml.age".publicKeys = everywhere;
  "gitleaks-work-remote.age".publicKeys = everywhere;
  "git-work-identity.age".publicKeys = work;
}
