# hyperion: personal Mac, Apple silicon
{ ... }:

{
  system = "aarch64-darwin";

  modules = {
    env.variables.LLM_WIKI_DIR = "$HOME/wiki";

    shell = {
      zsh.enable = true;
      starship.enable = true;
      atuin.enable = true;
      yazi.enable = true;
      git.enable = true;
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
    };

    editors = {
      default = "nvim";
      nvim.enable = true;
      helix.enable = true;
      zed.enable = true;
    };

    apps = {
      ghostty.enable = true;
      proton-pass = {
        enable = true;
        sshAgent.enable = true;
      };
    };

    agents = {
      claude.enable = true;
      omp.enable = true;
      pi.enable = true;
    };

    media.beets.enable = true;
    virt.containers.enable = true;
  };

  config = { ... }: {
    # Ghostty and Zed casks come from their modules.
    homebrew = {
      brews = [
        "btop"
        "coreutils"
        "ffmpeg"
        "qemu"
        "unar"
        "xdg-ninja"
      ];
      casks = [
        "appcleaner"
        "bit-slicer"
        "blender"
        "brave-browser"
        "calibre"
        "chatgpt"
        "claude"
        "codex-app"
        "crossover"
        "cryptomator"
        "dropbox"
        "filebot"
        "font-geist"
        "font-geist-mono"
        "font-symbols-only-nerd-font"
        "grok-bot"
        "helium-browser"
        "iina"
        "keka"
        "obsidian"
        "remnote"
        "roon"
        "signal"
        "spotify"
        "steam"
        "tailscale-app"
        "telegram"
        "transmission"
        "whatsapp"
        "yubico-authenticator"
        "zotero"
      ];
    };

    # nix-darwin's own state version, not a NixOS release.
    system.stateVersion = 6;
  };
}
