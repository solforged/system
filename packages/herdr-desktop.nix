{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  addDriverRunpath,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  libxcb,
  libxkbcommon,
  libglvnd,
  vulkan-loader,
  wayland,
  curl,
  openssh,
  xdg-utils,
  herdr-core,
}:
let
  releases = {
    x86_64-linux = {
      platform = "linux-x86_64";
      hash = "sha256-Ro/zFqJvxMLGOPEMWNLeNTyCXKxNhG+iVMYSlBQXRKM=";
    };
    aarch64-darwin = {
      platform = "macos-aarch64";
      hash = "sha256-fE5zGMVLvL8XX/1tG09hi1kTc4MzCv+OtbwQ3D/u7Lk=";
    };
  };
  release = releases.${stdenv.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "herdr-desktop";
  version = "0.1.11";

  src = fetchurl {
    url = "https://releases.herdr.dev/app/${finalAttrs.version}/herdr-app-${release.platform}.tar.gz";
    inherit (release) hash;
  };

  sourceRoot = ".";
  dontBuild = true;
  # The signed Mac bundle must remain byte-for-byte intact.
  dontFixup = stdenv.hostPlatform.isDarwin;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
    copyDesktopItems
  ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    libxcb
    libxkbcommon
  ];
  # GPUI loads these with dlopen. Keep them in RUNPATH, not an inherited
  # LD_LIBRARY_PATH that would affect shells and agents launched by the app.
  runtimeDependencies = lib.optionals stdenv.hostPlatform.isLinux [
    libglvnd
    vulkan-loader
    wayland
  ];
  appendRunpaths = lib.optionals stdenv.hostPlatform.isLinux [
    "${addDriverRunpath.driverLink}/lib"
  ];

  desktopItems = lib.optionals stdenv.hostPlatform.isLinux [
    (makeDesktopItem {
      name = "herdr-app";
      desktopName = "Herdr";
      comment = "Terminals and coding agents that keep running";
      exec = "herdr-app";
      icon = "herdr-app";
      categories = [ "Development" ];
      startupWMClass = "herdr-app";
    })
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    mkdir -p "$out/Applications"
    cp -R Herdr.app "$out/Applications/"
    makeWrapper "$out/Applications/Herdr.app/Contents/MacOS/Herdr" "$out/bin/herdr-app" \
      --prefix PATH : ${
        lib.makeBinPath [
          herdr-core
          curl
          openssh
        ]
      }
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    install -Dm755 herdr-app/herdr-app "$out/libexec/herdr-app"
    install -Dm644 herdr-app/herdr-app.svg "$out/share/icons/hicolor/scalable/apps/herdr-app.svg"
    install -Dm644 herdr-app/LICENSE "$out/share/doc/herdr-desktop/LICENSE"
    install -Dm644 herdr-app/THIRD-PARTY-NOTICES "$out/share/doc/herdr-desktop/THIRD-PARTY-NOTICES"
    makeWrapper "$out/libexec/herdr-app" "$out/bin/herdr-app" \
      --prefix PATH : ${
        lib.makeBinPath [
          herdr-core
          curl
          openssh
          xdg-utils
        ]
      }
  ''
  + ''
    runHook postInstall
  '';

  meta = {
    description = "Herdr desktop app for persistent terminals and coding agents";
    homepage = "https://github.com/herdrdev/herdr-app";
    license = lib.licenses.asl20;
    mainProgram = "herdr-app";
    platforms = builtins.attrNames releases;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
