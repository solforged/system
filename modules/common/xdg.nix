# modules/common/xdg.nix
#
# XDG base directories, and tool homes moved under them so $HOME stays clean.
{ ... }:

{
  modules.env = {
    variables = {
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";

      BUN_INSTALL = "$HOME/.local/share/bun";
      CARGO_HOME = "$HOME/.local/share/cargo";
      CODEX_HOME = "$HOME/.local/share/codex";
      DOCKER_CONFIG = "$HOME/.config/docker";
      GEM_SPEC_CACHE = "$HOME/.cache/gem";
      GNUPGHOME = "$HOME/.local/share/gnupg";
      GOBIN = "$HOME/.local/share/go/bin";
      GOPATH = "$HOME/.local/share/go";
      GRADLE_USER_HOME = "$HOME/.local/share/gradle";
      MPLCONFIGDIR = "$HOME/.config/matplotlib";
      PUB_CACHE = "$HOME/.cache/pub-cache";
      RUSTUP_HOME = "$HOME/.local/share/rustup";
      npm_config_cache = "$HOME/.cache/npm";
    };

    path = [
      "$HOME/.local/bin"
      "$HOME/.local/share/cargo/bin"
      "$HOME/.local/share/go/bin"
      "$HOME/.local/share/bun/bin"
    ];
  };
}
