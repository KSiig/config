---
name: orchestrate
description: "Set up an Opus-orchestrator / Sonnet-worker pattern for the current task. Forks the orchestrator's conversation via /branch, switches to Sonnet, and configures bidirectional tmux send-keys. Supports multiple concurrent workers. Triggers on: 'orchestrate', 'set up a worker', 'opus/sonnet pattern', 'spin up an orchestrator-worker', or any ask to delegate implementation to a persistent Sonnet session."
disable-model-invocation: false
---

# Orchestrate — Opus orchestrator + Sonnet workers (branch-based)

The current session (Opus) plans, reviews, and integrates; one or more Sonnet workers implement. Workers are created by forking the orchestrator's conversation via `/branch` — they start with full context, no bootstrapping needed. Communication is via tmux send-keys.

Reference files in `patterns/`:
- [tmux-protocol.md](patterns/tmux-protocol.md) — send-keys rule, naming, setup sequence, signaling
- [worker-role-prompt.md](patterns/worker-role-prompt.md) — mode-switch prompt template
- [writing-briefs.md](patterns/writing-briefs.md) — brief structure, when to use inline vs file-based
- [observability.md](patterns/observability.md) — per-task log and retro templates

## When to use

**Low threshold — use it liberally.** Spinning up a worker takes ~10 seconds (branch + model switch), and the worker already has full conversation context. The only cost is a one-time cache miss when Sonnet processes the existing conversation.

Use workers for:
- Any implementation slice requiring design decisions, code reading, or multi-file changes
- Parallel independent slices — spin up multiple workers simultaneously
- Tasks where the worker's autonomy adds value (the brief describes the goal, not the exact output)

## When NOT to use

- Trivially small scope (one 5-line edit)
- Pure exploration ("where is X defined") — use Explore subagents instead
- Copy-heavy/mechanical work where the brief is as long as the work

## Multiple workers

You can run multiple workers concurrently when slices are independent:
- 2-3 concurrent workers is a sweet spot — more becomes hard to track
- Each worker gets its own tmux session (numbered: `-worker-1`, `-worker-2`)
- Don't over-slice: a worker should have a meaningful unit of work, not a single file edit
- Stagger launches by a few seconds to avoid resource contention

---

## Phase 1 — Derive names and verify state

1. Get your tmux session name and derive worker name(s) (see [tmux-protocol.md](patterns/tmux-protocol.md) for naming rules)
2. Capture your pane identifier — workers need it to signal back:
   ```bash
   tmux display-message -p '#{session_name}:#{window_index}.#{pane_index}'
   ```
3. Capture your session ID — workers use it to resume the exact conversation:
   ```bash
   cat ~/.Codex/sessions/$PPID.json | python3 -c "import json,sys; print(json.load(sys.stdin)['sessionId'])"
   ```
   Save this UUID as `<SESSION_ID>`. It is substituted literally into the `--resume` flag in the worker setup sequence.
4. Verify the worktree is set up (`git status`, `git branch --show-current`). If not, follow AGENTS.md's worktree procedure first.

## Phase 2 — Spawn worker(s) via branch

For each worker to create, run the setup sequence in [tmux-protocol.md](patterns/tmux-protocol.md). Summary:

1. **Create tmux session** in the coordination worktree (never a target repo)
2. **Launch Codex**: `Codex --continue`. Wait ~5s.
3. **Verify Codex started**: capture the pane — look for `❯`, not `$` or errors
4. **Branch**: `/branch`. Wait ~2s.
5. **Switch model**: `/model sonnet`. Wait ~2s.
6. **Send mode-switch prompt**: write to file, tell worker to read it (see [worker-role-prompt.md](patterns/worker-role-prompt.md))

**Verification is mandatory.** Do NOT proceed with `/branch`, `/model`, or prompts until Codex is confirmed running. See error recovery in [tmux-protocol.md](patterns/tmux-protocol.md) if verification fails.

After all workers are launched, **reset the default model** by running `/model Codex-opus-4-6` in the orchestrator session. The workers' `/model sonnet` persists as the session default — without this reset, future sessions will start as Sonnet.

## Phase 3 — Fetch the task spec

Use the /linear skill to fetch the task using the ticket ID from the session name.

- `VEL-420-557-arc` → ticket is `VEL-557`
- `VEL-420` → ticket is `VEL-420`

## Phase 4 — Plan decomposition

Plan the slices before delegating. Explicitly mark which slices can run in parallel:

```
## Orchestration Plan

Task: VEL-XXX — <title>

### Slices
1. <slice description> → worker-1 ┐
2. <slice description> → worker-2 ├ parallel
3. <slice description> → worker-1 (after #1)
4. <small fixup> → self (< 10 lines)

### Worker count: 2
### Delegation criteria
- Worker tasks: implementation requiring design decisions, code reading, multi-file changes
- Self tasks: <10 line fixups, git ops, verification
```

Show the plan to the user, then proceed without waiting for confirmation.

## Phase 5 — Execute (task loop)

For each slice:

1. **Send the task** — For simple tasks, send instructions inline via tmux. For complex multi-step work, write a brief to `tasks/worker-task-N.md` and tell the worker to read it (see [writing-briefs.md](patterns/writing-briefs.md)).
2. **Wait** — Say "Waiting for worker(s) to report back." and END YOUR TURN. Do not poll.
3. **Receive signal** — Messages starting with `WORKER:` (or `WORKER-N:`) are from workers. Review the diff, then either move on or send rework instructions.
4. **Log** the round-trip (see [observability.md](patterns/observability.md))

With multiple workers, signals may arrive in any order. Handle whichever arrives first.

For self-tasks: do trivial fixups yourself while workers are busy.

## Phase 6 — Verify, commit, and PR

1. Run tests / verification appropriate to the codebase
2. Review the full diff: `git diff`
3. Stage, commit, push, and create a PR per AGENTS.md rules
4. Report PR URLs to the user

## Phase 7 — Retro

Write an end-of-task retro (see [observability.md](patterns/observability.md) for the template).

---

## Edge cases

- **Worker doesn't respond within ~5 minutes**: check `tmux list-sessions`. If alive, nudge. If dead, spin up a replacement — it's fast (branch + model switch).
- **Worker signals an error or blocker**: decide whether to rework instructions, do it yourself, or escalate to user
- **User sends a message while waiting**: user message takes priority — respond, then resume waiting
- **Worker session already exists**: ask the user whether to reuse or kill and recreate
- **Merge conflicts between parallel workers**: orchestrator resolves — plan parallel slices to touch independent files when possible
