{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.modules.shell.tools;
in
{
  options.modules.shell.tools.enable = lib.mkEnableOption "portable CLI tools";
  config = lib.mkIf cfg.enable {
    hm.home.packages =
      (with pkgs; [
        glow
        bat
        dprint
        ripgrep
        fd
        eza
        clang-tools
        uv
        gh
        lazygit
        tig
        mosh
        gitleaks
      ])
      ++ [ inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default ];
    modules.dotfiles = {
      configLink = {
        "dprint/dprint.jsonc" = "dprint/dprint.jsonc";
        "gh/config.yml" = "gh/config.yml";
        "lazygit/config.yml" = "lazygit/config.yml";
        "node/no-process-title.cjs" = "node/no-process-title.cjs";
      };
      homeLink.".local/share/cargo/config.toml" = "cargo/config.toml";
    };
    # macOS 27 aborts node on repeated native process.title assignments.
    modules.env.variables = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      NODE_OPTIONS = "--require $HOME/.config/node/no-process-title.cjs";
    };
  };
}
