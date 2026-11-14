# Find files and act on them: ft by extension, mdp for markdown. Both list
# with fd, so .gitignore and hidden files stay out unless --all, and pick
# with fzf; Tab marks several.
#
# For questions rather than actions, nu's own tables are often enough:
#   ls **/*.md | sort-by modified -r | first 10
#   ls **/*.nix | where size > 10kb
#   open flake.lock | get nodes | columns

# $EDITOR as a command line, which may carry its own arguments.
def editor [] { $env.EDITOR? | default "ms" | split row " " | where {|word| $word != "" } }

# fd's list for a directory: files with any of the extensions, or all files.
def find-files [dir: path, exts: list<string>, all: bool] {
  let types = $exts | each {|ext| [--extension ($ext | str trim --left --char ".")] } | flatten
  let hidden = if $all { [--hidden --no-ignore] } else { [] }
  # Without a path, fd searches here and leaves off the ./ prefix.
  let where = if ($dir | path expand) == $env.PWD { [] } else { [$dir] }
  ^fd --type file --exclude .git ...$hidden ...$types . ...$where | lines
}

# Run fzf over the lines with keys that end it. Returns the key pressed, ""
# for Enter, and the picks, or null when cancelled or nothing matched.
def choose [feed: list<string>, prompt: string, keys: list<string>, preview: string] {
  if ($feed | is-empty) { return null }
  let expect = if ($keys | is-empty) { [] } else { [--expect ($keys | str join ",") --header ($keys | str join "  ")] }
  let result = try {
    $feed | str join (char nl) | ^fzf --height=60% --reverse --multi --prompt $prompt --scheme path --with-shell "sh -c" --preview $preview --preview-window "right,60%" ...$expect | complete
  } catch { return null }
  if $result.exit_code != 0 { return null }
  let out = $result.stdout | lines
  # With --expect, fzf prints the key on the first line, empty for Enter.
  if ($keys | is-empty) { {key: "", picks: $out} } else { {key: ($out | first), picks: ($out | skip 1)} }
}

def opener [] { if $nu.os-info.name == "macos" { "open" } else { "xdg-open" } }

def copy [text: string] {
  if $nu.os-info.name == "macos" {
    $text | ^pbcopy
  } else if (which wl-copy | is-not-empty) {
    $text | ^wl-copy
  } else {
    $text | ^xclip -selection clipboard
  }
}

# glow's style for the light or dark appearance. Asked of macOS, because
# glow's own check queries the terminal, and inside fzf's preview the
# terminal's reply would arrive as typing.
def glow-style [] {
  if $nu.os-info.name != "macos" { return dark }
  let mode = try { ^defaults read -g AppleInterfaceStyle | complete } catch { {stdout: ""} }
  if ($mode.stdout | str trim) == "Dark" { "dark" } else { "light" }
}

# Text through bat, markdown through glow, anything else described by file.
# TERM=dumb stops glow querying the terminal; CLICOLOR_FORCE keeps its colors.
def preview [] {
  let glow = $"TERM=dumb CLICOLOR_FORCE=1 glow -s (glow-style) -w \"$FZF_PREVIEW_COLUMNS\" {}"
  $"case {} in
  *.md|*.markdown\) ($glow) ;;
  *\) if file --mime-encoding -b {} | grep -qv binary; then bat --style=numbers --color=always --theme=ansi --paging=never -- {}; else file -b {}; fi ;;
esac"
}

# Find files by extension below a directory and act on the picks: Enter
# edits them, Ctrl-V views each (glow or bat), Ctrl-O opens them in their
# default app, Ctrl-R reveals them, Ctrl-Y copies their paths. With --pick,
# returns the picks instead, to pipe on.
#
#   ft md            # markdown here and below
#   ft png jpg -d ~/Pictures
#   ft nix --pick | each { open --raw $in | lines | length }
export def ft [
  ...exts: string        # Extensions, with or without the dot; none for every file
  --dir (-d): path = "." # Where to look
  --all (-a)             # Include hidden and ignored files
  --pick (-p)            # Return the picked paths rather than acting on them
] {
  let label = if ($exts | is-empty) { "files" } else { $exts | str join "," }
  let keys = if $pick { [] } else { [ctrl-v ctrl-o ctrl-r ctrl-y] }
  let chosen = choose (find-files $dir $exts $all) $"($label)> " $keys (preview)
  if $chosen == null { return }
  if $pick { return $chosen.picks }
  let picks = $chosen.picks
  match $chosen.key {
    "ctrl-v" => { for file in $picks { show-file $file } }
    "ctrl-o" => { run-external (opener) ...$picks }
    "ctrl-r" => {
      if $nu.os-info.name == "macos" { ^open -R ...$picks } else { ^xdg-open ($picks | first | path dirname) }
    }
    "ctrl-y" => { copy ($picks | path expand | str join (char nl)) }
    _ => { run-external ...(editor) ...$picks }
  }
}

# Read a file in the terminal: glow for markdown, bat for the rest.
def show-file [file: path] {
  if ($file | path parse | get extension) in [md markdown] { ^glow -t $file } else { ^bat --paging=always -- $file }
}

# Pick markdown below a directory with a rendered preview and read it in
# glow. Ctrl-E edits the picks instead.
export def mdp [
  dir: path = "."  # Where to look
  --all (-a)       # Include hidden and ignored files
] {
  let chosen = choose (find-files $dir [md markdown] $all) "md> " [ctrl-e] (preview)
  if $chosen == null { return }
  if $chosen.key == "ctrl-e" {
    run-external ...(editor) ...$chosen.picks
  } else {
    for file in $chosen.picks { show-file $file }
  }
}
