# modules/common/shell/vcs/default.nix
#
# Version control: Git always, Jujutsu on request. This file holds the shared
# options and the gitleaks secrets; git.nix and jj.nix configure each tool
# from _common.nix.
{
  config,
  lib,
  pkgs,
  my,
  ...
}:

let
  inherit (lib) types;
  cfg = config.modules.shell.vcs;

  secret = file: {
    inherit file;
    owner = config.user.name;
    mode = "0400";
  };
in
{
  options.modules.shell.vcs = {
    enable = lib.mkEnableOption "Git and its tools";
    sign =
      my.mkOpt' types.bool true
        "Sign personal commits and tags with this host's key from user.sshKeys, when it has one.";
    personalIdentity = my.mkOpt' (types.enum [
      "everywhere"
      "github"
    ]) "everywhere" "Where the personal identity applies: every repository, or GitHub remotes only.";
    identity =
      my.mkOpt' (types.nullOr types.path) null
        "Age-encrypted git config with a [user] block that replaces the default identity.";
    jj.enable = lib.mkEnableOption "Jujutsu, with the same identity, signing and checks as Git";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        # Git picks the identity by remote URL; jj config cannot.
        assertion = !cfg.jj.enable || cfg.personalIdentity == "everywhere";
        message = "modules.shell.vcs.jj needs personalIdentity = \"everywhere\": jj cannot choose an identity by remote.";
      }
    ];

    age.secrets = {
      gitleaks-policy = secret ../../../../secrets/gitleaks.toml.age;
      gitleaks-allowlist = secret ../../../../secrets/gitleaks-allowlist.toml.age;
      gitleaks-work-remote = secret ../../../../secrets/gitleaks-work-remote.age;
    }
    // lib.optionalAttrs (cfg.identity != null) { git-identity = secret cfg.identity; };

    hm.home.packages = with pkgs; [
      gh
      hk
      lazygit
    ];
  };
}
