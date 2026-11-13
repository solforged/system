# hyperion: personal Mac, Apple silicon
{ ... }:

{
  system = "aarch64-darwin";

  modules = {
    shell = {
      zsh.enable = true;
      nushell.enable = true;
      atuin.enable = true;
      yazi.enable = true;
      vcs = {
        enable = true;
        jj.enable = true;
      };
      mise.enable = true;
      fnox.enable = true;
      tools.enable = true;
      ssh.enable = true;
    };

    dev = {
      devenv.enable = true;
      personal.enable = true;
      python.enable = true;
      node.enable = true;
      go.enable = true;
      rust.enable = true;
    };

    fonts = {
      berkeley.enable = true;
      ibmPlex.enable = true;
      geist.enable = true;
      nerdSymbols.enable = true;
    };

    editors = {
      default = "ms";
      mitos.enable = true;
      nvim.enable = true;
    };

    apps = {
      rex.enable = true;
      claude-desktop.enable = true;
      ghostty.enable = false;
      herdr-desktop.enable = false;
      tern.enable = false;
      # The password manager app; keys are in docs/secrets.md.
      proton-pass.enable = true;
    };

    # secrets-edit and secrets-rekey, with an admin YubiKey.
    secrets.admin.enable = true;

    agents = {
      claude.enable = true;
      herdr.enable = false;
      hermes.enable = true;
      omp.enable = true;
      pi.enable = true;
    };

    voice.enable = true;
    media.beets.enable = true;
    virt.containers.enable = true;

    # Remote Login for Tern, over the tailnet only; Rex pairs over Tailscale
    # without SSH.
    services.ssh.enable = true;
  };

  config = { pkgs, ... }: {
    # The macOS account on this Mac is "admin", not the default "sol".
    user.name = "admin";

    # Tern clients paired with this Mac. Login only; they sign nothing.
    users.users.admin.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF++Ii79FcOTz8I8ObCoGO7sinJrDmpSoG4j7I77F5De tern-paired 2026-10-16"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOzhivRLTuez7EWUjc/YreIloCItnXmoI3K8kUKnRmBN tern-paired 2026-10-24"
    ];

    # CLIs and apps only this Mac needs.
    hm.home.packages = with pkgs; [
      rage
      yubikey-manager
      btop
      coreutils
      ffmpeg
      qemu
      unar
      xdg-ninja
      brave
      chatgpt
      crossover
      iina
      keka
      obsidian
      telegram-desktop
      transmission_4-mac
      whatsapp-for-mac
    ];

    # Uninstall formulae and casks that are no longer listed. "zap" would
    # also delete the files those casks own.
    homebrew.onActivation.cleanup = "uninstall";

    # No usable aarch64-darwin package for these, except Signal, which stays
    # on the signed cask. Zotero's package depends on an end-of-life Firefox
    # ESR. Claude and Zed casks come from their modules.
    homebrew.casks = [
      "1password"
      "calibre"
      "cryptomator"
      "raycast"
      # "filebot"
      "remnote"
      # "roon"
      "signal"
      # "spotify"
      "tailscale"
      "steam"
      "yubico-authenticator"
      "zotero"
    ];

    # nix-darwin's own state version, not a NixOS release.
    system.stateVersion = 6;
  };
}
