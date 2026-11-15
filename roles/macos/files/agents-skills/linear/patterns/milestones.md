# Pattern — Project milestones

## Naming convention

Milestones use sequential numbering with a short description:

```
M0 — <description>
M1 — <description>
M2 — <description>
```

- **M0** is the foundational / initial phase (research, setup, prerequisites).
- Numbers increment sequentially from there.
- Description is 2–4 words, concise and specific. Not a full sentence.
- Use an em dash (` — `) between the number and description, not a hyphen.

### Examples (from Pancake)

```
M0 — Foundations
M1 — Data model reshape
M2 — Auto-workspaces
M3 — Agents reshape
M4 — Catalogue + Views
M5 — Endpoint migration
M6 — Cleanup
M8 — Performance + safety
```

## Creating milestones

Milestones are project-level objects. Creating or modifying them modifies the project.

**⚠️ NEVER create, update, or delete milestones without explicit user permission.** This falls under the project read-only policy in `SKILL.md`. Even if the user describes the milestones they want, confirm before calling `save_milestone`.

Use `save_milestone`:
```
save_milestone(
  name: "M0 — Foundations",
  projectId: "<project-id>",
  description: "One sentence: what this phase achieves and why it gates the next."
)
```

## Assigning issues to milestones

When creating or updating an issue, pass `milestone: "M0 — Foundations"` (the milestone name) to `save_issue`. The MCP tools accept human-readable milestone names.

## Completing milestones

A milestone is complete when all its issues are Done. When the last issue in a milestone moves to Done, note it — but do NOT auto-update the milestone status without checking with the user first (project modification).
