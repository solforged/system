# Prebuilt editor and grammars; no Rust or grammar rebuild on a system switch.
{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
}:
let
  releases = {
    aarch64-darwin = {
      platform = "aarch64-macos";
      hash = "sha256-M6SoSeR2o+CXQaVYlwBbHF0RG4B0Q1p587u9zpcJyOM=";
    };
    x86_64-linux = {
      platform = "x86_64-linux";
      hash = "sha256-CkzLsO2ixewMcCEJcNOh1flHFQEbCwP/+dkmlnWmc6g=";
    };
    aarch64-linux = {
      platform = "aarch64-linux";
      hash = "sha256-tcXqH7HyLEDHyNbq2mWWMMlVC6HZWLwBi6ykf3iHWjg=";
    };
  };
  release = releases.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "mitos";
  version = "0.2.1";
  src = fetchurl {
    url = "https://github.com/mitos-editor/mitos/releases/download/v${finalAttrs.version}/mitos-v${finalAttrs.version}-${release.platform}.tar.xz";
    inherit (release) hash;
  };
  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optional stdenvNoCC.hostPlatform.isLinux autoPatchelfHook;
  buildInputs = lib.optional stdenvNoCC.hostPlatform.isLinux stdenv.cc.cc.lib;
  dontBuild = true;
  # Leave the signed Darwin binary and grammar libraries untouched.
  dontStrip = stdenvNoCC.hostPlatform.isDarwin;
  dontPatchELF = stdenvNoCC.hostPlatform.isDarwin;
  installPhase = ''
    runHook preInstall
    install -Dm755 ms "$out/libexec/mitos/ms"
    mkdir -p "$out/share/mitos" "$out/bin"
    cp -r runtime "$out/share/mitos/"
    makeWrapper "$out/libexec/mitos/ms" "$out/bin/ms" \
      --set MITOS_RUNTIME "$out/share/mitos/runtime"
    install -Dm644 LICENSE "$out/share/licenses/mitos/LICENSE"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/ms" --version
    test -d "$out/share/mitos/runtime/grammars"
    test -f "$out/share/mitos/runtime/queries/rust/highlights.scm"
    runHook postInstallCheck
  '';
  meta = {
    description = "Modal terminal editor based on Helix";
    homepage = "https://github.com/mitos-editor/mitos";
    license = lib.licenses.mpl20;
    mainProgram = "ms";
    platforms = builtins.attrNames releases;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
