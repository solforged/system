{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.modules.apps.rex.enable {
    system.defaults.CustomUserPreferences."com.superlogical.rex" = {
      "Workspace.darkThemeID" = "custom-ECFA698F-859A-42C9-8E68-6CF77C160941";
      "Workspace.lightThemeID" = "custom-84E4B7A4-558E-4667-AD8D-DB75F55D41AA";
      "Workspace.inactivePaneFadeMode" = "both";
    };
    hm = hm: {
      # Rex stores JSON as plist data; CustomUserPreferences cannot express it.
      home.activation.rexThemes = hm.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe pkgs.python3} ${./rex-themes.py} ${../../../config/rex/solforge.json}
      '';
    };
  };
}
