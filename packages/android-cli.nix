{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  jdk25,
  makeWrapper,
  python3,
}:
let
  releases = {
    x86_64-linux = {
      platform = "linux_x86_64";
      hash = "sha256-s07Quu7/oqruJyDYJJG5dYNWluLlaEBEkHi+yIVDZWQ=";
    };
    aarch64-darwin = {
      platform = "darwin_arm64";
      hash = "sha256-6cbhn17YFC4ol+C2i0duF2hjPldAqlS/wjR2fMJkAf4=";
    };
  };
  release = releases.${stdenv.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "android-cli";
  version = "1.1.16717390";

  src = fetchurl {
    # The small `android` launcher downloads this payload at runtime.
    url = "https://dl.google.com/android/cli/${finalAttrs.version}/${release.platform}/android-cli";
    inherit (release) hash;
  };

  dontUnpack = true;
  dontBuild = true;
  nativeBuildInputs = [
    makeWrapper
    python3
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    # The release embeds a ZIP inside its native launcher. Use Nix's JVM instead.
    python3 - "$src" "$out/share/android-cli" <<'PY'
    import io
    import pathlib
    import struct
    import sys
    import zipfile

    data = pathlib.Path(sys.argv[1]).read_bytes()
    pos = 0
    while (pos := data.find(b"PK\x05\x06", pos)) != -1:
        _, disk, cd_disk, disk_count, count, size, offset, comment = struct.unpack_from(
            "<4s4H2IH", data, pos
        )
        start = pos - size - offset
        end = pos + 22 + comment
        if (
            disk == cd_disk == 0
            and disk_count == count
            and start >= 0
            and end <= len(data)
            and data[start:start + 4] == b"PK\x03\x04"
            and data[pos - size:pos - size + 4] == b"PK\x01\x02"
        ):
            with zipfile.ZipFile(io.BytesIO(data[start:end])) as archive:
                for member in archive.namelist():
                    if member == "main.jar" or member.startswith("lib/"):
                        archive.extract(member, sys.argv[2])
            break
        pos += 4
    else:
        raise RuntimeError("Android CLI embedded ZIP not found")
    PY
    makeWrapper ${jdk25}/bin/java "$out/bin/android" \
      --add-flags "--enable-native-access=ALL-UNNAMED" \
      --add-flags "-Djava.library.path=$out/share/android-cli/lib" \
      --add-flags '-Dandroid.cli.dir="''${ANDROID_USER_HOME:-$HOME/.android}/cli"' \
      --add-flags "-Dandroid.cli.exe=$out/bin/android" \
      --add-flags "-jar $out/share/android-cli/main.jar"
    runHook postInstall
  '';

  meta = {
    description = "Google Android development CLI";
    homepage = "https://developer.android.com/";
    license = lib.licenses.unfree;
    mainProgram = "android";
    platforms = builtins.attrNames releases;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
