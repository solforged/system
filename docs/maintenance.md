# System maintenance

`nh` is installed on every host. `NH_FLAKE` points to the live checkout configured
by `modules.dotfiles.dir`, so commands work from any directory and select the
local hostname.

For the first activation, before `nh` is installed:

```sh
nix run --inputs-from ~/src/system nixpkgs#nh -- os switch ~/src/system --ask
```

On Macs, replace `os` with `darwin`. Log out and back in after this first switch
to load `NH_FLAKE`, then use:

```sh
nh os switch --ask          # build, show the diff, confirm, activate (amarna)
nh os build                # build and show the diff without activating
nh os test --ask           # activate without changing the next-boot default
nh os boot --ask           # set the next-boot default without activating
nh os switch --update --ask # update all flake inputs, then rebuild and activate
nh darwin switch --ask      # Macs
nix fmt                    # nixfmt-tree
nix build .#installer-iso   # amarna installer
```

Run `nh` as your normal user; it elevates privileges when needed. Home Manager is
part of the system activation, so no separate `nh home switch` is needed.
On NixOS, `nh clean` runs weekly with a 14-day retention window and removes stale
gcroots. Determinate Nix manages garbage collection on Macs.

New files must be `git add`ed before the flake can see them.

For the private theme input and host credentials, see
[secrets and keys](secrets.md).
