# tmux Protocol

How to communicate between orchestrator and worker sessions via tmux.

## The send-keys rule

Every tmux send-keys call MUST use this two-step form:

```bash
tmux send-keys -t '<target>' 'message' && sleep 0.5 && tmux send-keys -t '<target>' Enter
```

NEVER combine text and Enter in a single send-keys call. The combined form fails silently — the text appears in the input but never submits.

## Deriving session names

The orchestrator session name is the source of truth.

```bash
CURRENT_SESSION=$(tmux display-message -p '#S')
```

**Naming rules:**

| Orchestrator session | Single worker | Multiple workers |
|---|---|---|
| `VEL-420-557-arc` | `vel-420-557-worker` | `vel-420-557-worker-1`, `-2` |
| `VEL-420` | `vel-420-worker` | `vel-420-worker-1`, `-2` |
| `vel-420-grafana` | `vel-420-grafana-worker` | `vel-420-grafana-worker-1`, `-2` |

The rule: lowercase the orchestrator name, strip any trailing slug like `-arc`/`-orc` if present, append `-worker` (or `-worker-N` for multiple).

## Identifying your pane

Workers need your pane address to signal back. Capture it early:

```bash
tmux display-message -p '#{session_name}:#{window_index}.#{pane_index}'
```

Save the result — it becomes `<ORCHESTRATOR_PANE>` in all instructions.

## Worker setup sequence

Workers are created by forking the orchestrator's conversation. This gives them full context without any file-reading overhead.

**Workers always launch in `velatir-coordination`** (or its task worktree) — never in a target repo. This ensures `--continue` finds the orchestrator's session. Workers access other repos via absolute paths.

For each worker:

```bash
# 1. Create tmux session in the coordination worktree
tmux new-session -d -s '<worker-name>' -c '<coordination-worktree-path>'

# 2. Launch Claude, resuming the orchestrator's exact conversation
#    <SESSION_ID> is the UUID captured in Phase 1 — substitute it literally.
#    Use --resume (not --continue) to target this specific session even when
#    multiple Claude sessions are active.
tmux send-keys -t '<worker-name>' 'claude --resume <SESSION_ID>' && sleep 0.5 && tmux send-keys -t '<worker-name>' Enter

# 3. Verify Claude launched
sleep 5
tmux capture-pane -t '<worker-name>' -p -S -5
# ✓ Claude's prompt (❯) or status bar visible → proceed
# ✗ Shell prompt ($), error, or "No conversation found" → see Error Recovery

# 4. Fork the conversation
tmux send-keys -t '<worker-name>' '/branch' && sleep 0.5 && tmux send-keys -t '<worker-name>' Enter
sleep 2

# 5. Switch to Sonnet
tmux send-keys -t '<worker-name>' '/model sonnet' && sleep 0.5 && tmux send-keys -t '<worker-name>' Enter
sleep 2

# 6. Send mode-switch prompt (see "Sending prompts to workers" below)
```

Stagger multiple worker launches by ~3 seconds to avoid resource contention.

## Signaling conventions

| Direction | Format | Mechanism |
|---|---|---|
| Orchestrator → Worker | Plain instruction text | tmux send-keys to worker session |
| Worker → Orchestrator | Prefixed with `WORKER:` (or `WORKER-N:`) | tmux send-keys to orchestrator pane |

ALL worker→orchestrator signals use `tmux send-keys` — never local output. Messages arriving in the orchestrator pane that start with `WORKER:` are from workers, not the user.

## Waiting for worker signals

After sending a task, say "Waiting for worker(s) to report back." and END YOUR TURN.

Do NOT:
- Poll with `until` loops
- Use the Monitor tool to watch the worker
- Run `tmux capture-pane` to grep for status
- Sleep-loop waiting for file changes

Worker signals arrive as your next user message via send-keys. Just wait.

## Sending prompts to workers

Always write prompts to a file and tell Claude to read it. Never send multi-line content directly via `send-keys` — special characters and newlines break shell interpretation if Claude isn't running.

```bash
# 1. Write the prompt to a temp file (role prompt, task brief, or both)
cat > /tmp/claude-prompt-<worker-name>.md << 'PROMPT'
<prompt content>
PROMPT

# 2. Tell Claude to read and follow it
tmux send-keys -t '<worker-name>' 'Read /tmp/claude-prompt-<worker-name>.md and follow the instructions.' && sleep 0.5 && tmux send-keys -t '<worker-name>' Enter
```

This works for mode-switch prompts, task briefs, and combined prompts (cross-project workers).

## Error recovery

If verification (step 3) shows Claude didn't start:

1. Check the pane: `tmux capture-pane -t '<worker-name>' -p -S -10`
2. Common causes:
   - **"No conversation found"**: the `<SESSION_ID>` is wrong or the session file doesn't exist — re-run the Phase 1 capture command and verify the UUID
   - **Worker session was created in the wrong directory**: it must be the coordination worktree, not a target repo
   - **Claude crashed on startup**: check for disk/memory issues, retry
3. Kill the failed session: `tmux kill-session -t '<worker-name>'` and recreate

## Troubleshooting

- **Worker doesn't respond within ~5 minutes**: check `tmux list-sessions`. If alive, nudge. If dead, spin up a replacement.
- **Worker session already exists**: ask the user whether to reuse or kill and recreate.
- **Mode-switch prompt appeared in shell, not Claude**: Claude didn't launch — verification step was skipped or failed. Kill session, verify launch, retry.
