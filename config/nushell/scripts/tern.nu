# Tern ships shell integration for fish, zsh, bash, xonsh and PowerShell, not
# for Nushell. Nushell's own OSC 133 marks give Tern the prompt rows and each
# command's status; the hooks here report the rest, and only when
# TERM_PROGRAM=tern. Before a command: the command line, which a command lens
# needs to recognize `git log` or `gh pr list`, and the pager variables that
# let the lens read the output instead of a pager. Before a prompt: the native
# prompt's state, and the prompt itself as blank columns Tern draws over.
#
# Tern reports what it wants through the environment. native-prompt=<style>
# in KITTY_SHELL_INTEGRATION asks for its native prompt; TERN_PROMPT_* give
# that prompt's width, the variables it reports and the file that names the
# current style. They are read once at startup and kept from every program
# the shell starts, as Tern's fish and zsh integrations do.

const prompt_vars = [PROMPT_COMMAND PROMPT_COMMAND_RIGHT PROMPT_INDICATOR PROMPT_INDICATOR_VI_INSERT PROMPT_INDICATOR_VI_NORMAL]

# A command line as one shell word, for cmdline= in OSC 133;C.
def quote [text: string] {
  $"'($text | str replace --all "'" "'\\''")'"
}

# The pager and progress variables that keep a command line from paging or
# redrawing, so Tern can show its output natively. Lines with pipes, lists or
# redirections get none. Ported from Tern's fish and xonsh integrations.
def hints [line: string] {
  if $env.TERN_LENSES? != "1" or $line =~ '[|;&<>]' { return {} }
  mut words = $line | split row --regex '\s+' | where {|word| $word != "" }
  while ($words | is-not-empty) {
    if $words.0 in [sudo env time command nice nohup] {
      $words = $words | skip 1
      while ($words | is-not-empty) and ($words.0 | str starts-with "-") { $words = $words | skip 1 }
    } else if $words.0 =~ '^[A-Za-z_][A-Za-z0-9_]*=' {
      $words = $words | skip 1
    } else {
      break
    }
  }
  if ($words | is-empty) { return {} }
  let prog = $words.0 | str trim --left --char "^" | path basename
  mut rest = $words | skip 1
  if $prog == "git" {
    while ($rest | is-not-empty) and ($rest.0 | str starts-with "-") {
      # `git -p log` asks for the pager: leave it be.
      if $rest.0 in [-p --paginate] { return {} }
      $rest = $rest | skip (if $rest.0 in [-C -c] { 2 } else { 1 })
    }
    let sub = $rest.0? | default ""
    if $sub == "diff" {
      # An external diff tool (difftastic) prints what no lens reads, so
      # git's pager stays.
      if not ("--no-ext-diff" in $rest) {
        if ($env.GIT_EXTERNAL_DIFF? | default "") != "" { return {} }
        let external = try { ^git config --get diff.external | str trim } catch { "" }
        if $external != "" { return {} }
      }
      return {GIT_PAGER: "cat"}
    }
    let paged = [log show branch tag stash reflog blame shortlog grep ls-files ls-tree]
    return (if $sub in $paged { {GIT_PAGER: "cat"} } else { {} })
  }
  if $prog == "docker" {
    let building = ($rest.0? == "build") or ($rest.0? in [compose buildx] and $rest.1? == "build")
    return (if $building { {BUILDKIT_PROGRESS: "plain"} } else { {} })
  }
  {
    gh: {GH_PAGER: "cat"}
    man: {MANPAGER: "cat"}
    systemctl: {SYSTEMD_PAGER: "cat"}
    journalctl: {SYSTEMD_PAGER: "cat"}
    aws: {AWS_PAGER: ""}
    bat: {BAT_PAGING: "never"}
    psql: {PSQL_PAGER: "cat"}
    ls: {CLICOLOR: "1"}
  } | get --optional $prog | default {}
}

# Marks the start of a command's output with its command line, and exports the
# pager hints for it. An alias is reported with its expansion, which is what a
# lens recognizes. TERN_PENDING is a record, so no child process sees it.
def --env preexec [tern: record] {
  $env.TERN_PENDING = {hinted: []}
  if not $tern.marks { return }
  let line = commandline
  let trimmed = $line | str trim --left
  let first = $trimmed | split row --regex '\s' | get 0? | default ""
  let expansion = if $first == "" { null } else { scope aliases | where name == $first | get 0?.expansion? }
  let expanded = if $expansion == null { $line } else { $trimmed | str replace $first $expansion }
  let printable = not ($line =~ '[\x00-\x1f\x7f]') and not ($expanded =~ '[\x00-\x1f\x7f]')
  if $expanded != $line and $printable {
    print -n $"\e]133;C;cmdline=(quote $line);cmdline_expanded=(quote $expanded)\a"
  } else {
    print -n $"\e]133;C;cmdline_url=($line | url encode --all)\a"
  }
  let hints = hints $expanded
  if ($hints | is-empty) { return }
  $env.TERN_PENDING.hinted = $hints | columns | each {|name| {name: $name, old: ($env | get --optional $name)} }
  load-env $hints
}

# Puts back what the pager hints replaced.
def --env unhint [hinted: list] {
  if ($hinted | is-empty) { return }
  let restore = $hinted | where old != null | reduce --fold {} {|hint, acc| $acc | insert $hint.name $hint.old }
  hide-env --ignore-errors ...$hinted.name
  load-env $restore
}

# The native prompt's width: the control file's line when it holds a style and
# a width, else the spawn's. Null for `imported` or no width, which leave the
# prompt from prompt.nu in place.
def prompt-columns [tern: record] {
  mut style = $tern.style
  mut columns = $tern.columns
  if $tern.prompt_file != "" and ($tern.prompt_file | path exists) {
    let fields = try { open --raw $tern.prompt_file | lines | get 0? | default "" | split row "\t" } catch { [] }
    if ($fields.0? | default "") != "" and ($fields.1? | default "") != "" {
      $style = $fields.0
      $columns = $fields.1
    }
  }
  if $style == "imported" or not ($columns =~ '^[0-9]+$') { null } else { $columns | into int }
}

# The shell state Tern's prompt shows, as JSON: the last status, the duration
# when a command ran since the last prompt, background jobs, the effective uid
# and the TERN_PROMPT_ENV variables that are set. Nushell does not expose the
# line editor's vi mode, so the state always says insert, which is the mode
# every new prompt starts in. Esc does not change Tern's prompt character.
def state [tern: record, ran: bool] {
  let reported = $tern.prompt_env | reduce --fold {} {|name, acc|
    let value = $env | get --optional $name
    let kind = $value | describe
    let text = if $kind == "string" {
      $value
    } else if ($kind | str starts-with "list") {
      try { $value | each {|item| $item | into string } | str join (if ($name | str ends-with "PATH") { ":" } else { " " }) } catch { null }
    } else {
      null
    }
    if $text == null { $acc } else { $acc | insert $name $text }
  }
  mut state = {status: ($env.LAST_EXIT_CODE? | default 0)}
  if $ran {
    let ms = try { $env.CMD_DURATION_MS | into int } catch { null }
    if $ms != null { $state = $state | insert duration_ms $ms }
  }
  $state = $state | insert jobs (job list | length) | insert vi "insert"
  if $tern.uid != null { $state = $state | insert uid $tern.uid }
  $state | insert env $reported | to json --raw
}

# Sends the state of the prompt about to be drawn, then hands the prompt to
# Tern for a preset style: that many blank columns, no indicator and no right
# prompt. The prompt from prompt.nu stays for `imported`. This runs before
# every prompt because the control file can change the style between prompts.
def --env prompt [tern: record] {
  let pending = $env.TERN_PENDING?
  hide-env --ignore-errors TERN_PENDING
  if $pending != null { unhint $pending.hinted }
  if not $tern.native { return }
  print -n $"\e_npp;s;(state $tern ($pending != null))\e\\"
  let columns = prompt-columns $tern
  if $columns != null {
    if $env.TERN_USER_PROMPT? == null {
      let present = $env | columns
      $env.TERN_USER_PROMPT = $prompt_vars | where {|name| $name in $present } | each {|name| {($name): ($env | get $name)} } | into record
    }
    $env.PROMPT_COMMAND = "" | fill --character " " --width $columns
    $env.PROMPT_COMMAND_RIGHT = ""
    $env.PROMPT_INDICATOR = ""
    $env.PROMPT_INDICATOR_VI_INSERT = ""
    $env.PROMPT_INDICATOR_VI_NORMAL = ""
  } else if $env.TERN_USER_PROMPT? != null {
    let user = $env.TERN_USER_PROMPT
    hide-env --ignore-errors ...$prompt_vars TERN_USER_PROMPT
    load-env $user
  }
}

export-env {
  if $env.TERM_PROGRAM? == "tern" {
    let flags = $env.KITTY_SHELL_INTEGRATION? | default "" | split row " "
    let style = (
      $flags
      | where {|flag| $flag | str starts-with "native-prompt=" }
      | get 0?
      | default ""
      | str replace "native-prompt=" ""
    )
    let marks = not ("no-prompt-mark" in $flags)
    let native = $style != "" and $marks
    let tern = {
      marks: $marks
      native: $native
      style: $style
      columns: ($env.TERN_PROMPT_COLUMNS? | default "")
      prompt_file: ($env.TERN_PROMPT_FILE? | default "")
      prompt_env: (
        ["PATH" "HOME"]
        | append ($env.TERN_PROMPT_ENV? | default "" | split row ":")
        | where {|name| $name =~ '^[A-Za-z_][A-Za-z0-9_]*$' }
        | uniq
      )
      uid: (if $native { try { ^id -u | into int } catch { null } } else { null })
    }
    hide-env --ignore-errors TERN_PROMPT_COLUMNS TERN_PROMPT_ENV TERN_PROMPT_FILE KITTY_SHELL_INTEGRATION
    # Tern's native prompt collapses its own bar in scrollback.
    if $native {
      hide-env --ignore-errors TRANSIENT_PROMPT_COMMAND TRANSIENT_PROMPT_INDICATOR TRANSIENT_PROMPT_INDICATOR_VI_INSERT TRANSIENT_PROMPT_INDICATOR_VI_NORMAL TRANSIENT_PROMPT_MULTILINE_INDICATOR TRANSIENT_PROMPT_COMMAND_RIGHT
    }
    $env.config.hooks.pre_execution = $env.config.hooks.pre_execution? | default [] | append {|| preexec $tern }
    $env.config.hooks.pre_prompt = $env.config.hooks.pre_prompt? | default [] | append {|| prompt $tern }
  }
}
