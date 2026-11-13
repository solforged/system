# system-bump: update flake inputs, check the result, and commit flake.lock.
#
#   system-bump [options] [input...]
#
# With no inputs, every input is updated. The lock is checked by building this
# host (nh), or with --eval-only by evaluating every host, check and package
# (CI). A failed check restores the previous lock. --verify runs only that
# evaluation, without updating anything. The commit follows
# the repo's commit style: `chore(flake): bumped <inputs>` plus one bullet per
# changed input.

usage() {
  cat <<'EOF'
Usage: system-bump [options] [input...]

Update flake inputs (all of them by default), check, and commit flake.lock.

Options:
  --flake DIR    Flake checkout (default: $NH_FLAKE, else the current directory)
  --eval-only    Evaluate every host instead of building this one (CI)
  --verify       Only evaluate every host, check and package; change nothing
  --switch       Activate this host after committing
  --no-commit    Leave flake.lock uncommitted
  -h, --help     Show this help

Private inputs need a GitHub token. Without access-tokens in NIX_CONFIG, the
token comes from `gh auth token` when gh is logged in.
EOF
}

die() {
  echo "system-bump: $*" >&2
  exit 1
}

flake=${NH_FLAKE:-$PWD}
eval_only=0
verify=0
switch=0
commit=1
inputs=()

while (($#)); do
  case $1 in
    --flake)
      [[ $# -ge 2 ]] || die "--flake needs a directory"
      flake=$2
      shift 2
      ;;
    --eval-only) eval_only=1 && shift ;;
    --verify) verify=1 && shift ;;
    --switch) switch=1 && shift ;;
    --no-commit) commit=0 && shift ;;
    -h | --help) usage && exit 0 ;;
    -*) die "unknown option $1" ;;
    *) inputs+=("$1") && shift ;;
  esac
done

cd "$flake" || die "no such directory: $flake"
[[ -f flake.nix && -f flake.lock ]] || die "$flake has no flake.nix and flake.lock"

if [[ ${NIX_CONFIG:-} != *access-tokens* ]] && command -v gh >/dev/null 2>&1; then
  if token=$(gh auth token 2>/dev/null) && [[ -n $token ]]; then
    export NIX_CONFIG="${NIX_CONFIG:+$NIX_CONFIG$'\n'}access-tokens = github.com=$token"
  fi
fi

# Every check (each host's system build among them) and package, on every
# platform, by drvPath. Unlike `nix flake check --no-build`, this lets inputs
# that import from derivations (hermes-agent reads its uv.lock that way) build
# what evaluation needs.
evaluate_all() {
  local outputs
  for outputs in checks packages; do
    nix eval --json ".#$outputs" \
      --apply 'builtins.mapAttrs (_: builtins.mapAttrs (_: drv: drv.drvPath))' >/dev/null ||
      return 1
  done
  echo "system-bump: every host, check and package evaluates"
}

if ((verify)); then
  evaluate_all
  exit
fi

case $(uname -s) in
  Darwin) platform=darwin ;;
  *) platform=os ;;
esac

before=$(mktemp)
trap 'rm -f "$before"' EXIT
cp flake.lock "$before"

restore() {
  cp "$before" flake.lock
  die "$1; restored the previous flake.lock"
}

nix flake update "${inputs[@]}"

if cmp -s "$before" flake.lock; then
  echo "system-bump: every input is already current"
  exit 0
fi

# One row per changed top-level input: name|date|short rev (empty for
# tarballs). A non-blank separator, so read keeps an empty rev field.
rows=()
while IFS= read -r row; do
  [[ -n $row ]] && rows+=("$row")
done < <(
  jq -r --slurpfile old "$before" '
    def node(lock; name): lock.nodes[lock.nodes.root.inputs[name]].locked;
    . as $new
    | .nodes.root.inputs | keys[] as $name
    | node($old[0]; $name) as $o
    | node($new; $name) as $n
    | select($o.narHash != $n.narHash)
    | [$name, ($n.lastModified | todate | .[0:10]), ($n.rev // "" | .[0:7])]
    | join("|")
  ' flake.lock
)
names=()
for row in "${rows[@]}"; do
  names+=("${row%%|*}")
done

echo "system-bump: updated ${names[*]:-transitive inputs}"

if ((eval_only)); then
  evaluate_all || restore "evaluation failed"
else
  nh "$platform" build . || restore "the build failed"
fi

if ((commit)); then
  case ${#names[@]} in
    1) subject="chore(flake): bumped ${names[0]}" ;;
    2) subject="chore(flake): bumped ${names[0]} and ${names[1]}" ;;
    *) subject="chore(flake): bumped flake inputs" ;;
  esac
  ((${#subject} <= 72)) || subject="chore(flake): bumped flake inputs"

  body=()
  for i in "${!rows[@]}"; do
    if ((i == 5 && ${#rows[@]} > 6)); then
      body+=("- Updated $((${#rows[@]} - 5)) other inputs.")
      break
    fi
    IFS='|' read -r name date rev <<<"${rows[$i]}"
    body+=("- Updated $name to $date${rev:+ ($rev)}.")
  done
  message=$subject
  if ((${#body[@]})); then
    message+=$'\n\n'$(printf '%s\n' "${body[@]}")
  fi

  if [[ -d .jj ]] && command -v jj >/dev/null 2>&1; then
    jj commit --message "$message" flake.lock
  else
    git commit --quiet --message "$message" -- flake.lock
  fi
  echo "system-bump: committed \"$subject\""
fi

if ((switch)); then
  nh "$platform" switch .
fi
