# Fish-style line editing: directory history (Alt-Left/Right), a project
# picker (Alt-C), the last argument of earlier commands (Alt-.), sudo (Alt-S),
# a file picker (Ctrl-T), history hints that prefer the current directory,
# and command-not-found suggestions. config.nu binds the keys; the commands they run are exported.
#
# State lives in records, which nu never passes to child processes.

# --- Directory history ---

# Moves to the last directory in one stack and pushes the current one onto the
# other. The PWD hook below sees `skip` and leaves the stacks alone.
def --env step [from: string, to: string] {
  let stack = $env.DIRHIST | get $from
  if ($stack | is-empty) { return }
  let dest = $stack | last
  let here = $env.PWD
  if $dest != $here {
    try { cd $dest } catch { return }
    $env.DIRHIST.skip = true
    $env.DIRHIST = $env.DIRHIST | update $to { append $here | last 100 }
  }
  $env.DIRHIST = $env.DIRHIST | update $from { drop 1 }
}

# Back to the previous directory.
export def --env prevd [] { step back fwd }

# Forward again, after prevd.
export def --env nextd [] { step fwd back }

# --- Projects ---

# The directories in each of $env.PROJECTS.roots, plus $env.PROJECTS.marks,
# most used first by zoxide's score and alphabetical after that. Ones that
# do not exist are skipped.
export def projects [] {
  let places = $env.PROJECTS? | default {}
  let roots = $places.roots? | default [] | path expand | where {|dir| ($dir | path type) == dir }
  let children = $roots | each {|root|
    ls $root | where type in [dir symlink] | get name | path expand | where {|dir| ($dir | path type) == dir }
  } | flatten
  let marks = $places.marks? | default [] | path expand | where {|dir| ($dir | path type) == dir }
  let listed = try { ^zoxide query --list --score | complete } catch { {exit_code: 1} }
  let scores = if $listed.exit_code == 0 {
    $listed.stdout | lines | parse --regex '^\s*(?<score>[0-9.]+) (?<path>.+)$' | update score { into float }
  } else { [] }
  $children ++ $marks
  | uniq
  | each {|dir| {path: $dir, rank: ($scores | where path == $dir | get score.0? | default 0 | $in * -1)} }
  | sort-by rank path
  | get path
}

# A path with $HOME shown as ~.
def tilde [path: string] {
  let home = $env.HOME
  if $path == $home or ($path | str starts-with $"($home)/") {
    "~" + ($path | str substring ($home | str length)..)
  } else { $path }
}

# Pick a project or marked place and enter it; Ctrl-Z in the picker swaps in
# everything zoxide knows. Words match exactly rather than fuzzily, so that
# `p tessera` is one match and enters directly. With none, it falls back to
# zoxide, so `p hermes` works like `z hermes`.
export def --env p [...query: string] {
  let feed = projects | each {|dir| $"($dir)\t(tilde $dir)" }
  # fzf runs these with sh; {1} is the absolute path, quoted.
  let everything = r#'zoxide query --list | awk -v h="$HOME" '{ d = $0; if ($0 == h || index($0, h "/") == 1) d = "~" substr($0, length(h) + 1); print $0 "\t" d }''#
  let preview = r#'if git -C {1} rev-parse --git-dir >/dev/null 2>&1; then git -C {1} -c color.status=always status -sb | head -20; echo; git -C {1} log --oneline --color=always -20; else eza -1 --color=always --group-directories-first {1}; fi'#
  let args = [
    --with-shell "sh -c" --delimiter "\t" --with-nth 2 --scheme path --tiebreak index
    --header "ctrl-z: everything zoxide knows" --bind $"ctrl-z:reload\(($everything)\)"
    --preview $preview --preview-window "right,50%"
  ]
  let args = if ($query | is-empty) { $args } else { $args ++ [--exact --query ($query | str join " ") --select-1 --exit-0] }
  let result = fzf-run $feed "cd> " ...$args
  if $result.exit_code == 0 {
    let line = $result.stdout | str trim --right --char (char nl)
    if $line != "" { cd ($line | split row (char tab) | first) }
  } else if $result.exit_code == 1 and ($query | is-not-empty) {
    let found = try { ^zoxide query --exclude $env.PWD -- ...$query | complete } catch { return }
    if $found.exit_code == 0 { cd ($found.stdout | str trim) } else { print -e $"no match for ($query | str join ' ')" }
  }
}

# --- Command line ---

# The command `index` entries back in nu's own history, newest first.
def history-line [index: int] {
  let path = $env.config.history.path?
  if $path == null or not ($path | path exists) { return null }
  let row = try {
    open $path | query db "SELECT command_line FROM history ORDER BY id DESC LIMIT 1 OFFSET ?" -p [$index]
  } catch { return null }
  $row.command_line.0?
}

# The last word of a command line as it was typed, quotes included, so
# `'two words'` comes back whole.
def last-token [line: string] {
  let words = try { ast --flatten $line | get content } catch { $line | split row " " }
  $words | where {|word| $word != "" } | last 1 | get 0?
}

# A word as nu would read it back, quoted only when it needs to be.
def quote-word [word: string] {
  if ($word | str contains " ") or ($word | str contains "'") { $word | to nuon } else { $word }
}

# Insert the last argument of the previous command; pressed again, replace
# it with the one from the command before that.
export def --env insert-last-arg [] {
  let line = commandline
  let cursor = commandline get-cursor
  let prev = $env.ALT_DOT? | default {text: "", index: -1}
  let prev_len = $prev.text | str length
  let continuing = (
    $prev.index >= 0
    and $prev_len > 0
    and $cursor >= $prev_len
    and (($line | str substring ($cursor - $prev_len)..<$cursor) == $prev.text)
  )
  let index = if $continuing { $prev.index + 1 } else { 0 }
  let hist = history-line $index
  if $hist == null { return }
  let quoted = last-token $hist
  if $quoted == null { return }
  if $continuing {
    let start = $cursor - $prev_len
    let next = ($line | str substring 0..<$start) + $quoted + ($line | str substring $cursor..)
    commandline edit --replace $next
    commandline set-cursor ($start + ($quoted | str length))
  } else {
    commandline edit --insert $quoted
  }
  $env.ALT_DOT = {text: $quoted, index: $index}
}

# Prefix the command line with sudo, or the previous command when it is empty.
export def prepend-sudo [] {
  let line = commandline
  if ($line | str starts-with "sudo ") { return }
  let next = if ($line | str trim | is-empty) {
    let prev = history-line 0
    if $prev == null { return }
    $"sudo ($prev)"
  } else {
    $"sudo ($line)"
  }
  commandline edit --replace $next
  commandline set-cursor ($next | str length)
}

# fzf over the lines, with its exit code: 1 means no match, 130 cancelled.
def fzf-run [feed: list<string>, prompt: string, ...args: string] {
  try {
    $feed | str join (char nl) | ^fzf --height=40% --reverse --prompt $prompt ...$args | complete
  } catch { {exit_code: 2, stdout: ""} }
}

def pick [feed: list<string>, prompt: string] {
  let result = fzf-run $feed $prompt
  if $result.exit_code != 0 { return null }
  let pick = $result.stdout | str trim
  if ($pick | is-empty) { null } else { $pick }
}

# Pick a file below the current directory and insert it at the cursor.
export def insert-file [] {
  let feed = ^fd --hidden --exclude .git --exclude target --exclude node_modules | complete
  if $feed.exit_code != 0 { return }
  let pick = pick ($feed.stdout | lines) "file> "
  if $pick != null { commandline edit --insert (quote-word $pick) }
}

# --- Hints and missing commands ---

def like-escape [text: string] {
  $text | str replace --all '\' '\\' | str replace --all '%' '\%' | str replace --all '_' '\_'
}

# The rest of the newest command starting with the line, preferring ones run
# in this directory. Runs on every keystroke, so it is one indexed query.
def hint [ctx: record] {
  let line = $ctx.line
  if ($line | is-empty) or $ctx.pos != ($line | str length) { return null }
  let path = $env.config.history.path?
  if $path == null or not ($path | path exists) { return null }
  let row = try {
    open $path | query db "SELECT command_line FROM history WHERE command_line LIKE ? ESCAPE '\\' AND command_line != ? AND command_line NOT IN ('ls', 'cd', 'clear', 'exit') ORDER BY (cwd = ?) DESC, id DESC LIMIT 1" -p [($"((like-escape $line))%") $line ($ctx.cwd? | default "")]
  } catch { return null }
  let match = $row.command_line.0?
  if $match == null or ($match | str length) <= ($line | str length) { return null }
  $match | str substring ($line | str length)..
}

def packages [name: string] {
  if (which nix-locate | is-empty) { return "" }
  let found = try { ^nix-locate --top-level --whole-name --at-root $"bin/($name)" | complete } catch { return "" }
  if $found.exit_code != 0 { return "" }
  let lines = $found.stdout | lines | where {|line| $line != "" } | first 5
  if ($lines | is-empty) { return "" }
  $"may be provided by: ($lines | str join ', ')"
}

def missing [name: string] {
  let near = (
    help commands
    | get name
    | each {|command| $command | split row " " | first }
    | uniq
    | each {|command| {name: $command, distance: ($command | str distance $name)} }
    | where {|row| $row.distance > 0 and $row.distance <= 2 }
    | sort-by distance
    | first 3
  )
  let hint = if ($near | is-empty) { "" } else { $"Did you mean ($near.name | str join ', ')?" }
  [$"Command ($name) not found" $hint (packages $name)] | where {|part| $part != "" } | str join "\n"
}

export-env {
  $env.DIRHIST = {back: [], fwd: [], skip: false}
  $env.config.hooks.env_change.PWD = (
    $env.config.hooks.env_change.PWD? | default [] | append {|before, after|
      if $before == null or $before == $after { return }
      if $env.DIRHIST.skip {
        $env.DIRHIST.skip = false
        return
      }
      $env.DIRHIST.back = $env.DIRHIST.back | append $before | last 100
      $env.DIRHIST.fwd = []
    }
  )
  $env.config.hinter.closure = {|ctx| hint $ctx }
  $env.config.hooks.command_not_found = {|name| missing $name }
}
