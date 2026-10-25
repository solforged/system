{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.apps.workstation-tools;
in
{
  options.modules.apps.workstation-tools.enable =
    lib.mkEnableOption "Workstation build and administration tools";
  config = lib.mkIf cfg.enable {
    hm.home.packages = with pkgs; [
      clang
      llvm
      dotnetCorePackages.runtime_9_0
      cmake
      ninja
      lazydocker
      sshpass
      trash-cli
      xmlstarlet
      libqalculate
      powerstat
      (python3Packages.toPythonApplication python3Packages.trafilatura)
    ];
  };
}
