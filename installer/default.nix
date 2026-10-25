# installer/default.nix
#
# A NixOS installer image for this repo's hosts. On top of the minimal ISO it
# adds the MT7927 Wi-Fi driver (amarna has no other working network),
# NetworkManager, the CUDA binary caches, and this flake with its locked
# inputs, so the private solforge-theme input needs no GitHub token.
# `install-amarna` runs the whole installation.
{
  lib,
  pkgs,
  modulesPath,
  inputs,
  ...
}:

let
  installAmarna = pkgs.writeShellApplication {
    name = "install-amarna";
    runtimeInputs = [
      inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.disko
      pkgs.coreutils
      pkgs.git
      pkgs.gnutar
      pkgs.networkmanager
      pkgs.nixos-install-tools
      pkgs.rage
      pkgs.util-linux
    ];
    text = builtins.readFile ./install-amarna.sh;
  };
in
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    ../modules/nixos/hardware/mt7927.nix
  ];

  modules.hardware.mt7927.enable = true;

  # ZFS does not follow the 7.2 kernel the Wi-Fi driver needs.
  boot.supportedFilesystems.zfs = lib.mkForce false;

  networking.hostName = "nixos-installer";

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [
      "https://nix-community.cachix.org"
      "https://cache.nixos-cuda.org"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };

  # The flake itself, and every top-level input already in the store.
  environment.etc = {
    system.source = inputs.self;
  }
  // lib.mapAttrs' (name: input: lib.nameValuePair "system-inputs/${name}" { source = input; }) (
    removeAttrs inputs [ "self" ]
  );

  environment.systemPackages = [
    installAmarna
    pkgs.git
    pkgs.rage
  ];

  image.baseName = lib.mkForce "nixos-system-installer";
}
