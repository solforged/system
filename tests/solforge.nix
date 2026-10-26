# Both desktop variants must evaluate, retain existing extensions, and produce
# CSS accepted by the pinned GTK and GNOME Shell versions (no display needed).
{ configuration }:
let
  inherit (configuration) pkgs;
  inherit (pkgs) lib;
  user = configuration.config.user.name;
  homeFor =
    variant:
    (configuration.extendModules {
      modules = [ { modules.desktop.solforge.variant = variant; } ];
    }).config.home-manager.users.${user};
  migrationHome =
    (configuration.extendModules {
      modules = [
        {
          modules.dotfiles.dir = lib.mkForce "/build/solforge-repo";
          hm.home.homeDirectory = lib.mkForce "/build/solforge-home";
        }
      ];
    }).config.home-manager.users.${user};
  checkMigration =
    name: entry:
    let
      script = pkgs.writeText "migrate-${name}.sh" migrationHome.home.activation.${entry}.data;
    in
    ''
      repo=/build/solforge-repo/config/${name}
      target=/build/solforge-home/.config/${name}
      old=/build/old-home-files/.config/${name}
      mkdir -p "$repo" "$(dirname "$target")" "$(dirname "$old")" /build/unrelated
      echo preserve-me > "$repo/settings"
      ln -s "$repo" "$old"
      ln -s "$old" "$target"
      # The two-hop managed link goes; its source must remain untouched.
      source ${script}
      test ! -L "$target"
      grep -q preserve-me "$repo/settings"
      mkdir "$target"
      source ${script}
      test -d "$target" && test ! -L "$target"
      rmdir "$target"
      ln -s /build/unrelated "$target"
      source ${script}
      test -L "$target"
      rm "$target"
      # Missing checkouts must not cause two failed readlinks to compare equal.
      mv "$repo" "$repo.saved"
      ln -s /build/nonexistent "$target"
      source ${script}
      test -L "$target"
      rm "$target"
    '';
  variants = [
    "dark"
    "light"
  ];
  validateCss = pkgs.writeText "validate-gtk-css.js" ''
    imports.gi.versions.Gtk = ARGV[0] + '.0';
    const Gtk = imports.gi.Gtk;
    const provider = new Gtk.CssProvider();
    const errors = [];
    provider.connect('parsing-error', (_, section, error) => {
      errors.push(error.message);
    });
    provider.load_from_path(ARGV[1]);
    if (errors.length)
      throw new Error(errors.join('\n'));
    print('GTK ' + ARGV[0] + ': ' + ARGV[1]);
  '';
  validateShell = pkgs.writeText "validate-shell-css.js" ''
    const {St, Gio} = imports.gi;
    Gio.resources_register(Gio.Resource.load(ARGV[0]));
    const theme = new St.Theme();
    theme.load_stylesheet(Gio.File.new_for_path(ARGV[1]));
    print('Shell: ' + ARGV[1]);
  '';
  checkVariant =
    variant:
    let
      home = homeFor variant;
      settings = home.dconf.settings;
      wallpaperKey = if variant == "dark" then "picture-uri-dark" else "picture-uri";
      enabledExtensions = map (value: value.value) settings."org/gnome/shell".enabled-extensions.value;
    in
    assert settings."org/gnome/desktop/interface".color-scheme == "prefer-${variant}";
    assert settings."org/gnome/shell/extensions/user-theme".name == "Solforge-${variant}";
    assert home.gtk.gtk4.theme == null;
    assert lib.all (extension: lib.elem extension.extensionUuid enabledExtensions) (
      with pkgs.gnomeExtensions;
      [
        dash-to-panel
        arcmenu
        gsconnect
        user-themes
      ]
    );
    ''
      gjs ${validateCss} 3 ${home.xdg.configFile."gtk-3.0/gtk.css".source}
      gjs ${validateCss} 4 ${home.xdg.configFile."gtk-4.0/gtk.css".source}
      shellCss=${home.xdg.dataFile."themes/Solforge-${variant}/gnome-shell/gnome-shell.css".source}
      # A missing palette token must not silently ship as invalid Shell CSS.
      ! grep -E '@[a-z_]+@' "$shellCss"
      gjs ${validateShell} \
        ${pkgs.gnome-shell}/share/gnome-shell/gnome-shell-theme.gresource "$shellCss"
      test -s ${lib.removePrefix "file://" settings."org/gnome/desktop/background".${wallpaperKey}}
      test -s ${home.xdg.configFile."ghostty/themes/solforge-${variant}".source}
      test -s ${home.xdg.configFile."helix/themes/solforge-${variant}.toml".source}
    '';
in
pkgs.runCommand "solforge-themes-check"
  {
    nativeBuildInputs = with pkgs; [
      gjs
      gobject-introspection
      gtk3
      gtk4
      glib
    ];
  }
  ''
    export G_DEBUG=fatal-warnings
    export GI_TYPELIB_PATH=${pkgs.gnome-shell}/lib/gnome-shell:$GI_TYPELIB_PATH
    export LD_LIBRARY_PATH=${pkgs.gnome-shell}/lib/gnome-shell
    for dir in ${pkgs.mutter}/lib/mutter-*; do
      export GI_TYPELIB_PATH="$dir:$GI_TYPELIB_PATH"
      export LD_LIBRARY_PATH="$dir:$LD_LIBRARY_PATH"
    done
    ${lib.concatMapStringsSep "\n" checkVariant variants}
    run() { "$@"; }
    ${checkMigration "ghostty" "migrateGhosttyDirectory"}
    ${checkMigration "helix" "migrateHelixDirectory"}
    touch "$out"
  ''
