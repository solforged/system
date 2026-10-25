# modules/nixos/default.nix
#
# Core settings for every NixOS host.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = config.user.name;
in
{
  users.users.${user} = {
    isNormalUser = true;
    home = "/home/${user}";
    extraGroups = [ "wheel" ];
    shell = lib.mkIf config.modules.shell.zsh.enable pkgs.zsh;
  };

  boot.loader = {
    systemd-boot.enable = lib.mkDefault true;
    systemd-boot.configurationLimit = lib.mkDefault 10;
    efi.canTouchEfiVariables = lib.mkDefault true;
  };

  nix = {
    settings.auto-optimise-store = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  # Project mise tools and npm/uv prebuilt binaries can require an FHS dynamic linker.
  programs.nix-ld.enable = true;

  hardware.enableRedistributableFirmware = true;
  services.journald.settings.Journal.SystemMaxUse = "2G";
  services.fwupd.enable = true;

  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  time.timeZone = lib.mkDefault "America/Los_Angeles";
  console.keyMap = lib.mkDefault "us";

  environment.systemPackages = with pkgs; [
    curl
    git
    vim
    wget
  ];
}
