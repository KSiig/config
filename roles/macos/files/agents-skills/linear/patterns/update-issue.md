# Pattern — Update an existing issue with a progress update

Triggered by things like *"Please update [task](https://linear.app/velatir/issue/VEL-418/...) with a progress update of where we're at"* or *"move VEL-XXX to In Progress and note we shipped phase 1"*.

## Steps

1. **Parse the identifier** from the URL: `VEL-\d+`. Linear URLs contain `/issue/(VEL-\d+)/` — the trailing slug is irrelevant.
2. **Check the current state** before changing it — don't silently downgrade a Done/Canceled issue:
   ```
   get_issue(id: "VEL-418")
   ```
3. **Determine the real progress** — don't make it up. For a task with a worktree under `~/Code/workspaces/<slug>/`, inspect: `git status`, `git log origin/main..HEAD`, `gh pr view <branch>`, plus `ai/chat-notes/<slug>/` for design notes and `docs/90-open-items/<slug>/` for newly-discovered open items. Cite specific commits, files, line numbers.
4. **State transition (if any).** Move to **In Progress** when committed work exists on a feature branch but no PR is open. Move to **In Review** when a PR is open. Move to **Done** only when the user confirms or the PR is merged. Set assignee to `"me"` when transitioning to a started state and no assignee is set.
5. **Post a comment**, don't overwrite the description. Comments are the idiomatic progress channel; the description stays the spec. Use a heading `**Progress update — YYYY-MM-DD** · branch \`...\` (PR: ...)` and sections **Done / committed**, **In progress / not started**, **New open question discovered** (if any).
6. **Run state-change + comment.** Use `save_issue` for state/assignee changes and `save_comment` for the progress note:

   ```
   save_issue(id: "VEL-418", state: "In Progress", assignee: "me")
   ```
   ```
   save_comment(issueId: "VEL-418", body: "**Progress update — 2026-05-27** · branch `feat/multi-az-prod-k8s` (no PR yet)\n\n**Done / committed**\n- ...\n\n**In progress / not started**\n- ...\n\n**New open question discovered**\n- ...")
   ```

**When NOT to change state.** Skip `save_issue` if the user only asked for a progress note. Use `save_comment` alone.
