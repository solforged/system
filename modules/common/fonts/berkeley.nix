{
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.users.users.${config.user.name}.home;
in
{
  options.modules.fonts.berkeley.enable = lib.mkEnableOption "Berkeley Mono Variable";
  config = lib.mkIf config.modules.fonts.berkeley.enable {
    age.secrets.berkeley-mono = {
      file = ../../../secrets/berkeley-mono-variable.otf.age;
      owner = config.user.name;
      mode = "0444";
      symlink = false;
      path = "${home}/${
        if pkgs.stdenv.hostPlatform.isDarwin then "Library/Fonts" else ".local/share/fonts"
      }/Berkeley Mono Variable.otf";
    };
  };
}
