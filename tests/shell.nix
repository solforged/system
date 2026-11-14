# Fast, unprivileged regression tests; no live home or macOS preferences.
{ pkgs }:
let
  # The whole directory, so config.nu finds scripts/ beside it.
  nushellConfig = ../config/nushell;
  valeVoice = pkgs.callPackage ../packages/vale-voice.nix { };
in
pkgs.runCommand "shell-and-rex-check"
  {
    nativeBuildInputs = with pkgs; [
      git
      nushell
      zsh
      python3
      zoxide
      vale
      valeVoice
    ];
  }
  ''
    export HOME="$TMPDIR/home" PYTHONDONTWRITEBYTECODE=1
    mkdir -p "$HOME"
    python ${../.}/tests/worktree-helpers.py
    python ${../.}/tests/rex-themes.py
    zsh -n ${../config/zsh/config.d/functions.zsh}
    zsh -n ${../config/zsh/config.d/aliases.zsh}
    test "$(nu -n -c 'nu-check ${nushellConfig}/config.nu')" = true
    for module in ${nushellConfig}/scripts/*.nu; do
      test "$(nu -n -c "nu-check --as-module '$module'")" = true
    done
    (cd "$HOME" && nu --config ${nushellConfig}/config.nu ${./nushell-config.nu})

    # vale-voice: a repository without a .vale.ini gets the style, its views
    # and a configuration whose rule tests pass; a refresh drops stale rules
    # and keeps the project's own test files.
    mkdir -p "$TMPDIR/config/vale"
    cp ${../config/vale/vale.ini} "$TMPDIR/config/vale/.vale.ini"
    export XDG_CONFIG_HOME="$TMPDIR/config" VALE_VOICE_SOURCE=${../config/vale/styles}
    repo="$TMPDIR/repo"
    git init -q "$repo"
    vale-voice "$repo" >/dev/null
    chmod -R u+w "$repo/.vale"
    grep -qx 'StylesPath = .vale/styles' "$repo/.vale.ini"
    grep -qx 'Voice.Spelling = YES' "$repo/.vale.ini"
    test -f "$repo/.vale/styles/config/views/UiCopy.yml"
    printf -- '- name: kept\n  input: The cache is cold.\n  want: ""\n' >"$repo/.vale/styles/Voice/local.test.yml"
    touch "$repo/.vale/styles/Voice/Stale.yml"
    vale-voice "$repo" >/dev/null
    test -f "$repo/.vale/styles/Voice/local.test.yml"
    test ! -e "$repo/.vale/styles/Voice/Stale.yml"
    (cd "$repo" && vale --no-global test --coverage .vale/styles/Voice >/dev/null)
    touch "$out"
  ''
