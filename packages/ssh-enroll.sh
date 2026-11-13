# ssh-enroll: give this host its SSH keys and register them on GitHub.
#
#   ssh-enroll           This host's FIDO2 key on the primary YubiKey
#                        (~/.ssh/id_ed25519_sk, a handle that is useless
#                        without it) for GitHub and logins, and its commit
#                        signing key, which never leaves the Mac's Secure
#                        Enclave (~/.ssh/id_ecdsa_sk_signing is a handle) or
#                        is sealed to the TPM elsewhere
#                        (~/.ssh/id_ecdsa_signing.tpm).
#   ssh-enroll --backup  The backup YubiKey's resident key, made once for
#                        every host, which needs the PIN and a touch. Other
#                        hosts fetch the handle when needed with
#                        `cd ~/.ssh && ssh-keygen -K`.
#
# A YubiKey is needed only while its key is created: then plug in that one
# alone, the primary for a host's key or the backup for --backup. The signing
# key needs none. Keys are made only when missing and added to GitHub only
# when GitHub lacks them, so it is safe to rerun. It prints the lines for
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
  if [ "$type" = ed25519-sk ]; then
    local which=primary
    [ "$comment" = backup ] && which=backup
    echo "ssh-enroll: plug in only the $which YubiKey; touch it when it blinks"
  fi
  ssh-keygen -q -t "$type" "$@" -N '' -C "$comment" -f "$key"
}

# enclave KEY: a Secure Enclave key that signs without a prompt, with its
# handle at KEY. -K fetches the handles of every enclave identity; keep ours.
enclave() {
  local key=$1 label=git-signing tmp
  [ -f "$key" ] && return
  echo "ssh-enroll: creating $key in the Secure Enclave"
  if ! /usr/sbin/sc_auth list-ctk-identities | awk -v l="$label" '$4 == l { f = 1 } END { exit !f }'; then
    /usr/sbin/sc_auth create-ctk-identity -l "$label" -N "$label" -k p-256-ne -t none
  fi
  tmp="$(mktemp -d)"
  echo "ssh-enroll: press Enter at the PIN prompt; the enclave has no PIN"
  (cd "$tmp" && SSH_SK_PROVIDER=/usr/lib/ssh-keychain.dylib ssh-keygen -q -K -N '')
  mv "$tmp/id_ecdsa_sk_rk_$label" "$key"
  printf '%s %s\n' "$(cut -d' ' -f1,2 "$tmp/id_ecdsa_sk_rk_$label.pub")" "$host" >"$key.pub"
  rm -rf "$tmp"
}

# tpm BASE: a key sealed to this machine's TPM, at BASE.tpm and BASE.pub.
tpm() {
  local base=$1
  [ -f "$base.tpm" ] && return
  echo "ssh-enroll: creating $base.tpm; press Enter twice, for no passphrase"
  ssh-tpm-keygen -C "$host" -f "$base"
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
  create "$auth" "$host" ed25519-sk
  case "$(uname -s)" in
  Darwin)
    sign="$dir/id_ecdsa_sk_signing"
    enclave "$sign"
    ;;
  *)
    sign="$dir/id_ecdsa_signing"
    tpm "$sign"
    ;;
  esac
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
  echo
  echo "Move a replaced signingKeys line to user.retiredSigningKeys, so old"
  echo "commits still verify."
fi
