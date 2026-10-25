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

{
  # mapHosts :: path -> { name = { isDarwin; build; }; }
  #
  # `build` stays a thunk, so flake.nix can sort hosts by platform without
  # evaluating them.
  mapHosts =
    dir:
    my.mapModules dir (
      path:
      let
        name = baseNameOf path;
        host = import path { inherit lib inputs; };
        isDarwin = lib.hasSuffix "-darwin" host.system;
        platform = if isDarwin then "darwin" else "nixos";
        moduleSet = if isDarwin then "darwinModules" else "nixosModules";
        builder = if isDarwin then inputs.nix-darwin.lib.darwinSystem else inputs.nixpkgs.lib.nixosSystem;
        platformDir = ../modules + "/${platform}";
      in
      {
        inherit isDarwin;
        build = builder {
          specialArgs = {
            inherit inputs my isDarwin;
            hostDir = path;
          };
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
          ++ lib.optional (builtins.pathExists (path + "/hardware.nix")) (path + "/hardware.nix");
        };
      }
    );
}
