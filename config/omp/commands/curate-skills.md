---
description: Audit and prune omp-managed skills safely
---

Audit omp's managed skills as a bounded working set.

Scope:

- Inspect every `SKILL.md` below the active managed-skills directory,
  `<agent dir>/managed-skills`, where `omp config path` prints the agent dir. On
  Sol's hosts that path links to `$XDG_DATA_HOME/omp/managed-skills`; resolve
  links and deduplicate paths that reach the same file, including through the
  legacy `~/.omp/agent` spelling.
- Inspect repository-local `.agents/skills` and `.omp/skills` read-only when
  checking references, ownership, or name collisions. A name missing from the
  global inventory may still exist in its owning repository.
- Do not edit, move, or delete existing authored or project skills, or managed
  skills belonging to another omp profile. Creating a repository-local copy of a
  managed skill requires an explicitly approved destination.
- A skill should encode a reusable, multi-step procedure. isolated facts belong
  in memory; one-off results, stale environment details, superseded procedures,
  and near-duplicates do not deserve separate skills.

First pass, dry run only:

1. Inventory the managed skills and read each one in full.
2. Classify each as keep global, update/merge, relocate to a repository, move to
   memory, or delete. Prefer repository-local storage for project-specific
   procedures and global storage for cross-project workflows.
3. Prefer updating one strong skill and deleting overlapping weaker skills.
   Preserve unique operational details during any proposed merge.
4. Treat uncertain value or obsolescence as keep. do not invent evidence that a
   procedure is stale.
5. Report exact skill names, evidence for every non-keep decision, destination
   paths for relocations, and separate global and repository-local counts.
6. Ask for one explicit approval covering the exact updates and deletions. Do
   not mutate anything in this pass, even if arguments request automatic
   application.

Application pass, only after that approval:

1. Apply approved updates before deletions. Use `manage_skill` for managed
   skills. For an approved relocation, create
   `<repo>/.agents/skills/<name>/SKILL.md` without overwriting an existing
   authored skill; preserve its contents and any companion files. Repair
   affected references and verify discovery from the owning repository before
   deleting the global copy with `manage_skill`. Do not leave aliases.
2. Store an approved isolated durable fact with `learn` or `retain` before
   deleting its former skill.
3. Delete only the exact approved managed-skill names.
4. Re-inventory both the global directory and approved repository destinations.
   Report names, counts, discovery checks, and any remaining blockers.

Optional focus from the user: $ARGUMENTS
