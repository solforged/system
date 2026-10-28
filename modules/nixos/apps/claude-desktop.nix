# modules/nixos/apps/claude-desktop.nix
#
# The package comes from numtide/llm-agents.nix, which tracks Anthropic's apt
# repository; `nix flake update llm-agents` picks up new releases. It runs the
# app in a bubblewrap FHS environment that supplies Cowork's UEFI firmware and
# virtiofsd at Debian's paths. That sandbox sets no_new_privs, so `sudo` fails
# in the app's terminal and in Claude Code sessions it starts.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.apps.claude-desktop;
in
{
  options.modules.apps.claude-desktop.cowork.enable =
    lib.mkEnableOption "Cowork, which runs Claude's agent tasks in a local QEMU VM";

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        hm.home.packages = [
          inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop
          # Claude Code's sandbox and proxy, recommended by the upstream .deb.
          pkgs.bubblewrap
          pkgs.socat
        ];

        # The app keeps its sign-in in the Secret Service.
        services.gnome.gnome-keyring.enable = true;
      }

      (lib.mkIf cfg.cowork.enable {
        # The app finds QEMU on the host PATH.
        hm.home.packages = [ pkgs.qemu_kvm ];

        # The VM's vsock needs /dev/vhost-vsock, which only the kvm group opens.
        users.users.${config.user.name}.extraGroups = [ "kvm" ];
        boot.kernelModules = [ "vhost_vsock" ];
      })
    ]
  );
}
