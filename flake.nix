# flake.nix
#
# Every host under hosts/ becomes a nixosConfiguration or a
# darwinConfiguration, depending on its `system`. See lib/hosts.nix.
# lib.mkHost builds a host for another flake, such as a work repo that adds
# its own modules on top of these.
{
  description = "NixOS and nix-darwin configuration for sol's machines";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # The nixpkgs-unstable channel tests Darwin; nixos-unstable gates Linux.
    nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs-darwin";

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

    # Coding agents. Its nixpkgs is left unfollowed so store paths match
    # cache.numtide.com; see modules/common/agents/cache.nix.
    llm-agents.url = "github:numtide/llm-agents.nix";

    # Hermes' upstream flake tracks main for both the CLI and desktop app.
    # Its home-manager only feeds a module this flake does not import.
    hermes-agent.url = "github:NousResearch/hermes-agent/main";
    hermes-agent.inputs.home-manager.follows = "home-manager";

    omp-intercom.url = "github:solforged/omp-intercom";
    omp-intercom.flake = false;

    # Private repo. Fetching it needs a GitHub token: system-bump and
    # bootstrap pass `gh auth token`, CI the SOLFORGE_THEME_TOKEN secret.
    # By hand: --option access-tokens "github.com=$(gh auth token)".
    solforge-theme.url = "github:solforged/solforge-theme";
    solforge-theme.flake = false;
  };

  outputs =
    inputs@{ nixpkgs, nixpkgs-darwin, ... }:
    let
      inherit (nixpkgs) lib;
      my = import ./lib { inherit lib inputs; };
      hosts = my.mapHosts ./hosts;
      only =
        darwin:
        lib.mapAttrs (_: host: host.build) (lib.filterAttrs (_: host: host.isDarwin == darwin) hosts);

      # Tooling (formatter, system-bump) for every platform the flake is
      # run from, including CI runners. Macs take the Darwin-tested channel.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      pkgsFor =
        system:
        (if lib.hasSuffix "-darwin" system then nixpkgs-darwin else nixpkgs).legacyPackages.${system};

      # Every host's system build, as a check on its own platform, so
      # `nix flake check` builds this Mac and `system-bump --verify`
      # evaluates every host.
      hostChecks = lib.foldlAttrs (
        acc: name: host:
        lib.recursiveUpdate acc { ${host.system}.${name} = host.build.config.system.build.toplevel; }
      ) { } hosts;

      toolingChecks = lib.genAttrs systems (system: {
        shell = import ./tests/shell.nix { pkgs = pkgsFor system; };
      });

      installerIso =
        (lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            ./installer
            { nixpkgs.hostPlatform = "x86_64-linux"; }
          ];
        }).config.system.build.isoImage;
    in
    {
      nixosConfigurations = only false;
      darwinConfigurations = only true;

      lib = { inherit (my) mkHost; };

      checks = lib.recursiveUpdate (lib.recursiveUpdate hostChecks toolingChecks) {
        x86_64-linux = {
          solforge = import ./tests/solforge.nix {
            configuration = hosts.amarna.build;
          };
          herdr-themes = import ./tests/herdr.nix {
            configuration = hosts.amarna.build;
          };
          herdr-pi = import ./tests/herdr-pi.nix {
            configuration = hosts.amarna.build;
          };
        };
      };

      packages = lib.genAttrs systems (
        system:
        {
          # nix run .#system-bump; installed on every host as system-bump.
          system-bump = (pkgsFor system).callPackage ./packages/system-bump.nix { };
          mitos = (pkgsFor system).callPackage ./packages/mitos.nix { };
        }
        # nix build .#installer-iso
        // lib.optionalAttrs (system == "x86_64-linux") { installer-iso = installerIso; }
      );

      formatter = lib.genAttrs systems (system: (pkgsFor system).nixfmt-tree);
    };
}
