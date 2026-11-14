# Workspaces in the `ga` layout: ${PI_WORKTREE_DIR:-~/.pi/wt}/<repo>--<name>,
# the root Pi's /wt uses. A jj repository gets a jj workspace; a Git-only one
# gets a worktree and branch. The same commands as
# config/zsh/config.d/functions.zsh; tests/worktree-helpers.py runs both.

def in-jj [] { (^jj root | complete).exit_code == 0 }

def worktree-root [] {
  let root = $env.PI_WORKTREE_DIR? | default ($env.HOME | path join .pi wt)
  if not ($root | str starts-with "/") { error make {msg: "PI_WORKTREE_DIR must be absolute"} }
  $root
}

def free-target [root: string, base: string, name: string] {
  let target = $root | path join $"($base)--($name | str replace --all '/' '-')"
  if ($target | path exists --no-symlink) { error make {msg: $"Path already exists: ($target)"} }
  $target
}

# Create a workspace (jj) or a branch and its worktree (Git), then enter it.
# The repo key comes from the default jj workspace or the canonical common git
# directory, so it is the same from any subdirectory or linked checkout.
export def --env ga [name: string] {
  if (in-jj) {
    if ($name | str trim) == "" or ($name =~ '\s') { error make {msg: $"Invalid workspace name: ($name)"} }
    let root = worktree-root
    let base = ^jj workspace root --name default | str trim | path basename
    let target = free-target $root $base $name
    mkdir $root
    ^jj workspace add --name ($name | str replace --all '/' '-') $target
    cd $target
    return
  }
  if (^git check-ref-format --branch $name | complete).exit_code != 0 {
    error make {msg: $"Invalid branch name: ($name)"}
  }
  let common = ^git rev-parse --path-format=absolute --git-common-dir | str trim | path expand
  let base = if ($common | path basename) == ".git" { $common | path dirname } else { $common } | path basename
  let root = worktree-root
  let target = free-target $root $base $name
  mkdir $root
  ^git worktree add -b $name $target
  cd $target
}

# Remove the current workspace or linked worktree after confirming. Refuses
# the main checkout and uncommitted changes, and never force-deletes a branch.
export def --env gd [] {
  if (in-jj) {
    let top = ^jj workspace root | str trim
    let main = ^jj workspace root --name default | str trim
    if $top == $main { error make {msg: "Not a linked workspace"} }
    let name = ^jj workspace list -T 'name ++ "\t" ++ root ++ "\n"' | lines | split column "\t" name root | where root == $top | get name.0
    if (^jj log -r @ --no-graph -T 'empty' | str trim) != "true" {
      error make {msg: "The working copy has changes; commit, squash or abandon them first"}
    }
    # gum exits 1 for "no", which nu would raise as an error.
    let confirmed = try { ^gum confirm $"Remove ($top) and workspace ($name)?"; true } catch { false }
    if not $confirmed { return }
    cd $main
    ^jj workspace forget $name
    ^rm -rf $top
    return
  }
  let paths = ^git rev-parse --path-format=absolute --git-common-dir --git-dir --show-toplevel | lines
  if $paths.0 == $paths.1 { error make {msg: "Not a linked worktree"} }
  let top = $paths.2
  let main = ^git worktree list --porcelain | lines | first | str replace "worktree " ""
  let branch = ^git branch --show-current | str trim
  let confirmed = try { ^gum confirm $"Remove ($top) and branch ($branch)?"; true } catch { false }
  if not $confirmed { return }
  cd $main
  ^git worktree remove $top
  if $branch != "" { ^git branch -d $branch }
}
