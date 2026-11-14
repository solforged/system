# Vendor the Voice prose style into a repository, so the project's Vale run
# needs nothing outside the checkout (CI, other machines, --no-global).
# Usage: vale-voice [repo]
#
# Copies styles/Voice and the shared views (Commit, UiCopy) from the live
# style, ~/.local/share/vale/styles (VALE_VOICE_SOURCE overrides), into the
# repository's StylesPath. Rerun it to refresh the copy. A repository without
# a .vale.ini gets one: the global configuration with StylesPath set to
# .vale/styles and the spelling rules on. Test files (*.test.yml) a project
# keeps beside the rules survive a refresh.

case ${1-} in -h | --help)
  cat <<'EOF'
usage: vale-voice [repo]

Copies the Voice prose style and its views into the repository's Vale
StylesPath; writes a .vale.ini, from the global one, where there is none.
Rerun to refresh. VALE_VOICE_SOURCE overrides ~/.local/share/vale/styles.
EOF
  exit 0
  ;;
-*)
  echo "usage: vale-voice [repo]" >&2
  exit 2
  ;;
esac
[ $# -le 1 ] || {
  echo "usage: vale-voice [repo]" >&2
  exit 2
}

source=${VALE_VOICE_SOURCE:-$HOME/.local/share/vale/styles}
global=${XDG_CONFIG_HOME:-$HOME/.config}/vale/.vale.ini
root=$(git -C "${1:-.}" rev-parse --show-toplevel) || {
  echo "vale-voice: ${1:-.} is not in a Git repository" >&2
  exit 1
}
if [ ! -f "$source/Voice/Brief.md" ]; then
  echo "vale-voice: no Voice style at $source/Voice" >&2
  exit 1
fi

config=$root/.vale.ini
if [ -f "$config" ]; then
  styles=$(awk -F= '/^[[:space:]]*StylesPath[[:space:]]*=/ { sub(/^[[:space:]]+/, "", $2); sub(/[[:space:]]+$/, "", $2); print $2; exit }' "$config")
  if [ -z "$styles" ]; then
    echo "vale-voice: $config sets no StylesPath; add one, such as .vale/styles" >&2
    exit 1
  fi
  created=""
else
  if [ ! -f "$global" ]; then
    echo "vale-voice: no global configuration at $global to start from" >&2
    exit 1
  fi
  styles=.vale/styles
  {
    echo "# Prose checks with the Voice house style, vendored by vale-voice from the"
    echo "# system checkout; rerun vale-voice to refresh it. The house standard is"
    echo "# $styles/Voice/Brief.md. Lint with --no-global so the result does not"
    echo "# depend on the machine's own configuration."
    echo "StylesPath = $styles"
    # The global file's body, after its header comment, with the spelling
    # rules turned on: a vendored copy carries its dictionaries.
    awk '
      !body && /^#/ { next }
      { body = 1; print }
      /^\[\*\.\{md,mdx\}\]$/ { print "Voice.Spelling = YES"; print "Voice.SpellingCompound = YES" }
    ' "$global"
  } >"$config"
  created=1
fi
case $styles in /*) target=$styles ;; *) target=$root/$styles ;; esac

mkdir -p "$target/Voice" "$target/config/views"
rsync -a --delete --filter='P *.test.yml' "$source/Voice/" "$target/Voice/"
rsync -a "$source/config/views/" "$target/config/views/"

echo "vale-voice: copied Voice and its views into $styles"
[ -z "$created" ] || echo "vale-voice: wrote .vale.ini from $global"
echo "Next: vale --no-global test --coverage $styles/Voice, then lint with --no-global."
echo "Project words go in a vocabulary: Vocab = <Name> and $styles/config/vocabularies/<Name>/accept.txt."
