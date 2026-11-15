---
name: linear
description: Create, update, or refine Linear issues for Velatir via the Linear MCP server. Triggers on requests like "create a Linear task / issue", "update VEL-XXX / [task](https://linear.app/...) with a progress update", "help me define a new task: ...", "fetch the task description from <file> and create it in Linear", or any ask to move a Linear issue's state, add a comment, or migrate a chat-note / open-item into a tracked issue.
disable-model-invocation: false
---

# Linear — Velatir workspace

All Linear operations go through `mcp__claude_ai_Linear__*` MCP tools. No curl, no GraphQL, no `$LINEAR_TOKEN`. The MCP server handles auth.

## Step 1 — Read the right pattern file

Based on what the user is asking, read **one** pattern file before proceeding:

| Operation | File to read |
|---|---|
| Create a new issue / define a task / migrate from file | `patterns/create-issue.md` |
| Update an existing issue / progress note / state change | `patterns/update-issue.md` |
| Sub-issue creation / dependency graph updates | `patterns/sub-issues-and-graphs.md` |
| Milestone creation / naming / assignment | `patterns/milestones.md` |
| Bulk migration of many items | `patterns/bulk-migration.md` |

To find the patterns directory, run `git rev-parse --show-toplevel` to get the repo root, then read the file at `<repo-root>/.Codex/skills/linear/patterns/<filename>`.

If the operation spans multiple patterns (e.g. create a sub-issue with a dependency graph update), read both relevant files.

## MCP tools — quick reference

| Operation | Tool |
|---|---|
| Create issue | `save_issue` (omit `id`) — requires `title` and `team` |
| Update issue | `save_issue` (pass `id`, e.g. `VEL-123`) |
| Get issue details | `get_issue` |
| Search/list issues | `list_issues` |
| Create comment | `save_comment` (pass `issueId`) |
| Update comment | `save_comment` (pass `id`) |
| List comments | `list_comments` |
| List labels | `list_issue_labels` |
| List workflow states | `list_issue_statuses` |
| List teams | `list_teams` |
| Get user / viewer | `get_user` (pass `"me"` for current user) |
| List cycles | `list_cycles` |

The MCP tools accept **human-readable names** for teams, labels, states, and assignees — no UUIDs needed.

## Defaults

Unless the user says otherwise:

- **State:** Backlog
- **Labels:** `["Infrastructure"]`
- **Cycle:** none — do NOT pass `cycle`.
- **Assignee, priority, project, estimate:** not set. Ask if the request implies one.
- **Team:** Velatir (the only team).

## Gotchas

- **Markdown in `description` and `body`:** send content with literal newlines and special characters — do NOT escape. The MCP server instruction says: "use real newlines in markdown content rather than literal backslash-n characters."
- **`cycle` is sticky if you set it.** Don't pass it unless the user asked.
- **Identifiers vs UUIDs.** MCP tools accept the human identifier (e.g. `VEL-418`) for `id`, `issueId`, etc. Use it; UUIDs aren't needed.
- **Linear URLs are slugged with the title.** Parse from the URL using `/issue/(VEL-\d+)/` and ignore the trailing slug.
- **`labels` on `save_issue` accepts names.** Pass `["Infrastructure", "Backend"]` not UUIDs.
- **`list_issue_labels` needs `team` to see team-scoped labels.** Always pass `team: "Velatir"`. Without it, only workspace-level labels are returned.
- **`assignee` accepts `"me"`.** Use it instead of looking up the viewer's UUID.

## Projects — read-only by default

**You are NEVER allowed to edit a Linear project (description, milestones, settings, status) without explicit permission.** No amount of context, user instruction, or apparent intent overrides this. Even if a user tells you to edit a project, you MUST confirm with a follow-up: "This would modify the project [name] — are you sure?" and cite this policy rule. This applies to:

- `save_project` / `save_milestone` — creating or updating projects/milestones
- Changing project description, status, dates, or members
- Adding or removing milestones

Reading project data (`get_project`, `list_projects`, `list_milestones`) is always fine.

## When to ask first vs just do it

- **New issue creation:** show the issue details, ask "create it?" once. The shared tracker is team-visible.
- **Issue updates (state, comment, assignee):** just do it. Trivially reversible.
- **Bulk creation (more than ~3 issues):** show the plan, get one confirmation, then run the batch.
- **Anything destructive** (deleting issues, changing state to Canceled/Duplicate): always confirm.
