# install-amarna: erase amarna's 990 PRO and install hosts/amarna from the
# flake on this image. Optional files on the Ventoy stick, under amarna/:
#   backup.tar.age          host SSH key and /var/lib/sbctl, passphrase-encrypted
#   system.bundle           git bundle of this repo, for ~/src/system with history
#   qwen3.8-27b-q8_0.gguf   the model for modules.ai.llama

if [[ $EUID -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

flake=/etc/system
host=amarna
disk=/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7KGNJ0Y522708F
stick=/run/ventoy
from=$stick/amarna
user=sol

step() { printf '\n==> %s\n' "$*"; }

step "Network"
until nm-online -q -t 10; do
  echo "No network. Connect to Wi-Fi in nmtui, then quit it."
  read -r -p "Press Enter to open nmtui. "
  nmtui
done

step "Ventoy stick"
mkdir -p "$stick"
if ! mountpoint -q "$stick"; then
  # Needs VTOY_LINUX_REMOUNT in ventoy/ventoy.json on the stick.
  mount -o ro /dev/disk/by-label/Ventoy "$stick" 2>/dev/null ||
    echo "Could not mount the Ventoy partition."
fi
if [[ ! -f $from/backup.tar.age ]]; then
  echo "No $from/backup.tar.age: the old host key and Secure Boot keys are lost,"
  echo "and secrets stay undecryptable until they are rekeyed for the new key."
  read -r -p "Continue anyway? [y/N] " answer
  [[ $answer == [Yy] ]] || exit 1
fi

[[ -e $disk ]] || {
  echo "Missing $disk." >&2
  exit 1
}

step "Erase $disk"
lsblk -o NAME,SIZE,FSTYPE,LABEL "$disk"
read -r -p "Type ERASE to wipe this disk: " answer
[[ $answer == ERASE ]] || {
  echo "Aborted."
  exit 1
}

step "Partition, encrypt and mount (disko asks for the new LUKS passphrase)"
disko --mode destroy,format,mount --yes-wipe-all-disks --flake "$flake#$host"

step "Restore the host SSH key and Secure Boot keys"
if [[ -f $from/backup.tar.age ]]; then
  # agenix decrypts secrets with this host key during activation, so it must
  # be in place before nixos-install.
  rage -d "$from/backup.tar.age" | tar -x -C /mnt
  chmod 600 /mnt/etc/ssh/ssh_host_ed25519_key
else
  echo "No backup.tar.age. Secrets will not decrypt until the new host key"
  echo "is added to secrets/agenix-rules.nix and the secrets are rekeyed."
fi

step "Install"
nixos-install --flake "$flake#$host" --no-root-passwd

step "Password for $user"
until nixos-enter --root /mnt -c "passwd $user"; do :; done

step "Repo checkout at ~/src/system"
repo=/mnt/home/$user/src/system
mkdir -p "$(dirname "$repo")"
if [[ -f $from/system.bundle ]]; then
  git clone -q "$from/system.bundle" "$repo"
  git -C "$repo" remote set-url origin git@github.com:solforged/system.git
else
  cp -r "$flake/." "$repo"
  echo "No system.bundle; copied the flake without git history."
fi
nixos-enter --root /mnt -c "chown -R $user:users /home/$user"

step "Model weights"
if [[ -f $from/qwen3.8-27b-q8_0.gguf ]]; then
  install -d -m 0750 /mnt/var/lib/llama-models
  cp "$from/qwen3.8-27b-q8_0.gguf" /mnt/var/lib/llama-models/
  nixos-enter --root /mnt -c \
    "chown -R root:llama /var/lib/llama-models && chmod 0640 /var/lib/llama-models/*.gguf"
else
  echo "No model on the stick; qwen-mtp-256k fails until one is copied in."
fi

step "Done"
cat <<'EOF'
Reboot, log in, then:
  pass-cli login                     # starts the Proton Pass SSH agent
  systemctl --user status proton-pass-ssh-agent
For Secure Boot, set security.secureboot.sign = true in hosts/amarna,
run `sudo nixos-rebuild boot --flake ~/src/system#amarna --install-bootloader`,
check `sudo sbctl verify`, then turn Secure Boot back on in firmware.
EOF
