# packages/omp.nix
#
# Oh My Pi from its pinned release binaries; nixpkgs has no package.
{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  patchelf,
}:

let
  releases = {
    x86_64-linux = {
      platform = "linux-x64";
      hash = "sha256-hdna86Bfx26M1CWuGQTrV2r40hzIX89GkHQmJuB8z6Q=";
    };
    aarch64-darwin = {
      platform = "darwin-arm64";
      hash = "sha256-z7teOM2PijvlXnEHAL5YfSh96qzcWMmwpmHFCGvM/lg=";
    };
  };
  release = releases.${stdenv.hostPlatform.system};
in
stdenvNoCC.mkDerivation rec {
  pname = "oh-my-pi";
  version = "18.12.6";
  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-${release.platform}";
    inherit (release) hash;
  };
  dontUnpack = true;
  dontBuild = true;
  # Stripping breaks Bun's embedded application; the binary then runs bare Bun.
  dontStrip = true;
  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
    patchelf
  ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];
  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/omp"
  ''
  # Mnemopi dlopens a downloaded onnxruntime whose RUNPATH is only $ORIGIN.
  # Preloading the C++ runtime lets glibc satisfy it by soname.
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    patchelf --add-needed libstdc++.so.6 --add-needed libgcc_s.so.1 "$out/bin/omp"
  ''
  + ''
    runHook postInstall
  '';
  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck
    test "$("$out/bin/omp" --version)" = "omp/${version}"
    runHook postInstallCheck
  '';
  meta = {
    description = "Oh My Pi coding agent";
    homepage = "https://github.com/can1357/oh-my-pi";
    license = lib.licenses.mit;
    mainProgram = "omp";
    platforms = builtins.attrNames releases;
  };
}
