# modules/common/dev/devenv.nix
#
# Per-project environments: devenv, and direnv with nix-direnv so a
# project's .envrc (`use devenv` or `use flake`) loads on cd. The zsh and
# Nushell hooks live in modules/common/shell/{zsh,nushell}.nix, since both
# shells' rc files are linked from config/ rather than written by Home
# Manager.
{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:

let
  cfg = config.modules.dev.devenv;
  # devenv's nixpkgs and its own builds.
  cache = {
    extra-substituters = [ "https://devenv.cachix.org" ];
    extra-trusted-public-keys = [ "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=" ];
  };
in
{
  options.modules.dev.devenv.enable = lib.mkEnableOption "devenv and direnv for project environments";

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        hm = {
          home.packages = [ pkgs.devenv ];
          programs.direnv = {
            enable = true;
            nix-direnv.enable = true;
            # Home Manager would write config.nu, which is a live link.
            enableNushellIntegration = false;
            enableZshIntegration = false;
            config.global = {
              hide_env_diff = true;
              warn_timeout = "30s";
            };
          };
        };
      }
      # Determinate Nix owns nix.conf on Macs; see modules/darwin/default.nix.
      (if isDarwin then { determinateNix.customSettings = cache; } else { nix.settings = cache; })
    ]
  );
}
