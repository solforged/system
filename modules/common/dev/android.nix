{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.dev.android;
  android = pkgs.androidenv.composeAndroidPackages {
    # Match Flutter's compile SDK and NDK. Images and the emulator stay project-specific.
    platformVersions = [ "36" ];
    buildToolsVersions = [ "36.0.0" ];
    includeNDK = true;
    ndkVersions = [ "28.2.13676358" ];
    cmakeVersions = [ "3.22.1" ];
    includeEmulator = false;
    includeSystemImages = false;
    toolsVersion = null;
  };
  sdk = "${android.androidsdk}/libexec/android-sdk";
in
{
  options.modules.dev.android.enable = lib.mkEnableOption "Android and Flutter development";

  config = lib.mkIf cfg.enable {
    nixpkgs.config.android_sdk.accept_license = true;
    hm.home.packages = [
      # cmdline-tools also ships `bin/android`, a launcher that downloads the
      # CLI at runtime. The pinned package wins.
      (lib.hiPrio pkgs.android-cli)
      android.androidsdk
      pkgs.flutter
      pkgs.jdk21
    ];
    modules.env.variables = {
      ANDROID_HOME = sdk;
      ANDROID_SDK_ROOT = sdk;
      JAVA_HOME = "${pkgs.jdk21.home}";
    };
  };
}
