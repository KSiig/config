I need you to spawn claude-tmux sessions. Here's exactly how it works:

## Mechanism

claude-tmux is a TUI that enumerates tmux sessions and shows the ones running
`claude`. To spawn a new session that shows up in claude-tmux, do:

1. tmux new-session -d -s "<session-name>" -c "<working-directory>"
2. tmux send-keys -t "<session-name>" "claude --model claude-opus-4-7 -n '<session-name>' '<prompt>'" Enter

The --model flag is REQUIRED right now because opus 4.6 has issues — always
use claude-opus-4-7. The -n flag sets the display name for /resume.

## For long prompts

send-keys gets messy with quoting. Write the prompt to a tempfile and stream it:

cat > /tmp/claude-prompt-<name>.md << 'PROMPT'
<full prompt content>
PROMPT

tmux send-keys -t "<name>" "claude --model claude-opus-4-7 -n '<name>' < /tmp/claude-prompt-<name>.md" Enter

## Worktree reminder (MANDATORY in every prompt)

Spawned sessions land in the primary velatir-coordination checkout, but
CLAUDE.md requires all work to happen in a worktree. Every prompt MUST start
with this block:

  BEFORE DOING ANYTHING ELSE: You are running in the primary velatir-coordination
  checkout. Per CLAUDE.md, all work must happen in a worktree. Read CLAUDE.md
  for the full worktree setup instructions, then:
  1. Set up a worktree under workspaces/<task-slug>/ for every repo you will
     touch (always including velatir-coordination)
  2. Register the worktrees in VSCode settings (see CLAUDE.md for the python3 snippet)
  3. IMPORTANT: After setting up the worktree, tell the user to switch to the
     worktree session. You cannot cd into the worktree yourself. Create the
     worktrees, register them, then stop and report what you did.

## Default mode: research-only

Unless I explicitly say "implement" / "build" / "fix", prompts should tell the
spawned session to research only — read code/config/Linear, write findings to
ai/chat-notes/<task-slug>/ IN THE WORKTREE, and stop before making changes.

## Before spawning

- Run `tmux list-sessions -F '#{session_name}'` to avoid name collisions
- Use valid tmux names (no dots, no colons)
- Default working directory: /Users/kaspersiig/Code/velatir-coordination
- Do NOT switch to the spawned session — leaves my current session

## Report back

Session name, working directory, mode (research/implement), how to switch
(`tmux switch-client -t <name>` or via claude-tmux TUI).
