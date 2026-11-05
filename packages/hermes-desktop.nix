# Upstream's desktop derivation supplies an XDG launcher, but no macOS bundle.
# Keep its renderer, native modules and Electron runtime together.
{
  lib,
  stdenv,
  hermes,
}:
let
  system = stdenv.hostPlatform.system;
  upstreamPkgs = import hermes.inputs.nixpkgs { inherit system; };
  agent = hermes.packages.${system}.default;
in
hermes.packages.${system}.desktop.overrideAttrs (old: {
  nativeBuildInputs = old.nativeBuildInputs ++ [ upstreamPkgs.nodejs ];

  postInstall = (old.postInstall or "") + ''
    app="$out/Applications/Hermes.app"
    mkdir -p "$out/Applications"
    cp -R ${upstreamPkgs.electron.dist}/Electron.app "$app"
    chmod -R u+w "$app"
    mv "$app/Contents/MacOS/Electron" "$app/Contents/MacOS/Hermes"
    rm "$app/Contents/Resources/default_app.asar"
    mv "$out/share/hermes-desktop" "$app/Contents/Resources/app"
    chmod -R u+w "$app/Contents/Resources/app"
    ln -s "$app/Contents/Resources/app" "$out/share/hermes-desktop"
    cp ${hermes}/apps/desktop/assets/icon.icns "$app/Contents/Resources/icon.icns"

    # Finder supplies no shell environment. Select the same backend as the CLI.
    main="$app/Contents/Resources/app/dist/electron-main.mjs"
    {
      printf '%s\n' \
        'process.env.HERMES_DESKTOP_HERMES ||= ${builtins.toJSON (lib.getExe agent)};' \
        'process.env.ELECTRON_IS_DEV = "0";'
      cat "$main"
    } > "$main.nix"
    mv "$main.nix" "$main"

    # Reuse upstream's identity, URL scheme and privacy-purpose descriptions.
    node -e 'const c = require(process.argv[1]); console.log(JSON.stringify(c))' \
      ${hermes}/apps/desktop/electron-builder.config.cjs > "$TMPDIR/hermes-bundle.json"
    python3 - "$app" "$TMPDIR/hermes-bundle.json" <<'PY'
    import json
    import pathlib
    import plistlib
    import sys

    app = pathlib.Path(sys.argv[1])
    config = json.loads(pathlib.Path(sys.argv[2]).read_text())
    info_path = app / "Contents/Info.plist"
    with info_path.open("rb") as source:
        info = plistlib.load(source)
    info.update(config["mac"]["extendInfo"])
    info.update({
        "CFBundleIdentifier": config["appId"],
        "CFBundleIconFile": "icon.icns",
        "CFBundleShortVersionString": "${agent.version}",
        "CFBundleVersion": "${agent.version}",
        "LSApplicationCategoryType": config["mac"]["category"],
        "LSMinimumSystemVersion": config["mac"]["minimumSystemVersion"],
        "CFBundleURLTypes": [
            {"CFBundleURLName": protocol["name"],
             "CFBundleURLSchemes": protocol["schemes"],
             "CFBundleTypeRole": "Editor"}
            for protocol in config["protocols"]
        ],
    })
    with info_path.open("wb") as destination:
        plistlib.dump(info, destination)
    PY

    rm "$out/bin/hermes-desktop"
    makeWrapper "$app/Contents/MacOS/Hermes" "$out/bin/hermes-desktop"
    /usr/bin/codesign --force --deep --sign - "$app"
  '';
})
