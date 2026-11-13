# Local Parakeet dictation for Pi. Python/uv/ffmpeg are pinned by Nix;
# MLX dependencies use uv's script locks because they ship macOS wheels.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.voice;
  home = config.users.users.${config.user.name}.home;
  source = "${config.modules.dotfiles.dir}/config/voice";
  command =
    name: script:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.uv
        pkgs.ffmpeg
      ];
      text = ''
        exec uv run --no-managed-python --python ${lib.getExe pkgs.python313} \
          --locked --script ${lib.escapeShellArg "${source}/${script}.py"} \
          --config ${lib.escapeShellArg "${home}/.config/voice/config.toml"} "$@"
      '';
    };
  serve = command "voice-serve" "server";
  bench = command "voice-bench" "bench";
in
{
  options.modules.voice.enable = lib.mkEnableOption "local Apple silicon dictation";
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.system == "aarch64-darwin";
        message = "Local voice dictation requires Apple silicon (MLX).";
      }
    ];
    modules.dotfiles.configLink."voice/config.toml" = "voice/config.toml";
    hm.home.packages = [
      serve
      bench
      pkgs.ffmpeg
    ];
    launchd.user.agents.voice-stt.serviceConfig = {
      ProgramArguments = [ (lib.getExe serve) ];
      WorkingDirectory = home;
      EnvironmentVariables = {
        HOME = home;
        XDG_CACHE_HOME = "${home}/.cache";
        PYTHONDONTWRITEBYTECODE = "1";
      };
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 30;
      StandardOutPath = "${home}/Library/Logs/voice-stt.log";
      StandardErrorPath = "${home}/Library/Logs/voice-stt.log";
    };
  };
}
