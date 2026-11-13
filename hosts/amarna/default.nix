# amarna: desktop workstation
# ASUS ProArt X870E-CREATOR, Ryzen 9 9950X, RTX PRO 6000 Blackwell, 990 PRO 4TB
{ inputs, ... }:

{
  system = "x86_64-linux";

  modules = {
    profiles = {
      role = "workstation";
      hardware = [
        "cpu/amd"
        "gpu/nvidia"
        "audio"
        "bluetooth"
        "ssd"
      ];
    };

    desktop = {
      gnome.enable = true;
      solforge.enable = true;
      preferences.enable = true;
    };

    hardware = {
      apfs.enable = true;
      mt7927.enable = true;
    };

    security = {
      authentication = {
        enable = true;
        fingerprint = true;
      };
      # Set sign = true once /var/lib/sbctl is restored after install; the
      # option description lists the steps.
      secureboot.enable = true;
    };

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
    };

    editors = {
      default = "ms";
      mitos.enable = true;
      nvim.enable = true;
    };

    apps = {
      claude-desktop = {
        enable = true;
        cowork.enable = true;
      };
      ghostty.enable = true;
      herdr-desktop.enable = true;
      tern.enable = true;
      personal.enable = true;
      # Signing and SSH use this host's own key; see docs/secrets.md.
      proton-pass.enable = true;
      workstation-tools.enable = true;
    };

    agents = {
      claude.enable = true;
      herdr.enable = true;
      hermes = {
        enable = true;
        sandbox.enable = true;
      };
      omp.enable = true;
      pi.enable = true;
    };

    ai.llama = {
      enable = true;
      tailscaleServe.enable = true;
    };

    games.desktop.enable = true;
    virt = {
      libvirt.enable = true;
      containers.enable = true;
    };

    media = {
      beets.enable = true;
      streamrip.enable = true;
      import.enable = true;
    };

    services = {
      tailscale.enable = true;
      ssh.enable = true;
    };
  };

  config = { ... }: {
    imports = [
      inputs.disko.nixosModules.disko
      ./disko.nix
    ];

    # This host is administered over Tailscale; keep SSH off other interfaces.
    services.openssh.openFirewall = false;
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

    # The release this host was installed with. Never bump it.
    system.stateVersion = "26.05";
  };
}
