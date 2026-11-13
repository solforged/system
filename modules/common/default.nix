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
      authKeys =
        my.mkOpt' (types.attrsOf types.str) { }
          "Public halves of each host's ~/.ssh/id_ed25519_sk, a FIDO2 key on the primary YubiKey made by ssh-enroll, by host. They authenticate to GitHub; those of sshLoginHosts also log in.";
      backupAuthKey =
        my.mkOpt' (types.nullOr types.str) null
          "Public half of the backup YubiKey's resident FIDO2 key (ssh-enroll --backup). It needs the PIN and a touch, and logs in wherever authKeys do.";
      sshLoginHosts =
        my.mkOpt' (types.listOf types.str) [ ]
          "Hosts in authKeys whose key may log in to this user's account.";
      signingKeys =
        my.mkOpt' (types.attrsOf types.str) { }
          "Public halves of the key each host signs commits with, by host. Git and jj trust them for signatures; they authorize no logins.";
      retiredSigningKeys =
        my.mkOpt' (types.listOf types.str) [ ]
          "Public halves of retired keys. Git and jj still verify their old signatures; they authorize nothing.";
      agentSigningKeys =
        my.mkOpt' (types.attrsOf types.str) { }
          "Public halves of keys that sandboxed agents sign commits with, by name (hermes-<host>: modules/nixos/agents/hermes-sandbox.nix). Git trusts them for signatures only; they never authorize logins.";
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

    # Filled in by ssh-enroll on each host; see docs/secrets.md.
    user.authKeys = {
      hyperion = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDKbD8uuk06z37rrhIi5huJb16uewOLCmCLpbufet6u1AAAABHNzaDo= hyperion";
    };
    user.backupAuthKey = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIJ6/cAxT1/LKMtq98Cgj/dYCsL0z+Q1cr62sT4CsLbuJAAAACnNzaDpiYWNrdXA= backup";
    # The work Mac reaches GitHub but does not log in to personal machines.
    user.sshLoginHosts = [
      "hyperion"
      "amarna"
    ];
    user.signingKeys = {
      hyperion = "sk-ecdsa-sha2-nistp256@openssh.com AAAAInNrLWVjZHNhLXNoYTItbmlzdHAyNTZAb3BlbnNzaC5jb20AAAAIbmlzdHAyNTYAAABBBBKZCikpKuquxv1fGSQsAD9eiFHMfmESuaDdJvTQpPonCBuUBDzRXCRzBDKucKs3MvwCt+TqFJKolc4/DXcaAA8AAAAEc3NoOg== hyperion";
      amarna = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO4ILJOzgl9yhaZ5mNZAtq16R8pvxXIgqX1ks/7+0ttD amarna";
      atlas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPp+FPH5hWad4uKJWwkQuDt1SqKy4tKY+gSmA/xnpyWZ atlas";
    };
    user.retiredSigningKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINJVrIRrq7NWLBvH/yDwoFCgZ4Ha/i7EKYCDEk3fDRNr amarna (Proton Pass)"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJ1b34vIwDUfuIkKUrcFD/oji8cVPHD0pJQgBwn4ZII amarna"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGcTyuiMYZAm8fCEMjUG2uWlSylRqfA/azJksC8wY+8C hyperion (Proton Pass)"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIErof9IMxQpX5/SSsZeJ8cH6h6WYOiiIBURVUZFkd4r 1password"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAugIdnV1mNxWv1SJK/qHzXVixB6ufI7n5Fc2RngN59o hermes-amarna (Proton Pass)"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJhK+KaTssKEnfGu7L1mPgvycDLyAIZIqlJ089Wi7kWd hyperion (file)"
    ];
    # TPM-sealed keys; docs/hermes-sandbox.md makes one.
    user.agentSigningKeys = { };
    users.users.${user}.openssh.authorizedKeys.keys =
      lib.concatMap (
        host: lib.optional (config.user.authKeys ? ${host}) config.user.authKeys.${host}
      ) config.user.sshLoginHosts
      # sshd then demands the backup key's PIN as well as a touch.
      ++ lib.optional (config.user.backupAuthKey != null) "verify-required ${config.user.backupAuthKey}";
    warnings =
      lib.optional
        (
          config.services.openssh.enable == true
          && config.users.users.${user}.openssh.authorizedKeys.keys == [ ]
        )
        "sshd is on, but no key may log in to ${user}: run ssh-enroll and fill in user.authKeys before switching a host you reach over SSH.";

    modules.env.variables = {
      DOTFILES_DIR = dotfiles.dir;
    };
  };
}
