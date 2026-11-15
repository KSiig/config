# Worker Mode-Switch Prompt

Workers are forked from the orchestrator's conversation — they already have full context. The mode-switch prompt tells the worker it's now in worker mode and sets up the signaling protocol.

## Placeholders

| Placeholder | Source |
|---|---|
| `<ORCHESTRATOR_PANE>` | Result of `tmux display-message -p '#{session_name}:#{window_index}.#{pane_index}'` |
| `<WORKER_ID>` | Worker number (e.g., `1`, `2`) — omit prefix numbering for single-worker setups |

## Mode-switch prompt

Send this after the `/branch` and `/model sonnet` steps are complete:

```
You are now a worker session. You have full context from the orchestrator's conversation.

## Your protocol

1. You'll receive task instructions via tmux (either inline or pointing to a brief file).
2. Implement what's described — you make design and implementation decisions.
3. Do NOT commit or stage anything. The orchestrator handles git.
4. When done, signal the orchestrator:
   tmux send-keys -t '<ORCHESTRATOR_PANE>' 'WORKER: Done. Files: <list>. Summary: <one line>.' && sleep 0.5 && tmux send-keys -t '<ORCHESTRATOR_PANE>' Enter
5. Wait for the next task.

## tmux send-keys rule

ALWAYS split text and Enter into two calls:
  tmux send-keys -t '<target>' 'message' && sleep 0.5 && tmux send-keys -t '<target>' Enter

## Rules

- Stay in the worktree. Don't cd elsewhere.
- If something is ambiguous, make a reasonable call — don't ask.
- If blocked, signal back explaining why.
- Use Explore subagents for lookups.

Signal readiness now:
tmux send-keys -t '<ORCHESTRATOR_PANE>' 'WORKER: Session ready.' && sleep 0.5 && tmux send-keys -t '<ORCHESTRATOR_PANE>' Enter
```

For multiple workers, replace `WORKER:` with `WORKER-<N>:` in all signal prefixes.

## How to send

Write the prompt (with all placeholders filled) to `/tmp/claude-prompt-<worker-name>.md`, then:

```bash
tmux send-keys -t '<worker-name>' 'Read /tmp/claude-prompt-<worker-name>.md and follow the instructions.' && sleep 0.5 && tmux send-keys -t '<worker-name>' Enter
```

**Never send this prompt directly via `tmux send-keys`** — multi-line content breaks shell interpretation if Claude isn't running.

