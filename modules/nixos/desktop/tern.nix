{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.desktop.tern;
in
{
  options.modules.desktop.tern.enable = lib.mkEnableOption "Tern desktop preferences";
  config = lib.mkIf cfg.enable {
    # Tern replaces its settings file on save, so keep a writable copy.
    hm = hm: {
      home.activation.ternSettings = hm.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                run ${lib.getExe pkgs.python3} - ${../../../config/tern/settings.json} "$HOME/.config/tern/settings.json" <<'PY'
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
