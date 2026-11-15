---
name: enrich-session-names
description: Scan all tmux sessions for Linear task IDs (parent and sub-issues), look up each issue title, and save them to ~/.Codex-tmux/titles.json so Codex-tmux displays them in group headers and inline on sub-issue rows.
disable-model-invocation: true
---

# Enrich session names — fetch Linear titles for the TUI

Scans all tmux sessions, identifies Linear issue IDs (both parent tasks and sub-issues), fetches their titles, and writes the mapping to `~/.Codex-tmux/titles.json`. The Codex-tmux TUI reads this file to:
- Show parent titles in group headers: `── VEL-420 — Self-hosted GH Actions runner ──`
- Show sub-issue titles inline instead of the working directory path

Titles are reloaded on refresh (R key in the TUI).

## Session name patterns

| Pattern | Example | Linear ID |
|---------|---------|-----------|
| `VEL-<num>` | `VEL-420` | `VEL-420` |
| `VEL-<parent>-<sub>-<slug>` | `VEL-420-556-ci` | `VEL-556` |
| `vel-<parent>-<slug>` | `vel-420-grafana` | _(no Linear ID — skip)_ |

Sub-issues are identified by having a numeric segment after the parent number: `VEL-<parent>-<sub>-...` where `<sub>` is a number.

## titles.json format

Flat JSON object. Parent titles are keyed by their task ID. Sub-issue titles are keyed by their **session name** (so the TUI can look them up directly):

```json
{
  "VEL-419": "Cluster resource dashboard",
  "VEL-420": "Self-hosted GH Actions runner",
  "VEL-420-556-ci": "Migrate CI to self-hosted runner",
  "VEL-420-557-arc": "Deploy ARC in Kapsule cluster"
}
```

## Steps

1. List all tmux sessions:
   ```bash
   tmux list-sessions -F '#{session_name}'
   ```

2. Read the existing `~/.Codex-tmux/titles.json` if it exists.

3. Build a fetch list — for each session, determine if it needs a title:
   - **Parent sessions** (`VEL-<num>`): Linear ID = session name. Key in titles.json = session name.
   - **Sub-issue sessions** (`VEL-<parent>-<sub>-<slug>` where `<sub>` is numeric): Linear ID = `VEL-<sub>`. Key in titles.json = session name.
   - **Ad-hoc sessions** (`vel-<parent>-<slug>`, no numeric sub-issue): skip.
   - **Non-Linear sessions**: skip.

   Only fetch titles for keys not already in the file.

4. For each new ID, call `mcp__claude_ai_Linear__get_issue` to fetch the title.

5. Merge new titles into the existing map and write back to `~/.Codex-tmux/titles.json`.

6. Report what was added. If all titles were already cached, say so.
