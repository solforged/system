# modules/common/agents/skills.nix
#
# Skills in ~/.agents/skills, which Pi and omp both read. The authored ones
# live in config/agents/skills; the memory skill comes from the wiki checkout
# (pi-setup clones it). Apps that ship their own skills, such as Rex and
# terminal-browser, install them there themselves.
{
  config,
  lib,
  ...
}:
let
  agents = config.modules.agents;
in
{
  config = lib.mkIf (agents.pi.enable || agents.omp.enable) {
    modules.dotfiles.homeLink = {
      ".agents/skills/humanizer" = "agents/skills/humanizer";
      ".agents/skills/visual-debugging" = "agents/skills/visual-debugging";
    };
    hm = hm: {
      home.file.".agents/skills/memory".source =
        hm.config.lib.file.mkOutOfStoreSymlink "${hm.config.xdg.dataHome}/wiki/.agents/skills/memory";
    };
  };
}
