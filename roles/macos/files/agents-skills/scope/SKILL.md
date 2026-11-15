---
name: scope
description: "Plan implementation for explored goals. Use when the user says /scope, asks to scope implementation, convert explored goals into an implementation plan, revise implementation planning from NOTE FROM USER annotations, or plan a simple standalone task without /explore output. Validates goal confidence, checks staleness hashes, and produces an implementation/ subtree."
---

# Scope - Implementation Planning

Take `/explore` output, or a simple task description, and produce an implementation plan in an `implementation/` subtree. Validate goal confidence before planning. Use the same Obsidian annotation loop for revisions.

## Discovery

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

Find `<name>.research/` in `velatir-coordination/ai/chat-notes/`.

- If `goals/` exists: normal mode.
- If no research folder exists: standalone mode.

Location rule: same as `/explore`. If CWD contains `workspaces/`, write to `<worktree>/velatir-coordination/ai/chat-notes/`. If CWD does not contain `workspaces/`, stop and ask for a worktree. Never create research folders in primary checkouts under `/Users/kaspersiig/Code/`.

## Entry Validation

Run this on every normal-mode invocation before scoping.

1. Scan all files in `goals/` for `NOTE FROM USER:` lines.
2. Treat a note as unprocessed if no following `REVISED:` block addresses it.
3. Re-evaluate current goal confidence markers against unprocessed notes and current code/docs.
4. Report findings before planning:
   - List unprocessed annotations and likely impact.
   - Warn if any confidence marker should change, with reasoning.
   - If clear, briefly confirm and proceed.

The user may choose to go back to `/explore` or continue.

## Hash Validation

On first `/scope` invocation, compute:

```bash
find <research-folder>/goals/ -type f -name '*.md' | sort | xargs cat | md5
```

Store it at the top of `implementation/README.md`:

```markdown
<!-- goals-hash: <hash> -->
```

On later invocations:

1. Extract the stored hash.
2. Recompute the current goals hash.
3. If it differs, warn: `Goals have changed since last scope - review implementation plan for staleness.`
4. Continue anyway.
5. Update the hash after revision.

## Scaffold Mode

Create:

```text
<name>.research/
  implementation/
    README.md
```

`implementation/README.md`:

```markdown
<!-- goals-hash: <computed-hash> -->
# Implementation Plan

## Overview

<High-level summary of implementation approach>

## Deliverables

| # | Deliverable | Path | Goal |
|---|-------------|------|------|
| 1 | ... | ... | G1 |

## Implementation order

<Ordered steps with rationale>

## Key decisions

| Decision | Rationale |
|----------|-----------|
| ... | ... |
```

Create additional `implementation/<topic>.md` files only when a topic exceeds about 30 lines in README. Update the top-level research `README.md` phase to `scoping`.

After scaffolding, output an Obsidian URI for `implementation/README.md` as both a markdown link and raw URL. Do not open it automatically.

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

For existing `implementation/` plans:

- Preserve `NOTE FROM USER:` lines verbatim.
- Strikethrough outdated content with `~~...~~`.
- Add `REVISED:` blocks.
- Propagate corrections through downstream sections.
- For tables with multiple corrections, strikethrough the whole table and add a `REVISED table:`.

If a revision raises new goal questions, do not modify `goals/`; say that the question should be addressed with `/explore`.

## Standalone Mode

When invoked without `goals/`:

- Skip entry validation and hash checks.
- Treat conversation context as requirements.
- Create:

```text
<name>.research/
  README.md
  implementation/
    README.md
```

Top-level README should set `Phase: scoping` and omit the goals link.

## Underspecified Goals

Do not guess. If a goal lacks enough detail for implementation planning, write:

```text
Goal G<N> needs more /explore work: <what is missing>
```

Plan what can be planned for other goals, but skip the underspecified one.

## Phase Tracking

- Creating `implementation/` updates the top-level README to `Phase: scoping`.
- When the user accepts the implementation plan, update to `Phase: scoping (complete)`.
- The implementing agent updates to `Phase: complete` when work is done.

## Boundaries

`/scope` does not define or redefine goals, implement changes, silently override goal confidence, block on hash mismatch, or modify `goals/` files.
