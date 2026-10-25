{ config, lib, ... }:
let
  cfg = config.modules.hardware.apfs;
in
{
  options.modules.hardware.apfs.enable =
    lib.mkEnableOption "APFS filesystem tools and kernel support";
  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = [ "apfs" ];
  };
}
