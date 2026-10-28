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
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        user
      ];
      warn-dirty = false;
      auto-optimise-store = true;
    };
  };

  # Replaces nix.gc: also clears stale gcroots, and always keeps the last 5
  # generations however old they are.
  programs.nh.clean = {
    enable = true;
    dates = "weekly";
    extraArgs = "--keep-since 14d --keep 5";
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
