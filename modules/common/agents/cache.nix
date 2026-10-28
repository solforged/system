# modules/common/agents/cache.nix
#
# The agents come from the llm-agents input, which builds several of them from
# source (omp is Rust and Bun). Numtide's cache serves them prebuilt as long as
# that input's nixpkgs is left unfollowed in flake.nix.
{
  config,
  lib,
  isDarwin,
  ...
}:
let
  agents = config.modules.agents;
  cache = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };
in
{
  config = lib.mkIf (agents.claude.enable || agents.omp.enable || agents.pi.enable) (
    # Determinate Nix owns nix.conf on Macs; see modules/darwin/default.nix.
    if isDarwin then { determinateNix.customSettings = cache; } else { nix.settings = cache; }
  );
}
