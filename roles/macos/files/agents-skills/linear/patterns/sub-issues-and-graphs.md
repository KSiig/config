# Pattern — Sub-issues and dependency graphs

## Auto-created "Graduate docs" sub-issue

When creating a new issue that is a **direct member of a project** (i.e. it has a `project` but is NOT a sub-issue of another issue), **always** create a companion sub-issue:

- **Title:** `Graduate docs from ai/ to stable docs`
- **Parent:** the issue just created
- **Labels:** `["Infrastructure"]`
- **Description:** use the standard template:

```
## Summary

Review accumulated working notes and chat-notes from `ai/` created during this task. Graduate verified findings to stable documentation in the repo's `docs/` tree.

## Steps

1. Review `ai/chat-notes/` files related to this task
2. Identify findings with durable value (architecture decisions, operational procedures, reference data)
3. Promote verified content to `docs/` following the preferred docs structure
4. Clean up graduated working notes
5. Verify remaining `docs/90-open-items/` entries are still relevant

## Notes

This is the final sub-task — all implementation work must be completed first.
```

If the parent issue already has other sub-issues at creation time, set `blockedBy` to all of them so the docs sub-issue is visibly last.

Do NOT create this sub-issue when:
- The issue being created is itself a sub-issue of another issue (has a `parentId` pointing to an issue)
- The issue is not a member of any project

## Dependency graph maintenance

Parent issues may contain a **Dependency graph** section at the bottom of their description — an ASCII code block showing sub-issue relationships and a **Status table** with auto-linked issue references. When either exists, keep them in sync with every status change.

### Status icons (used in the code block graph)

```
□  Not started (Backlog / Todo)
◧  In progress (In Progress / In Review)
■  Completed (Done)
×  Cancelled
```

### When to update the graph

**On any sub-issue status change** (state transition via `save_issue`):

1. After changing the sub-issue's state, fetch the parent issue with `get_issue`.
2. Check if the parent's description contains a `## Dependency graph` section.
3. If it does, update the status icon for the changed sub-issue in both:
   - The ASCII code block (e.g. `□ VEL-634` → `◧ VEL-634`)
   - The status table is auto-linked — Linear handles status display there. No manual update needed.
4. Write the updated description back with `save_issue`.

**On new sub-issue creation** under a parent with a dependency graph:

1. After creating the sub-issue, fetch the parent issue.
2. If a dependency graph exists, add the new sub-issue to the code block and status table in the appropriate phase/position based on its blocking relationships.
3. If the graph doesn't exist and the parent has 4+ sub-issues with blocking relations, suggest creating one.

**On sub-issue cancellation:**

1. Update the icon to `×` in the code block. Do NOT remove the entry — cancelled tasks are still part of the history.

### Graph structure rules

- The code block graph uses box-drawing characters (`─`, `│`, `┐`, `┤`, `▼`, etc.) in a monospace layout. Preserve alignment when editing.
- Two-track layout: **INFRA TRACK** (left) and **HARDWARE TRACK** (right), converging at the bottom. Adapt track names if the task domain is different.
- The legend line at the top of the code block must always be present: `◧ In progress  ■ Completed  □ Not started  × Cancelled`
- The status table below the graph uses markdown table format with columns: Phase, Task, Blocked by. Issue references in the table are plain `VEL-XXX` text (Linear auto-links them and shows native status icons).

### Example update

If VEL-634 moves to In Progress, change in the code block:
```
□ VEL-634 cluster ──────┐
```
to:
```
◧ VEL-634 cluster ──────┐
```

Then save the parent's description with the updated code block.
