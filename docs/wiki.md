# On-demand wiki

`/wiki` is a Markdown command in `config/tern/plugins/wiki/wiki.md`, linked into
`~/.config/omp/agent/commands/` by Home Manager. Tern links the same directory into
`~/.config/tern/plugins/wiki`. Start a fresh omp process, including
the agent used by Tern, after installing it; command directories are not watched.
omp advertises the command over RPC as well as in its terminal interface.

The default wiki is `~/wiki`, independent of the working project and omp's
internal state. It is a Git repository of ordinary Markdown in the OKF v0.2
format, browsable through `index.md` in any editor. `/wiki` commits the files
each write changes and never pushes. Home Manager does not own the notes or
include them in this repo.

| Invocation                                     | Behavior                                                                                                        |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `/wiki <question or topic>`                    | Research the topic and save a sourced note.                                                                     |
| `/wiki write <topic or instructions>`          | Create or surgically update a readable note and its index entry. With no topic, capture the current discussion. |
| `/wiki ask <question>`                         | Answer from relevant notes with source links; no writes.                                                        |
| `/wiki use <page or topic>`                    | Read selected notes as background for the current task; no writes.                                              |
| `/wiki queue <topic>`                          | Add a topic to the inbox queue without researching it.                                                          |
| `/wiki promote <draft or topic> [into <page>]` | Move reviewed inbox drafts into the wiki.                                                                       |
| `/wiki` or `/wiki help`                        | Show usage without accessing the wiki.                                                                          |

For example: `/wiki write Explain what we learned about the Tern launcher,
including why its wrapper is necessary.` To use another directory, explicitly
name it as the wiki root in the request; that selection applies only to that
invocation.

Writes preserve human annotations, distinguish user decisions from model
recommendations, and record dates and sources. Profiles are ordinary pages;
they are not inferred or read implicitly. A missing wiki is created only by
research or `write`, never by `ask`, `use`, or help.

Mnemopi memory and skill autolearning are enabled separately from `/wiki`.
The wiki command adds no automatic recall, session mining, or background
maintenance. Its rules are model instructions, not a filesystem permission boundary.
Notes read through either `ask` or `use` remain in the conversation's context;
start a fresh session to work without that previously loaded context.

## Inbox

`wiki-inbox` spends spare Codex and Grok subscription quota on drafts you
review later; it never uses Anthropic. Each queued topic is drafted once per
lane into `~/wiki/inbox/<topic>/<lane>.md` with `status: draft` and no
`verified` entry, so OKF consumers treat it as unreviewed, and `/wiki ask`
skips it. Lanes and models are constants at the top of
`config/tern/plugins/wiki/wiki-inbox.py`.

| Command                                                | Behavior                                                                                                   |
| ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `wiki-inbox add <topic>`                               | Append a topic to `inbox/queue.txt`.                                                                       |
| `wiki-inbox status`                                    | Show which lanes have drafted each queued topic.                                                           |
| `wiki-inbox run [--lane L] [--limit N] [--dry-run]`    | Draft every missing topic and lane, lanes in parallel.                                                     |
| `wiki-inbox promote inbox/<topic>/<lane>.md [page.md]` | Publish a reviewed draft as stable and verified by you, then drop the topic's other drafts and queue line. |
| `wiki-inbox discard <topic>[/<lane>.md]`               | Delete one draft (redrafted next run) or a whole topic.                                                    |

Runs use `omp -p` with read-only tools and no memory, autolearn, or advisor;
the script writes and commits each draft itself, logging every run to
`~/.local/state/wiki-inbox/`. To merge several drafts or fold one into an
existing page, use `/wiki promote` or the Tern browser's Promote button
instead; a merged page is not marked verified until you review it.
