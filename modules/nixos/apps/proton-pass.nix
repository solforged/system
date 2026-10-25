# modules/nixos/apps/proton-pass.nix
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
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { hm.home.packages = [ pkgs.proton-pass ]; }

      (lib.mkIf cfg.sshAgent.enable {
        # GNOME would otherwise claim SSH_AUTH_SOCK for its own agent.
        services.gnome.gcr-ssh-agent.enable = false;

        hm.systemd.user.services.proton-pass-ssh-agent = {
          Unit.Description = "Proton Pass SSH agent";
          Service = {
            ExecStartPre = [
              "${pkgs.coreutils}/bin/mkdir -p -m 700 %h/.ssh"
              "${pkgs.coreutils}/bin/rm -f ${cfg.sshAgent.socket}"
            ];
            ExecStart = "${lib.getExe' pkgs.proton-pass-cli "pass-cli"} ssh-agent start --socket-path ${cfg.sshAgent.socket}";
            # Fails until `pass-cli login` has run on this host.
            Restart = "on-failure";
            RestartSec = 30;
          };
          Install.WantedBy = [ "default.target" ];
        };
      })
    ]
  );
}
