# External completions through carapace, with a deadline. A command with a
# native carapace spec gets a longer budget, and a timeout there shows nothing
# rather than a file list that looks like an answer. Every other command goes
# through carapace's zsh bridge (CARAPACE_BRIDGES in config.nu), which spawns
# zsh, so it gets a short budget and falls back to files. Globs list files
# directly, since carapace does not expand them.
#
# The carapace init in vendor autoload keeps this completer, as it keeps any
# completer that is already set. modules/common/shell/nushell.nix lists the
# native specs at build time in CARAPACE_NATIVE_SPECS; `carapace --list`
# takes too long to run here.

# The shell's commands, aliases and variables, which carapace's bridges ask
# for. A completer cannot keep environment changes, so the first prompt
# builds this, once every autoload has defined its commands.
def context [] {
  let first_words = {|commands| $commands | get name | each {|command| $command | split row " " | first } | uniq | str join "\n" }
  let commands = help commands
  {
    CARAPACE_SHELL: "nushell"
    CARAPACE_SHELL_ALIASES: (scope aliases | get name | uniq | str join "\n")
    CARAPACE_SHELL_BUILTINS: (do $first_words ($commands | where category != ""))
    CARAPACE_SHELL_FUNCTIONS: (do $first_words ($commands | where category == ""))
    CARAPACE_SHELL_VARIABLES: (scope variables | get name | uniq | str join "\n")
  }
}

# Files for the token at the cursor, the way fish lists them: relative paths
# stay relative, `~` stays `~`, dotfiles only when the name starts with a dot,
# and a token holding *, ? or [ lists what it matches. In VAR=value and
# --flag=value the value completes.
def files [token: string] {
  let eq = $token | str index-of "="
  if $eq > 0 {
    let prefix = $token | str substring ..$eq
    return (files ($token | str substring ($eq + 1)..) | each {|row| {value: $"($prefix)($row.value)"} })
  }
  let token = $token | str trim --char "'" | str trim --char '"' | str trim --char '`'
  let home = $env.HOME
  let tilde = $token == "~" or ($token | str starts-with "~/")
  let expanded = if $tilde { $home + ($token | str substring 1..) } else { $token }
  let pattern = if $expanded =~ '[*?\[]' { $expanded } else { $"($expanded)*" }
  let hidden = $expanded | split row "/" | last | str starts-with "."
  try {
    ls --all ($pattern | into glob)
    | where {|row| $hidden or not ($row.name | path basename | str starts-with ".") }
    | first 40
    | each {|row|
      let name = if $tilde { $row.name | str replace $home "~" } else { $row.name }
      let is_dir = $row.type == "dir" or ($row.type == "symlink" and (try { ($row.name | path expand | path type) == "dir" } catch { false }))
      if $is_dir { {value: $"($name)/"} } else { {value: $name} }
    }
  } catch { [] }
}

# `place.command` holds the words up to the cursor, with aliases expanded.
def complete-external [place: record] {
  let words = $place.command
  if ($words | length) <= 1 { return null }
  let token = $words | last
  if $token =~ '[*?\[]' { return (files $token) }
  let context = if $env.CARAPACE_CONTEXT? != null { $env.CARAPACE_CONTEXT } else { context }
  let native = ($words.0 | path basename) in ($env.CARAPACE_NATIVE_SPECS? | default [])
  let tag = random int 1..1_000_000_000
  let id = job spawn {
    let result = try { with-env $context { ^carapace $words.0 nushell ...$words | from json } } catch { null }
    {value: $result} | job send 0 --tag $tag
  }
  let got = try { job recv --tag $tag --timeout (if $native { 350ms } else { 80ms }) } catch { {timeout: true} }
  if $got.timeout? == true {
    try { job kill $id }
    job flush --tag $tag
    return (if $native { [] } else { files $token })
  }
  $got.value
}

export-env {
  $env.config.completions.external.enable = true
  $env.config.completions.external.completer = {|place| complete-external $place }
  $env.config.hooks.pre_prompt = $env.config.hooks.pre_prompt? | default [] | append {||
    if $env.CARAPACE_CONTEXT? == null { $env.CARAPACE_CONTEXT = context }
  }
}
