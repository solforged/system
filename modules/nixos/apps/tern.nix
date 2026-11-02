{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.apps.tern;
  # Keep the local download outside the flake source and Nix store.
  binary = "${config.modules.dotfiles.dir}/config/tern/local/tern";
  # Tern runs natively through nix-ld rather than an FHS sandbox: bubblewrap
  # sets no_new_privs, so sudo failed in every shell Tern started. These are
  # the libraries Tern loads at runtime.
  # nixpkgs has no WPE WebKit, the engine Tern prefers, so it uses WebKitGTK.
  libraries = with pkgs; [
    stdenv.cc.cc.lib
    libglvnd
    vulkan-loader
    wayland
    libxkbcommon
    libxcb
    pam
    libpulseaudio
    webkitgtk_4_1
  ];
  # Shells inherit NIX_LD_LIBRARY_PATH (nix-ld hides only LD_LIBRARY_PATH from
  # them), so keep the system nix-ld libraries for programs they start.
  libraryPath = lib.concatStringsSep ":" [
    (lib.makeLibraryPath libraries)
    "${pkgs.addDriverRunpath.driverLink}/lib"
    "/run/current-system/sw/share/nix-ld/lib"
  ];
  tern = pkgs.writeShellScriptBin "tern" ''
    export NIX_LD=${lib.escapeShellArg pkgs.stdenv.cc.bintools.dynamicLinker}
    export NIX_LD_LIBRARY_PATH=${lib.escapeShellArg libraryPath}
    exec ${lib.escapeShellArg binary} "$@"
  '';
  launcher = "${config.users.users.${config.user.name}.home}/.local/bin/tern";
  desktopEntry = {
    desktopName = "Tern";
    icon = "so.stencil.tern";
    terminal = false;
    extraConfig.StartupWMClass = "so.stencil.tern";
  };
  desktopEntries = {
    "so.stencil.tern" = {
      exec = "${launcher}";
      categories = [
        "System"
        "TerminalEmulator"
      ];
      extraConfig = desktopEntry.extraConfig // {
        X-TerminalArgExec = "-e";
      };
    };
    "so.stencil.tern.url" = {
      exec = "${launcher} --open-url %u";
      noDisplay = true;
      mimeTypes = [ "x-scheme-handler/tern" ];
    };
    "so.stencil.tern.open" = {
      exec = "${launcher} --open-file %f";
      noDisplay = true;
      mimeTypes = [
        "text/plain"
        "text/markdown"
        "text/x-source"
        "image/png"
        "image/jpeg"
        "image/gif"
        "image/webp"
        "image/svg+xml"
        "application/vnd.sqlite3"
        "application/x-sqlite3"
        "application/x-sqbpro"
        "application/x-ipynb+json"
        "inode/directory"
      ];
    };
  };
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.programs.nix-ld.enable;
        message = "modules.apps.tern runs the downloaded binary through nix-ld; enable programs.nix-ld.";
      }
    ];
    hm = hm: {
      home.packages = [ tern ];
      # Replace Tern's Downloads symlink, which otherwise shadows home.packages.
      home.file.".local/bin/tern" = {
        source = "${tern}/bin/tern";
        force = true;
      };
      # The wiki plugin starts omp panes, so it follows the omp module.
      xdg.configFile."tern/plugins/wiki" = lib.mkIf config.modules.agents.omp.enable {
        source = hm.config.lib.file.mkOutOfStoreSymlink config.modules.agents.omp.wiki.dir;
      };
      # Read-only entries prevent Tern from registering its unwrapped executable.
      xdg.dataFile = lib.mapAttrs' (
        name: entry:
        lib.nameValuePair "applications/${name}.desktop" {
          source = "${
            pkgs.makeDesktopItem (desktopEntry // entry // { inherit name; })
          }/share/applications/${name}.desktop";
          force = true;
        }
      ) desktopEntries;
      home.activation.ternAutostart = hm.lib.hm.dag.entryAfter [ "ternSettings" ] ''
                run ${lib.getExe pkgs.python3} - ${lib.escapeShellArg "${hm.config.xdg.configHome}/autostart/so.stencil.tern.login.desktop"} ${lib.escapeShellArg launcher} <<'PY'
        import pathlib, sys
        # Preserve Tern's login preference, but migrate its existing Exec path.
        autostart = pathlib.Path(sys.argv[1])
        if autostart.exists():
            lines = autostart.read_text().splitlines()
            autostart.write_text("\n".join(
                f'Exec="{sys.argv[2]}" daemon --login' if line.startswith("Exec=") else line
                for line in lines
            ) + "\n")
        PY
      '';
    };
  };
}
