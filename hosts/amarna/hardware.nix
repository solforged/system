# hosts/amarna/hardware.nix
#
# Written by hand for this board. During install, compare it with
# `nixos-generate-config --no-filesystems --show-hardware-config` and keep
# whatever that adds. disko.nix owns the filesystems.
{ lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "thunderbolt"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];

  networking.useDHCP = lib.mkDefault true;
}
