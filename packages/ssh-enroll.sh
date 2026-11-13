# ssh-enroll: give this host its SSH keys and register them on GitHub.
#
#   ssh-enroll           With only the primary YubiKey plugged in: this host's
#                        FIDO2 key (~/.ssh/id_ed25519_sk, a handle that is
#                        useless without the YubiKey) for GitHub and logins,
#                        and its signing key (~/.ssh/id_ed25519).
#   ssh-enroll --backup  With only the backup YubiKey plugged in: its resident
#                        key, made once for every host, which needs the PIN
#                        and a touch. Other hosts fetch the handle when needed
#                        with `cd ~/.ssh && ssh-keygen -K`.
#
# Keys are made only when missing and added to GitHub only when GitHub lacks
# them, so it is safe to rerun. It prints the lines for
# modules/common/default.nix.
#
# Adding keys needs gh's admin:public_key and admin:ssh_signing_key scopes.
# The token sits in the keychain where any process can use it, so they are
# granted only for this run and removed again on exit.

usage() {
  echo "usage: ssh-enroll [--backup]" >&2
  exit 2
}

backup=false
case "${1:-}" in
"") ;;
--backup) backup=true ;;
*) usage ;;
esac

host="$(hostname -s | tr '[:upper:]' '[:lower:]')"
dir="$HOME/.ssh"
mkdir -p "$dir"
chmod 700 "$dir"

# create KEY COMMENT TYPE [KEYGEN-ARGS...]: create KEY unless it exists.
create() {
  local key=$1 comment=$2 type=$3
  shift 3
  [ -f "$key" ] && return
  echo "ssh-enroll: creating $key"
  [ "$type" = ed25519-sk ] && echo "ssh-enroll: touch the YubiKey when it blinks"
  ssh-keygen -q -t "$type" "$@" -N '' -C "$comment" -f "$key"
}

# register PUB TYPE: add PUB to GitHub as an authentication or signing key.
register() {
  local pub=$1 type=$2 endpoint=user/keys body
  [ "$type" = signing ] && endpoint=user/ssh_signing_keys
  body="$(cut -d' ' -f2 "$pub")"
  if ! gh api --hostname github.com --paginate "$endpoint" --jq '.[].key' | grep -qF "$body"; then
    GH_HOST=github.com gh ssh-key add "$pub" --type "$type" --title "$(cut -d' ' -f3- "$pub")"
  fi
}

line() {
  printf '  %s = "%s %s";\n' "$1" "$(cut -d' ' -f1,2 "$2")" "$3"
}

admin_scopes=admin:public_key,admin:ssh_signing_key
drop_scopes() {
  gh auth refresh --hostname github.com --remove-scopes "$admin_scopes" ||
    echo "ssh-enroll: remove the scopes by hand: gh auth refresh --remove-scopes $admin_scopes" >&2
}

if $backup; then
  auth="$dir/id_ed25519_sk_rk_backup"
  create "$auth" backup ed25519-sk -O resident -O verify-required -O application=ssh:backup
else
  auth="$dir/id_ed25519_sk"
  sign="$dir/id_ed25519"
  create "$auth" "$host" ed25519-sk
  create "$sign" "$host" ed25519
fi

trap drop_scopes EXIT
gh auth refresh --hostname github.com --scopes "$admin_scopes"
register "$auth.pub" authentication
$backup || register "$sign.pub" signing

echo
echo "ssh-enroll: on GitHub. Add to modules/common/default.nix, then switch:"
echo
if $backup; then
  line user.backupAuthKey "$auth.pub" backup
else
  line "user.authKeys.$host" "$auth.pub" "$host"
  line "user.signingKeys.$host" "$sign.pub" "$host"
fi
