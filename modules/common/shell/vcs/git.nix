# modules/common/shell/vcs/git.nix
#
# Git config and the commit hooks.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.shell.vcs;
  secrets = config.age.secrets;
  common = import ./_common.nix { inherit config lib pkgs; };
  inherit (common)
    name
    email
    signingKey
    sign
    allowedSigners
    gitleaksScan
    ;

  # Git runs config hooks in file order, and the generated file sorts them by
  # name, so commit-message strips Cursor's trailers and scans the message
  # before commit-message-policy reads the body. The policy is a hook of its
  # own so config/lazygit/config.yml can skip it alone.
  commitMsg = pkgs.writeShellApplication {
    name = "git-commit-msg";
    runtimeInputs = with common; [
      stripCursorAttribution
      gitleaksScan
    ];
    text = ''
      git-strip-cursor-attribution "$1"
      git-gitleaks-scan --commit-msg "$1"
    '';
  };

  personal = {
    user = {
      inherit name email;
    }
    // lib.optionalAttrs sign { signingkey = "key::${signingKey}"; };
    gpg.format = "ssh";
    gpg.ssh.allowedSignersFile = "${allowedSigners}";
    commit.gpgsign = sign;
    tag.gpgsign = sign;
  };

  githubRemotes = [
    "hasconfig:remote.*.url:git@github:*/**"
    "hasconfig:remote.*.url:git@github.com:*/**"
    "hasconfig:remote.*.url:https://github.com/*/**"
  ];
in
{
  config = lib.mkIf cfg.enable {
    hm.programs.git = {
      enable = true;

      settings = {
        user = { inherit name email; };
        init.defaultBranch = "main";
        pull.ff = "only";
        push.autoSetupRemote = true;
        fetch.prune = true;
        rerere.enabled = true;
        diff.algorithm = "histogram";
        color.ui = "auto";
        # lazygit reads core.editor before $EDITOR.
        core.editor = lib.mkIf (config.modules.editors.default != null) config.modules.editors.default;
        commit.template = "${./commit-template}";

        # Hook names must not collide with event names.
        hook = {
          commit-message = {
            command = lib.getExe commitMsg;
            event = "commit-msg";
          };
          commit-message-policy = {
            command = lib.getExe common.commitMessagePolicy;
            event = "commit-msg";
          };
          secret-scan = {
            command = lib.getExe gitleaksScan;
            event = "pre-commit";
          };
        };
      };

      ignores = [
        ".DS_Store"
        "*~"
        "*.swp"
        "*.swo"
      ];

      # Later includes win: the host identity, then machine-local overrides,
      # then the personal identity where it applies.
      includes =
        lib.optional (cfg.identity != null) { path = secrets.git-identity.path; }
        ++ [ { path = "~/.config/git/config.local"; } ]
        ++ (
          if cfg.personalIdentity == "everywhere" then
            [ { contents = personal; } ]
          else
            map (condition: {
              inherit condition;
              contents = personal;
            }) githubRemotes
        );
    };
  };
}
