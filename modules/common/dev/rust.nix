{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.dev.rust;
in
{
  options.modules.dev.rust.enable = lib.mkEnableOption "Rust development";

  config = lib.mkIf cfg.enable {
    hm.home.packages = [
      # The NixOS patch repairs downloaded toolchains. Project toolchain files still apply.
      # Dedicated tools such as rust-analyzer take precedence over rustup's proxies.
      (lib.lowPrio pkgs.rustup)
      pkgs.sccache
      # Run by hand to prune stale target/ artifacts.
      pkgs.cargo-sweep
    ];
    modules.env.variables.RUSTC_WRAPPER = lib.getExe pkgs.sccache;
  };
}
