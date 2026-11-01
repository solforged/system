# Local inference

NixOS modules for NVIDIA-backed llama.cpp inference and optional Ollama.
Amarna runs Qwen 3.8 27B with on-demand 64k and 256k context services.

## Setup

The NVIDIA hardware profile supplies the driver. Enable inference and the
optional tailnet endpoint in the host configuration:

```nix
modules.ai.llama = {
  enable = true;
  tailscaleServe.enable = true;
};
modules.services.tailscale.enable = true;
```

Apply the host configuration, then [install the model weights](../../../docs/local-inference.md#model-weights).
Weights are mutable data outside the Nix store; activation does not download them.

Start a service when needed; stop it to release VRAM:

```sh
sudo systemctl start qwen-256k # or qwen-64k
sudo systemctl stop qwen-256k
```

Neither service starts at boot by default. For API model IDs, endpoints, boot
settings, Ollama and CUDA caches, see the [operations guide](../../../docs/local-inference.md).

## Develop

- [llama.nix](llama.nix): Qwen options, system units and tailnet proxy.
- [ollama.nix](ollama.nix): optional Ollama runtime.
- [cache.nix](cache.nix): CUDA binary caches.

Follow the repository [development guide](../../../docs/development.md) to build
changes before activation.
