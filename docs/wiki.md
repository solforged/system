# Memory wiki

Pi's memory extension and the shared `memory` skill read and write a Git
repository of notes, [`solforged/wiki`](https://github.com/solforged/wiki),
checked out at `$LLM_WIKI_DIR` (`~/.local/share/wiki`, set in
`modules/common/xdg.nix`). The repository also holds the `wiki` command-line
tool and the skill. Neither Home Manager nor this repo owns its contents.

`pi-setup` clones it when missing and builds the tool into `bin/wiki`. Home
Manager links `~/.agents/skills/memory` to the skill in the checkout, where Pi
and omp find it.

## Scope and private bundles

`modules.agents.wiki.scope` sets `LLM_WIKI_SCOPE`, which picks the private
bundle read beside `shared` and where writes go. It defaults to `home`; atlas
sets `work`. Without a scope, only `shared` is read and writes fail.

The home bundle is its own private repository,
[`solforged/wiki-home`](https://github.com/solforged/wiki-home), checked out at
`~/.local/share/wiki/home` on every personal host. `pi-setup` clones it when the
scope is `home`. Nothing commits or pulls it for you: commit and push it like
any repository, and pull on the other hosts. Its `.recall` log is per machine
and ignored.

atlas's private work flake links the work bundle in from the work repository,
so work notes never reach a personal host; see [atlas](atlas.md).

## After a switch

Activation prints `Pi setup is incomplete; run pi-setup` with the missing paths
while pi-mono, the built wiki tool, or the home bundle is absent. Cloning needs
the network and GitHub keys, so `pi-setup` remains a manual step.
