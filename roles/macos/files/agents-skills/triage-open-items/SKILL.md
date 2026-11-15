---
name: triage-open-items
description: "Triage and graduate open-items across all repos. Scans docs/90-open-items/, analyzes which items can be resolved from the codebase, generates a triage file for user review, then promotes checked items to stable docs and cleans up closed items."
disable-model-invocation: false
---

# Open Items Triage

Automate the cycle of resolving `docs/90-open-items/` entries across all Velatir repos: gather, analyze, propose, review, execute.

## When to use

- The user asks to "triage open items", "graduate docs", "clean up open items", "check what open items we can close"
- Periodically after a round of code changes that may have resolved drift items or open questions

## Prerequisites

- You MUST be running from a task worktree (`workspaces/<task-slug>/velatir-coordination/`) with all relevant repos checked out, per the coordination repo's AGENTS.md rules.
- Repos that aren't in the worktree are skipped silently.

---

## Phase 1 — Gather

Scan every repo in the worktree for open-items files.

```bash
find /Users/kaspersiig/Code/workspaces/<task-slug>/ -path '*/docs/90-open-items/*' -name '*.md' | sort
```

Read every file found. Build a flat list of all individual open items across all repos. Each item has:
- **Repo** (e.g. `velatir-backend`)
- **Subject** (e.g. `architecture`, `kubernetes`, `mcp`)
- **File** (e.g. `verification-backlog.md`, `known-gaps.md`)
- **Item ID or heading** (e.g. `Q-7`, `4b-4`, `Escalation State Enum`)
- **Summary** (one sentence from the item's description)

## Phase 2 — Analyze

For each open item, determine whether the agent can resolve it from the current codebase and docs.

**Resolution categories:**

| Category | Meaning | Triage action |
|----------|---------|---------------|
| **Agent-resolvable** | The answer is verifiable from code, config, or existing stable docs. The agent can write the promotion. | Propose a resolution line with `[x]` |
| **Needs human decision** | The item asks "should we X?" or "is this intended?" — no amount of code reading answers it. | List under "Needs Your Decision" with `[ ]` |
| **Already resolved in code** | The drift or gap described in the item no longer exists (code was fixed, file was deleted, etc.) | Propose closing with `[x]` and note what changed |
| **Stale / superseded** | The item references code, files, or architecture that no longer exists. | Propose closing with `[x]` and note why |

**How to analyze each item:**

1. Read the item's description carefully — what claim does it make? What question does it ask?
2. Search the codebase for the relevant code, config, or file. Use `grep`, `find`, or read specific files.
3. Check if the stable docs already contain the answer (items sometimes get fixed but the open-item isn't closed).
4. If the item is a drift finding ("docs say X, code says Y"), verify whether the drift still exists.
5. If the item is a question ("what does X do?"), determine whether you can answer it from the code.

Use Explore subagents liberally — one per repo or per subject — to parallelize the analysis. This phase is read-only; don't modify anything.

## Phase 3 — Generate triage file

Write `open-items-triage.md` in the coordination worktree root. Format:

```markdown
# Open Items Triage

Check the box for items I should resolve. Unchecked items stay as open-items.

## <repo> — <subject>

- [x] **<item-id>**: <one-line summary> → <proposed resolution>
- [x] **<item-id>**: <one-line summary> → <proposed resolution>
  - <extra context line, only when the one-liner isn't enough>
- [ ] **<item-id>**: <one-line summary> → stays open (reason)

## <repo> — <subject>

...

---

## Needs Your Decision (not code-resolvable)

### <repo> — `<path-to-open-items-file>`

- [ ] **<item-id>**: <summary> — <what needs deciding>
```

### Format rules

- **Default: one line per item.** The proposed resolution goes after `→` on the same line as the checkbox. Examples:
  - `→ fix README to say .NET 10`
  - `→ promote to service-registration.md (OTLP exporter, Npgsql sources)`
  - `→ close (file already deleted during multi-AZ migration)`
  - `→ document in hangfire.md (IP is ProtonVPN public IP)`

- **Extra context when needed.** If the one-liner doesn't give the user enough to decide, add indented lines below. Use this sparingly — only when the item involves a non-obvious judgment call or the user would need to look something up without it. Example:
  ```
  - [x] **4b-7**: Icon storage prod-only → document as intentional in secrets-and-eso.md
    - Backoffice `IconStorage__*` env vars + ExternalSecret exist only in prod. Dev has no icon storage wiring.
    - Anyone working on icon features in dev needs to add: bucket, IAM key, ExternalSecret, env vars.
  ```

- **Pre-check agent-resolvable items** (`[x]`). The user unchecks any they disagree with.
- **Leave human-decision items unchecked** (`[ ]`). Group them under "Needs Your Decision" at the bottom.
- **Group by repo, then by subject** (architecture, kubernetes, features, etc.).

### Anti-patterns in the triage file

- Don't dump the full open-item text — the triage file is a summary, not a copy.
- Don't propose "ask a manager" as a resolution — that's a "Needs Your Decision" item.
- Don't mix resolvable and unresolvable items in the same section — keep them separate.

## Phase 4 — Guide the user

After generating the triage file, tell the user:

> I've generated `open-items-triage.md` with proposed resolutions for N items across M repos.
>
> **How to use it:**
> 1. Open the file and review each item
> 2. Items marked `[x]` are ones I can resolve — uncheck any you disagree with
> 3. Items marked `[ ]` under "Needs Your Decision" need human input — you can:
>    - Leave them unchecked (they stay as open items)
>    - Add a `NOTE FROM USER:` line with your decision, and I'll incorporate it
> 4. When you're done, ask me to execute the triage
>
> X items are agent-resolvable, Y need your decision.

Then **stop and wait**. Do not proceed to Phase 5 until the user asks.

## Phase 5 — Execute

When the user says to execute (e.g. "go ahead", "execute the triage", "promote based on the triage"):

1. **Read `open-items-triage.md`** and parse which items are checked vs unchecked, including any `NOTE FROM USER:` annotations.

2. **For checked items**, determine the action:
   - **Promote to stable docs**: delegate to `docs-writer` subagents, grouped by repo. Each agent gets the exact file paths, what to change, and the verified facts. Run agents for independent repos in parallel.
   - **Close (already resolved / stale)**: no doc write needed — just remove from the verification-backlog.
   - **Delete files**: for orphaned files the user approved for deletion.
   - **Create Linear issues**: for items where the user's note requests it. Use the `/linear` skill.

3. **Rewrite verification-backlog files** to contain only the remaining unchecked items. Follow these rules:
   - Remove all resolved items completely — no "Resolved" section, no trace of former items.
   - Keep the file's header and format consistent.
   - If ALL items in a file are resolved, delete the file. If the directory is then empty, delete the directory.
   - Incorporate `NOTE FROM USER:` annotations into the remaining items where applicable.

4. **Update cross-references** in stable docs that point to now-resolved verification-backlog items.

5. **Delete `open-items-triage.md`** after execution is complete — it's a transient artifact.

6. **Report** what was done: files changed, items promoted, items remaining, any issues encountered.

### Execution constraints

- Use `docs-writer` subagents for stable doc writes — don't write stable docs directly.
- Group subagent work by repo to avoid file conflicts.
- Verify agent output by spot-checking key changes after they complete.
- Never silently rewrite a stable doc that the agent hasn't verified — the drift rule still applies.
- The "Resolved" anti-pattern must never appear in open-items files. When items are resolved, they are removed entirely.

---

## Edge cases

- **New open items discovered during analysis**: if you find something that should be tracked but isn't in any open-items file, mention it in the triage file under a "Newly Discovered" section. Don't create the open-item file yet — let the user confirm.
- **Items that partially resolve**: if an item has multiple sub-points and only some are resolvable, split it in the triage file. Check the resolvable parts, leave the rest unchecked.
- **Empty open-items directories after cleanup**: delete them. The goal is for `docs/90-open-items/` to shrink toward empty over time.
- **Recently completed work**: always triage all open items, including subjects that were just implemented. Items may have been opened early in a task and become resolvable by the end — skipping them creates stale open items.
