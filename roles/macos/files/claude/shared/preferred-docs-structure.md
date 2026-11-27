# Preferred Documentation Structure

The canonical reference for how repositories should organize documentation.
The `repo-docs-structure` skill is the *procedure* for applying this; this file
is the *source of truth* for the structure itself. The docs-aware output style
also defers here.

## Primary audience: AI retrieval

These docs exist first and foremost as a **knowledge resource for AI agents**.
Optimize for *query-based lookup*, not start-to-finish reading. Nobody — human
or agent — is expected to read the tree linearly to understand the product;
they arrive with a question and need to land on the answer fast. Humans should
still be able to read it, but retrievability wins when the two trade off.

This drives every rule below:

- **One concern per file.** A file answers a single question
  ("how is terraform state stored", "why did the ESO Kustomization deadlock").
  Split a file as soon as it starts covering multiple concerns — never let a
  subject collapse into one giant `terraform.md`.
- **Self-contained files.** A file is retrieved and read in isolation, without
  its siblings. Give it enough context to stand alone; don't rely on the reader
  having seen the rest of the subject.
- **Filenames and headings are the retrieval signal.** Name files after the
  question they answer (`remote-state.md`, `crd-ordering.md`,
  `api-key-project-scoping.md`), not vaguely (`misc.md`, `notes.md`). Use
  keyword-rich headings for the same reason.
- **Index files for navigation.** Each directory has a `README.md` that
  maps concern → file and states the folder's scope, so an agent scanning the
  tree can route quickly.
- **Cross-link related files** so a reader who lands on one can follow to
  adjacent concerns.

## Layout

```
<repo>/
  README.md                         # thin entry point — purpose + links into docs/
  docs/
    README.md                       # top-level map: numbered folders → what they cover
    00-start-here/                  # onboarding: routing guide + repo map
      README.md                     # "where to look next" table, "For AI Assistants" section
      repo-map.md                   # what the repo manages, directory layout
    01-reference/                   # exact literals: IDs, IPs, commands — fast lookup only
      README.md                     # fast lookup keys table + scope rule
      resource-ids.md               # live resource IDs, IPs, project UUIDs
      commands-reference.md         # common CLI commands with links to full docs
    10-<subject>/                   # e.g. 10-terraform/, 20-flux/, 30-multi-az/
      README.md                     # concern → file table + scope rule
      <concern>.md                  # one focused, self-contained concern
    90-open-items/
      README.md                     # status summary of all subjects
      <subject>/
        README.md                   # domain-indexed reference table
        decision-log.md             # decisions taken and their rationale
        <ref>-<name>.md             # individual item, e.g. 1a-nginx-pod-placement.md
    91-tech-debt/
      README.md                     # summary of all subjects
      <subject>/
        README.md                   # file table with re-evaluation triggers
        <name>.md                   # accepted shortcuts, with rationale
  ai/
    chat-notes/
      <topic>.md                    # session-derived working notes, per topic
```

### Numbering convention

Topic folders use numbered prefixes with intentional gaps for lexicographic
ordering: `00-`, `01-`, `10-`, `15-`, `20-`, `30-`, etc. Gaps allow inserting
new subjects without renumbering existing folders. `90-open-items` and
`91-tech-debt` sort last by convention.

The `00-start-here/` and `01-reference/` layers are special: onboarding and
fast-lookup respectively. Stable topic documentation starts at `10-`.

### Folder README convention

Every folder has a `README.md` with:

1. A **navigation table** (`| Page | Use it for |` or `| File | Answers |`)
   mapping files to their purpose.
2. A **scope rule** (`## Scope — do not add X here`) stating what belongs in
   this folder and what doesn't. This prevents folders from becoming catch-alls.
3. A **related** section linking to adjacent folders.

### Open-item file convention

Each open item is an **individual file** with a domain-based reference number.
Domains group related items within a subject:

```
90-open-items/<subject>/
  README.md                 # domain-indexed table with status column
  decision-log.md           # cross-cutting decisions (unnumbered)
  1a-<name>.md              # Domain 1, item a
  1b-<name>.md              # Domain 1, item b
  2a-<name>.md              # Domain 2, item a
```

Each item file includes **inline verification commands** — the exact commands
to run to check whether the item is still relevant or resolved. No separate
`known-gaps.md` or `verification-backlog.md` files; each item is
self-contained.

Create only the folders and files that are actually useful. A subject with one
concern can be a single file (`docs/<subject>.md`) until it grows — but the
moment it spans multiple concerns, promote it to a `docs/<nn>-<subject>/`
directory of concern-files. Err toward splitting early; many small named files
beat one long file an agent has to scan top to bottom.

## What goes where (routing)

- **Onboarding, orientation** → `docs/00-start-here/`.
- **Exact literals for fast lookup** (IDs, IPs, commands) →
  `docs/01-reference/`.
- **Stable, verified facts** (how the system works, how to operate/debug/extend
  it) → `docs/<nn>-<subject>/<concern>.md`.
- **Unresolved facts, verification gaps, open decisions/questions** →
  `docs/90-open-items/<subject>/`. Each item is its own file with inline
  verification commands.
- **Deliberately accepted shortcuts / tech debt** — *with* a recorded rationale
  and a re-evaluation trigger → `docs/91-tech-debt/<subject>/`. A shortcut with
  no recorded rationale is an *open item*, not tech debt.
- **Session-derived working notes, supporting findings** →
  `ai/chat-notes/<topic>.md` (topic-scoped, never one catch-all file).

Infer subjects from the actual repo (workloads, domains, existing docs/items).
Do not invent subjects from a fixed list.

## README convention

A README is an entry point, not a manual. It states what the repo/directory is
and how the pieces relate, then links into `docs/` for everything operational.

- **Root `README.md`**: repo purpose, high-level architecture, and a short
  "Documentation" section linking into `docs/`. No command reference, setup
  walkthrough, or troubleshooting — those live in `docs/`.
- **Subdirectory READMEs** (e.g. `terraform/README.md`): same rule at smaller
  scope — what this directory is, then link to the relevant `docs/` page(s).
  Prefer `docs/` over a fat sub-README.
- **No parallel top-level docs** (`README-flux.md`, `SETUP.md`, …) at the repo
  root. Fold them into `docs/` and link from the README.
- A **stale README is rewritten from current repo state**, not relocated
  verbatim. Verify claims against reality before moving them.

## Graduation

Content moves between layers **explicitly, never by silent edit**:

`ai/chat-notes/` → `docs/90-open-items/` → `docs/` (stable).

- Promote chat-notes to an open item once a finding is worth tracking across
  sessions but isn't yet resolved/verified.
- Promote an open item to stable `docs/` once it's verified and resolved —
  this requires explicit human confirmation; writing the stable version is the
  `docs-writer` agent's job. When promoting, split into concern-files rather
  than dumping the whole investigation into one page.
- Demotions are legal: if a "stable" doc turns out unverified or wrong, move it
  back to an open item.

## Drift rule

When a doc claims X and current repo state shows Y, **do not silently rewrite
the stable doc**. Log a new open-item file under the relevant
`docs/90-open-items/<subject>/` with inline verification commands, and surface
it; the human resolves. Once the correct value is verified, correct the doc and
close the item.

## Anti-patterns

- **Monolithic topic files** — one `docs/terraform.md` accreting every
  terraform concern. Split into `docs/10-terraform/<concern>.md`.
- **Unnumbered topic folders** that give no sort/navigation hint. Use numbered
  prefixes with gaps.
- **Folders without a README** — every folder needs a navigation table and
  scope rule.
- **Separate `known-gaps.md` / `verification-backlog.md`** files that fragment
  context from the item they describe. Each open item is self-contained with
  inline verification.
- Vague filenames (`misc.md`, `notes.md`, `other.md`) that carry no retrieval
  signal.
- Files that only make sense after reading their siblings (not self-contained).
- Fat READMEs that duplicate `docs/` content; root-level `README-*.md` siblings.
- Burying an unresolved issue or known gap inside a stable doc.
- A single catch-all chat-notes file mixing unrelated topics.
- Inventing facts to fill a note or doc.
- Promoting unverified content into stable `docs/` without confirmation.
- Recording a shortcut as "tech debt" without rationale + re-evaluation trigger
  (it's an open item until the rationale exists).
- Silently rewriting a stable doc to match drifted reality (use the drift rule).
