# The desktop must follow GNOME's Style setting: Home Manager may not write the
# mode, both palettes must reach GTK 3 and GTK 4, the follower must switch the
# per-mode dconf keys, and all CSS must load in the pinned GTK and Shell.
{ configuration }:
let
  inherit (configuration) pkgs;
  inherit (pkgs) lib;
  inherit (configuration._module.specialArgs) inputs;
  user = configuration.config.user.name;
  home = configuration.config.home-manager.users.${user};
  paletteFor =
    variant:
    builtins.fromTOML (
      builtins.readFile "${inputs.solforge-theme}/omarchy-solforge-${variant}-theme/colors.toml"
    );
  follow = lib.head (lib.toList home.systemd.user.services.solforge-appearance.Service.ExecStart);
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
  # Loads CSS into the pinned GTK, fails on any parse error, and checks the
  # resolved window background (optionally for a LIGHT or DARK color scheme).
  checkCss = pkgs.writeText "check-gtk-css.js" ''
    // check-gtk-css.js VERSION CSS EXPECTED [LIGHT|DARK]
    imports.gi.versions.Gtk = ARGV[0] + '.0';
    const {Gtk, Gdk} = imports.gi;
    if (ARGV[0] === '3') Gtk.init(null); else Gtk.init();
    const provider = new Gtk.CssProvider();
    const errors = [];
    provider.connect('parsing-error', (_, section, error) => {
      errors.push(error.message);
    });
    if (ARGV[3])
      provider.prefers_color_scheme = Gtk.InterfaceColorScheme[ARGV[3]];
    provider.load_from_path(ARGV[1]);
    if (errors.length)
      throw new Error(errors.join('\n'));
    const context = ARGV[0] === '3' ? new Gtk.StyleContext() : new Gtk.Label().get_style_context();
    context.add_provider(provider, 800);
    const [found, color] = context.lookup_color('window_bg_color');
    const expected = new Gdk.RGBA();
    expected.parse(ARGV[2]);
    if (!found || !color.equal(expected))
      throw new Error(`''${ARGV[1]} ''${ARGV[3] ?? ""}: window_bg_color is ''${found ? color.to_string() : "unset"}, expected ''${ARGV[2]}`);
    print(`GTK ''${ARGV[0]} ''${ARGV[3] ?? ""}: ''${ARGV[1]}`);
  '';
  validateShell = pkgs.writeText "validate-shell-css.js" ''
    const {St, Gio} = imports.gi;
    Gio.resources_register(Gio.Resource.load(ARGV[0]));
    const theme = new St.Theme();
    theme.load_stylesheet(Gio.File.new_for_path(ARGV[1]));
    print('Shell: ' + ARGV[1]);
  '';
  settings = home.dconf.settings;
  gtk4Css = home.xdg.configFile."gtk-4.0/gtk.css".source;
  checkVariant =
    variant:
    let
      theme = "themes/Solforge-${variant}";
      background = (paletteFor variant).background;
      wallpaperKey = if variant == "dark" then "picture-uri-dark" else "picture-uri";
    in
    ''
      gjs ${checkCss} 3 ${home.xdg.dataFile."${theme}/gtk-3.0/gtk.css".source} '${background}'
      gjs ${checkCss} 4 ${gtk4Css} '${background}' ${lib.toUpper variant}
      shellCss=${home.xdg.dataFile."${theme}/gnome-shell/gnome-shell.css".source}
      # A missing palette token must not silently ship as invalid Shell CSS.
      ! grep -E '@[a-z_]+@' "$shellCss"
      gjs ${validateShell} \
        ${pkgs.gnome-shell}/share/gnome-shell/gnome-shell-theme.gresource "$shellCss"
      test -s ${lib.removePrefix "file://" settings."org/gnome/desktop/background".${wallpaperKey}}
      test -s ${home.xdg.configFile."ghostty/themes/solforge-${variant}".source}
      test -s ${home.xdg.configFile."helix/themes/solforge-${variant}.toml".source}
    '';
  # Waits for the follower to apply MODE's theme after a Style change.
  expectMode = mode: ''
    for _ in $(seq 100); do
      [ "$(dconf read /org/gnome/desktop/interface/gtk-theme)" = "'Solforge-${mode}'" ] && break
      sleep 0.1
    done
    test "$(dconf read /org/gnome/desktop/interface/gtk-theme)" = "'Solforge-${mode}'"
    test "$(dconf read /org/gnome/shell/extensions/user-theme/name)" = "'Solforge-${mode}'"
    test "$(dconf read /org/gnome/shell/extensions/arcmenu/menu-background-color)" \
      = "'${(paletteFor mode).background}'"
  '';
  followerCheck = pkgs.writeShellScript "check-follower" ''
    set -eu
    ${follow} &
    follower=$!
    ${expectMode "light"}
    dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
    ${expectMode "dark"}
    dconf write /org/gnome/desktop/interface/color-scheme "'default'"
    ${expectMode "light"}
    kill "$follower"
  '';
  interface = settings."org/gnome/desktop/interface";
  enabledExtensions = map (value: value.value) settings."org/gnome/shell".enabled-extensions.value;
in
# Writing any of these on activation would undo the user's Style choice.
assert !(interface ? color-scheme) && !(interface ? gtk-theme);
assert !(settings ? "org/gnome/shell/extensions/user-theme");
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
pkgs.runCommand "solforge-themes-check"
  {
    nativeBuildInputs = with pkgs; [
      dbus
      dconf
      gjs
      gobject-introspection
      gtk3
      gtk4
      glib
      xvfb-run
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
    export HOME=$TMPDIR XDG_CONFIG_HOME=$TMPDIR/config XDG_RUNTIME_DIR=$TMPDIR/run
    export XDG_DATA_DIRS=${pkgs.dconf}/share
    # No accessibility bus here; its warnings would be fatal.
    export NO_AT_BRIDGE=1 GTK_A11Y=none
    mkdir -p "$XDG_RUNTIME_DIR"
    cat > checks.sh <<'EOF'
    set -eu
    ${lib.concatMapStringsSep "\n" checkVariant variants}
    ${followerCheck}
    EOF
    # GTK needs a display and, to stay quiet, a session bus; dconf needs the bus.
    dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- \
      xvfb-run sh checks.sh
    run() { "$@"; }
    ${checkMigration "ghostty" "migrateGhosttyDirectory"}
    ${checkMigration "helix" "migrateHelixDirectory"}
    touch "$out"
  ''
