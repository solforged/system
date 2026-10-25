{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.media.streamrip;
  python = pkgs.python3.withPackages (p: [ p.tomlkit ]);
in
{
  options.modules.media.streamrip.enable = lib.mkEnableOption "Streamrip music downloads";
  config = lib.mkIf cfg.enable {
    hm = hm: {
      home.packages = [ pkgs.streamrip ];
      home.activation.streamripSettings = hm.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe python} ${../../../config/streamrip/merge.py} \
          ${pkgs.streamrip}/${pkgs.python3.sitePackages}/streamrip/config.toml \
          ${../../../config/streamrip/config.toml} \
          "${hm.config.home.homeDirectory}/${
            if pkgs.stdenv.hostPlatform.isDarwin then "Library/Application Support" else ".config"
          }/streamrip/config.toml"
      '';
    };
  };
}
