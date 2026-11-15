---
name: spawn-session
description: Spawn a new Codex-tmux session with an initial prompt. Triggers on requests like "spin up a session to ...", "spawn a session for VEL-XXX", "start a new Codex session to research ...", "kick off a parallel session", or any ask to create a separate Codex session in tmux with a task.
disable-model-invocation: false
---

# Spawn Session — create a Codex-tmux session with an initial prompt

Creates a new tmux session, starts `Codex` in it with an initial prompt, and (optionally) switches to it. The session appears in `Codex-tmux`'s TUI like any other session.

## How it works

`Codex-tmux` creates sessions via:
```
tmux new-session -d -s <name> -c <path>
tmux send-keys -t <name> "Codex" && sleep 0.5 && tmux send-keys -t <name> Enter
```

This skill does the same, but passes the prompt as a positional argument to `Codex`:
```
tmux new-session -d -s <name> -c <path>
tmux send-keys -t <name> "Codex -n '<name>' '<prompt>'" && sleep 0.5 && tmux send-keys -t <name> Enter
```

The `-n` flag sets the session display name so it's identifiable in `/resume`.

## Default mode: research-only

Unless the user explicitly says "implement", "build", "fix", or similar action words, **default to research mode**. Research-mode prompts tell the spawned session to:

- Read the relevant code, config, docs, and Linear issue description
- Produce findings, notes, and an implementation plan
- Write research output to `ai/chat-notes/` (not stable docs)
- **Stop and wait** before making any code changes — do NOT implement

Only include implementation instructions in the prompt when the user explicitly asks for it (e.g. "spawn a session to implement VEL-550" or "go ahead and build it").

## Main issue preamble (mandatory for top-level tickets)

When spawning a session for a **top-level ticket** (format `VEL-<num>`, not a sub-issue or ad-hoc sub-session), the prompt MUST include this preamble before the actual task instructions:

```
FIRST: Evaluate the Linear task description for this issue and ensure it's still accurate against the current codebase. Fetch and pull latest main on the primary checkout for all repos that the task touches:

  cd /Users/kaspersiig/Code/<repo> && git fetch origin && git pull origin main

Do this for every repo referenced in the task description. Then read the relevant code and compare it to the task's assumptions. If the description is outdated or inaccurate, note what changed and propose an updated description before continuing with research.
```

This does NOT apply to sub-issues or ad-hoc sub-sessions — only top-level tickets that are being researched for the first time.

## Research doc naming convention (mandatory)

Every research-mode session MUST create its research doc at:

```
<worktree>/velatir-coordination/ai/chat-notes/<session-name-lowercase>-research.md
```

The filename MUST match the regex `vel.*research\.md` — an Obsidian plugin auto-expands folders containing files with this pattern. Examples:

| Session name | Type | Research doc filename |
|---|---|---|
| `VEL-420` | Top-level | `vel-420-research.md` |
| `VEL-420-557-arc` | Sub-issue | `vel-557-arc-research.md` |
| `vel-420-grafana` | Ad-hoc sub-session | `vel-420-grafana-research.md` |

The rules:
- **Top-level and ad-hoc sub-sessions**: lowercase the session name, append `-research.md`
- **Linear sub-issues** (`VEL-<parent>-<sub>-<slug>`): use the sub-issue number + slug — `vel-<sub>-<slug>-research.md`. The parent context is already in the worktree path, so the research doc just needs the sub-issue ID and descriptor.

Include this instruction in every research-mode prompt sent to the spawned session.

## Worktree reminder (mandatory in every prompt)

Every prompt sent to a spawned session MUST begin with a worktree setup instruction. The AGENTS.md in velatir-coordination requires all work to happen in worktrees, never in the primary checkout. Include this block at the top of every prompt:

```
BEFORE TOUCHING ANY CODE: You are running in the primary velatir-coordination checkout. Per AGENTS.md, all work must happen in a worktree. Read AGENTS.md for the full worktree setup instructions, then:
1. Set up a worktree under workspaces/<task-slug>/ for every repo you will touch (always including velatir-coordination).
2. Register the worktrees in VSCode settings (see AGENTS.md for the python3 snippet).
3. Continue the task in this same session, using absolute paths into the worktree directory (the shell cwd does not persist between Bash tool calls, but `cd <worktree> && <cmd>` works fine, and absolute paths work without any cd). Do NOT stop and ask the user to start a new session — keep working.
```

This ensures the spawned session doesn't modify the primary checkout but also doesn't bounce the work back to the user unnecessarily.

## Task context system (mandatory in every prompt)

Every prompt MUST include a context awareness block after the worktree reminder. This tells the spawned session about the flush/restore system:

```
CONTEXT SYSTEM: A UserPromptSubmit hook will inject a task context pointer if a previous session flushed context for this session name. If you see a "[Task Context]" message, read the referenced INDEX.md file to restore context from the prior session.

Before ending your work or when the user says /flush, use the /flush skill to serialize your accumulated knowledge (approaches tried, files understood, decisions made) so the next session can pick up where you left off.
```

## Session naming convention

Session names determine how task context is stored and linked. Every sub-issue and sub-session name includes a short descriptor slug (1-2 words) so it's recognizable at a glance in tmux, worktree listings, and file browsers.

| Type | Format | Example | Worktree slug |
|------|--------|---------|---------------|
| Top-level ticket | `VEL-<num>` | `VEL-420` | `vel-420` |
| Linear sub-issue | `VEL-<parent>-<sub>-<slug>` | `VEL-420-557-arc` | `vel-420-557-arc` |
| Ad-hoc sub-session | `vel-<parent>-<slug>` | `vel-420-grafana-tf` | (shares parent worktree) |

**How to tell them apart:**
- `VEL-420-557-arc` — number after parent → Linear sub-issue of VEL-420, with descriptor `arc`
- `vel-420-grafana-tf` — slug after parent, no sub-issue number → ad-hoc sub-session of VEL-420

The naming matters because the context system uses the `VEL-<parent>` prefix to link related contexts. All three examples above share prefix `VEL-420` and are recognized as related.

**Deriving the slug:** Pick 1-2 words from the sub-issue title that identify the work at a glance. E.g., "Deploy ARC in existing Kapsule cluster" → `arc`. "Migrate K8s/Flux Terraform CI to self-hosted runner" → `ci-migration`.

When the user asks to "spawn a session for VEL-557 under VEL-420", and VEL-557 is about deploying ARC, derive the name `VEL-420-557-arc`.
When the user asks to "spawn a session for the Grafana part of VEL-420", derive the name `vel-420-grafana`.

## Prompt file approach

For prompts longer than ~200 characters, write the prompt to a temporary file and have Codex read it, rather than trying to pass it inline via send-keys (which has quoting/length limitations):

```bash
# Write prompt to a temp file
cat > /tmp/Codex-prompt-<session-name>.md << 'PROMPT'
<full prompt content>
PROMPT

# Start Codex reading from the file
tmux send-keys -t "<session-name>" "Codex -n '<session-name>' < /tmp/Codex-prompt-<session-name>.md" && sleep 0.5 && tmux send-keys -t "<session-name>" Enter
```

## Follow-up commands (skill triggers, model switches, etc.)

Slash commands like `/orchestrate` only trigger skills when they arrive as their own user message. Embedding `/orchestrate` inside a longer prompt means Codex sees it as prose — the skill never fires.

When a spawned session needs to invoke a skill or run a slash command after startup:

1. **Initial prompt**: provide context only — what the task is, where files are, which repos are involved. The prompt MUST end with an explicit instruction to acknowledge and wait. Do NOT include implementation instructions — the follow-up command handles that. If the prompt says "implement", "rename", "create", or any action verb, the session will start working immediately and the follow-up arrives too late.
2. **Follow-up message**: send the skill trigger as a separate `tmux send-keys` call after the session is alive. This is what actually kicks off the work.

The follow-up is queued as the next user input. Codex finishes processing the initial prompt (which is just an acknowledgment), then picks up the follow-up and the skill triggers normally.

**Mandatory send-keys pattern** — always split text and Enter with a delay:
```bash
tmux send-keys -t '<session>' '<message>' && sleep 0.5 && tmux send-keys -t '<session>' Enter
```
Never combine text and Enter in a single send-keys call — it fails silently.

**Example**: spawning a session that should use `/orchestrate`:

The context prompt (written to `/tmp/Codex-prompt-vel-420-557-arc.md`):
```
TASK: VEL-557 — Deploy ARC in existing Kapsule cluster
PLAN: Read ai/chat-notes/vel-557-arc-research.md for the full implementation plan.
REPOS: velatir-infrastructure

Set up your own worktree per AGENTS.md rules, then acknowledge this context and wait for the next message — do NOT start working yet.
```

The spawn sequence:
```bash
# Step 1: start Codex with context-only prompt (no action verbs)
tmux send-keys -t "vel-420-557-arc" "Codex -n 'vel-420-557-arc' < /tmp/Codex-prompt-vel-420-557-arc.md" && sleep 0.5 && tmux send-keys -t "vel-420-557-arc" Enter

# Step 2: wait for Codex to start and acknowledge, then send the skill trigger
sleep 5
tmux send-keys -t "vel-420-557-arc" '/orchestrate work on this task' && sleep 0.5 && tmux send-keys -t "vel-420-557-arc" Enter
```

The 5-second sleep gives Codex time to start and process the context prompt (which just acknowledges). Then `/orchestrate` arrives as a fresh user message and triggers the skill.

## Steps

1. **Parse the request.** Extract:
   - **Session name**: follow the naming convention above. Top-level tickets → `VEL-550`. Sub-tasks → `vel-550-<slug>` (lowercase prefix + descriptive slug). If ambiguous, ask.
   - **Prompt**: the task description / initial prompt to send to Codex. Default to research-only framing (see above). Always include the worktree reminder and context system blocks.
   - **Follow-up command**: if the spawned session needs to invoke a skill (e.g. `/orchestrate`), extract it as a separate follow-up — do NOT embed it in the prompt.
   - **Working directory**: defaults to `/Users/kaspersiig/Code/velatir-coordination`. Override if the user specifies a repo or path.

2. **Check for conflicts.** Run `tmux list-sessions -F '#{session_name}'` and verify the chosen name doesn't collide. If it does, append a numeric suffix or ask the user.

3. **Create the session and start Codex.**

   ```bash
   tmux new-session -d -s "<session-name>" -c "<working-directory>"
   ```

   Then start Codex. For short prompts, pass inline:
   ```bash
   tmux send-keys -t "<session-name>" "Codex -n '<session-name>' '<prompt>'" && sleep 0.5 && tmux send-keys -t "<session-name>" Enter
   ```

   For longer prompts, use the prompt file approach described above.

   **If there's a follow-up command**, send it after a delay:
   ```bash
   sleep 5
   tmux send-keys -t "<session-name>" '<follow-up command>' && sleep 0.5 && tmux send-keys -t "<session-name>" Enter
   ```

4. **Report back.** Tell the user:
   - Session name
   - Working directory
   - Mode (research / implement / orchestrate)
   - Follow-up command sent (if any)
   - How to switch: `tmux switch-client -t <session-name>` or find it in `Codex-tmux`

5. **Do NOT switch automatically** unless the user asked to. Switching would leave the current session.

## Docs graduation sub-issues — do NOT spawn

Issues titled "Graduate docs from ai/ to stable docs" are docs-graduation sub-issues. They are handled by the `docs-writer` subagent in the orchestrating session, not by a separate tmux session.

If asked to spawn a session for one of these issues:
1. **Do NOT create a tmux session.**
2. Tell the user: "This is a docs graduation task — it should be run via the `docs-writer` subagent in the current session, not as a separate tmux session. Use the `/linear` skill to move it to In Progress when you're ready to graduate the docs."

Detection: the issue title contains "Graduate docs" or the Linear issue description contains "Graduate verified findings to stable documentation".

## Multi-phase spawning

When spawning multiple sessions for phases of a task (e.g., Phase 0–4 of VEL-634):

### Each phase gets its own worktree and branch

Do NOT point phase sessions at the parent task's worktree. Each phase is an independent work unit:
- Phase 0 → `workspaces/vel-634-phase0/`, branch `feat/vel-634-phase0`
- Phase 1 → `workspaces/vel-634-phase1/`, branch `feat/vel-634-phase1`

The phase session sets up its own worktree per AGENTS.md rules (the worktree reminder block handles this). Do NOT include a `WORKTREE:` directive in the context prompt that points at the parent's worktree — that causes all phases to pile onto one branch.

### Inter-phase dependencies

If a phase depends on code changes from a previous phase (e.g., Phase 1 needs files that Phase 0 creates), the phase session should:
1. Note the dependency explicitly in its output
2. Prepare everything it can without the missing code
3. Wait for confirmation that the dependency has been merged before continuing
4. Signal the orchestrator that it's blocked on another phase, so the orchestrator knows to unblock it once the dependency is resolved

Do NOT tell phases to coordinate commits on a shared branch. Each phase works independently and merges independently.

### Merge targets and rebase sequence

Before a phase can open a PR, it must rebase to incorporate upstream changes:
1. Rebase the sub-issue worktree's branch onto latest `main`
2. Rebase the phase branch onto the sub-issue branch

Then open the PR. The merge target depends on the situation:
- **Most common**: merge to `main`. This is the default, and required when later phases or other tasks need the changes immediately (e.g., Phase 0 renames that must land before Phase 1 can branch).
- **Gathering changes**: occasionally it makes sense to merge a phase into the sub-issue branch to collect related changes before they go to `main` together. This is the exception, not the rule — only do it when explicitly requested.

Include the merge target in the phase's context prompt so the session knows where to PR.

## Constraints

- Do not create worktrees or branches — this skill only spawns the session. If the prompt implies a full task with worktree setup, mention that the spawned session should handle its own worktree setup per AGENTS.md rules.
- Keep prompts concise. If the user gives a long description, summarize it into a clear directive for the spawned session.
- Session names should be valid tmux session names (no dots, no colons).
