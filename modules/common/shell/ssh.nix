{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.modules.shell.ssh.enable = lib.mkEnableOption "SSH client configuration";
  config = lib.mkIf config.modules.shell.ssh.enable {
    hm.home.packages = [ pkgs.openssh ];
    modules.dotfiles.homeLink.".ssh/config" = "ssh/config";
  };
}
