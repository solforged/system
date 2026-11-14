# Fish-style line editing: directory history (Alt-Left/Right, Alt-C), the last
# argument of earlier commands (Alt-.), sudo (Alt-S), a file picker (Ctrl-T),
# history hints that prefer the current directory, and command-not-found
# suggestions. config.nu binds the keys; the commands they run are exported.
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

# Pick a directory zoxide knows and enter it.
export def --env cdh [] {
  let listed = try { ^zoxide query -l | complete } catch { return }
  if $listed.exit_code != 0 { return }
  let pick = pick ($listed.stdout | lines) "cd> "
  if $pick != null { cd $pick }
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

def pick [feed: list<string>, prompt: string] {
  let result = try {
    $feed | str join (char nl) | ^fzf --height=40% --reverse --prompt=$prompt | complete
  } catch { return null }
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
