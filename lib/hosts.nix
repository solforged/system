# lib/hosts.nix
#
# A host is hosts/<name>/default.nix, a function of { lib, inputs } that
# returns an attrset, not a module:
#
#   system  -- "x86_64-linux", "aarch64-darwin", ...; picks the builder
#   modules -- values for the modules.* options
#   config  -- an ordinary NixOS or nix-darwin module for host-only settings
#
# hosts/<name>/hardware.nix is imported when it exists.
{
  lib,
  inputs,
  my,
  ...
}:

rec {
  # mkHost :: { name; host; hostDir?; extraModules?; extraSpecialArgs?; } -> system
  #
  # Builds one host from a host attrset. Exported as the flake's lib.mkHost so
  # another flake can build a host from these modules plus its own:
  # extraModules are loaded after everything here, and extraSpecialArgs join
  # `inputs` (always this flake's), `my`, `isDarwin` and `hostDir`.
  mkHost =
    {
      name,
      host,
      hostDir ? null,
      extraModules ? [ ],
      extraSpecialArgs ? { },
    }:
    let
      isDarwin = lib.hasSuffix "-darwin" host.system;
      platform = if isDarwin then "darwin" else "nixos";
      moduleSet = if isDarwin then "darwinModules" else "nixosModules";
      builder = if isDarwin then inputs.nix-darwin.lib.darwinSystem else inputs.nixpkgs.lib.nixosSystem;
      platformDir = ../modules + "/${platform}";
      hardware = hostDir + "/hardware.nix";
    in
    builder {
      specialArgs = {
        inherit
          inputs
          my
          isDarwin
          hostDir
          ;
      }
      // extraSpecialArgs;
      modules = [
        ../modules/common
        platformDir
      ]
      ++ my.modulePaths ../modules/common
      ++ my.modulePaths platformDir
      ++ [
        inputs.home-manager.${moduleSet}.home-manager
        inputs.agenix.${moduleSet}.default
        {
          nixpkgs.hostPlatform = host.system;
          networking.hostName = name;
          modules = host.modules or { };
        }
        (host.config or { })
      ]
      ++ lib.optional isDarwin inputs.determinate.darwinModules.default
      ++ lib.optional (hostDir != null && builtins.pathExists hardware) hardware
      ++ extraModules;
    };

  # mapHosts :: path -> { name = { isDarwin; build; }; }
  #
  # `build` stays a thunk, so flake.nix can sort hosts by platform without
  # evaluating them.
  mapHosts =
    dir:
    my.mapModules dir (
      path:
      let
        host = import path { inherit lib inputs; };
      in
      {
        isDarwin = lib.hasSuffix "-darwin" host.system;
        build = mkHost {
          name = baseNameOf path;
          inherit host;
          hostDir = path;
        };
      }
    );
}
