# Linux-only helpers. macOS already detaches `open`.
[[ $OSTYPE == linux* ]] || return 0

# Detach GUI opens from the shell.
if command -v xdg-open >/dev/null 2>&1; then
  open() {
    xdg-open "$@" >/dev/null 2>&1 &
  }
fi
