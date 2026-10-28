# atlas: work machine. Base tools only; no personal agents.
{ ... }:

{
  system = "aarch64-darwin";

  modules = {
    shell = {
      zsh.enable = true;
      nushell.enable = true;
      starship.enable = true;
      atuin.enable = true;
      yazi.enable = true;
      git = {
        enable = true;
        # The work identity everywhere, the personal one on GitHub remotes.
        identity = ../../secrets/git-work-identity.age;
        personalIdentity = "github";
      };
      mise.enable = true;
      fnox.enable = true;
      tools.enable = true;
      ssh.enable = true;
    };

    dev = {
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

    apps.ghostty.enable = true;
  };

  config = { ... }: {
    system.stateVersion = 6;
  };
}
