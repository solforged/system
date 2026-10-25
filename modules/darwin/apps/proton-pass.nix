# modules/darwin/apps/proton-pass.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.apps.proton-pass;
  home = config.users.users.${config.user.name}.home;
in
{
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { homebrew.casks = [ "proton-pass" ]; }

      (lib.mkIf cfg.sshAgent.enable {
        launchd.user.agents.proton-pass-ssh-agent.serviceConfig = {
          ProgramArguments = [
            "/bin/sh"
            "-c"
            ''
              /bin/mkdir -p -m 700 ${home}/.ssh
              /bin/rm -f ${cfg.sshAgent.socket}
              exec ${lib.getExe' pkgs.proton-pass-cli "pass-cli"} ssh-agent start --socket-path ${cfg.sshAgent.socket}
            ''
          ];
          RunAtLoad = true;
          # Exits until `pass-cli login` has run on this host; retry slowly.
          KeepAlive.SuccessfulExit = false;
          ThrottleInterval = 30;
          StandardOutPath = "${home}/Library/Logs/proton-pass-ssh-agent.log";
          StandardErrorPath = "${home}/Library/Logs/proton-pass-ssh-agent.log";
        };
      })
    ]
  );
}
