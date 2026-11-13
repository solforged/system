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

atlas's private work flake links the work bundle in from the work repository,
so work notes never reach a personal host; see [atlas](atlas.md).
