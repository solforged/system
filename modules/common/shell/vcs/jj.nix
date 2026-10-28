# modules/common/shell/vcs/jj.nix
#
# Jujutsu with Git's identity and signing key. jj runs no Git hooks, so the
# commit checks move to `jj push`, which runs them over everything a push
# would publish before calling `jj git push`.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.shell.vcs;
  common = import ./_common.nix { inherit config lib pkgs; };
  inherit (common)
    name
    email
    signingKey
    sign
    allowedSigners
    ;

  jjPush = pkgs.writeShellApplication {
    name = "jj-push";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
      jujutsu
      common.commitMessagePolicy
      common.gitleaksScan
    ];
    text = builtins.readFile ./jj-push.sh;
  };

  # commit-template's comments, as the JJ: lines jj strips from a description.
  templateHints = lib.concatMapStrings (line: "JJ:${lib.removePrefix "#" line}\n") (
    lib.filter (lib.hasPrefix "#") (lib.splitString "\n" (builtins.readFile ./commit-template))
  );
in
{
  config = lib.mkIf (cfg.enable && cfg.jj.enable) {
    hm.programs.jujutsu = {
      enable = true;
      settings = {
        user = { inherit name email; };

        templates.draft_commit_description = "concat(builtin_draft_commit_description, ${builtins.toJSON templateHints})";

        # `jj commit` leaves an empty @ on top; advance bookmarks to the
        # commit under it.
        revsets.bookmark-advance-to = "@-";

        aliases.push = [
          "util"
          "exec"
          "--"
          (lib.getExe jjPush)
        ];
      }
      # jj rewrites @ on every snapshot, so signing as it goes would ask the
      # agent for a signature on almost every command. Sign at push instead.
      // lib.optionalAttrs sign {
        signing = {
          behavior = "drop";
          backend = "ssh";
          key = signingKey;
          backends.ssh.allowed-signers = "${allowedSigners}";
        };
        git.sign-on-push = true;
      };
    };
  };
}
