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
          "Public halves of each host's ~/.ssh/id_ed25519, made by ssh-enroll, by host. A host listed here signs commits with its own key.";
      sshLoginHosts =
        my.mkOpt' (types.listOf types.str) [ ]
          "Hosts in sshKeys whose key may log in to this user's account.";
      retiredSigningKeys =
        my.mkOpt' (types.listOf types.str) [ ]
          "Public halves of retired keys. Git and jj still verify their old signatures; they authorize nothing.";
      agentSigningKeys =
        my.mkOpt' (types.attrsOf types.str) { }
          "Public halves of Proton Pass keys that sandboxed agents sign commits with, by name. Git trusts them for signatures only; they never authorize logins.";
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

    nixpkgs.config.allowUnfree = true;

    # packages/<name>.nix becomes pkgs.<name> on every host.
    nixpkgs.overlays = [
      (final: _prev: my.mapModules ../../packages (path: final.callPackage path { }))
    ];

    user.sshKeys = {
      hyperion = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJhK+KaTssKEnfGu7L1mPgvycDLyAIZIqlJ089Wi7kWd hyperion";
      amarna = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO4ILJOzgl9yhaZ5mNZAtq16R8pvxXIgqX1ks/7+0ttD amarna";
      atlas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPp+FPH5hWad4uKJWwkQuDt1SqKy4tKY+gSmA/xnpyWZ atlas";
    };
    # The work Mac signs commits but does not log in to personal machines.
    user.sshLoginHosts = [
      "hyperion"
      "amarna"
    ];
    user.retiredSigningKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINJVrIRrq7NWLBvH/yDwoFCgZ4Ha/i7EKYCDEk3fDRNr amarna (Proton Pass)"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJ1b34vIwDUfuIkKUrcFD/oji8cVPHD0pJQgBwn4ZII amarna"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGcTyuiMYZAm8fCEMjUG2uWlSylRqfA/azJksC8wY+8C hyperion (Proton Pass)"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIErof9IMxQpX5/SSsZeJ8cH6h6WYOiiIBURVUZFkd4r 1password"
    ];
    # Each lives alone in a "Hermes" Proton Pass vault; see modules/nixos/agents.
    user.agentSigningKeys = {
      hermes-amarna = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAugIdnV1mNxWv1SJK/qHzXVixB6ufI7n5Fc2RngN59o hermes-amarna";
    };
    users.users.${user}.openssh.authorizedKeys.keys = map (
      host: config.user.sshKeys.${host}
    ) config.user.sshLoginHosts;

    modules.env.variables = {
      DOTFILES_DIR = dotfiles.dir;
    };
  };
}
