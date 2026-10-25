# Linux-only helpers. macOS already detaches `open`, and its find lacks -printf.
[[ $OSTYPE == linux* ]] || return 0

# Detach GUI opens from the shell.
if command -v xdg-open >/dev/null 2>&1; then
  open() {
    xdg-open "$@" >/dev/null 2>&1 &
  }
fi

# Pick a recently modified file with ff and scp it to a destination.
sff() {
  if (( $# == 0 )); then
    echo "Usage: sff <destination> (e.g. sff host:/tmp/)"
    return 1
  fi
  local file
  file=$(find . -type f -printf '%T@\t%p\n' 2>/dev/null | sort -rn | cut -f2- | ff)
  [[ -n "$file" ]] && scp "$file" "$1"
}

# Rsync-on-change watchers: rsw starts one in the background, lsw lists, dsw stops.
rsw() {
  (( $# != 2 )) && echo "Usage: rsw <source> <destination>" && return 1
  local src="${1%/}" dest="$2"
  # Reuse one SSH connection per watcher instead of reconnecting for every sync.
  local sockets="${XDG_RUNTIME_DIR:-$HOME/.ssh/sockets}"
  mkdir -p "$sockets"
  local rsh="ssh -o ControlMaster=auto -o ControlPath=$sockets/rsw-%r@%h:%p -o ControlPersist=yes"
  setsid --fork env RSYNC_RSH="$rsh" bash -c 'rsync -a "$1/" "$2"; while inotifywait -r -q -e modify,create,delete,move "$1"; do rsync -a "$1/" "$2"; done' rsw-watch "$src" "$dest" >/dev/null 2>&1
  echo "Watching $src -> $dest"
}

lsw() {
  local pid cmd rest found=0
  while read -r pid cmd; do
    rest="${cmd##*rsw-watch }"
    echo "$pid: ${rest% *} -> ${rest##* }"
    found=1
  done < <(pgrep -af 'rsw-watch ')
  (( found )) || echo "No active watches"
}

dsw() {
  local pid found=0
  for pid in $(pgrep -f 'rsw-watch '); do
    kill -- -"$pid" 2>/dev/null && echo "Stopped watch (pid $pid)" && found=1
  done
  (( found )) || echo "No active watches"
}
