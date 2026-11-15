---
name: flush
description: "Flush conversation context to structured, searchable files before /clear. Captures approaches tried, files understood, and decisions made so the next session can restore context without re-reading everything. Triggers on: 'flush', 'flush context', 'save context', 'checkpoint before clear'."
disable-model-invocation: false
---

# Flush Context

Serialize the current conversation's accumulated knowledge into a structured file tree that a fresh session can quickly scan and selectively drill into.

The output is optimized for AI retrieval: a single INDEX.md that a new session reads first, with links to detail files it reads only when needed.

## When to use

- Before running `/clear` to reset the context window
- When the context is getting large and you want to checkpoint understanding
- The user says "flush", "flush context", "save context", "checkpoint"

## Output location

Resolve the output path from the **current working directory** — do NOT search for worktrees by name.

- **CWD is inside a worktree** (path contains `workspaces/`): write to `<that-worktree>/velatir-coordination/ai/task-context/<context-id>/`. Use the worktree you are already in, even if the context ID doesn't match the worktree's directory name.
- **CWD is NOT inside a worktree** (orchestration or design sessions): write to `/Users/kaspersiig/Code/ai/task-context/<context-id>/`

The `~/Code/ai/task-context/` directory is the fallback for sessions that aren't tied to a specific repo or ticket worktree. These are typically orchestration sessions, design conversations, or cross-cutting work that doesn't belong in any single repo's worktree.

### Detecting the context ID

1. Get the tmux session name: `tmux display-message -p '#S'` (may fail outside tmux — that's fine)
2. Use the session name as the context ID verbatim (e.g. `VEL-554`, `vel-554-grafana-tf`, `SD-M2-VEL-843`)
3. Fallback: use the current git branch name, stripping any `feat/` or `chore/` prefix
4. If neither yields a usable ID, ask the user

### Session naming conventions

Sessions have a parent–child relationship based on naming. Two naming patterns are in use:

**Ticket-rooted** (older convention):
- `VEL-554` — the parent ticket session
- `vel-554-grafana-tf` — a sub-session handling one piece of VEL-554

**Project-milestone-ticket** (current convention):
- `SD-M2-VEL-843` — project SD, milestone M2, ticket VEL-843
- `SD-M2-VEL-843-enrichment` — a sub-session of the above

Each gets its own `ai/task-context/<name>/` directory. They stay separate — the sub-session's context shouldn't pollute the parent. The link between them is handled via a **Related Contexts** section in INDEX.md (see format below).

### Related context scanning

When flushing, scan `ai/task-context/` for sibling directories that share the same **ticket identifier** (the `VEL-XXX` portion). Extract the ticket ID from anywhere in the session name — it may be at the start (`VEL-554-grafana-tf`) or embedded (`SD-M2-VEL-843`). Match case-insensitively. List matches in the Related Contexts section so the next session knows they exist.

## File structure

```
ai/task-context/<ticket-id>/
  INDEX.md            # Single entrypoint — scannable lookup
  approaches/         # One file per approach explored
    <approach-slug>.md
  decisions/          # One file per non-obvious decision
    <decision-slug>.md
```

Keep it flat. Don't create subdirectories beyond `approaches/` and `decisions/`. If there are no rejected approaches or non-trivial decisions, skip those directories entirely — don't create empty structure.

---

## INDEX.md — the critical file

A new session reads ONLY this file first. It must give the agent enough to understand the full task state at a glance, and tell it exactly where to drill deeper.

### Format

```markdown
# Task Context: <ticket-id>

> <one-line summary of the ticket/task>

## Status

<what was just completed, what step is next>

## Approaches Explored

| Approach | Verdict | Detail |
|----------|---------|--------|
| <name> | Adopted / Rejected — <reason in ≤10 words> | [detail](approaches/<slug>.md) |

## Key Files

| File | Role |
|------|------|
| `<path>` | <what this file does and why it matters for the task — one line> |

## Decisions

| Decision | Rationale | Detail |
|----------|-----------|--------|
| <what was decided> | <why, in ≤15 words> | [detail](decisions/<slug>.md) |

## Gotchas

- <anything the next session should know to avoid wasting time>

## Related Contexts

| Context | Summary |
|---------|---------|
| [vel-554-grafana-tf](../vel-554-grafana-tf/INDEX.md) | Grafana Terraform module for VEL-554 |
```

Omit the Related Contexts section entirely if no sibling directories share the ticket prefix.

### INDEX.md rules

- **Every table row must be self-contained.** The agent should be able to decide whether to click the detail link from the one-liner alone. If the one-liner doesn't explain enough, improve it — don't rely on the detail file.
- **Key Files is a lookup table, not a file listing.** Only include files the next session would need to understand, modify, or avoid. Skip files that were only glanced at.
- **Gotchas are the highest-value section.** Anything that wasted time, was surprising, or contradicts what the code/docs suggest. These prevent the next session from repeating mistakes.
- **Status must be actionable.** "Done with step 3 of 5 in tasks/todo.md" is useful. "Making progress" is not.

---

## Detail files

### Approach files (`approaches/<slug>.md`)

Only create these for approaches that were actually explored (code written, commands run, errors hit). Don't document approaches that were briefly considered and dismissed in conversation — a one-liner in the INDEX.md table is enough for those.

```markdown
# Approach: <name>

**Verdict**: Adopted | Rejected | Partially used
**Why**: <2-3 sentences>

## What was tried

<concrete steps: code written, commands run, config changed>

## What happened

<results, errors, unexpected behavior — include actual error messages>

## Key takeaway

<one sentence the next session should internalize>
```

### Decision files (`decisions/<slug>.md`)

Only create these for decisions where the next session might reasonably choose differently without context. "We used .NET because the project is .NET" doesn't need a file.

```markdown
# Decision: <what was decided>

**Alternatives considered**: <list>
**Chosen**: <the decision>
**Why**: <reasoning, constraints, tradeoffs>

## Context

<what information drove this decision — specific code, config, or constraints discovered>
```

---

## Merging with previous flushes

If `ai/task-context/<ticket-id>/INDEX.md` already exists, this is a continuation. Read it and:

- **Append** new table rows to existing sections (approaches, files, decisions)
- **Update** the Status section to reflect current state
- **Add** new gotchas — don't remove old ones
- **Create** new detail files for newly explored approaches/decisions

Never discard information from a previous flush.

### Reconcile detail files with INDEX.md

After updating INDEX.md, open **every existing file** in `approaches/` and `decisions/` and check for contradictions:

- If the INDEX.md row says a verdict or status changed (e.g. "Discussion-only" → "Partially implemented"), update the detail file's **Verdict**, **Why**, and body text to match.
- INDEX.md is the source of truth. Detail files elaborate on what INDEX.md says — they must never contradict it.
- A new session may read a detail file without reading INDEX.md first. Stale detail files cause the next session to give wrong answers with high confidence.

---

## Steps

Flush is delegated to a **branched session** in a separate tmux window. The branch has the full conversation context to introspect on, so the main session returns immediately and the user can keep working or `/clear`.

If tmux is unavailable (detection fails at any step), fall back to **inline mode**: do steps 4–6 directly in the main session.

### Main session steps (orchestration)

1. **Detect context ID** (tmux session name → branch name → ask)

2. **Resolve output path** — apply the rules from "Output location" above.

3. **Check for existing flush** — check whether `ai/task-context/<context-id>/INDEX.md` exists. Pass this as a flag to the worker so it knows whether to merge or create fresh.

4. **Capture pane ID** (its own Bash call — variables don't survive between calls):

   ```bash
   tmux display-message -p '#{pane_id}'
   ```

   Read the output (e.g. `%5`). Hardcode this value into subsequent commands.

5. **Get conversation ID** (its own Bash call):

   ```bash
   cat ~/.Codex/sessions/$PPID.json | python3 -c "import json,sys; print(json.load(sys.stdin)['sessionId'])"
   ```

   Read the output (a UUID). This is the session ID needed for `--resume`.

6. **Write the flush instruction file** — use the Write tool to create `/tmp/flush-worker-<context-id>.md` with the content described in "Flush worker instruction file" below. This file tells the branched session exactly what to do.

7. **Create tmux window and launch branched Codex** (single Bash call, substitute captured values as literals):

   Replace `<PANE_ID>` with the value from step 4, `<SESSION_ID>` with the value from step 5:

   ```bash
   CWD=$(pwd) && WINDOW_ID=$(tmux display-message -t "<PANE_ID>" -p '#{window_id}') && TS=$(date '+%Y-%m-%d-%H%M') && NEW_PANE=$(tmux new-window -d -a -t "$WINDOW_ID" -c "$CWD" -n "flush-$TS" -P -F '#{pane_id}') && tmux set-option -t "$NEW_PANE" -p @Codex-tmux-exclude 1 && tmux send-keys -t "$NEW_PANE" "Codex --resume <SESSION_ID>" && sleep 0.5 && tmux send-keys -t "$NEW_PANE" Enter
   ```

   The output is the new pane ID (e.g. `%12`). Capture it for step 8.

8. **Branch and send flush instruction** (single Bash call, substitute `<NEW_PANE>` with the value from step 7, `<CONTEXT_ID>` with the context ID):

   ```bash
   sleep 5 && tmux send-keys -t "<NEW_PANE>" '/branch' && sleep 0.5 && tmux send-keys -t "<NEW_PANE>" Enter && sleep 3 && tmux send-keys -t "<NEW_PANE>" 'Read /tmp/flush-worker-<CONTEXT_ID>.md and follow the instructions exactly.' && sleep 0.5 && tmux send-keys -t "<NEW_PANE>" Enter
   ```

9. **Report and return** — tell the user:
   - Flush delegated to tmux window `flush-<ts>`
   - The worker will self-terminate when done
   - This session is free to continue working or `/clear`

   Then **end your turn**. Do not wait for the worker.

---

### Flush worker instruction file

Write this to `/tmp/flush-worker-<context-id>.md`. The branched session reads it and does the actual flush work.

The file must contain:

1. **Role statement**: "You are a flush worker. Your job is to serialize this conversation's accumulated knowledge into structured files."
2. **Context ID and output path**: the exact values resolved in steps 1–2.
3. **Previous flush flag**: whether INDEX.md already exists (so the worker knows to merge or create fresh).
4. **Reference to SKILL.md**: tell the worker to read `.Codex/skills/flush/SKILL.md` for the exact file format. Specifically call out these sections:
   - "Output location" (including related context scanning)
   - "File structure"
   - "INDEX.md — the critical file" (format and rules)
   - "Detail files"
   - "Merging with previous flushes" (if previous flush exists)
   - "What NOT to flush"
   - "Constraints"
5. **Explicit instruction to introspect**: tell the worker to review the full conversation and identify: task summary/status, approaches explored, key files, decisions, gotchas.
6. **Cleanup**: after writing files, delete `/tmp/flush-worker-<context-id>.md`.
7. **Self-terminate**: after cleanup, exit the Codex session by running `kill $PPID`. This sends SIGTERM to the Codex process and closes the tmux window.

Example instruction file:

```markdown
# Flush Worker Instructions

You are a flush worker. Your job is to serialize the conversation you were branched from into structured, searchable files.

## Parameters

- **Context ID**: `skill-flush`
- **Output path**: `/Users/kaspersiig/Code/ai/task-context/skill-flush/`
- **Previous flush exists**: yes — merge with the existing INDEX.md

## What to do

1. Read `.Codex/skills/flush/SKILL.md` — follow the "File structure", "INDEX.md", "Detail files", "Merging with previous flushes", "What NOT to flush", and "Constraints" sections exactly.
2. Introspect on the conversation you were branched from. Identify:
   - Task summary and current status
   - Approaches explored: what was tried, outcomes, verdicts
   - Files read or modified that matter for the task
   - Decisions made that weren't obvious
   - Gotchas: surprises, wasted time, non-obvious behavior
3. Scan for related contexts — look for sibling directories in the task-context parent that share the same ticket ID.
4. Write the files: INDEX.md first, then any detail files.
5. Report what was flushed and the output path.
6. Delete this instruction file: `rm -f /tmp/flush-worker-skill-flush.md`
7. Exit this session: `kill $PPID` — this closes the tmux window.
```

## What NOT to flush

- The full conversation (defeats the purpose)
- Trivial observations ("I read the README", "the project uses .NET")
- Anything already in AGENTS.md, stable docs, or the Linear ticket description
- Task progress checkboxes (those belong in `tasks/todo.md`)
- Standard patterns or conventions discoverable from the codebase
- Information that would be faster to re-derive than to read from a flush file

## Constraints

- Do not read the Linear ticket during flush — the conversation already has that context. The next session can fetch it fresh if needed.
- Keep INDEX.md under 80 lines. If you're exceeding that, you're including too much detail — move it to a detail file and keep the index row to one line.
- File slugs should be descriptive: `redis-caching.md` not `approach-1.md`.
