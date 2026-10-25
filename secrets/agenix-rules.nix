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
  amarna = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILwkM1KLq8tcovQxQw6iqcSirQbZikwmYbQri9tpqUpF";

  everywhere = [
    admin
    amarna
  ];
  work = [ admin ];
in
{
  "berkeley-mono-variable.otf.age".publicKeys = everywhere;
  "gitleaks.toml.age".publicKeys = everywhere;
  "gitleaks-allowlist.toml.age".publicKeys = everywhere;
  "gitleaks-work-remote.age".publicKeys = everywhere;
  "git-work-identity.age".publicKeys = work;
}
