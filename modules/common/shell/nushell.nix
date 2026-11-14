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
    ${lib.optionalString shell.mise.enable ''
      # mise's init is a module: its `main` becomes the `mise` wrapper that
      # applies `mise shell` to this shell. Sourced directly, it would only
      # define a command called `main`. Keep the caller's PATH; the first
      # PATH assignments capture the build environment.
      mkdir "$out/modules"
      ${pkgs.mise}/bin/mise activate nu \
        | ${pkgs.gnused}/bin/sed -E "/^ *[\$]env[.](__MISE_ORIG_PATH|PATH) = [(]?r#'/d; /^set,PATH,/d" > "$out/modules/mise.nu"
      echo "use $out/modules/mise.nu" > "$out/mise.nu"
    ''}
    ${lib.optionalString shell.fnox.enable ''
      ${pkgs.fnox}/bin/fnox activate nu > "$out/fnox.nu"
    ''}
    ${pkgs.zoxide}/bin/zoxide init nushell > "$out/zoxide.nu"
    ${lib.optionalString config.modules.dev.devenv.enable ''
      # Sorts after mise.nu, so a project's .envrc layers over mise's tools.
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
    # Keep config.nu live and let Home Manager own env.nu; nu writes its
    # plugin registry beside them.
    modules.dotfiles.configLink."nushell/config.nu" = "nushell/config.nu";

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
