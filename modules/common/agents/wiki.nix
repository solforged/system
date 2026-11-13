# modules/common/agents/wiki.nix
#
# The memory wiki that Pi and omp share: its scope, which picks the private
# bundle read beside shared, and the memory skill from the checkout. pi-setup
# clones the checkout and, for the home scope, the home bundle (docs/wiki.md).
{
  config,
  lib,
  my,
  ...
}:
let
  agents = config.modules.agents;
  cfg = agents.wiki;
in
{
  options.modules.agents.wiki.scope =
    my.mkOpt'
      (lib.types.nullOr (
        lib.types.enum [
          "shared"
          "home"
          "work"
        ]
      ))
      "home"
      "Memory wiki scope (LLM_WIKI_SCOPE) for every directory on this host. Personal hosts read and write home; atlas uses work. null leaves it to the wiki's scopes file.";

  config = lib.mkIf (agents.pi.enable || agents.omp.enable) {
    modules.env.variables = lib.mkIf (cfg.scope != null) {
      LLM_WIKI_SCOPE = cfg.scope;
    };
    hm = hm: {
      home.file.".agents/skills/memory".source =
        hm.config.lib.file.mkOutOfStoreSymlink "${hm.config.xdg.dataHome}/wiki/.agents/skills/memory";
    };
  };
}
