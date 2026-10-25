# modules/nixos/ai/cache.nix
{ config, lib, ... }:

{
  config = lib.mkIf (config.modules.ai.llama.enable || config.modules.ai.ollama.enable) {
    # Keep the standard CUDA variants so their store paths can match the caches.
    # The cuda-maintainers Cachix jobset moved to nix-community.
    nix.settings = {
      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos-cuda.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      ];
    };
  };
}
