# Options, keys, aliases and small commands. Larger pieces are modules in
# scripts/ beside this file:
#
#   prompt.nu      the prompt, matching zsh's
#   tern.nu        Tern's shell integration (native prompt, command lenses)
#   editing.nu     fish-style editing: directory history, Alt-., hints
#   completion.nu  carapace completions with a deadline
#   worktree.nu    ga and gd
#   remote.nu      ssh that cleans up and reconnects; fip, dip, lip
#
# Atuin, mise, fnox, zoxide, carapace and direnv load after this file, from
# the vendor autoload directory that modules/common/shell/nushell.nix
# generates.

use scripts/prompt.nu
use scripts/tern.nu
use scripts/editing.nu *
use scripts/completion.nu
use scripts/worktree.nu *
use scripts/remote.nu *

# --- Options ---
$env.config.show_banner = false
$env.config.edit_mode = "vi"
$env.config.cursor_shape = {vi_insert: line, vi_normal: block}
$env.config.buffer_editor = ($env.EDITOR? | default "ms")
# Unknown commands highlight as errors before you run them.
$env.config.highlight_resolved_externals = true
$env.config.use_kitty_protocol = true
$env.config.table.mode = "compact"
$env.config.rm.always_trash = true
$env.config.error_style = "short"
# A bare directory name enters it, the way zsh autocd does.
$env.config.auto_cd_implicit = true

# Prefix matches, then a pager that stays open while you type. Fuzzy belongs
# to Atuin, not Tab.
$env.config.completions.algorithm = "prefix"
$env.config.completions.persistent_menus = true
# One bridge. Fish and bash bridges only add another shell spawn.
$env.CARAPACE_BRIDGES = "zsh"

# SQLite history, which editing.nu queries for hints and Alt-. alongside
# Atuin's own.
let history_dir = $env.XDG_STATE_HOME? | default ($env.HOME | path join .local state) | path join nushell
mkdir $history_dir
$env.config.history.file_format = "sqlite"
$env.config.history.path = $history_dir | path join history.sqlite3
$env.config.history.max_size = 100_000

# --- Keys ---
# Tab opens the description menu. Ctrl-Space accepts the hint, as Right, End
# and Ctrl-Right already do; it no longer opens the menu. Ctrl-E keeps the
# default accept-or-end chain.
let edit_modes = [emacs vi_normal vi_insert vi_visual helix_normal helix_select helix_insert]
let host_command = {|cmd| {send: executehostcommand, cmd: $cmd} }
$env.config.keybindings ++= [
  {
    name: completion_menu
    modifier: none
    keycode: tab
    mode: $edit_modes
    event: {until: [{send: menu, name: ide_completion_menu}, {send: menunext}, {edit: complete}]}
  }
  {name: ide_completion_menu, modifier: control, keycode: space, mode: $edit_modes, event: null}
  {name: accept_hint, modifier: control, keycode: space, mode: [vi_insert], event: {send: HistoryHintComplete}}
  {name: prevd, modifier: alt, keycode: left, mode: [vi_insert vi_normal], event: (do $host_command prevd)}
  {name: nextd, modifier: alt, keycode: right, mode: [vi_insert vi_normal], event: (do $host_command nextd)}
  {name: insert_last_arg, modifier: alt, keycode: char_., mode: [vi_insert vi_normal], event: (do $host_command insert-last-arg)}
  {name: prepend_sudo, modifier: alt, keycode: char_s, mode: [vi_insert vi_normal], event: (do $host_command prepend-sudo)}
  {name: insert_file, modifier: control, keycode: char_t, mode: [vi_insert vi_normal], event: (do $host_command insert-file)}
  {name: dir_history, modifier: alt, keycode: char_c, mode: [vi_insert vi_normal], event: (do $host_command cdh)}
]

$env.config.menus = $env.config.menus | each {|menu|
  if $menu.name != "ide_completion_menu" {
    $menu
  } else {
    $menu
    | upsert marker ""
    | upsert type ($menu.type | upsert correct_cursor_pos true | upsert description_mode "prefer_right")
  }
}

# --- Aliases ---
alias grep = grep --color=auto
alias gg = lazygit
alias gl = glow -t

# `g` stays an alias. Carapace already completes it as git, and a one-letter
# abbreviation is too easy to expand by accident.
alias g = git

alias d = docker
alias b = brew
alias bs = brew search
alias decompress = tar -xzf
alias o = omp
alias omr = omp --resume
alias pir = pi --resume

# Abbreviations expand on Space, so history stores the long command. Enter
# only expands the word at the cursor, so a pasted `ll --version` would miss.
# The aliases cover that path.
alias ll = eza --color=auto --group-directories-first --classify=auto -l --time-style=long-iso
alias la = ll -a
alias lt = ll --tree --level=2 --icons --git
alias lta = lt -a
alias gcm = git commit -m
alias gcam = git commit -a -m
alias gcad = git commit -a --amend
let eza_long = "eza --color=auto --group-directories-first --classify=auto -l --time-style=long-iso"
$env.config.abbreviations = {
  ll: $eza_long
  la: $"($eza_long) -a"
  lt: $"($eza_long) --tree --level=2 --icons --git"
  lta: $"($eza_long) --tree --level=2 --icons --git -a"
  gcm: "git commit -m"
  gcam: "git commit -a -m"
  gcad: "git commit -a --amend"
}

# --- Commands ---
# $EDITOR as a command line, which may carry its own arguments.
def editor [] { $env.EDITOR? | default "ms" | split row " " | where {|word| $word != "" } }

def --wrapped e [...args] { run-external ...(editor) ...$args }

def --env cdd [] { cd $env.DOTFILES_DIR }
def --env cdw [] { cd $env.LLM_WIKI_DIR }
def --env eal [] {
  cd $env.DOTFILES_DIR
  run-external ...(editor) config/nushell/config.nu
}

def --env md [dir: path] { mkdir $dir; cd $dir }

def --env .. [] { cd .. }
def --env ... [] { cd ../.. }

def mup [] { with-env {MISE_MINIMUM_RELEASE_AGE: 0} { ^mise up } }

def cx [] { clear; ^claude --permission-mode auto }

def compress [dir: path] {
  let dir = $dir | str trim --right --char "/"
  ^tar -czf $"($dir).tar.gz" $dir
}

# Open nvim on the current directory, or on the given files.
def --wrapped n [...args] {
  if ($args | is-empty) { ^nvim . } else { ^nvim ...$args }
}

# Yazi, then stay in the directory it was in when it quit.
def --env --wrapped y [...args] {
  let tmp = mktemp -t "yazi-cwd.XXXXXX"
  ^yazi ...$args --cwd-file $tmp
  let cwd = open --raw $tmp
  rm --permanent $tmp
  if $cwd != "" and $cwd != $env.PWD and ($cwd | path exists) { cd $cwd }
}

# Fuzzy-find a file with a preview.
def --wrapped ff [...args] {
  ^fzf --preview "bat --style=numbers --color=always --theme=ansi --paging=never -- {}" ...$args
}

# The same, then open the pick in $EDITOR.
def --wrapped eff [...args] {
  let selected = try { ff ...$args | str trim } catch { return }
  if $selected != "" { run-external ...(editor) "--" $selected }
}

# omp commit uses its own prompt and will not read AGENTS.md. Inject the
# global commit-msg policy unless the caller already passed --context.
# OMP_LAUNCHER names a wrapper to run instead of omp, such as a sandbox.
def --wrapped omp [...args] {
  let bin = $env.OMP_LAUNCHER? | default omp
  if ($args | get 0?) == "commit" and not ($args | any {|arg| $arg in [--context -c --help -h] }) {
    let policy = $env.XDG_CONFIG_HOME? | default ($env.HOME | path join .config) | path join git commit-style.md
    ^$bin commit --context (open --raw $policy) ...($args | skip 1)
  } else {
    ^$bin ...$args
  }
}
