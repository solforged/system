# flake.nix
#
# Every host under hosts/ becomes a nixosConfiguration or a
# darwinConfiguration, depending on its `system`. See lib/hosts.nix.
{
  description = "NixOS and nix-darwin configuration for sol's machines";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # Determinate Nix owns /etc/nix/nix.conf and the daemon on Macs; this
    # module writes nix.custom.conf and turns off nix-darwin's Nix management.
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    lanzaboote.url = "github:nix-community/lanzaboote/v1.2.0";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

    mt7927.url = "github:cmspam/mt7927-nixos/4177e1edb28fdc48ab696903f012348ac8ad39e8";
    mt7927.inputs.nixpkgs.follows = "nixpkgs";

    # Not following nixpkgs: upstream builds and tests its uv2nix package
    # against its own lock.
    hermes-agent.url = "github:NousResearch/hermes-agent";
    hermes-agent.inputs.home-manager.follows = "home-manager";

    # Private repo. Fetching it needs a GitHub token, e.g.
    # --option access-tokens "github.com=$(gh auth token)".
    solforge-theme.url = "github:solforged/solforge-theme";
    solforge-theme.flake = false;
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
      my = import ./lib { inherit lib inputs; };
      hosts = my.mapHosts ./hosts;
      only =
        darwin:
        lib.mapAttrs (_: host: host.build) (lib.filterAttrs (_: host: host.isDarwin == darwin) hosts);
    in
    {
      nixosConfigurations = only false;
      darwinConfigurations = only true;

      # nix build .#installer-iso
      packages.x86_64-linux.installer-iso =
        (lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            ./installer
            { nixpkgs.hostPlatform = "x86_64-linux"; }
          ];
        }).config.system.build.isoImage;

      formatter = lib.genAttrs [ "x86_64-linux" "aarch64-darwin" ] (
        system: nixpkgs.legacyPackages.${system}.nixfmt-tree
      );
    };
}
