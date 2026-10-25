# Installing amarna

amarna installs from a custom image built by `nix build .#installer-iso`. The
stock NixOS image isn't enough: amarna's only network is MT7927 Wi-Fi, and
that driver isn't in the standard kernel. The image adds:

- the MT7927 driver on the kernel `modules.hardware.mt7927` pins;
- NetworkManager (`nmtui`) and the CUDA binary caches;
- this flake and its locked inputs at `/etc/system`, so the private
  solforge-theme input needs no GitHub token;
- `install-amarna` (`installer/install-amarna.sh`).

## The Ventoy stick

| Path | Contents |
|---|---|
| `iso/nixos-system-installer.iso` | The installer image |
| `ventoy/ventoy.json` | `{ "control": [ { "VTOY_LINUX_REMOUNT": "1" } ] }`, so the booted image can mount the stick |
| `amarna/backup.tar.age` | Host SSH key and `/var/lib/sbctl`, passphrase-encrypted |
| `amarna/system.bundle` | `git bundle create system.bundle main`, cloned to `~/src/system` |
| `amarna/qwen3.8-27b-q8_0.gguf` | Model for `modules.ai.llama` |

Only the image and `ventoy.json` are required. Without the backup, the new
host key has to be added to `secrets/agenix-rules.nix` and the secrets
rekeyed. Without the bundle, `~/src/system` is a copy of the flake with no
history.

## Before wiping

1. **Admin key.** Make sure the `agenix admin` item exists in the Proton Pass
   `Personal` vault.
2. **Key backup.** Write `amarna/backup.tar.age` with the passphrase you will
   type during install:

   ```sh
   sudo tar -C / -c etc/ssh/ssh_host_ed25519_key \
       etc/ssh/ssh_host_ed25519_key.pub var/lib/sbctl |
     rage -p -o /run/media/sol/Ventoy/amarna/backup.tar.age
   ```

   Run `sudo -v` first, so the sudo prompt doesn't interfere with rage's
   passphrase prompt.
3. **Home.** Copy anything in `/home` that you want to keep to another drive.
   disko erases the whole 990 PRO.
4. **Firmware.** Turn Secure Boot off without clearing the enrolled keys.

## Install

Boot the stick, choose `nixos-system-installer.iso`, and run `install-amarna`.
It:

1. Waits for the network; use `nmtui` to join Wi-Fi.
2. Mounts the stick at `/run/ventoy`. If `backup.tar.age` is missing, it asks
   before continuing.
3. Asks you to type `ERASE`, then runs disko, which asks for the new LUKS
   passphrase. Layout: an ESP, plus LUKS2 holding btrfs subvolumes `@`,
   `@home`, `@nix` and `@log` (`hosts/amarna/disko.nix`).
4. Restores the backup into `/mnt`, then runs `nixos-install`.
5. Sets the password for `sol`, clones the bundle to `~/src/system`, and
   copies the model to `/var/lib/llama-models`.

## After the first boot

1. `pass-cli login`, which starts the SSH agent
   (`systemctl --user status proton-pass-ssh-agent`).
2. Secure Boot: set `security.secureboot.sign = true` in `hosts/amarna`, run
   `sudo nixos-rebuild boot --flake ~/src/system#amarna --install-bootloader`,
   check `sudo sbctl verify`, then turn Secure Boot back on in firmware. If
   the firmware keys were reset, enroll them with
   `sbctl enroll-keys --microsoft --tpm-eventlog` from Setup Mode.
3. `fprintd-enroll` for the fingerprint reader and `pamu2fcfg` for security
   keys.
4. Compare `hosts/amarna/hardware.nix` against
   `nixos-generate-config --no-filesystems --show-hardware-config`.

## Testing the image

The image can be booted in QEMU with OVMF. Use the graphical console: GRUB
boots with `terminal_output console`, so a serial console shows nothing.

```sh
qemu-system-x86_64 -enable-kvm -m 4096 -smp 4 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=ovmf-vars.fd \
  -cdrom nixos-system-installer.iso -nic user,model=virtio-net-pci
```

`install-amarna` stops at its disk check in a VM, because the 990 PRO isn't
present.
