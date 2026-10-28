# modules/common/apps/tern.nix
#
# Tern is installed by hand on every host. Its omp folder isn't a setting: it
# follows PI_CONFIG_DIR from modules/common/agents/omp.nix.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.apps.tern;
in
{
  options.modules.apps.tern.enable = lib.mkEnableOption "Tern settings";
  config = lib.mkIf cfg.enable {
    # Tern replaces its settings file on save, so merge our keys into a
    # writable copy; keys set only in the app survive.
    hm = hm: {
      home.activation.ternSettings =
        let
          target =
            if pkgs.stdenv.hostPlatform.isDarwin then
              "${hm.config.home.homeDirectory}/Library/Application Support/Tern/settings.json"
            else
              "${hm.config.xdg.configHome}/tern/settings.json";
        in
        hm.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                    run ${lib.getExe pkgs.python3} - ${../../../config/tern/settings.json} ${lib.escapeShellArg target} <<'PY'
          import json, os, pathlib, sys
          source, target = map(pathlib.Path, sys.argv[1:])
          settings = json.loads(target.read_text()) if target.exists() else {}
          settings.update(json.loads(source.read_text()))
          target.parent.mkdir(parents=True, exist_ok=True)
          if target.is_symlink():
              target.unlink()
          target.write_text(json.dumps(settings, indent=2) + "\n")
          os.chmod(target, 0o600)
          PY
        '';
    };
  };
}
