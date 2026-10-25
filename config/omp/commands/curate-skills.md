---
description: Audit and prune omp-managed skills safely
---

Audit omp's managed skills as a bounded working set.

Scope:

- Inspect every `skill.md` below the active omp managed-skills directory. account for both `~/.omp/agent/managed-skills` and `~/.config/omp/agent/managed-skills`, but deduplicate paths that resolve to the same file.
- Do not inspect, edit, move, or delete authored skills, project skills, or managed skills belonging to another omp profile.
- A skill should encode a reusable, multi-step procedure. isolated facts belong in memory; one-off results, stale environment details, superseded procedures, and near-duplicates do not deserve separate skills.

First pass, dry run only:

1. Inventory the managed skills and read each one in full.
2. Classify each as keep, update/merge, move to memory, or delete.
3. Prefer updating one strong skill and deleting overlapping weaker skills. Preserve unique operational details during any proposed merge.
4. Treat uncertain value or obsolescence as keep. do not invent evidence that a procedure is stale.
5. Report the exact skill names, concise evidence for every non-keep decision, and the before/after count.
6. Ask for one explicit approval covering the exact updates and deletions. Do not mutate anything in this pass, even if arguments request automatic application.

Application pass, only after that approval:

1. Apply approved updates before deletions, using `manage_skill` rather than raw filesystem writes.
2. Store an approved isolated durable fact with `learn` or `retain` before deleting its former skill.
3. Delete only the exact approved managed-skill names.
4. Re-inventory the managed-skills directory and report the resulting names and count.

Optional focus from the user: $ARGUMENTS
