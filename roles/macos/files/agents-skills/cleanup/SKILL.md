---
name: cleanup
description: "Flush and tear down all sessions, worktrees, and branches for a completed task. Flushes context from all sub-sessions before closing them, then removes worktrees and deletes local/remote branches. Triggers on: 'clean up', 'tear down', 'close out VEL-XXX', 'we're done with this task'."
disable-model-invocation: false
---

# Cleanup — flush, close, and tear down a completed task

End-of-task cleanup: flush all related sessions so their context is preserved for docs, then tear down tmux sessions, worktrees, and branches.

## When to use

- The user says "clean up", "tear down", "we're done", "close out this task"
- A task's PRs have been merged and the user wants to clean up the local state
- The user asks to shut down sub-sessions for a ticket

## Prerequisites

- Run this from the **main ticket session** (e.g. `VEL-554`), not from a sub-session
- PRs should be merged or explicitly abandoned before cleanup — this skill deletes branches

---

## Phase 1 — Discover

Gather everything related to the task. The ticket ID comes from the tmux session name.

### 1a. Related tmux sessions

```bash
tmux list-sessions -F '#{session_name}' | grep -i '<ticket-prefix>'
```

This finds the main session and all sub-sessions (e.g. `VEL-554`, `vel-554-grafana-tf`, `vel-554-helm`).

### 1b. Worktrees

```bash
ls -d /Users/kaspersiig/Code/workspaces/<ticket-prefix>*/ 2>/dev/null
```

For each worktree directory, list the repos inside and their branches:

```bash
for repo in /Users/kaspersiig/Code/workspaces/<slug>/*/; do
  echo "$(basename "$repo"): $(git -C "$repo" branch --show-current)"
done
```

### 1c. Existing context flushes

Check which sessions already have flushed context:

```bash
for dir in /Users/kaspersiig/Code/workspaces/<slug>/velatir-coordination/ai/task-context/*/; do
  [ -d "$dir" ] && echo "$(basename "$dir"): flushed"
done
```

### 1d. PR status

For each repo with a worktree, check if the branch has a PR and its status:

```bash
gh pr view <branch-name> --repo velatir/<repo-name> --json state,mergedAt 2>/dev/null
```

### 1e. Stale remote branches

**Do not rely only on local worktree branches.** Merged PRs often leave remote branches behind (GitHub auto-delete is not always enabled). For every repo involved, scan the remote for task-related branches:

```bash
git -C /Users/kaspersiig/Code/<repo-name> fetch --prune origin
git -C /Users/kaspersiig/Code/<repo-name> branch -r | grep -iE '<ticket-id>|<sub-issue-ids>'
```

Also scan for local branches that aren't in any worktree but match the task pattern:

```bash
git -C /Users/kaspersiig/Code/<repo-name> branch | grep -iE '<ticket-id>|<sub-issue-ids>'
```

Include all discovered branches in the cleanup plan — not just those found via worktrees.

---

## Phase 2 — Present plan

Show the user what will happen before doing anything destructive. Format:

```
## Cleanup Plan for <ticket-id>

### Sessions to flush and close
- VEL-554 (main — will flush, will NOT close)
- vel-554-grafana-tf (will flush, then close)
- vel-554-helm (already flushed, will close)

### Worktrees to remove
- workspaces/vel-554-cockpit-audit/velatir-infrastructure (branch: fix/vel-554-varlog-mount)
- workspaces/vel-554-cockpit-audit/velatir-coordination (branch: feat/vel-554-cockpit-audit)

### Branches to delete
| Repo | Branch | PR Status | Local | Remote |
|------|--------|-----------|-------|--------|
| velatir-infrastructure | fix/vel-554-varlog-mount | merged | delete | delete |
| velatir-coordination | feat/vel-554-cockpit-audit | merged | delete | delete |

### Context preserved at
- ai/task-context/VEL-554/INDEX.md
- ai/task-context/vel-554-grafana-tf/INDEX.md
- ...
```

**Wait for user confirmation before proceeding.** The user may want to keep certain sessions or branches.

### Plan rules

- **Never close the main session** — the user is running this skill from it. Flush it, but don't kill it.
- **Flag unmerged PRs** — if a branch has an open (unmerged) PR, warn prominently. Default to skipping branch deletion for these; the user must explicitly confirm.
- **Flag branches with no PR** — these may have unfinished work. Warn and default to skip.
- **Show what context will be preserved** — list the INDEX.md paths so the user knows the knowledge is safe.

---

## Phase 3 — Flush sessions

Flush all sub-sessions that don't already have up-to-date context. Skip sessions that already have an INDEX.md modified within the current session's lifetime.

### How to flush a sub-session

The sub-sessions are running Codex instances in other tmux sessions. Send `/flush` to each:

```bash
tmux send-keys -t "<session-name>" "/flush" Enter
```

**Important constraints:**

- Only send `/flush` to sessions that are **idle** (waiting for user input). Check by inspecting the last line of the pane:
  ```bash
  tmux capture-pane -t "<session-name>" -p | tail -5
  ```
  If the session shows a prompt (`>` or `$`), it's idle. If it shows tool output or "thinking", it's busy.

- **For busy sessions**: wait and retry, or report to the user that the session needs to finish its current work first. Do NOT send keys to a busy session.

- **For dead/exited sessions**: skip — there's nothing to flush. Note this in the report.

### Polling for flush completion

After sending `/flush`, poll until the INDEX.md appears or is updated:

```bash
# Check if INDEX.md was modified in the last 120 seconds
find <worktree>/velatir-coordination/ai/task-context/<session-name>/ -name INDEX.md -mmin -2 2>/dev/null
```

Poll every 10 seconds, timeout after 2 minutes. If a flush doesn't complete, report it and continue — don't block the entire cleanup.

### Flush the main session too

After all sub-sessions are flushed, flush the main session's own context. This is a direct `/flush` invocation (the skill is running in the main session, so just call the flush skill inline — introspect on the current conversation and write the context files).

---

## Phase 4 — Close sub-sessions

Kill each sub-session's tmux session:

```bash
tmux kill-session -t "<session-name>"
```

Do NOT kill the main session.

---

## Phase 5 — Preserve flushed context

Before removing sub-task worktrees, consolidate all flushed `ai/task-context/` and `ai/chat-notes/` into the **main task's worktree** (e.g. `workspaces/vel-419-resource-dashboard/velatir-coordination`). This is the worktree for the parent ticket — the one the orchestration session manages. The user will write stable documentation from this material in that worktree, and it reaches main through a PR like any other change.

**Do NOT copy to the primary checkout.** Do NOT open a PR as part of cleanup — the user will do that after writing docs.

### Identify the main task worktree

The main task worktree is the one belonging to the parent ticket session (e.g. `workspaces/vel-422/velatir-coordination` for VEL-422). It should already exist from when the task was set up.

**If the main task worktree does not exist, CREATE it.** Do not fall back to the primary checkout — that violates the worktree rule in AGENTS.md. Create it the same way any other worktree is created:

```bash
mkdir -p /Users/kaspersiig/Code/workspaces/<main-task-slug>
git -C /Users/kaspersiig/Code/velatir-coordination worktree add -b feat/<main-task-slug> /Users/kaspersiig/Code/workspaces/<main-task-slug>/velatir-coordination main
```

If it was removed earlier in this cleanup, that's a mistake — the main task worktree must survive cleanup so the user can write docs in it.

### Copy context

```bash
DEST="/Users/kaspersiig/Code/workspaces/<main-task-slug>/velatir-coordination"
mkdir -p "${DEST}/ai/task-context" "${DEST}/ai/chat-notes"

# Copy from each sub-task worktree being cleaned up
for slug in <sub-task-worktree-slugs>; do
  SRC="/Users/kaspersiig/Code/workspaces/${slug}/velatir-coordination"
  cp -rn "${SRC}/ai/task-context/"* "${DEST}/ai/task-context/" 2>/dev/null
  cp -rn "${SRC}/ai/chat-notes/"* "${DEST}/ai/chat-notes/" 2>/dev/null
done
```

Use `-rn` (no-clobber) so newer context from one worktree doesn't overwrite context from another.

Verify the copy succeeded:

```bash
ls "${DEST}/ai/task-context/"
ls "${DEST}/ai/chat-notes/"
```

This is mandatory — do not skip it. The flushed context feeds into documentation and is the primary knowledge artifact from the task.

### Stray flush locations

Sub-sessions may flush context to unexpected paths (e.g. `/Users/kaspersiig/Code/ai/` if the session ran from the parent directory). After copying to the main task worktree, check for and clean up any stray `ai/task-context/` directories outside the coordination repo.

### What gets removed vs. what stays

- **Sub-task worktrees** (e.g. `vel-551-grafana-alerting/`, `fix-k8s-monitoring-varlog/`): removed in Phase 6 after context is copied out.
- **Main task worktree** (e.g. `vel-419-resource-dashboard/`): **kept**. This is where the user writes docs. Only cleaned up after docs are merged.

---

## Phase 6 — Remove worktrees

For each worktree directory:

```bash
# From the primary checkout of each repo
git -C /Users/kaspersiig/Code/<repo-name> worktree remove /Users/kaspersiig/Code/workspaces/<slug>/<repo-name>
```

If the worktree has uncommitted changes, `git worktree remove` will fail. In that case:
- Report the uncommitted changes to the user
- Ask whether to force-remove (`--force`) or skip
- Default to skip — never force-remove without confirmation

After all worktrees are removed, delete the empty task directory:

```bash
rmdir /Users/kaspersiig/Code/workspaces/<slug> 2>/dev/null
```

---

## Phase 7 — Delete branches

For each branch confirmed for deletion in the plan:

**Local branch:**
```bash
git -C /Users/kaspersiig/Code/<repo-name> branch -d <branch-name>
```

Use `-d` (safe delete), not `-D`. If the branch isn't fully merged, git will refuse — report this and let the user decide.

**Remote branch:**
```bash
git -C /Users/kaspersiig/Code/<repo-name> push origin --delete <branch-name>
```

Skip remote deletion for branches whose PRs are not merged (unless the user explicitly confirmed).

---

## Phase 8 — Report

Summarize what was done:

```
## Cleanup Complete: <ticket-id>

### Flushed
- VEL-554 → ai/task-context/VEL-554/INDEX.md
- vel-554-grafana-tf → ai/task-context/vel-554-grafana-tf/INDEX.md

### Closed sessions
- vel-554-grafana-tf, vel-554-helm, vel-554-metric-gaps, vel-554-terraform

### Removed worktrees
- workspaces/vel-554-cockpit-audit/velatir-infrastructure
- workspaces/vel-554-cockpit-audit/velatir-coordination

### Deleted branches
- velatir-infrastructure: fix/vel-554-varlog-mount (local + remote)
- velatir-coordination: feat/vel-554-cockpit-audit (local + remote)

### Skipped
- (anything that was skipped and why)
```

---

## Edge cases

- **Multiple worktree directories for one ticket**: possible if sub-tasks created their own worktrees. Discover all with the glob pattern, clean up each.
- **Shared branches across worktrees**: unlikely but check — don't try to delete a branch twice.
- **Main session has no worktree**: this can happen (e.g. the coordination repo memory says task-1 intentionally has no coordination worktree). The skill still flushes and cleans up what exists.
- **Context files in worktree vs primary checkout**: flushed context lives in the cleaned-up task's worktree. After worktree removal, these files are gone. **Always copy `ai/task-context/` and `ai/chat-notes/` to the current session's worktree before removing the cleaned-up worktrees.** The context then gets committed and merged as part of the current session's PR.
- **User wants partial cleanup**: respect the plan confirmation — if they say "keep vel-554-grafana-tf running", skip it entirely (no flush, no kill, no branch delete).

## Constraints

- Always confirm before destructive actions (worktree removal, branch deletion)
- Never kill the main session
- Never force-delete branches with unmerged PRs without explicit confirmation
- Flush before close — context preservation is the whole point
- The flushed context is valuable for documentation — note the paths clearly in the report
