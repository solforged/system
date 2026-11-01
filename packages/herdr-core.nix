{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  releases = {
    x86_64-linux = {
      platform = "linux-x86_64";
      hash = "sha256-WNaGEXbcb+kFtYiA1b/weplZvmE6mOXWa0WDsEts+kU=";
    };
    aarch64-darwin = {
      platform = "macos-aarch64";
      hash = "sha256-aY2PDET05LFf7BdNUqOdV6AUz9ca3e1EtToHU7Rp0P0=";
    };
  };
  release = releases.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "herdr-core";
  version = "0.1.16";

  src = fetchurl {
    url = "https://releases.herdr.dev/core/${finalAttrs.version}/herdr-core-${release.platform}.tar.gz";
    inherit (release) hash;
  };

  sourceRoot = ".";
  dontBuild = true;
  # Preserve the upstream signature on macOS.
  dontFixup = stdenvNoCC.hostPlatform.isDarwin;

  installPhase = ''
    runHook preInstall
    install -Dm755 herdr-core "$out/bin/herdr-core"
    ln -s herdr-core "$out/bin/hc"
    install -Dm644 LICENSE "$out/share/doc/herdr-core/LICENSE"
    install -Dm644 THIRD-PARTY-NOTICES "$out/share/doc/herdr-core/THIRD-PARTY-NOTICES"
    runHook postInstall
  '';

  meta = {
    description = "Persistent terminal runtime for the Herdr desktop app";
    homepage = "https://github.com/herdrdev/herdr-core";
    license = lib.licenses.asl20;
    mainProgram = "hc";
    platforms = builtins.attrNames releases;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
