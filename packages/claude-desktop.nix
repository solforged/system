# Anthropic's Linux .deb, patched to run from the store. macOS hosts install
# the "claude" cask instead.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  bubblewrap,
  cairo,
  cups,
  dbus,
  expat,
  gjs,
  glib,
  gtk3,
  libGL,
  libayatana-appindicator,
  libcap_ng,
  libdrm,
  libgbm,
  libnotify,
  libpulseaudio,
  libseccomp,
  libsecret,
  libuuid,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  libxshmfence,
  libxtst,
  nspr,
  nss,
  openssh,
  pango,
  pipewire,
  socat,
  systemdLibs,
  wayland,
  xdg-utils,
}:

let
  releases = {
    x86_64-linux = {
      arch = "amd64";
      hash = "sha256-D27R8oRcMEGbhUWoMgZ210ZKGfYl4F4CkZI4qml47LQ=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-W3CutrszWz1GhO0QataMfaRP86pH/42y/v5VvegQwQs=";
    };
  };
  release = releases.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation (finalAttrs: {
  pname = "claude-desktop";
  version = "3.6556.2";

  src = fetchurl {
    url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${finalAttrs.version}_${release.arch}.deb";
    inherit (release) hash;
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libcap_ng
    libdrm
    libgbm
    libseccomp
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
    pipewire
    stdenv.cc.cc.lib
    systemdLibs
  ];

  # Chromium dlopens these at runtime.
  runtimeDependencies = [
    libGL
    libayatana-appindicator
    libnotify
    libpulseaudio
    libsecret
    libuuid
    libxshmfence
    libxtst
    systemdLibs
    wayland
  ];

  dontBuild = true;
  dontConfigure = true;
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/bin
    cp -r usr/lib/claude-desktop $out/lib/
    cp -r usr/share $out/
    rm -r $out/share/lintian

    # dpkg's postinst copies these into /usr/share; ship them in the profile.
    res=$out/lib/claude-desktop/resources
    install -Dm644 $res/linux-mime/com.anthropic.Claude.xml \
      $out/share/mime/packages/com.anthropic.Claude.xml
    install -Dm644 $res/gnome-search-provider/com.anthropic.Claude.search-provider.ini \
      $out/share/gnome-shell/search-providers/com.anthropic.Claude.search-provider.ini
    install -Dm644 $res/gnome-search-provider/com.anthropic.Claude.SearchProvider.service \
      $out/share/dbus-1/services/com.anthropic.Claude.SearchProvider.service
    substituteInPlace $out/share/dbus-1/services/com.anthropic.Claude.SearchProvider.service \
      --replace-fail /usr/bin/gjs ${lib.getExe gjs} \
      --replace-fail /usr/lib/claude-desktop $out/lib/claude-desktop

    runHook postInstall
  '';

  # bubblewrap, socat and ssh back Claude Code's sandbox and remote sessions.
  postFixup = ''
    makeWrapper $out/lib/claude-desktop/claude-desktop $out/bin/claude-desktop \
      "''${gappsWrapperArgs[@]}" \
      --suffix PATH : ${
        lib.makeBinPath [
          bubblewrap
          openssh
          socat
          xdg-utils
        ]
      }
  '';

  meta = {
    description = "Anthropic's desktop app for Claude chat, Cowork and Claude Code";
    homepage = "https://claude.ai/download";
    license = lib.licenses.unfree;
    mainProgram = "claude-desktop";
    platforms = builtins.attrNames releases;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
