# ssh that cleans up the terminal and reconnects when a connection drops, and
# port forwarding helpers. Ported from config/zsh/config.d/ssh.zsh.
#
# A remote tmux or editor arms terminal modes over the SSH pipe (mouse
# tracking, focus reporting, the alternate screen) that only it can disarm. If
# the connection dies instead of exiting cleanly, those modes stay armed on
# the local terminal, and every mouse move floods the prompt with escape junk.

# Disarm mouse tracking (1000/1002/1003, 1006 encoding), focus reporting
# (1004), and the alternate screen (1049), and show the cursor again.
def disarm [] {
  print -n "\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?1004l\e[?1049l\e[?25h"
}

# Runs ssh and returns its error, or null, instead of raising it.
def attempt [args: list<string>] {
  try { ^ssh ...$args; null } catch {|err| $err }
}

def code [err] { if $err == null { 0 } else { $err.exit_code? | default 1 } }

# Raises ssh's own error again, so the caller sees its exit code as from the
# external itself.
def finish [err] { if $err != null { error make $err.raw } }

# True for an interactive session: a destination and no remote command. The
# letters are the ssh(1) options that consume a value, so their arguments are
# not mistaken for the destination.
def interactive [args: list<string>] {
  let value_opts = "BbcDEeFIiJLlmOoPpQRSWw" | split chars
  mut rest = $args
  mut dest: any = null
  mut opts_done = false
  while ($rest | is-not-empty) {
    let arg = $rest.0
    $rest = $rest | skip 1
    if not $opts_done and $arg == "--" {
      $opts_done = true
    } else if not $opts_done and $arg =~ '^-.' {
      let letters = $arg | str substring 1.. | split chars
      let at = $letters | enumerate | where {|it| $it.item in $value_opts } | get 0?.index?
      # The value is glued to the letter (-p2222) unless the letter ends the
      # argument, in which case it consumes the next one (-p 2222).
      if $at != null and $at == ($letters | length) - 1 { $rest = $rest | skip 1 }
    } else if $dest == null {
      $dest = $arg
    } else {
      return false
    }
  }
  if $dest == null { return false }

  # A RemoteCommand from ssh_config or -o replays on reconnect just like a
  # positional command; ssh -G resolves the effective configuration for this
  # exact invocation without connecting. Fail closed when it cannot resolve,
  # since an undetected RemoteCommand must not replay. The explicit "none"
  # cancels a configured command, and some versions emit it when unset.
  let resolved = ^ssh -G ...$args | complete
  if $resolved.exit_code != 0 { return false }
  $resolved.stdout | lines | where {|line| $line =~ '(?i)^remotecommand ' and $line !~ '(?i)^remotecommand none$' } | is-empty
}

export def --wrapped ssh [...args] {
  let args = $args | each { into string }
  let started = date now
  let err = attempt $args
  if not (is-terminal --stdout) { return (finish $err) }
  disarm

  # Reconnect only when an interactive session drops: ssh exits 255 for
  # transport failures, but a fast 255 with no established session is a
  # connect/auth failure, a remote command's own 255 passes through
  # indistinguishably and must not replay its side effects, and redirected
  # stdin would feed the remaining piped input to a fresh remote shell.
  if (code $err) != 255 or not (is-terminal --stdin) or ((date now) - $started) < 30sec or not (interactive $args) {
    return (finish $err)
  }

  # Ctrl-C stops the attempt in flight, and interrupts the sleep between
  # attempts. Keep retrying fast failures, since a rebooting server refuses
  # connections too.
  loop {
    print "Connection lost. Reconnecting (Ctrl-C to stop)..."
    sleep 2sec
    let err = attempt $args
    disarm
    if (code $err) != 255 { return (finish $err) }
  }
}

# Forward local ports to the same ports on a host, in the background.
export def fip [host: string, ...ports: int] {
  if ($ports | is-empty) { error make {msg: "Usage: fip <host> <port1> [port2] ..."} }
  for port in $ports {
    ^ssh -f -N -L $"($port):localhost:($port)" $host
    print $"Forwarding localhost:($port) -> ($host):($port)"
  }
}

# Stop forwarding ports.
export def dip [...ports: int] {
  if ($ports | is-empty) { error make {msg: "Usage: dip <port1> [port2] ..."} }
  for port in $ports {
    let stopped = (^pkill -f $"ssh.*-L ($port):localhost:($port)" | complete).exit_code == 0
    print (if $stopped { $"Stopped forwarding port ($port)" } else { $"No forwarding on port ($port)" })
  }
}

# List active port forwards.
export def lip [] {
  # Full command lines: -a on Linux, -l with -f on macOS.
  let long = if $nu.os-info.name == "linux" { "-a" } else { "-l" }
  let found = ^pgrep -f $long "ssh.*-L [0-9]+:localhost:[0-9]+" | complete
  print (if $found.exit_code == 0 { $found.stdout | str trim } else { "No active forwards" })
}
