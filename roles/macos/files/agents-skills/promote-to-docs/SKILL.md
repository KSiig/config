---
name: promote-to-docs
description: "Promote AI session content (chat-notes, decisions, approaches) from the ai/ folder to stable docs/, 90-open-items/, or 91-tech-debt/. Runs fully autonomously — no plan approval step. Always ends by invoking /triage-open-items. Triggers on: 'promote', 'promote to docs', 'graduate ai content', 'finish up this task', 'promote everything from ai'."
disable-model-invocation: true
---

# Promote AI Content to Docs

Promote durable findings from the `ai/` folder (chat-notes, task-context decisions, approaches) into their correct homes in each repo's `docs/` tree: stable numbered-topic folders, `90-open-items/`, or `91-tech-debt/`.

This skill runs **fully autonomously** — no plan approval, no pause for user review. Classify, write, and invoke triage in one pass.

## When to use

- A task is complete (all sub-issues merged, PRs closed) and the `ai/` folder has accumulated session-derived knowledge
- The user says "promote", "finish up this task", "graduate to docs", "promote everything from ai"

## Prerequisites

- You MUST be running from a task worktree (`workspaces/<task-slug>/velatir-coordination/`) with all relevant repos checked out.
- The `ai/` folder in at least one repo worktree must contain content (chat-notes, task-context, or both).
- Repos that aren't in the worktree are skipped silently.

---

## Phase 0 — Rebase onto main

Before writing any docs, rebase every repo worktree onto the latest `origin/main`. Sub-issue PRs often update the same docs (system-overview, tech-debt items, workflow docs) during implementation. Without a rebase, the promotion pass writes content that duplicates or conflicts with what's already on main.

```bash
WORKSPACE_ROOT="/Users/kaspersiig/Code/workspaces/<task-slug>"

for repo in "${WORKSPACE_ROOT}"/*/; do
  git -C "$(dirname "$repo"/../$(basename "$repo"))" fetch origin main 2>/dev/null
  git -C "$repo" stash --include-untracked 2>/dev/null
  git -C "$repo" rebase origin/main 2>&1
  git -C "$repo" stash pop 2>/dev/null || true
done
```

If a stash pop produces a conflict, resolve it before continuing — the conflict is almost always a doc that was already updated by a merged sub-issue PR. Keep the more detailed version.

---

## Phase 1 — Discovery

### 1a. Find all ai/ content in the worktree

Scan every repo in the worktree for AI content files:

```bash
# Find the task slug from the current worktree path
TASK_DIR=$(pwd | grep -o 'workspaces/[^/]*/') 
WORKSPACE_ROOT="/Users/kaspersiig/Code/${TASK_DIR}"

# Find all ai/ content
find "${WORKSPACE_ROOT}" -path '*/ai/*' -name '*.md' | sort
```

### 1b. Find all existing docs

For each repo that has ai/ content, also scan its docs/ tree to understand what stable docs already exist:

```bash
find "${WORKSPACE_ROOT}" -path '*/docs/*' -name '*.md' | sort
```

### 1c. Build the inventory

Read every ai/ file found. For each file, record:
- **Repo** (e.g. `velatir-infrastructure`)
- **Type** (`chat-note`, `task-context-index`, `decision`, `approach`)
- **Path** (full path)
- **Summary** (one sentence)
- **Key claims** (facts, decisions, open questions, gotchas)

Also read every INDEX.md in the task-context tree — these are the most important files because they summarize what was learned, decided, and what gotchas were discovered.

## Phase 2 — Classification

For each piece of content discovered, classify it into one of four categories:

| Category | Criteria | Destination |
|----------|----------|-------------|
| **Stable docs** | Verified implementation details, architectural decisions that were implemented, operational reference | `docs/<numbered-topic>/` |
| **Open item** | Unresolved questions, known gaps, things that need human decisions, pending ops work | `docs/90-open-items/<subject>/` |
| **Tech debt** | Deliberately accepted shortcuts with rationale and a re-evaluation trigger | `docs/91-tech-debt/<subject>/` |
| **Skip** | Ephemeral session details, task progress notes, things already in stable docs, things derivable from code | No action |

### Classification rules

1. **Decisions that were implemented** → stable docs. The decision's rationale becomes part of the relevant topic page.
2. **Decisions that were deferred** → open items (if they need a human decision) or tech debt (if an explicit shortcut was accepted with rationale).
3. **Approaches that were adopted** → stable docs (the "what was tried" section informs the reference doc).
4. **Approaches that were rejected** → skip (the rejection is only useful in the session context, not as a permanent doc).
5. **Chat-notes** → mine for claims. Each claim gets classified individually. The chat-note file itself is never promoted wholesale.
6. **Gotchas from INDEX.md** → stable docs (if the gotcha is a permanent operational concern) or open items (if it's an unresolved gap).
7. **Things already in stable docs** → skip. Check existing docs before writing duplicates.

### Content grouping

After classification, group the content by target:
- For **stable docs**: group by concern (what question does this answer?). Multiple ai/ files may contribute to a single stable doc page. A single ai/ file may contribute to multiple stable doc pages.
- For **open items**: one file per item, following the `<domain><letter>-<title>.md` naming convention.
- For **tech debt**: one file per shortcut, with rationale and re-evaluation trigger.

### Determine target files

For stable docs, determine which existing topic folder each piece belongs in — or whether a new topic folder is needed. Use the existing docs/ structure as the guide:
- `00-start-here/` — onboarding, entry points
- `01-reference/` — lookup tables (IDs, commands, specs)
- `10-terraform/` — Scaleway provisioning
- `15-kubernetes/` — K8s manifest concerns
- `20-flux/` — GitOps / FluxCD
- `30-multi-az/` — multi-AZ architecture
- `40-observability/` — monitoring, alerting, dashboards
- New folders: use the next available number in the sequence, maintaining gaps for insertion

For each stable doc file to be written, prepare a brief that includes:
- **Target path** (e.g. `docs/40-observability/alerting.md`)
- **What question it answers** (one sentence)
- **Source files** (which ai/ files contribute)
- **Key facts to include** (extracted from the ai/ content)
- **What to verify against code** (the agent MUST cross-check claims against the actual codebase)

## Phase 3 — Execution

Execute all writes. Do NOT pause for user approval.

### 3a. Stable docs — delegate to docs-writer agents

For each target stable doc file, spawn a `docs-writer` subagent with:
- The exact file path to write or update
- The key facts and source material
- Instructions to verify every claim against the actual codebase (grep for functions, check file paths exist, validate config values)
- The existing file content (if updating rather than creating)
- The README.md of the target folder (so the agent understands scope)

**Parallelize** by repo — agents working on different repos can run simultaneously. Within a repo, group by folder to avoid README update conflicts.

After all docs-writer agents complete, update the folder's README.md to include new pages in the navigation table.

### 3b. Open items — write directly

Write open-item files directly (no docs-writer needed — these are short, structured files).

For each open item:
1. Determine the subject folder (create if new)
2. Determine the domain number and letter (check existing items in the subject)
3. Write the file following the open-items format:
   - Status line
   - Finding section
   - How to verify section (include actual bash/CLI commands)
   - Action needed section
   - Source section (file paths and line numbers)
4. Update the subject README.md
5. Update `docs/90-open-items/README.md` if a new subject was added

### 3c. Tech debt — write directly

Write tech-debt files directly.

For each tech debt item:
1. Determine the subject folder (create if new)
2. Write the file following the tech-debt format:
   - Linear link (if tracked)
   - The shortcut section
   - Why it's accepted (rationale) section
   - Current state section
   - Cost / risk section
   - Re-evaluation trigger section (REQUIRED — no tech debt without a trigger)
3. Update the subject README.md
4. Update `docs/91-tech-debt/README.md` if a new subject was added

### 3d. Update parent README indexes

After all writes are complete, update:
- Each modified folder's README.md (add new pages to navigation tables)
- `docs/90-open-items/README.md` (add new subjects)
- `docs/91-tech-debt/README.md` (add new subjects)
- `docs/README.md` (only if new topic folders were created)

## Phase 4 — Verification

Before finishing:
1. Spot-check 2-3 stable doc files by reading them and verifying key claims against the codebase
2. Ensure all README indexes are consistent with the files that exist
3. Verify no duplicate content was created (same fact in both stable docs and open items)

## Phase 5 — Report and triage

### 5a. Report what was done

Summarize:
- How many files were promoted to stable docs (list them)
- How many open items were created (list them)
- How many tech debt items were created (list them)
- How many ai/ files were skipped and why (one-line summary)

### 5b. Invoke triage

After reporting, invoke the `/triage-open-items` skill. This ensures the newly created open items are immediately triaged alongside existing ones. The triage MUST cover ALL open items in the repo — never skip a subject because it was "just implemented." Items may have been opened early in a task and become resolvable by the end.

---

## Edge cases

- **No ai/ content found**: Report "no ai/ content found in the worktree" and skip to invoking `/triage-open-items` (there may still be existing open items to triage).
- **ai/ content already promoted**: If the content matches what's already in stable docs, skip it. Report the overlap.
- **Multiple repos with ai/ content**: Process each repo independently. Stable docs go to that repo's docs/ tree.
- **Missing docs/ structure**: If a repo has no `docs/` tree at all, invoke the `/repo-docs-structure` skill first to bootstrap it, then continue with promotion.
- **Large chat-notes**: Chat-notes over 500 lines should be processed in chunks. Extract claims methodically — don't try to hold the entire file in context at once.
- **Conflicting claims across files**: If two ai/ files make contradictory claims, verify against the codebase. The codebase is the source of truth. Document the resolved fact, not both claims.
- **Content that spans repos**: Some decisions affect multiple repos (e.g. "we chose X architecture" affects both backend and infrastructure). Write the stable doc in the most relevant repo and add a cross-reference note in the other.
