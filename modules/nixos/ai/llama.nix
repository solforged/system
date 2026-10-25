# modules/nixos/ai/llama.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.ai.llama;
  modelDirectory = builtins.dirOf cfg.modelPath;
  mkServer =
    {
      contextSize,
      port,
      alias,
      autoStart,
    }:
    {
      description = "Qwen 3.8 27B (${toString (builtins.div contextSize 1024)}k context)";
      wantedBy = lib.optional autoStart "multi-user.target";
      after = [ "ollama.service" ];
      conflicts = [ "ollama.service" ];
      environment = {
        CUDA_VISIBLE_DEVICES = "0";
        CUDA_CACHE_PATH = "/var/cache/llama/cuda";
        HOME = "/var/lib/llama";
      };
      serviceConfig = {
        Type = "exec";
        User = "llama";
        Group = "llama";
        SupplementaryGroups = [
          "render"
          "video"
        ];
        StateDirectory = "llama";
        CacheDirectory = "llama";
        WorkingDirectory = "/var/lib/llama";
        ExecStart = lib.escapeShellArgs [
          "${cfg.package}/bin/llama-server"
          "--model"
          cfg.modelPath
          "-ngl"
          "999"
          "-c"
          (toString contextSize)
          "-np"
          "1"
          "-fa"
          "on"
          "--spec-type"
          "draft-mtp"
          "--spec-draft-n-max"
          "2"
          "--alias"
          alias
          "--jinja"
          "--reasoning"
          "auto"
          "--reasoning-format"
          "deepseek"
          "--reasoning-preserve"
          "--host"
          "127.0.0.1"
          "--port"
          (toString port)
          "--no-webui"
          "--offline"
        ];
        Restart = "on-failure";
        RestartSec = 3;
        TimeoutStopSec = 120;
        UMask = "0077";
        NoNewPrivileges = true;
        CapabilityBoundingSet = "";
        PrivateTmp = true;
        PrivateDevices = false;
        DevicePolicy = "closed";
        DeviceAllow = [
          "char-nvidiactl"
          "char-nvidia-caps"
          "char-nvidia-frontend"
          "char-nvidia-uvm"
        ];
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadOnlyPaths = [ modelDirectory ];
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        LockPersonality = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        SystemCallArchitectures = "native";
        # CUDA can JIT executable code. Do not enable MemoryDenyWriteExecute.
      };
    };
in
{
  options.modules.ai.llama = {
    enable = lib.mkEnableOption "local Qwen 3.8 27B inference";
    package = lib.mkPackageOption pkgs "llama-cpp-cuda" {
      extraDescription = ''
        Must support --spec-type draft-mtp and --spec-draft-n-max.
        The locked nixpkgs llama.cpp 0.6.0 implements both flags.
      '';
    };
    modelPath = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/llama-models/qwen3.8-27b-q8_0.gguf";
      description = ''
        Absolute path to the Qwen 3.8 27B Q8_0 GGUF with an embedded MTP head.
        Keep weights outside the Nix store, readable by the llama group.
        Home directories are hidden from the services. See README.md in this
        module directory for the Ollama blob migration commands.
      '';
    };
    start64k = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Start Qwen 3.8 27B with 64k context at boot (qwen-64k, loopback port 8080).";
    };
    start256k = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Qwen 3.8 27B with 256k context at boot (qwen-256k, loopback port 8081).";
    };
    tailscaleServe.enable = lib.mkEnableOption "tailnet-only HTTPS for Qwen 3.8 27B with 256k context";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.modelPath;
        message = "modules.ai.llama.modelPath must be an absolute path.";
      }
      {
        assertion = !cfg.tailscaleServe.enable || config.services.tailscale.enable;
        message = "modules.ai.llama.tailscaleServe requires services.tailscale.enable.";
      }
    ];

    environment.systemPackages = [ cfg.package ];
    users.groups.llama = { };
    users.users.llama = {
      isSystemUser = true;
      group = "llama";
      home = "/var/lib/llama";
    };
    systemd.tmpfiles.rules = [ "d /var/lib/llama-models 0750 root llama -" ];
    systemd.services = {
      qwen-64k = mkServer {
        contextSize = 65536;
        port = 8080;
        alias = "qwen3.8-27b-64k";
        autoStart = cfg.start64k;
      };
      qwen-256k = mkServer {
        contextSize = 262144;
        port = 8081;
        alias = "qwen3.8-27b-256k";
        autoStart = cfg.start256k;
      };
      qwen-tailscale-serve = lib.mkIf cfg.tailscaleServe.enable {
        description = "Qwen 3.8 27B (256k context) tailnet HTTPS endpoint";
        wantedBy = [ "multi-user.target" ];
        requires = [
          "tailscaled.service"
          "qwen-256k.service"
        ];
        after = [
          "tailscaled.service"
          "tailscaled-autoconnect.service"
          "qwen-256k.service"
        ];
        partOf = [ "tailscaled.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${config.services.tailscale.package}/bin/tailscale serve --yes --bg --https=443 http://127.0.0.1:8081";
          ExecStop = "${config.services.tailscale.package}/bin/tailscale serve --yes --https=443 off";
          Restart = "on-failure";
          RestartSec = 5;
          NoNewPrivileges = true;
          CapabilityBoundingSet = "";
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
          ];
        };
      };
    };
  };
}
