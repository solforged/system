# secrets/host-keys.nix
#
# Each host's /etc/ssh/ssh_host_ed25519_key.pub. agenix encrypts to them
# (agenix-rules.nix), and every host pins them in /etc/ssh/ssh_known_hosts
# (modules/common/shell/ssh.nix). Replace a host's line when its key changes,
# then run secrets-rekey.
{
  amarna = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKZvfZCi4oa8t+rQZeQz/fhzC9JfadSFRcU5NVTcy2Mm";
  hyperion = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJwRPLR9b88m47AjZdWO1uEEvOIUz9cSwheSyHkCrKLO";
  atlas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKP1VxJ1WmNU+P8RVE0Rp9v+5IZJZkCPcOK/zHnd7uhk";
  aster = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILgFKlyEEzTasdAm4hH6HSsp9oL9r9abCo53fQjp2Tqf";
}
