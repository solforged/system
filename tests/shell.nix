# Fast, unprivileged regression tests; no live home or macOS preferences.
{ pkgs }:
pkgs.runCommand "shell-and-rex-check"
  {
    nativeBuildInputs = with pkgs; [
      git
      nushell
      zsh
      python3
    ];
  }
  ''
    export HOME="$TMPDIR/home" PYTHONDONTWRITEBYTECODE=1
    mkdir -p "$HOME"
    python ${../.}/tests/worktree-helpers.py
    python ${../.}/tests/rex-themes.py
    zsh -n ${../config/zsh/config.d/functions.zsh}
    zsh -n ${../config/zsh/config.d/aliases.zsh}
    test "$(nu -n -c 'nu-check ${../config/nushell/config.nu}')" = true
    touch "$out"
  ''
