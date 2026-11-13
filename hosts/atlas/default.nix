# atlas: work machine. Base tools and the work-safe agents; the private work
# flake builds it with its own modules on top (docs/atlas.md).
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

    # Work-safe agents; the private work flake adds the rest (docs/atlas.md).
    agents = {
      omp.enable = true;
      pi.enable = true;
    };
  };

  config = { ... }: {
    # Every directory here is in the memory wiki's work scope.
    modules.env.variables.LLM_WIKI_SCOPE = "work";

    system.stateVersion = 6;
  };
}
