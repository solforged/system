# On-demand wiki

The `/wiki` command, the Tern wiki browser, and the `wiki-inbox` runner live in
their own repository, `omp-wiki`, which documents their use. This repo expects
a live checkout beside it at `~/src/omp-wiki`; set
`modules.agents.omp.wiki.dir` to use another path. Clone it on each host before
switching, or the links below dangle.

| Target                                   | Source in the checkout            | Module                          |
| ---------------------------------------- | --------------------------------- | ------------------------------- |
| `~/.config/omp/agent/commands/wiki.md`   | `wiki.md`                         | `modules/common/agents/omp.nix` |
| `wiki-inbox` on `PATH`                   | runs `wiki-inbox.py` with `python3` | `modules/common/agents/omp.nix` |
| `~/.config/tern/plugins/wiki`            | the checkout root                 | `modules/nixos/apps/tern.nix`   |

All three are out-of-store links to the checkout, so edits there apply without
a rebuild. Start a fresh omp process, including the agent Tern uses, after
changing `wiki.md`; command directories are not watched. Run
`tern plugin reload wiki` after changing the plugin.

The notes themselves live in `~/wiki`, a Git repository that neither Home
Manager nor this repo owns.
