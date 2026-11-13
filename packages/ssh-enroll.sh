# ssh-enroll: give this host its own SSH key and register it on GitHub.
#
# Creates ~/.ssh/id_ed25519 (no passphrase, never copied off the host) only
# when it is missing, then adds it to GitHub as an authentication key and a
# signing key unless GitHub already has it. Safe to rerun.
#
# Adding keys needs gh's admin:public_key and admin:ssh_signing_key scopes.
# The token sits in the keychain where any process can use it, so they are
# granted only for this run and removed again on exit.

key="$HOME/.ssh/id_ed25519"
host="$(hostname -s | tr '[:upper:]' '[:lower:]')"

if [ ! -f "$key" ]; then
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  ssh-keygen -q -t ed25519 -N '' -C "$host" -f "$key"
  echo "ssh-enroll: created $key"
fi

admin_scopes=admin:public_key,admin:ssh_signing_key
drop_scopes() {
  gh auth refresh --hostname github.com --remove-scopes "$admin_scopes" ||
    echo "ssh-enroll: remove the scopes by hand: gh auth refresh --remove-scopes $admin_scopes" >&2
}
trap drop_scopes EXIT
gh auth refresh --hostname github.com --scopes "$admin_scopes"

body="$(cut -d' ' -f2 "$key.pub")"
if ! gh api --hostname github.com user/keys --jq '.[].key' | grep -qF "$body"; then
  GH_HOST=github.com gh ssh-key add "$key.pub" --type authentication --title "$host"
fi
if ! gh api --hostname github.com user/ssh_signing_keys --jq '.[].key' | grep -qF "$body"; then
  GH_HOST=github.com gh ssh-key add "$key.pub" --type signing --title "$host"
fi

cat <<EOF
ssh-enroll: $key.pub is on GitHub for push and signing. To sign commits and
allow logins with it, add it to user.sshKeys (and user.sshLoginHosts, for
logins) in modules/common/default.nix, then switch:

  $host = "$(cut -d' ' -f1,2 "$key.pub") $host";
EOF
