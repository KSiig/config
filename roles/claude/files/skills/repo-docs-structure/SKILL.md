---
name: repo-docs-structure
description: Bootstrap or normalize a repository's documentation layout to the preferred structure with `docs/`, `docs/90-open-items/<subject>/`, `docs/91-tech-debt/<subject>/`, and topic-scoped `ai/chat-notes/`. Use when a repo has no `docs/90-open-items/` folder, no `docs/91-tech-debt/` folder, no `ai/chat-notes/`, flat or mixed open-items files, accepted shortcuts that are not recorded anywhere, catch-all chat notes mixing unrelated topics, ad-hoc documentation notes that need organizing, or when the user says things like "set up docs", "bootstrap docs layout", "fix the docs structure", "normalize this repo's docs", or "this repo's docs are a mess".
---

# Repository Docs Structure

The canonical layout, open-items folder contents, graduation criteria, drift rule, and anti-patterns are defined in `~/.claude/shared/preferred-docs-structure.md`. Read that file first — it is the source of truth, this skill is the procedure.

The user typically invokes this as `/repo-docs-structure <repo or docs area to inspect, plus any subject areas that should exist>`.

## Outcome

- inspect the repo's current documentation layout
- compare it against the canonical structure
- preserve existing useful content
- create missing folders and files
- reorganize misplaced material
- leave a clean split between stable docs, open items, and working notes
- keep READMEs thin: a pointer to `docs/`, not a home for detail

## README convention

A README is an entry point, not a manual. It states what the repo is, what it's
for, and how the pieces relate — then links into `docs/` for everything
operational. Specifically:

- **Root `README.md`**: repo purpose, high-level architecture, and a short
  "Documentation" section linking to the relevant `docs/` pages. No command
  reference, no setup walkthrough, no troubleshooting — those live in `docs/`.
- **Subdirectory READMEs** (e.g. `terraform/README.md`): same rule at smaller
  scope — what this directory is, then link to the `docs/` page(s) that cover
  its commands and setup. Prefer a single `docs/` page over a fat sub-README.
- **No parallel top-level docs** (e.g. `README-flux.md`, `SETUP.md`,
  `DEPLOY.md` at the repo root). Fold these into `docs/` and link to them from
  the README. The root should not accumulate sibling doc files.

When normalizing, treat a fat README or a root-level `README-*.md` as content to
relocate into `docs/`, leaving the README as a thin pointer.

## Procedure

1. List the repo's current docs-related folders and files.
2. Read the nearest routing or README pages before restructuring.
3. Decide: adopt the preferred structure directly, or minimally normalize an existing equivalent that's already coherent.
4. Infer relevant subject areas from the actual repo — workloads, domains, existing docs, existing open items. Do not invent subjects from a fixed list.
5. Create only the relevant `docs/90-open-items/<subject>/` folders, with the minimal starter files (`README.md`, `known-gaps.md`, `verification-backlog.md`, `decision-log.md`) when useful.
6. If `ai/chat-notes/` is missing or mixed across unrelated topics, create or split it into topic-relevant files.
7. Move flat or mixed open-items content into subject folders.
8. Keep stable facts in `docs/`; move unresolved or verification-only material into `docs/90-open-items/`.
9. Normalize READMEs per the README convention: relocate detail (setup, commands, troubleshooting) and any root-level `README-*.md` into `docs/`, leaving the root README and any subdirectory READMEs as thin pointers that link into `docs/`. Verify a README's claims against repo reality before relocating — a stale README is rewritten from current state, not moved verbatim.
10. Preserve existing content where possible — do not delete and rewrite when reorganization will do.
11. Verify the resulting layout is coherent and routing pages still make sense.

## Decision Rules

Adopt the preferred structure directly when:

- the repo is new or lightly documented
- it already resembles the preferred pattern
- the current layout mixes stable docs, unresolved items, and session notes confusingly

Prefer minimal adaptation when:

- the repo already has a clear, established docs system that works
- a different but coherent structure is already in place
- forcing the preferred layout would create churn without real improvement

## Quality Criteria

Docs are primarily an **AI retrieval resource**: optimize for landing on the
answer to a query, not for linear reading. That means small, self-contained,
descriptively-named concern-files over monolithic topic files.

Complete when:

- stable documentation lives under `docs/`, organized as `docs/<subject>/<concern>.md`
  — one concern per file, self-contained, named after the question it answers;
  a subject that spans multiple concerns is a directory of files, not one page
- each subject directory has an index (`README.md`) mapping concern → file
- unresolved items are grouped under `docs/90-open-items/` by subject
- working notes live under `ai/chat-notes/` in topic-specific files
- any new subject area has the minimal starter files needed to be usable
- the resulting structure is easy to navigate and consistent with existing repo conventions
- no durable unresolved issue is left buried only in stable docs or mixed notes

## Suggested Execution Pattern

- Use `Explore` for broad layout discovery before any writes.
- After the structure is normalized, delegate stable-doc rewrites to the `docs-writer` subagent.
- If unsure whether a finding belongs in stable docs, open items, or chat notes, do a read-only pass first.

## Example Prompts

- `/repo-docs-structure Check this repo and make its documentation layout follow my preferred structure.`
- `/repo-docs-structure Normalize this new repo so it has docs, subject-based 90-open-items, and topic-scoped chat-notes.`
- `/repo-docs-structure Inspect the docs workflow here and fix anything that does not match my preferred file structure.`
