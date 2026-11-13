# pi-setup: the parts of Pi that live in checkouts rather than the flake.
#
# Clones pi-mono and the memory wiki when missing, builds the wiki tool that
# Pi's memory extension calls, and runs pi-mono's installer, which links its
# extensions and roles into ~/.pi/agent. Quick when nothing changed; safe to
# rerun after pulling either checkout. Uses go and node from PATH.

pi_mono="${PI_MONO_DIR:-$HOME/src/pi-mono}"
wiki="${LLM_WIKI_DIR:-$HOME/.local/share/wiki}"

clone() {
  if [ ! -d "$2/.git" ]; then
    mkdir -p "$(dirname "$2")"
    git clone "$1" "$2"
  fi
}

clone git@github.com:solforged/pi-mono.git "$pi_mono"
clone git@github.com:solforged/wiki.git "$wiki"

if [ -d "$wiki/cmd/wiki" ]; then
  command -v go >/dev/null || {
    echo "pi-setup: go is not on PATH; enable modules.dev.go" >&2
    exit 1
  }
  go -C "$wiki" build -o bin/wiki ./cmd/wiki
  echo "pi-setup: built $wiki/bin/wiki"
fi

command -v node >/dev/null || {
  echo "pi-setup: node is not on PATH; enable modules.dev.node" >&2
  exit 1
}
node "$pi_mono/scripts/install.ts"
echo "pi-setup: linked pi-mono's extensions and roles into ~/.pi/agent"
