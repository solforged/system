# modules/common/default.nix
#
# Core settings for every host, NixOS or nix-darwin. Modules under common/
# may only set options that exist on both platforms; anything else goes in
# modules/nixos or modules/darwin, keyed off the same modules.* flags.
{
  config,
  lib,
  my,
  ...
}:

let
  inherit (lib) mapAttrs types;
  user = config.user.name;
  dotfiles = config.modules.dotfiles;
in
{
  options = {
    modules = { };

    user = {
      name = my.mkOpt types.str "sol";
      sshKeys =
        my.mkOpt' (types.attrsOf types.str) { }
          "Public halves of this user's Proton Pass SSH keys, by host. Every key authorizes SSH logins; a host signs commits with its own key.";
    };

    # Write home-manager config as `hm.<option>` from any module. A
    # deferredModule merges every definition, and may be a function of
    # home-manager's own module arguments: `hm = hm: { ... hm.config ... }`.
    hm = my.mkOpt types.deferredModule { };

    modules.dotfiles = {
      dir = my.mkOpt' types.str "${
        config.users.users.${user}.home
      }/src/system" "Live checkout of this repo; the links below point into it.";

      # Out-of-store symlinks into config/ of the live checkout, so edits apply
      # without a rebuild. Keys are targets; values are paths under config/.
      configLink =
        my.mkOpt' (types.attrsOf types.str) { }
          "Links under $XDG_CONFIG_HOME, e.g. { nvim = \"nvim\"; }.";
      homeLink =
        my.mkOpt' (types.attrsOf types.str) { }
          "Links under $HOME, e.g. { \".zshenv\" = \"zsh/.zshenv\"; }.";
    };
  };

  config = {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      # The first switch on a host replaces files mise deployed.
      backupFileExtension = "hm-backup";
      users.${user} = config.hm;
    };

    hm =
      hm:
      let
        link = rel: {
          source = hm.config.lib.file.mkOutOfStoreSymlink "${dotfiles.dir}/config/${rel}";
        };
      in
      {
        home.stateVersion = "26.05";
        xdg.enable = true;
        xdg.configFile = mapAttrs (_: link) dotfiles.configLink;
        home.file = mapAttrs (_: link) dotfiles.homeLink;
      };

    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        user
      ];
      warn-dirty = false;
    };

    nixpkgs.config.allowUnfree = true;

    # packages/<name>.nix becomes pkgs.<name> on every host.
    nixpkgs.overlays = [
      (final: _prev: my.mapModules ../../packages (path: final.callPackage path { }))
    ];

    user.sshKeys = {
      amarna = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINJVrIRrq7NWLBvH/yDwoFCgZ4Ha/i7EKYCDEk3fDRNr amarna";
      hyperion = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGcTyuiMYZAm8fCEMjUG2uWlSylRqfA/azJksC8wY+8C hyperion";
    };
    users.users.${user}.openssh.authorizedKeys.keys = lib.attrValues config.user.sshKeys;

    modules.env.variables.DOTFILES_DIR = dotfiles.dir;
  };
}
