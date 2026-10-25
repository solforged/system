{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.virt.libvirt;
in
{
  options.modules.virt.libvirt.enable =
    lib.mkEnableOption "Libvirt guests with QEMU, UEFI and virtiofs";
  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        vhostUserPackages = [ pkgs.virtiofsd ];
        swtpm.enable = true;
      };
    };
    users.users.${config.user.name}.extraGroups = [
      "libvirtd"
      "kvm"
    ];
    # virt-manager also supplies virt-install and virt-clone.
    hm.home.packages = with pkgs; [
      virt-manager
      cloud-utils
      dnsmasq
    ];
  };
}
