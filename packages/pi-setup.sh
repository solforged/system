# pi-setup: the parts of Pi that live in checkouts rather than the flake.
#
# Clones pi-mono and the memory wiki when missing, and the wiki's home bundle
# when the host's scope is home. Builds the wiki tool that Pi's memory
# extension calls, and runs pi-mono's installer, which links its extensions
# and roles into ~/.pi/agent. Quick when nothing changed; safe to rerun after
# pulling a checkout. Uses go and node from PATH.

pi_mono="${PI_MONO_DIR:-$HOME/src/pi-mono}"
wiki="${LLM_WIKI_DIR:-$HOME/.local/share/wiki}"
scope="${LLM_WIKI_SCOPE:-}"

clone() {
  if [ ! -d "$2/.git" ]; then
    mkdir -p "$(dirname "$2")"
    git clone "$1" "$2"
  fi
}

clone git@github.com:solforged/pi-mono.git "$pi_mono"
clone git@github.com:solforged/wiki.git "$wiki"

# The home bundle is its own private repository, shared by personal hosts.
# The work bundle is linked in by the private work flake, never cloned here.
case "$scope" in
  home)
    if [ ! -e "$wiki/home" ]; then
      clone "${WIKI_HOME_REMOTE:-git@github.com:solforged/wiki-home.git}" "$wiki/home"
    elif [ ! -d "$wiki/home/.git" ]; then
      echo "pi-setup: $wiki/home is not a Git checkout; move it aside and rerun to clone it" >&2
    fi
    ;;
  work)
    [ -e "$wiki/work" ] ||
      echo "pi-setup: $wiki/work is missing; the work flake links it (docs/atlas.md)" >&2
    ;;
esac

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
