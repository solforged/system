# Validate the generated themes with Herdr's own parser, check their palette
# and contrast, and exercise the writable-settings merge without a real home.
{ configuration }:
let
  inherit (configuration) pkgs;
  inherit (pkgs) lib;
  inherit (configuration._module.specialArgs) inputs;
  user = configuration.config.user.name;
  home = configuration.config.home-manager.users.${user};
  variants = [
    "dark"
    "light"
  ];
  sources = lib.genAttrs variants (
    variant: home.xdg.configFile."herdr-app/themes/solforge-${variant}.json".source
  );
  expected = lib.genAttrs variants (
    variant: builtins.fromJSON home.xdg.configFile."herdr-app/themes/solforge-${variant}.json".text
  );
  # The CLI's checker imports the same themes() API used by Settings and mods.
  nativeCheck = pkgs.writeTextDir "main.js" ''
    import { View, div } from "gpui-kit";
    import { themes } from "herdr";
    const expected = ${builtins.toJSON expected};
    export default class CheckThemes extends View {
      render() {
        const available = themes();
        for (const [variant, wanted] of Object.entries(expected)) {
          const actual = available.find(t => t.name === `solforge-''${variant}`);
          if (!actual || actual.light !== (variant === "light"))
            throw new Error(`missing or misclassified Solforge ''${variant}`);
          const colors = { ...wanted.colors, background: wanted.background,
            terminal_foreground: wanted.foreground, selection: wanted.selection,
            cursor: wanted.cursor };
          wanted.ansi.forEach((color, i) => colors[`ansi''${i}`] = color);
          for (const [key, value] of Object.entries(colors))
            if (actual.colors[key] !== value)
              throw new Error(`''${variant}.''${key}: ''${actual.colors[key]} != ''${value}`);
        }
        return div().child("Solforge themes parsed by Herdr");
      }
    }
  '';
  activationHome =
    (configuration.extendModules {
      modules = [ { hm.home.homeDirectory = lib.mkForce "/build/herdr-home"; } ];
    }).config.home-manager.users.${user};
  activate = pkgs.writeShellScript "activate-herdr-settings" ''
    set -eu
    run() { "$@"; }
    ${activationHome.home.activation.herdrSettings.data}
  '';
in
pkgs.runCommand "herdr-themes-check"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.herdr-desktop
    ];
  }
  ''
    export HOME=$TMPDIR HERDR_APP_HOME=$TMPDIR/herdr-app
    export HERDR_TELEMETRY=0
    mkdir -p "$HERDR_APP_HOME/themes"
    ${lib.concatMapStringsSep "\n" (variant: ''
      cp ${sources.${variant}} "$HERDR_APP_HOME/themes/solforge-${variant}.json"
    '') variants}
    python3 - "$HERDR_APP_HOME" ${inputs.solforge-theme} ${activate} <<'PY'
    import json, pathlib, re, stat, subprocess, sys, tomllib
    app, upstream = map(pathlib.Path, sys.argv[1:3])
    activate = sys.argv[3]

    def luminance(color):
        rgb = [int(color[i:i+2], 16) / 255 for i in (1, 3, 5)]
        linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in rgb]
        return sum(v * w for v, w in zip(linear, (0.2126, 0.7152, 0.0722)))

    def contrast(a, b):
        low, high = sorted(map(luminance, (a, b)))
        return (high + 0.05) / (low + 0.05)

    for variant in ("dark", "light"):
        theme = json.loads((app / f"themes/solforge-{variant}.json").read_text())
        palette = tomllib.loads((upstream / f"omarchy-solforge-{variant}-theme/colors.toml").read_text())
        ghostty = (upstream / f"ghostty/solforge-{variant}").read_text()
        ansi = dict(re.findall(r"^palette = (\d+)=(#[0-9a-f]{6})$", ghostty, re.M))
        assert set(theme) == {"background", "foreground", "selection", "cursor", "ansi", "colors"}
        assert theme["ansi"] == [ansi[str(i)] for i in range(16)]
        for key in ("background", "foreground", "selection"):
            assert theme[key] == palette[key]
        assert theme["cursor"] == palette["accent"]
        colors = theme["colors"]
        assert colors["accent"] == palette["accent"]
        assert colors["working"] == palette["yellow"]
        assert colors["blocked"] == palette["red"]
        assert colors["done"] == palette["green"]
        for color in [theme[k] for k in ("background", "foreground", "selection", "cursor")] + theme["ansi"] + list(colors.values()):
            assert re.fullmatch(r"#[0-9a-f]{6}", color), color
        for fg, bg, minimum in (
            (theme["foreground"], theme["background"], 4.5),
            (colors["foreground"], colors["selected"], 4.5),
            (colors["muted"], colors["chrome"], 4.5),
            (colors["dim"], colors["chrome"], 3),
            (colors["accent"], theme["background"], 4.5),
            (colors["solid_foreground"], colors["solid"], 4.5),
        ):
            assert contrast(fg, bg) >= minimum, (variant, fg, bg, minimum)

    target = pathlib.Path("/build/herdr-home/.config/herdr-app/settings.json")
    def run_activation():
        subprocess.run([activate], check=True)
    def read():
        return json.loads(target.read_text())
    pair = {"light": "solforge-light", "dark": "solforge-dark"}
    run_activation()
    assert read() == {"theme": pair}
    assert stat.S_IMODE(target.stat().st_mode) == 0o600
    preferences = {"font": "Berkeley Mono Variable", "ui_font": "IBM Plex Sans",
                   "font_size": 12, "zoom": 1.2, "telemetry": False,
                   "appearance": "light", "sounds": {"enabled": False}}
    target.write_text(json.dumps({**preferences, "theme": "graphite"}))
    run_activation()
    assert read() == {**preferences, "theme": pair}
    before = target.stat().st_mtime_ns
    run_activation()
    assert target.stat().st_mtime_ns == before, "unchanged settings should not be rewritten"
    original = target.with_name("old-settings.json")
    target.rename(original)
    target.symlink_to(original)
    old = original.read_text()
    run_activation()
    assert not target.is_symlink() and original.read_text() == old
    assert read() == {**preferences, "theme": pair}
    target.write_text("{invalid")
    assert subprocess.run([activate], capture_output=True).returncode != 0
    assert target.read_text() == "{invalid", "invalid settings must not be discarded"
    assert not list(target.parent.glob(".settings-*"))
    PY
    herdr-app check ${nativeCheck}
    touch "$out"
  ''
