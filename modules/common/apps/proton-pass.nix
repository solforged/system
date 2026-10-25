# modules/common/apps/proton-pass.nix
#
# Proton Pass, its CLI, and its SSH agent. The agent serves the SSH keys
# stored in Proton Pass, so no private key sits in ~/.ssh. Log in once per
# host with `pass-cli login`; the agent service retries until then.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.apps.proton-pass;
in
{
  options.modules.apps.proton-pass = {
    enable = lib.mkEnableOption "Proton Pass";
    sshAgent = {
      enable = lib.mkEnableOption "the Proton Pass SSH agent as this user's SSH agent";
      socket = lib.mkOption {
        type = lib.types.str;
        default = "${config.users.users.${config.user.name}.home}/.ssh/proton-pass-agent.sock";
        readOnly = true;
        description = "Socket the agent listens on; SSH_AUTH_SOCK points here.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    hm.home.packages = [ pkgs.proton-pass-cli ];

    modules.env.variables = lib.mkIf cfg.sshAgent.enable {
      SSH_AUTH_SOCK = cfg.sshAgent.socket;
    };
  };
}
