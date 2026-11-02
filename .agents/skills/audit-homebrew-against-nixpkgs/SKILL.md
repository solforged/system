---
name: audit-homebrew-against-nixpkgs
description: Check whether Homebrew formulae and casks in the system flake can move to pinned nixpkgs packages on aarch64-darwin.
---

# Audit Homebrew items against pinned nixpkgs

Use this when a Darwin host in `/Users/admin/src/system` lists `homebrew.brews`
or `homebrew.casks` and the question is which items can become
`hm.home.packages` or nix-darwin packages.

## Check the pinned nixpkgs

1. Resolve the flake input, not a substitute store path:
   `nix eval --impure --raw --expr 'let f = builtins.getFlake "/Users/admin/src/system"; in f.inputs.nixpkgs.rev + " " + f.inputs.nixpkgs.outPath'`.
2. Import that nixpkgs with `system = "aarch64-darwin"` and
   `config.allowUnfree = true`. The common module already allows unfree, so an
   unfree license is not a blocker.
3. Do not set `allowBroken`. With it set, nixpkgs strips `meta.broken`, and a
   broken package such as `calibre` reports `broken = false`.
4. A usable package must exist, evaluate, have `meta.broken or false == false`,
   and list `aarch64-darwin`. Confirm the derivation is the same program,
   including a macOS `.app` when the Homebrew item is a cask.
5. Force `pkg.outPath` with `builtins.tryEval`. Availability is not enough:
   `zotero` evaluates, then refuses because it depends on insecure
   `firefox-esr-140-bin-unwrapped`.

Re-check package-name mappings and exclusions after each nixpkgs bump; they are
pin-specific.

## Install through the existing host pattern

- Put accepted packages in the host's `hm.home.packages`. `home.stateVersion`
  26.05 enables `targets.darwin.copyApps`, so bundles are copied to
  `~/Applications/Home Manager Apps`.
- Leave items with no usable package in `homebrew.casks`. Preserve commented-out
  entries.
- Homebrew `cleanup` is `"none"` in `modules/darwin/homebrew.nix`, so activation
  does not uninstall the old formulae and casks.
- Do not add unprefixed `coreutils` without saying that it shadows BSD `ls` and
  `cp`.
