# modules/common/shell/nushell.nix
#
# nu is the shell terminals open. zsh stays the login shell so anything that
# runs $SHELL still gets a POSIX shell. Home Manager loads the Nix environment
# for direct nu launches too. Tool init code is generated in the store and
# loaded from ~/.local/share/nushell/vendor/autoload.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.shell.nushell;
  shell = config.modules.shell;
  # Where carapace looks without XDG_CONFIG_HOME (Go's os.UserConfigDir).
  carapaceConfigFallback =
    if pkgs.stdenv.hostPlatform.isDarwin then "Library/Application Support" else ".config";
  # Home Manager's direnv hook for Nushell, which it would otherwise write
  # into config.nu (a live link here). PATH arrives as a string and is split
  # back into a list.
  direnvHook = pkgs.writeText "direnv.nu" ''
    $env.config.hooks = ($env.config.hooks? | default {})
    $env.config.hooks.pre_prompt = (
      $env.config.hooks.pre_prompt? | default [] | append {||
        let direnv = (${lib.getExe pkgs.direnv} export json | from json --strict | default {})
        for key in ($direnv | columns) {
          if ($direnv | get $key) == null { hide-env --ignore-errors $key }
        }
        $direnv
        | items {|key, value|
          let value = do (
            {
              "PATH": {
                from_string: {|s| $s | split row (char esep) | path expand --no-symlink }
                to_string: {|v| $v | path expand --no-symlink | str join (char esep) }
              }
            }
            | merge ($env.ENV_CONVERSIONS? | default {})
            | get ([[value, optional, insensitive]; [$key, true, true] [from_string, true, false]] | into cell-path)
            | if ($in | is-empty) { {|x| $x} } else { $in }
          ) $value
          return [ $key $value ]
        }
        | where {|pair| $pair.1 != null }
        | into record
        | load-env
      }
    )
  '';
  autoload = pkgs.runCommand "nushell-autoload" { } ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME" "$out"
    ${lib.optionalString shell.atuin.enable ''
      ${pkgs.atuin}/bin/atuin init nu --disable-ai --disable-up-arrow > "$out/atuin.nu"
    ''}
    ${lib.optionalString shell.fnox.enable ''
      ${pkgs.fnox}/bin/fnox activate nu > "$out/fnox.nu"
    ''}
    ${pkgs.zoxide}/bin/zoxide init nushell > "$out/zoxide.nu"
    ${lib.optionalString config.modules.dev.devenv.enable ''
      # Sorts last, so a project's .envrc layers over the tools set up above.
      cp ${direnvHook} "$out/zz-direnv.nu"
    ''}
    # The init puts carapace's bin directory first on PATH. Generate it with a
    # placeholder and resolve the directory when nu starts, or PATH keeps the
    # build's home directory.
    XDG_CONFIG_HOME=/carapace-config ${pkgs.carapace}/bin/carapace _carapace nushell \
      | ${pkgs.gnused}/bin/sed 's#"/carapace-config/carapace/bin"#($env.XDG_CONFIG_HOME? | default ($env.HOME | path join "${carapaceConfigFallback}") | path join carapace bin)#g' \
      > "$out/carapace.nu"
    if grep -q /carapace-config "$out/carapace.nu"; then
      echo "carapace.nu still names the build's config directory" >&2
      exit 1
    fi
    # Commands with a native carapace spec, for config/nushell/scripts/completion.nu.
    # `carapace --list` takes too long to run on every completion.
    ${pkgs.carapace}/bin/carapace --list \
      | ${pkgs.nushell}/bin/nu -n --stdin -c '
          $in | from json
          | items {|name, specs| if ($specs | any {|spec| $spec.group != "bridge" }) { $name } }
          | compact | to nuon | $"$env.CARAPACE_NATIVE_SPECS = ($in)\n"' \
      > "$out/carapace-specs.nu"

    # Fail the build, not the shell, when a tool emits code nu cannot parse.
    for f in "$out"/*.nu "$out"/modules/*.nu; do
      [[ -e $f ]] || continue
      [[ $(${pkgs.nushell}/bin/nu -n -c "nu-check '$f'") == true ]] || {
        echo "nu-check failed: $f" >&2
        exit 1
      }
    done
  '';

  # Apps started by launchd or GNOME lack the PATH and Nix environment that
  # /etc/zshenv sets up, and nu reads no POSIX profile, so go through zsh.
  login = pkgs.writeShellApplication {
    name = "nu-login";
    text = ''
      # shellcheck disable=SC2016
      exec ${lib.getExe pkgs.zsh} -l -c 'exec "$0" "$@"' ${lib.getExe pkgs.nushell} "$@"
    '';
  };
in
{
  options.modules.shell.nushell.enable = lib.mkEnableOption "Nushell";

  config = lib.mkIf cfg.enable {
    # Keep config.nu and its modules live and let Home Manager own env.nu;
    # nu writes its plugin registry beside them. config.nu finds scripts/
    # beside its own link.
    modules.dotfiles.configLink = {
      "nushell/config.nu" = "nushell/config.nu";
      "nushell/scripts" = "nushell/scripts";
    };

    hm = {
      # env.nu runs before config.nu and vendor autoloads. Direct launches
      # (e.g. editor terminals) need the same PATH as the zsh login launcher.
      programs.nushell = {
        enable = true;
        loadSessionVariables = true;
      };
      home.packages = with pkgs; [
        login
        carapace
        fd
        fzf
        gum
        zoxide
      ];
      xdg.dataFile."nushell/vendor/autoload".source = autoload;

      # config/ghostty/config includes this. nu marks prompts and
      # reports its directory itself, and Ghostty's nu integration only wraps
      # ssh and sudo, which are off by default.
      xdg.configFile."ghostty/shell.ghostty" = lib.mkIf config.modules.apps.ghostty.enable {
        text = ''
          command = direct:${lib.getExe login}
          shell-integration = none
        '';
      };
    };
  };
}
