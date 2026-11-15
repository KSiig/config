---
name: walkthrough-script
description: >
  Turn an ordered human procedure into an executable interactive bash
  walkthrough. Each step is a command to run, a command that needs a
  decision, or an action outside the terminal (signup, API key, admin
  console). Use when the user asks for a walkthrough script, an
  interactive script for manual steps, a script they can execute that
  takes them through an issue, or a runbook for SII-xx / VEL-xx. Also
  used by coordinate-implementation after human-issue writeups.
  Slash command: /walkthrough-script or /skill:walkthrough-script.
triggers:
  - walkthrough script
  - interactive script
  - script I can execute
  - takes me through the steps
  - runbook for
  - human steps script
  - manual steps script
---

# Walkthrough script

Turn an ordered procedure into one bash script the person runs. The
script prints each step, runs commands that belong in the terminal,
pauses for actions outside the terminal, and prompts when a step needs
a decision.

This skill writes a file. It does not run the procedure live. It does
not open a pull request. It does not mark a Linear issue Done.

Read `references/script-shape.md` before you write the script. Copy
those templates. Do not invent a second flag set or a second prompt
shape.

## Invocation

```
/walkthrough-script <source>
/skill:walkthrough-script <source>
```

`<source>` is one of:

- A Linear issue id or URL (`SII-74`, `VEL-1234`, `https://linear.app/.../issue/...`)
- A path to a markdown file that already lists the steps
- Nothing, when the steps are already in the user message

If there is no source, ask. Do not invent a procedure from a milestone
summary or from chat history.

A caller (for example `coordinate-implementation`) may also pass an
output path. That path wins.

## Your task

1. Resolve the source into an ordered step list.
2. Classify each step as `command`, `command+decision`, or `out-of-terminal`.
3. Resolve the output path.
4. Write one bash script from `references/script-shape.md`.
5. Verify: `chmod +x`, `bash -n`, full `--dry-run` (must not block on `read`).
6. If the source was a Linear issue, append a `## Walkthrough script` section.
   Do not replace `## Manual steps`.
7. Report the path, the classification table, required env, and which
   steps leave the terminal.

## Phase 1 — Resolve the source

**Linear issue.** Fetch the issue. Use `linear-velatir` when the URL or
team is Velatir. Use `linear-personal` for every other workspace (for
example `linear.app/siig`). Parse `## Manual steps` first. If that
heading is missing, parse `## Steps`. Keep, in order: step number,
title, exact commands, URLs, "why a person", expected outputs, dest
paths for secrets. Also keep required env vars and host/repo hints from
`## Context`.

**Markdown file.** Read it. Parse the same headings, or a numbered list
of actions.

**User message.** Use the steps the user pasted. Do not add steps they
did not write.

If the parsed list is empty, stop and say so. Do not guess.

## Phase 2 — Classify each step

Each step is exactly one class:

| Class | When | Script behaviour |
|---|---|---|
| `command` | The step is a bash invocation the person must run (privileged CLI, personal credentials). | Run it under `--live`. No extra confirm. |
| `command+decision` | The step is still a command, but the person must pick among options (which policy, which account, create vs skip). | List options. Prompt. Then run. |
| `out-of-terminal` | The person leaves the terminal: signup, API key from a portal, admin console, phone, vendor site. | Print the action and URL. Optional `xdg-open`. Wait. Hidden paste if a secret is produced. Then any terminal-side verify. |

A procedure may mix classes. That is normal. Mixed **issues** (agent
work plus human work in one Linear issue) are not this skill's problem.
Encode the steps you were given.

Classification hints:

- A fenced shell command (`gcloud`, `wrangler`, `curl`, `chmod`, …) with
  no "pick among N" language → `command`.
- The same, plus "find the X and choose" / "inspect then update" /
  a placeholder such as `<policy-id>` → `command+decision`.
- "Open …", "Sign up …", "Create an account", "Generate a key in the
  console", a phone/app action, no runnable command (or the command is
  only verify-after) → `out-of-terminal`.
- A step that fetches a secret from a website and then runs a CLI →
  `out-of-terminal` prefix (URL, wait, hidden paste) then the `command`.
  Keep it as one script function so the person is not bounced out of
  the walkthrough.

Encode commands from the source. Do not paraphrase flags.

## Phase 3 — Resolve the output path

1. If the caller passed a path, use it.
2. Else if the current directory is a git repo, write
   `scripts/<id-or-slug>.sh`. `<id-or-slug>` is the Linear identifier
   in lowercase (`sii-74`) when the source is an issue, otherwise a
   short kebab slug from the procedure title.
3. Else ask.

Create parent directories. Do not write onto a primary checkout when
the caller passed a worktree path.

Default for `coordinate-implementation` (the caller always passes this):

```
~/Code/workspaces/<milestone-slug>/human/<ISSUE-ID>.sh
```

## Phase 4 — Write the script

One script per procedure. One function per step. Read
`references/script-shape.md` and use those templates for:

- header, flag parsing, helpers (`run`, `runsh`, `step`, `ok`, `warn`, `fail`)
- preflight
- `command` step
- `command+decision` step
- `out-of-terminal` step (including hidden paste)
- summary

Required flags:

- `--dry-run` — print what would run. Execute nothing that changes
  state. **Do not call a real `read`.** Print the prompt shape and
  return.
- `--live` — execute. This is the default when neither flag is passed.
- `--from-step=N` / `--to-step=M` — resume or subset
- `--help` / `-h`

Required behaviour:

- `set -euo pipefail`
- No secrets in the file. Secrets come from env or from a hidden paste
  at run time.
- Idempotent create-vs-update when the source already says "if it
  exists, update".
- Verify after a live command step when the source names an expected
  output.
- Color helpers only when stdout is a tty.
- Preflight: required CLIs, git/cwd if the source needs a repo, auth
  if a live command needs it. Missing optional CLIs warn and skip the
  steps that need them.
- Interactive **only** at `command+decision` and `out-of-terminal`
  pauses. Do not confirm every command.
- Do not add `--confirm-each` unless the user asked for it.

## Phase 5 — Verify

Before you report:

```
chmod +x <path>
bash -n <path>
<path> --dry-run
<path> --help
```

`--dry-run` must finish without waiting for stdin. If it blocks, the
script is wrong: a `read` ran in dry-run. Fix it.

Do not run `--live`. Do not open a pull request. Do not `git add` the
script unless the user explicitly asked to commit it.

## Phase 6 — Linear, when the source was an issue

Append this section. Do not replace `## Manual steps`. Do not paste
secrets.

```
## Walkthrough script

The steps above remain the source of truth if you run them by hand.

  <path> --dry-run
  <path> --live

Required env: <list or "none">
Out-of-terminal steps: <N, N, … or "none">
```

If that heading already exists, replace only that section.

Do not set the issue to Done. Do not comment "you still need to run
this" as a substitute for the section.

## Phase 7 — Report

```
## Walkthrough script ready

Path: <path>

  <path> --dry-run
  <path> --live

| Step | Title | Class |
|------|-------|-------|
| 1 | <title> | command \| command+decision \| out-of-terminal |
| … | | |

Required env: <name=purpose, … or none>
Out-of-terminal steps: <list or none>
Verify: bash -n OK · --dry-run OK
```

## Constraints

- Do not run `--live`.
- Do not let `--dry-run` block on `read`.
- Do not put secrets in the script, in Linear, or in the report.
- Do not echo a secret after a hidden paste.
- Do not open a pull request.
- Do not mark the Linear issue Done.
- Do not skip or delete `## Manual steps` because a script exists.
- Do not confirm every command. Prompt only for decisions and for
  out-of-terminal pauses.
- Do not paraphrase commands from the source.
- Do not write the script onto a primary checkout when the caller
  passed a worktree path.
