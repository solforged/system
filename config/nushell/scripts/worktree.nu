# Git worktrees in the `ga` layout: ${OMP_WORKTREE_DIR:-~/.omp/wt}/<repo>--<branch>.
# The same commands as config/zsh/config.d/functions.zsh; tests/worktree-helpers.py
# runs both.

# Create a branch and its worktree, then enter it. The repo key comes from the
# canonical common git directory, so it is the same from any subdirectory or
# linked worktree.
export def --env ga [branch: string] {
  if (^git check-ref-format --branch $branch | complete).exit_code != 0 {
    error make {msg: $"Invalid branch name: ($branch)"}
  }
  let common = ^git rev-parse --path-format=absolute --git-common-dir | str trim | path expand
  let base = if ($common | path basename) == ".git" { $common | path dirname } else { $common } | path basename
  let root = $env.OMP_WORKTREE_DIR? | default ($env.HOME | path join .omp wt)
  if not ($root | str starts-with "/") { error make {msg: "OMP_WORKTREE_DIR must be absolute"} }
  let target = $root | path join $"($base)--($branch | str replace --all '/' '-')"
  if ($target | path exists --no-symlink) { error make {msg: $"Path already exists: ($target)"} }
  mkdir $root
  ^git worktree add -b $branch $target
  cd $target
}

# Remove the current linked worktree and its branch after confirming. Refuses
# main checkouts and dirty trees, and never force-deletes the branch.
export def --env gd [] {
  let paths = ^git rev-parse --path-format=absolute --git-common-dir --git-dir --show-toplevel | lines
  if $paths.0 == $paths.1 { error make {msg: "Not a linked worktree"} }
  let top = $paths.2
  let main = ^git worktree list --porcelain | lines | first | str replace "worktree " ""
  let branch = ^git branch --show-current | str trim
  # gum exits 1 for "no", which nu would raise as an error.
  let confirmed = try { ^gum confirm $"Remove ($top) and branch ($branch)?"; true } catch { false }
  if not $confirmed { return }
  cd $main
  ^git worktree remove $top
  if $branch != "" { ^git branch -d $branch }
}
