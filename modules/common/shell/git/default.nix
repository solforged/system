# modules/common/shell/git/default.nix
#
# Git config, the commit hooks, and the gitleaks policy from secrets/.
{
  config,
  lib,
  pkgs,
  my,
  ...
}:

let
  inherit (lib) types;
  cfg = config.modules.shell.git;
  secrets = config.age.secrets;

  name = "solforged";
  email = "sol@sowilo.io";

  # Proton Pass keys, served by its SSH agent. Each host signs with its own.
  signingKey = config.user.sshKeys.${config.networking.hostName} or null;
  sign = cfg.sign && signingKey != null;
  allowedSigners = pkgs.writeText "allowed_signers" (
    lib.concatMapStrings (key: "${email} ${key}\n") (lib.attrValues config.user.sshKeys)
  );

  stripCursorAttribution = pkgs.writeShellApplication {
    name = "git-strip-cursor-attribution";
    runtimeInputs = with pkgs; [
      coreutils
      diffutils
      gawk
    ];
    text = builtins.readFile ./strip-cursor-attribution.sh;
  };

  commitMessagePolicy = pkgs.writeShellApplication {
    name = "git-commit-message-policy";
    runtimeInputs = with pkgs; [
      gawk
      git
    ];
    text = builtins.readFile ./commit-message-policy.sh;
  };

  gitleaksScan = pkgs.writeShellApplication {
    name = "git-gitleaks-scan";
    runtimeInputs = with pkgs; [
      coreutils
      git
      gitleaks
      gnugrep
      gnused
    ];
    text = ''
      policy_file=${secrets.gitleaks-policy.path}
      allowlist_file=${secrets.gitleaks-allowlist.path}
      work_remote_file=${secrets.gitleaks-work-remote.path}
    ''
    + builtins.readFile ./gitleaks.sh;
  };

  # Git runs config hooks in file order, and the generated file sorts them by
  # name, so one commit-msg hook fixes the order: strip Cursor's trailers
  # before the policy reads the body, then scan the final message.
  commitMsg = pkgs.writeShellApplication {
    name = "git-commit-msg";
    runtimeInputs = [
      stripCursorAttribution
      commitMessagePolicy
      gitleaksScan
    ];
    text = ''
      git-strip-cursor-attribution "$1"
      git-commit-message-policy "$1"
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

  secret = file: {
    inherit file;
    owner = config.user.name;
    mode = "0400";
  };
in
{
  options.modules.shell.git = {
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
  };

  config = lib.mkIf cfg.enable {
    age.secrets = {
      gitleaks-policy = secret ../../../../secrets/gitleaks.toml.age;
      gitleaks-allowlist = secret ../../../../secrets/gitleaks-allowlist.toml.age;
      gitleaks-work-remote = secret ../../../../secrets/gitleaks-work-remote.age;
    }
    // lib.optionalAttrs (cfg.identity != null) { git-identity = secret cfg.identity; };

    hm = {
      home.packages = with pkgs; [
        gh
        hk
        lazygit
      ];

      programs.git = {
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
  };
}
