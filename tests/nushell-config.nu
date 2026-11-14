# Run with `nu --config config/nushell/config.nu tests/nushell-config.nu`:
# loads the real config in a scratch HOME and checks what it sets up.
use std/assert

# Public commands are in scope; module helpers are not.
let commands = scope commands | get name
for name in [ga gd prevd nextd p projects insert-last-arg prepend-sudo insert-file ssh fip dip lip e ff eff y omp] {
  assert ($name in $commands) $"missing command ($name)"
}
for name in [git-segment hints preexec step history-line tilde fzf-run complete-external interactive main] {
  assert not ($name in $commands) $"($name) leaks into the shell"
}

# The prompt renders outside a repository and outside Tern.
cd $env.HOME
let prompt = do $env.PROMPT_COMMAND | ansi strip
assert str contains $prompt "~"
assert equal (do $env.PROMPT_INDICATOR | ansi strip) "> "
assert equal $env.TRANSIENT_PROMPT_INDICATOR "> "

# Directory history: the PWD hook records moves, and prevd/nextd walk them
# without the hook recording their own moves. nu runs the hook at the next
# prompt, so this calls it the same way.
let pwd_hook = $env.config.hooks.env_change.PWD | last
mkdir a b
def --env visit [dir: string] {
  let before = $env.PWD
  cd $dir
  do --env $pwd_hook $before $env.PWD
}
visit a
visit ../b
let a = $env.HOME | path join a
let b = $env.HOME | path join b
prevd
do --env $pwd_hook $b $env.PWD
assert equal $env.PWD $a
nextd
do --env $pwd_hook $a $env.PWD
assert equal $env.PWD $b
prevd
do --env $pwd_hook $b $env.PWD
assert equal $env.DIRHIST.fwd [$b]

# Projects: directories in a root and existing marks, without files or
# duplicates, most visited first by zoxide.
cd $env.HOME
mkdir src/alpha src/beta .config
touch src/notes.md
$env._ZO_DATA_DIR = $env.HOME | path join zoxide
^zoxide add src/beta
let found = projects
let in_home = {|rel| $env.HOME | path join $rel | path expand }
assert equal ($found | first) (do $in_home src/beta)
for rel in [src/alpha src .config] { assert ((do $in_home $rel) in $found) $"($rel) is not a project" }
assert not ((do $in_home src/notes.md) in $found)
assert not ((do $in_home .local/share/wiki) in $found)
assert equal ($found | uniq | length) ($found | length)

# Shell state stays out of child environments.
let child_env = ^env | lines | where {|line| $line =~ '^(DIRHIST|ALT_DOT|TERN_|CARAPACE_CONTEXT)' }
assert equal $child_env []

# Globs complete as files, with directories marked.
cd $env.HOME
let completer = $env.config.completions.external.completer
assert equal (do $completer {command: [cat "a*"]}) [{value: "a/"}]

# A line nothing in history starts with gets no hint, and no error.
let line = "zz-no-such-command-zz"
assert equal (do $env.config.hinter.closure {line: $line, pos: ($line | str length), cwd: $env.PWD}) null

print "nushell config: commands, prompt, directory history, projects and completions passed"
