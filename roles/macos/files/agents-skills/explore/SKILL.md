---
name: explore
description: "Drive exhaustive goal exploration for a research topic. Use when the user says /explore, asks to explore goals, discover requirements, refine research goals, process Obsidian NOTE FROM USER annotations for goals, or prepare goal discovery before /scope. Produces confidence-assessed goals, priority-tagged probing questions, self-answered findings, and inline assumptions."
---

# Explore - Goal Discovery And Refinement

Scaffold a new research folder or revise an existing one from `NOTE FROM USER:` annotations. Use an iterative loop: write goals and questions, the user annotates in Obsidian, then revise and surface new questions. Repeat until the user declares done.

## Session And Folder

Derive a session name:

1. Run `tmux display-message -p '#S' 2>/dev/null`.
2. If tmux is unavailable, use the current git branch, stripping `feat/` or `chore/`.
3. If neither yields a usable name, ask the user.

Lowercase the result and derive the research folder name:

| Session pattern | Folder name |
|---|---|
| `VEL-420` | `vel-420.research/` |
| `VEL-420-557-arc` | `vel-557-arc.research/` |
| `vel-420-grafana` | `vel-420-grafana.research/` |
| `skill-explore` | `skill-explore.research/` |
| `SD-M2-VEL-870` | `vel-870.research/` |

Validate that the folder ends with `.research/`. For ticket-linked sessions, the folder must begin with `vel`.

## Location

Research folders go under `velatir-coordination/ai/chat-notes/`.

Hard rule: never create research folders in primary checkouts under `/Users/kaspersiig/Code/`. Research folders must go in a worktree.

Resolution:

- If CWD contains `workspaces/`: write to `<worktree>/velatir-coordination/ai/chat-notes/`.
- If CWD does not contain `workspaces/`: stop and tell the user: `No worktree detected. Research folders must not be created in the primary checkout. Set up a worktree first, or tell me which worktree to use.`

Create `ai/chat-notes/` in the worktree if needed.

## Mode

If `<name>.research/goals/` exists, use revision mode. Otherwise use scaffold mode.

## Pre-Generation Read

Before writing anything, read enough context to avoid shallow questions:

1. Target repo docs: root README, topic README files, relevant docs.
2. Relevant code, using `rg` based on conversation context.
3. Existing research in `ai/chat-notes/`.
4. `ai/` folders of active worktrees when relevant.
5. Current conversation context.
6. `resolved-questions.md` if resuming.

This is intentionally thorough; `/explore` is for goal quality, not speed.

## Scaffold Mode

Create:

```text
<name>.research/
  README.md
  goals/
    README.md
    resolved-questions.md
```

Top-level `README.md`:

```markdown
# <Title> - Research

**Date:** <YYYY-MM-DD>
**Session:** `<session-name>`
**Phase:** exploring

---

## Problem

<3-4 lines synthesized from conversation>

## What we're building

<Summary: what and why, not how>

## Decisions made

| Decision | Rationale |
|----------|-----------|

## Goals

See [goals/README.md](goals/README.md)
```

`goals/README.md`:

```markdown
# Goals Overview

## G<N>: <goal title>

**Confidence: <HIGH|MEDIUM|LOW>** - <rationale sentence>

<Goal description: what the user wants>

**Assumptions (G<N>):**
- <assumption relevant to this goal>

## Open Questions

### [CRITICAL]

**<Question text>**

**Found:** <evidence from code/docs, if available>

Confirm, correct, or expand?
```

`goals/resolved-questions.md`:

```markdown
# Resolved Questions

Questions answered during `/explore` rounds, with how each answer shaped the goals.
```

After scaffolding, output an Obsidian URI for `goals/README.md` as both a markdown link and raw URL. Do not open it automatically.

Build Obsidian URIs by matching the absolute path to the longest vault root:

| Vault root | Vault name |
|---|---|
| `/Users/kaspersiig/Code/` | `Code` |
| `/Users/kaspersiig/siig/Siig/` | `Siig` |
| `/Users/kaspersiig/siig/` | `siig` |

Strip the vault root, strip `.md`, URL-encode the vault name and file path, and use:

```text
obsidian://open?vault=<vault>&file=<relative-path>&paneType=tab
```

## Revision Mode

Read all files in `goals/`, including `resolved-questions.md`.

For each `NOTE FROM USER:` line, and for raw user text that clearly looks like an annotation:

- Preserve the user note verbatim.
- Strikethrough corrected content with `~~...~~`.
- Add a `REVISED:` block with the new understanding.
- Propagate corrections through downstream goals, assumptions, and questions.
- For tables with multiple corrections, strikethrough the whole table and add a `REVISED table:`.

Goal-specific behavior:

- Revise annotated goal descriptions and generate new questions revealed by the change.
- Move answered questions to `resolved-questions.md` with a 1-2 sentence impact summary.
- Track unanswered questions across rounds: no marker -> add `PENDING:` marker -> if still pending, move to `## Parked`.
- Update confidence assessments.
- If a goal exceeds about 30 lines in README, split it into `goals/<goal-slug>.md`.

## Probing Bar

Actively challenge the idea. Mix domain expert, devil's advocate, and neutral interviewer postures naturally, without labeling them.

Questions must be:

- Exhaustive but sharp: prefer a few blind-spot questions over obvious lists.
- Priority-tagged only by `[CRITICAL]`, `[IMPORTANT]`, `[NICE-TO-KNOW]`.
- Self-answering when code evidence exists:

```markdown
**Question text**

**Found:** evidence from code/docs

Confirm, correct, or expand?
```

Implementation references are allowed as goal evaluation context. Do not prescribe implementation; that belongs in `/scope`.

Probe implementation constraints when they affect goals: compatibility, migration windows, performance budgets, deployment ordering, API contracts, shared state, and multi-repo effects. Flag blind spots explicitly when evidence cannot be verified.

## Final Review

When the user says "final round" or otherwise signals completion:

- Append `## Final Review` to `goals/README.md`.
- Include parked questions, all assumptions by goal, and any LOW-confidence goals.
- Ask: `Confirm you're OK proceeding to /scope with these unresolved.`

## Boundaries

`/explore` does not write implementation plans, decide that goals are complete enough, or prescribe how to build something. Only the user decides when exploration is complete.
