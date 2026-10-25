# modules/nixos/ai/ollama.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.ai.ollama;
in
{
  options.modules.ai.ollama.enable = lib.mkEnableOption "optional CUDA Ollama inference";

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      package = pkgs.ollama-cuda;
      host = "127.0.0.1";
    };

    # Keep Ollama available on demand without competing for VRAM at boot.
    # Starting either runtime stops the other before loading its model.
    systemd.services.ollama = {
      wantedBy = lib.mkForce [ ];
      conflicts = [
        "qwen-64k.service"
        "qwen-256k.service"
      ];
    };
  };
}
