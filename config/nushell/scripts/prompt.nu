# The prompt nu draws when Tern does not (Ghostty, ssh, Tern's `imported`
# style), matching config/zsh/config.d/prompt.zsh: a blank line, host,
# directory and git state, then `>` on the input line, green or red by the
# last status, and `<` in vi normal mode. The right side of the input line
# shows the last command's duration from 2 seconds and a failing status.
# Earlier lines collapse to `> command` in scrollback.

# The repository's git directory, found without running git, so a prompt
# outside a repository starts no process.
def git-dir [] {
  mut dir = $env.PWD
  loop {
    let dot = $dir | path join .git
    let kind = if ($dot | path exists) { $dot | path type } else { "" }
    if $kind == "dir" { return $dot }
    if $kind == "file" {
      # A worktree or submodule: `gitdir: <path>`, maybe relative.
      let target = try { open --raw $dot | str trim | str replace --regex '^gitdir: ' '' } catch { "" }
      return (if $target == "" { null } else { $dir | path join $target })
    }
    let parent = $dir | path dirname
    if $parent == $dir { return null }
    $dir = $parent
  }
}

# A rebase, merge or other operation in progress, with its progress.
def git-operation [gitdir: string] {
  let has = {|name| $gitdir | path join $name | path exists }
  let read = {|name| try { open --raw ($gitdir | path join $name) | str trim } catch { "" } }
  let found = if (do $has rebase-merge) {
    {state: "REBASING", current: (do $read rebase-merge/msgnum), total: (do $read rebase-merge/end)}
  } else if (do $has rebase-apply) {
    let state = if (do $has rebase-apply/rebasing) { "REBASING" } else if (do $has rebase-apply/applying) { "AM" } else { "AM/REBASE" }
    {state: $state, current: (do $read rebase-apply/next), total: (do $read rebase-apply/last)}
  } else if (do $has MERGE_HEAD) {
    {state: "MERGING"}
  } else if (do $has REVERT_HEAD) {
    {state: "REVERTING"}
  } else if (do $has CHERRY_PICK_HEAD) {
    {state: "CHERRY-PICKING"}
  } else if (do $has BISECT_LOG) {
    {state: "BISECTING"}
  } else {
    return ""
  }
  let current = $found.current? | default ""
  let total = $found.total? | default ""
  let progress = if $current != "" and $total != "" { $" ($current)/($total)" } else { "" }
  $" (ansi yellow_bold)|($found.state)($progress)(ansi reset)"
}

# `[branch status]`: the branch, or `@hash` when detached; one symbol per
# kind of change; ahead, behind or diverged from upstream.
def git-segment [] {
  let gitdir = git-dir
  if $gitdir == null { return "" }
  let result = ^git --no-optional-locks status --porcelain=2 --branch | complete
  if $result.exit_code != 0 { return "" }
  let lines = $result.stdout | lines
  let branch = (
    $lines
    | where {|line| $line | str starts-with "# branch." }
    | parse "# branch.{key} {value}"
    | reduce --fold {} {|row, acc| $acc | upsert $row.key $row.value }
  )
  let codes = $lines | where {|line| $line =~ '^[12] ' } | each {|line| $line | str substring 2..3 }
  let index = $codes | each {|code| $code | str substring 0..0 }
  let tree = $codes | each {|code| $code | str substring 1..1 }
  let ab = $branch.ab? | default "+0 -0" | split row " " | each {|n| $n | str substring 1.. | into int }
  let ahead = $ab.0? | default 0
  let behind = $ab.1? | default 0
  let symbols = [
    [shown symbol];
    [($lines | any {|line| $line | str starts-with "u " }) $"(ansi red_bold)="]
    [("D" in $index or "D" in $tree) $"(ansi red)✘"]
    [("R" in $index) $"(ansi cyan)»"]
    [("M" in $tree) $"(ansi yellow)!"]
    [("T" in $index or "T" in $tree) $"(ansi yellow)~"]
    [($index | any {|x| $x != "." }) $"(ansi green)+"]
    [($lines | any {|line| $line | str starts-with "? " }) $"(ansi yellow)?"]
    [($ahead > 0 and $behind > 0) $"(ansi yellow)⇕"]
    [($ahead > 0 and $behind == 0) $"(ansi blue)⇡"]
    [($behind > 0 and $ahead == 0) $"(ansi yellow)⇣"]
  ]
  let status = $symbols | where shown | get symbol | str join
  let status = if $status == "" { "" } else { $" ($status)" }
  let head = $branch.head? | default ""
  let name = if $head == "(detached)" {
    $"(ansi yellow)@($branch.oid? | default '' | str substring 0..6)"
  } else {
    $"(ansi blue)($head)"
  }
  $"(ansi blue)[($name)($status)(git-operation $gitdir)(ansi blue)](ansi reset) "
}

# The working directory with `~` for home, cut to its last three parts.
def dir-segment [] {
  let home = $env.HOME
  let pwd = $env.PWD
  let shown = if $pwd == $home or ($pwd | str starts-with $"($home)/") {
    "~" + ($pwd | str substring ($home | str length)..)
  } else {
    $pwd
  }
  let parts = $shown | split row "/" | where {|part| $part != "" }
  if ($parts | length) > 3 { $"…/($parts | last 3 | str join '/')" } else { $shown }
}

def duration-segment [ms: int] {
  let s = $ms // 1000
  let h = $s // 3600
  let m = ($s mod 3600) // 60
  let sec = $s mod 60
  if $h > 0 { $"($h)h($m)m($sec)s" } else if $m > 0 { $"($m)m($sec)s" } else { $"($sec)s" }
}

def indicator [char: string] {
  let ok = $char == "<" or ($env.LAST_EXIT_CODE? | default 0) == 0
  $"(if $ok { ansi green_bold } else { ansi red_bold })($char)(ansi reset) "
}

export-env {
  let host = try { ^hostname -s | str trim } catch { "" }
  $env.PROMPT_COMMAND = {||
    $"\n(ansi dark_gray)($host)(ansi reset) (ansi blue)(dir-segment)(ansi reset) (git-segment)\n"
  }
  $env.PROMPT_COMMAND_RIGHT = {||
    # CMD_DURATION_MS starts as the placeholder "0823".
    let ms = if $env.CMD_DURATION_MS? in [null "0823"] { 0 } else { $env.CMD_DURATION_MS | into int }
    let code = $env.LAST_EXIT_CODE? | default 0
    [
      (if $ms >= 2000 { $"(ansi yellow)(duration-segment $ms)(ansi reset)" })
      (if $code != 0 { $"(ansi red)($code)(ansi reset)" })
    ] | compact | str join " "
  }
  $env.config.render_right_prompt_on_last_line = true
  $env.PROMPT_INDICATOR = {|| indicator ">" }
  $env.PROMPT_INDICATOR_VI_INSERT = {|| indicator ">" }
  $env.PROMPT_INDICATOR_VI_NORMAL = {|| indicator "<" }
  $env.PROMPT_MULTILINE_INDICATOR = $"(ansi dark_gray)∙(ansi reset) "

  # Collapse the two-line prompt in scrollback. tern.nu removes these again
  # when Tern draws a native prompt, which collapses its own bar.
  $env.TRANSIENT_PROMPT_COMMAND = ""
  $env.TRANSIENT_PROMPT_INDICATOR = "> "
  $env.TRANSIENT_PROMPT_INDICATOR_VI_INSERT = "> "
  $env.TRANSIENT_PROMPT_INDICATOR_VI_NORMAL = "< "
  $env.TRANSIENT_PROMPT_MULTILINE_INDICATOR = ""
  $env.TRANSIENT_PROMPT_COMMAND_RIGHT = ""
}
