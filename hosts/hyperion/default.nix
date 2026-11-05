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
      default = "nvim";
      nvim.enable = true;
      helix.enable = true;
      zed.enable = true;
    };

    apps = {
      claude-desktop.enable = true;
      ghostty.enable = false;
      herdr-desktop.enable = false;
      tern.enable = true;
      proton-pass = {
        enable = true;
        sshAgent.enable = true;
      };
    };

    agents = {
      claude.enable = true;
      herdr.enable = false;
      hermes.enable = true;
      omp.enable = true;
      pi.enable = true;
    };

    media.beets.enable = true;
    virt.containers.enable = true;
  };

  config = { pkgs, ... }: {
    # The macOS account on this Mac is "admin", not the default "sol".
    user.name = "admin";

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
