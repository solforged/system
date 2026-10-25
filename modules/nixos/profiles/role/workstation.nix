# modules/nixos/profiles/role/workstation.nix
{ config, lib, ... }:

{
  config = lib.mkIf (config.modules.profiles.role == "workstation") {
    networking.networkmanager.enable = true;
    users.users.${config.user.name}.extraGroups = [ "networkmanager" ];
    services.printing.enable = true;
  };
}
