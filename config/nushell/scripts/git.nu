# Git as tables, plus a branch picker. lazygit (gg) stays the place to stage
# and commit; these answer questions from the prompt and feed other commands.
#
# Each turns git's text into a table: ask git for fields split by tabs or NUL
# bytes, then `lines`/`split row` and `split column`. From there it is all
# where, sort-by, group-by and get.

# Recent commits as a table of hash, author, date and subject. Revisions and
# paths after the count pass through to git log.
#
#   glog 200 | where subject =~ nushell
#   glog 500 | group-by author --to-table | update items { length }
#   glog 20 flake.nix | to md
export def glog [
  count: int = 50  # How many commits
  ...revs: string  # Revisions or paths, as for git log
] {
  ^git log $"--max-count=($count)" "--pretty=format:%h%x09%an%x09%aI%x09%s" ...$revs
  | lines
  | split column --number 4 "\t" hash author date subject
  | update date { into datetime }
}

# Changes in the working tree as a table of status, path and, for renames
# and copies, the path they came from. status is git's two letters, the
# index then the working tree: "M " staged, " M" not, "??" untracked. Paths
# are relative to the repository root, as git reports them.
#
#   gst | where status =~ M
#   e ...(gst | get path)
export def gst [] {
  # -z keeps paths with spaces unquoted. A rename or copy is two entries: the
  # new path with its status, then the old path on its own.
  let entries = ^git status --porcelain -z | split row (char nul) | where {|entry| $entry != "" }
  $entries | enumerate | reduce --fold {rows: [], skip: false} {|it, acc|
    if $acc.skip {
      $acc | update skip false
    } else {
      let status = $it.item | str substring 0..<2
      let moved = ($status | str trim) =~ '^[RC]'
      let from = if $moved { $entries | get ($it.index + 1) } else { null }
      {rows: ($acc.rows | append {status: $status, path: ($it.item | str substring 3..), from: $from}), skip: $moved}
    }
  } | get rows
}

# Switch to a branch picked from local and remote ones, most recently
# committed first. Picking a remote branch creates a local one tracking it.
export def gb [] {
  # %(HEAD) is * for the current branch, which is left out.
  let refs = ^git for-each-ref --sort=-committerdate "--format=%(HEAD)%09%(refname)%09%(committerdate:relative)%09%(subject)" refs/heads refs/remotes
  | lines
  | split column --number 4 "\t" head ref when subject
  | where {|row| $row.head != "*" and not ($row.ref | str ends-with "/HEAD") }
  | each {|row|
    let local = $row.ref | str starts-with "refs/heads/"
    let name = $row.ref | str replace --regex '^refs/(heads|remotes)/' ''
    {branch: $name, when: $row.when, subject: $row.subject, remote: (not $local)}
  }
  # Skip remote branches already checked out under the same name.
  let locals = $refs | where not remote | get branch
  let choices = $refs | where {|row| not $row.remote or ($row.branch | str replace --regex '^[^/]+/' '') not-in $locals }
  if ($choices | is-empty) { return }
  let pick = $choices | input list --fuzzy "Switch to"
  if $pick == null { return }
  # git switch creates a tracking branch from a unique origin/<name>.
  let name = if $pick.remote { $pick.branch | str replace --regex '^[^/]+/' '' } else { $pick.branch }
  ^git switch $name
}
