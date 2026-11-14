# Fast, unprivileged regression tests; no live home or macOS preferences.
{ pkgs }:
let
  # The whole directory, so config.nu finds scripts/ beside it.
  nushellConfig = ../config/nushell;
in
pkgs.runCommand "shell-and-rex-check"
  {
    nativeBuildInputs = with pkgs; [
      git
      nushell
      zsh
      python3
      zoxide
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
    touch "$out"
  ''
