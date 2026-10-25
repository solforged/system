# Local inference

## Amarna

Enable the following host modules. The NVIDIA hardware profile supplies the
Blackwell driver.

```nix
modules.ai.llama = {
  enable = true;
  tailscaleServe.enable = true;
};
modules.services.tailscale.enable = true;
```

Both services run **Qwen 3.8 27B**. The context size is the maximum conversation
window, including input and generated output.

| Context | System service | API model ID | Local endpoint | Starts at boot |
| --- | --- | --- | --- | --- |
| 64k (65,536 tokens) | `qwen-64k` | `qwen3.8-27b-64k` | `127.0.0.1:8080` | No |
| 256k (262,144 tokens) | `qwen-256k` | `qwen3.8-27b-256k` | `127.0.0.1:8081` | Yes |

OMP shows **Qwen 3.8 27B (256k context)** through the local `llama.cpp` provider
or the remote `amarna` provider. Both connect to the same 256k service.
Other API clients should use the model IDs above.

When activating these names, update external clients' saved model IDs and any
service-management scripts at the same time. Previous API IDs and service
names are not retained as aliases. Deploy the OMP model configuration together
with the server change, then refresh its model catalog.

Start the optional 64k service with `sudo systemctl start qwen-64k`.
These are system units, not user units. Both keep one inference slot,
Flash Attention, full GPU offload, Jinja templates and preserved reasoning.
Multi-token prediction (MTP) accelerates generation with two-token drafts;
it is an inference setting, not a separate model variant.
Both services can fit the 96 GB GPU together, but their combined VRAM use is
substantial.

The package is nixpkgs `llama-cpp-cuda`, not an Ollama runner. The locked
llama.cpp 0.6.0 source implements
[`--spec-type` and `--spec-draft-n-max`](https://github.com/ggml-org/llama.cpp/blob/v0.6.0/common/arg.cpp)
and the
[`draft-mtp` implementation](https://github.com/ggml-org/llama.cpp/blob/v0.6.0/common/speculative.cpp).
No separate ggml, CUDA toolkit or NCCL installation is needed for this
single-GPU service. Its package closure supplies the runtime libraries.

## Model migration

Weights are mutable data outside the Nix store. The default path is
`/var/lib/llama-models/qwen3.8-27b-q8_0.gguf`. Use the existing Qwen 3.8 27B
Q8_0 GGUF with the embedded MTP head. This is not the FP8 model.

After the first activation creates the `llama` group, copy the existing blob:

```sh
sudo install -d -m 0750 -o root -g llama /var/lib/llama-models
sudo cp --reflink=auto \
  /home/sol/.ollama/models/blobs/sha256-31756fca94beca71ea4b8706d6fdc896dab2a3c6376ab0c1863b98512a24f8d6 \
  /var/lib/llama-models/qwen3.8-27b-q8_0.gguf
sudo chown root:llama /var/lib/llama-models/qwen3.8-27b-q8_0.gguf
sudo chmod 0640 /var/lib/llama-models/qwen3.8-27b-q8_0.gguf
sudo systemctl restart qwen-256k
```

Preserve the blob on backup or external storage before reinstalling the host.
Copy or reflink instead of symlinking into a home directory: service hardening
hides home directories. `modules.ai.llama.modelPath` can select a different
absolute path; arrange parent-directory traversal and read permission for the
`llama` group yourself. No model download or conversion runs during activation.
The server fails visibly until its model is present.

## Tailnet endpoint

`modules.ai.llama.tailscaleServe.enable` manages
`qwen-tailscale-serve.service`. It sets up tailnet-only HTTPS on port 443,
proxying to `127.0.0.1:8081`. It never enables Funnel and does not open inference
ports in the host firewall. On amarna, clients use
`https://amarna.ussuri-alphard.ts.net/v1`.

Authenticate the NixOS host with Tailscale and enable HTTPS certificates for the
tailnet before starting this unit. Hostname and tailnet DNS determine the
certificate name; keep the node name `amarna` for existing clients. This unit
owns the root HTTPS handler on port 443. Do not configure another Serve
application at that address. Stopping or disabling the unit removes that
handler without resetting unrelated Serve configuration. After manually
switching back from Ollama, start `qwen-tailscale-serve` to restore the endpoint.
The endpoint has no application API key. Tailnet access policy controls access.

## Optional Ollama

`modules.ai.ollama.enable = true` installs the CUDA Ollama service and CLI on
loopback port 11434. The service is not enabled at boot. Start it with
`sudo systemctl start ollama`. It stores its own models under
`/var/lib/ollama/models`, independently of the Qwen GGUF. Starting Ollama stops
both Qwen units; starting either Qwen unit stops Ollama. This prevents an
accidental competing model allocation. Leave this module disabled on amarna
unless Ollama's model management is wanted.

## CUDA caches and vLLM

Either inference module adds the
[nix-community cache](https://nix-community.org/cache/) and the
[NixOS CUDA cache](https://wiki.nixos.org/wiki/CUDA#Setting_up_CUDA_Binary_Cache),
with their signing keys. The old cuda-maintainers Cachix jobset has moved to
nix-community. Cache hits depend on the locked nixpkgs revision. Keep the
standard package variants rather than narrowing CUDA architectures per host,
which would change their store paths.

The new cache settings take effect only after activation. For the initial
build, pass `--option extra-substituters
'https://nix-community.cachix.org https://cache.nixos-cuda.org'` and
`--option extra-trusted-public-keys
'nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M='` to Nix.
A missing substitute still requires a build; these caches do not guarantee
that every revision is available.

The separate vLLM FP8 task is deliberately dropped. Qwen's managed GGUF
runtime already covers the two required context windows and API model IDs. A
second runtime would add a separate set of FP8 weights and a large
PyTorch/CUDA closure. The existing vLLM installation was not importable, so an
unmanaged `uv tool` plus `nix-ld` is not treated as a working migration. No
floating Python environment or globally enabled `nixpkgs.config.cudaSupport`
is introduced.
