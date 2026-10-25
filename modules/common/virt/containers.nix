# modules/common/virt/containers.nix
#
# OCI containers with each platform's native runtime: rootless Podman on
# NixOS, Apple's `container` on macOS. See modules/{nixos,darwin}/virt.
{ lib, ... }:

{
  options.modules.virt.containers.enable = lib.mkEnableOption "OCI containers";
}
