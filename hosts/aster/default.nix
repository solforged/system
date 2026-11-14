# aster: personal Mac, Apple silicon. The base set: shell, dev toolchains,
# editors, agents and Tailscale, without hyperion's apps and media.
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
      fnox.enable = true;
      tools.enable = true;
      ssh.enable = true;
    };

    dev = {
      devenv.enable = true;
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

    apps.rex.enable = true;

    agents = {
      claude.enable = true;
      omp.enable = true;
      pi.enable = true;
    };

    services = {
      tailscale.enable = true;
      # Remote Login over the tailnet only.
      ssh.enable = true;
    };
  };

  config = { ... }: {
    # The macOS account on this Mac is "admin", not the default "sol".
    user.name = "admin";

    # nix-darwin's own state version, not a NixOS release.
    system.stateVersion = 6;
  };
}
