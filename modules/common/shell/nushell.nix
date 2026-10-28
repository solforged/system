# modules/common/shell/nushell.nix
#
# nu is the shell terminals open. zsh stays the login shell and sets up the
# environment, so terminals start nu from it; anything that runs $SHELL still
# gets a POSIX shell. Tool init code is generated in the store and loaded from
# nu's vendor autoload directory, ~/.local/share/nushell/vendor/autoload.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.shell.nushell;
  shell = config.modules.shell;
  autoload = pkgs.runCommand "nushell-autoload" { } ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME" "$out"
    ${lib.optionalString shell.starship.enable ''
      ${pkgs.starship}/bin/starship init nu > "$out/starship.nu"
    ''}
    ${lib.optionalString shell.atuin.enable ''
      ${pkgs.atuin}/bin/atuin init nu --disable-ai > "$out/atuin.nu"
    ''}
    ${lib.optionalString shell.mise.enable ''
      # Keep the caller's PATH. The first PATH assignments capture the build environment.
      ${pkgs.mise}/bin/mise activate nu \
        | ${pkgs.gnused}/bin/sed -E "/^ *[\$]env[.](__MISE_ORIG_PATH|PATH) = [(]?r#'/d; /^set,PATH,/d" > "$out/mise.nu"
    ''}
    ${lib.optionalString shell.fnox.enable ''
      ${pkgs.fnox}/bin/fnox activate nu > "$out/fnox.nu"
    ''}
    ${pkgs.zoxide}/bin/zoxide init nushell > "$out/zoxide.nu"
    ${pkgs.carapace}/bin/carapace _carapace nushell > "$out/carapace.nu"

    # Fail the build, not the shell, when a tool emits code nu cannot parse.
    for f in "$out"/*.nu; do
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
    # Link only config.nu: nu writes its plugin registry beside it.
    modules.dotfiles.configLink."nushell/config.nu" = "nushell/config.nu";

    hm = {
      home.packages = with pkgs; [
        carapace
        fzf
        gum
        nushell
        zoxide
      ];
      xdg.dataFile."nushell/vendor/autoload".source = autoload;

      # config/ghostty/config.ghostty includes this. nu marks prompts and
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
