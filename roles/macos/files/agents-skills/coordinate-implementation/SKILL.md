---
name: coordinate-implementation
description: "Coordinate the autonomous implementation of a Linear milestone from the pi coding harness by spawning one pi sub-agent per agentic issue (in waves), assembling the PRs into a mergeable git stack, reviewing the cumulative diff, then writing human-issue walkthroughs. Use when the user asks to coordinate, orchestrate, or fan out a milestone or a set of related Linear issues for parallel execution. Expects a Linear milestone URL (or project URL plus milestone identifier) as an argument. Pi-specific: relies on pi's subagent tool, subagent_wait, and the gh-stack CLI extension."
metadata:
  author: Kasper Siig
  harness: pi
  triggers:
    - coordinate implementation
    - coordinate milestone
    - fan out milestone
    - run milestone
    - implement milestone
    - orchestrate issues
    - parallel issues
    - milestone execution
disable-model-invocation: true
---

# Coordinate Implementation — milestone fan-out

End-to-end orchestration: take a Linear milestone, fan out one sub-agent per `agentic` issue, wait for all of them, and collect the resulting pull requests into one **git** stack that is mergeable, not merely linked on GitHub. Human work lives in its own `human`-labelled issues — never as a phase inside an agentic issue — and is recorded back into those Linear issues themselves, never as cross-pointers. A person reading only that issue must be able to act. After that Linear writeup, spawn one sub-agent per human issue to follow `/skill:walkthrough-script` and write a runnable walkthrough. The parent does not write that script. The walkthrough-script skill owns the bash contract; do not copy it here.

This is an **orchestration skill**, not an implementation skill. The parent does not implement issues, author feature commits, or write walkthrough scripts. Stack assembly (cascade rebase, scaffold policy, composing sibling imports) is delegated to a Phase 6 child. The parent may run `gh stack` plumbing (`link`, `view`, `checkout`, `push` after the assembly child returns) and the CodeRabbit CLI review. Everything else is delegated.

## Invocation

```
/skill:coordinate-implementation <linear-milestone URL>
```

The single argument is the URL of the Linear milestone to run. Both forms are accepted:

- `https://linear.app/<workspace>/project/<project-slug>-<project-id>/overview#milestone-<milestone-id>` — full milestone anchor
- `https://linear.app/<workspace>/milestone/<milestone-id>` — short milestone URL

If no argument is given, ask the user for the milestone URL before doing anything else. Do not guess, do not search Linear for "the current milestone", do not pick a recent one from history.

The MCP server to use depends on the workspace in the URL:

- `linear.app/velatir` → `linear-velatir` MCP server
- any other workspace (e.g. `linear.app/siig`) → `linear-personal` MCP server

Resolve this once at the start of the run and stick with it.

## Your task

1. Resolve the milestone: fetch it from Linear, list every issue in scope, classify each issue as agentic or human (see §Classification), and record file ownership per repo (see Phase 1).
2. For agentic issues: spawn in **waves** (Phase 3). Independent issues in the same wave run in one parallel `subagent({ tasks: [...] })` call. Set `thinking: "off"` on every spawn. Start immediately — the milestone is already refined, do not pause for confirmation.
3. Each wave drains in the foreground. After it returns, every run in that wave is terminal. Collect the run map and resolve per-issue outcomes.
4. Collect all pull requests into one stack using `/skill:gh-stack`. Linking is not done: cascade-rebase until each parent is a git ancestor of its child, compose sibling imports via the assembly child, then review. Always one stack per milestone — never separate stacks. Do not start Phase 7 while any stacked PR is `CONFLICTING`.
5. For each issue classified human: after the stack is mergeable, write the human steps into the Linear issue body with full context. Then spawn one sub-agent per human issue that loads `/skill:walkthrough-script` and writes the walkthrough script (Phase 7b). Do not skip the Linear body because a script will exist.
6. Report to the user only after no agentic work remains, every stacked PR is `MERGEABLE`, and every human issue has both a Linear writeup and a walkthrough script. The report includes the script path, the run commands, and the actual human steps inline, not just Linear links.

## Sub-agent rules

Every **agentic** per-issue sub-agent gets these rules, passed verbatim in its task prompt. Walkthrough-script children in Phase 7b do not get these rules — they follow `/skill:walkthrough-script` instead, and they do not open a pull request. The Phase 6 stack-assembly child gets its own prompt, not these rules.

1. **Build the exact specification in the issue.** Change the specification only when a test shows that the specification is wrong.
2. **Act only on facts from a codebase search or a web search.** Do not assume. Do not use training data as a source.
3. **Do all work that does not depend on a later layer.**
4. **Open one pull request for the issue.**
5. **Import files owned by other issues in this milestone.** Do not recreate them. Do not inline their types. Isolation is git history (branch off `main`), not the type system. A branch that does not typecheck until stacked is expected.
6. **Write the real imports** for sibling modules this issue must call. Empty registries, `@ts-ignore` dynamic imports, and "compile in isolation" stubs are unfinished work. Spec text that says "inline so this module stands alone" is overridden by rule 5.

In addition, the **parent** sets `thinking: "off"` on every per-issue spawn. There are two equivalent ways to do this in the `subagent` tool:

- `thinking: "off"` — a top-level launch parameter. Applies to single, parallel, and chain launches.
- A model suffix `model: "provider/model:off"` — e.g. `model: "anthropic/claude-sonnet-4:off"`. Same effect, expressed via the model id.

Either is correct. The top-level `thinking` field is preferred because it does not depend on the child agent's `model` field.

Each **agentic** sub-agent owns:

- One issue.
- One worktree.
- One pull request.

Each **walkthrough-script** child owns:

- One human issue.
- One script path.

The **stack-assembly** child owns:

- One stack (all PRs from this milestone in one repo, or one child per repo if the milestone spans repos).
- Cascade rebase, scaffold resolution, composing sibling imports, and `gh stack push`.

Sub-agents do not coordinate with each other. They only report back to the parent. Cross-issue dependencies are the parent's problem.

## Phase 1 — Resolve the milestone

Fetch the milestone and its issues from Linear. Use the MCP server resolved from the URL workspace.

Record:

- **Milestone title and URL** — to put in the final report.
- **Issue list** — every issue in the milestone, with identifier, title, status, priority, labels, and current assignee. Expect exactly one of `agentic` or `human` on each issue.
- **Issue dependencies** — `blockedBy` / `blocks` relations, cross-references in bodies, any parent/child structure.
- **Existing comments on each issue** — comments are part of the spec; "we already decided X" often lives there. Always fetch.
- **File ownership** — from issue bodies and `blocks` relations, which issue owns each shared path (`src/types.ts`, `package.json`, `tsconfig.json`, the writer, the test runner). If `main` has no toolchain and more than one issue in that repo needs tests, the bottom agentic issue in that repo owns `package.json` / lockfile / `tsconfig.json` / the test runner. Put that issue in wave 1. Other issues in that repo do not add those files.
- **Worktrees in use** — `~/Code/workspaces/<slug>/*` for any worktree already claimed by a running task. A new milestone gets a fresh top-level slug derived from the milestone name (kebab-case, ≤ 40 chars). Parallel issues in the same repo each get `~/Code/workspaces/<slug>/<repo>-<issue-id>` — never a shared `<slug>/<repo>`.

Print the summary for your own bookkeeping (and so the final report can include it), but do **not** pause for user confirmation. The milestone has already been refined before the skill was invoked. Proceed straight to Phase 2.

```
# Milestone — <title>
  <n> total · <a> agentic · <h> human · <x> mixed (spec defect) · <d> blocked-by-other-milestones

## Issues

### <ISSUE-ID> — <title>  [agentic | human]
  Status: <status> · Priority: <priority> · Label: <agentic | human | missing> · Assignee: <name | unassigned>
  <one-line spec summary>

### <ISSUE-ID> — <title>  [human]
  ...

### <ISSUE-ID> — <title>  [mixed — spec defect]
  ...

## Dependencies

- <ISSUE-A> → <ISSUE-B>  (blocks / blocked-by)
- ...

## File ownership

- <path>  — <ISSUE-ID>  (wave 1 | wave 2)

## Worktrees

- workspaces/<slug>/<repo>-<issue-id>  → <branch>  (existing | new)
```

## Phase 2 — Classify each issue

Classification is at the **issue** level, not at the step or phase level. An issue is agent work or human work. Not both.

Read the Linear label first (`agentic` or `human`), then confirm it against the body. The label is the marker of who owns the issue. The body must match the label.

- **Agentic** — every step in the body is work an agent can do. The body is a complete spec. Acceptance criteria are checkable. No privileged decisions. No human-only actions. One issue produces one pull request. Linear label: `agentic`.
- **Human** — every step in the body is work only a person can do. Examples: paying for a SaaS account, running a CLI that requires a personal token, signing a contract, sending a verification SMS, accessing a vendor portal, obtaining a license key from a vendor. If an agent can perform a step, that step does not belong in this issue. Linear label: `human`.
- **Mixed (spec defect)** — the body contains both agent-capable steps and human-only steps. Do **not** relabel the whole issue `human`. Do **not** spawn a sub-agent for it. Record it in the summary and in the final report. The correct fix (done before this skill runs) is to split: agent-capable steps in an `agentic` issue, human-only steps in a `human` issue, with a blocker relation between them.
- **Blocked (out of scope)** — the issue depends on something outside this milestone. Surface it but do not plan around it; the user decides.

Mark the classification in the summary table. Human, mixed, and blocked issues do not get an agentic implementation sub-agent in Phase 3. Human issues get a walkthrough-script child in Phase 7b. Mixed and blocked issues get neither.

For human issues, do not write the human steps yet — that happens in Phase 7, after agentic work has settled. This ordering matters: the agentic work often changes the context (which step is now #1, which step is now redundant, what was assumed and is no longer assumed). Writing human steps too early locks in stale assumptions.

## Phase 3 — Spawn agentic sub-agents in waves

Split agentic issues into at most two waves. Independent issues **inside** a wave still start in one parallel `tasks` block. Do not serialize independent issues.

- **Wave 1** — issues whose files other issues in this milestone must import: toolchain (`package.json`, lockfile, `tsconfig.json`, the test runner), shared types, the writer, a shared test harness. Drain this wave before starting wave 2.
- **Wave 2** — every remaining agentic issue. Branch off `main`, open a PR against `main`. Import wave-1 paths; do not recreate them.

Skip wave 1 when `main` already has the toolchain and no issue in this milestone owns a new shared module.

Each parallel task gets `thinking: "off"` (or equivalently the model suffix `:off`). The child prompt does not need to be told about thinking — the parent owns that setting.

The parent passes the following task prompt to each sub-agent:

```
You are implementing <ISSUE-ID> from milestone <milestone-title> (<milestone-url>).

## Issue spec

<full issue body, including acceptance criteria and any inline decisions>

## Comments already on the issue

<relevant comments — only those that pin down the spec>

## Files you do not own

<path> — owned by <ISSUE-ID>. Import it. Do not recreate it. Do not
inline its types or its public surface.
(If this issue is the owner, omit that row.)

Use the test runner and package manager already on main, or the one
wave 1 just added. Do not introduce a second test runner.

## Rules

1. Build the exact specification in the issue. Change the specification only
   when a test shows that the specification is wrong.
2. Act only on facts from a codebase search or a web search. Do not assume.
   Do not use training data as a source.
3. Do all work that does not depend on a later layer.
4. Open one pull request for the issue.
5. Import files owned by other issues in this milestone. Isolation is
   git history, not the type system. tsc may fail on this branch until
   the stack is rebased; still write the real imports.
6. Write the real imports for sibling modules this issue must call.
   Empty registries and @ts-ignore dynamic imports are unfinished.
   Spec text that says "inline so this module stands alone" is
   overridden by rule 5.
7. If this issue has no internal descendants in the milestone (no
   other agentic issue's `blocks` graph points at it, or it sits at
   the bottom of every stack order), this is a foundation. The
   fetch handler (or analogous entry point) MUST contain only its
   own routes and the 404 default. Sibling dispatch branches and
   their corresponding imports belong to each sibling's PR and
   land as follow-up commits in cascade rebase. Imports of
   `./products.ts`, `./approval.ts`, or any sibling-owned module
   MUST NOT appear in this commit.

## Foundation issues

If this issue is a foundation (no `blocks` graph in this milestone
points to it), the fetch handler (or analogous entry point) MUST
contain only its own routes and the 404 default. Do not import or
dispatch sibling-owned routes in this commit — those land as
follow-up commits in each sibling's own PR.

## Deliverable

- One branch off latest main in a fresh worktree at
  ~/Code/workspaces/<milestone-slug>/<repo>-<issue-id> on a branch named
  feat/<issue-id>-<short-slug>. Do not reuse another issue's worktree.
- One pull request against main. The PR body must contain a
  `Linear: <ISSUE-ID>` line so the Linear-link check passes.
- Report back: branch name, PR URL, commit list, anything that needs
  the parent's attention (assumptions you had to make, gaps in the spec,
  conflicts with the milestone context).

Do not coordinate with sibling sub-agents. Do not modify other issues'
worktrees. If you discover cross-issue work that has to happen, report
it and stop — the parent will handle it in Phase 6.
```

Spawn each wave in a `subagent` call with a `tasks` array (one entry per issue in that wave). Set the following on every task:

- `agent` — the worker agent to use. If unsure, `worker` is the standard; the parent's defaults override anything specific.
- `thinking: "off"` — required on every spawn. Disables the child's thinking block.
- `cwd` — leave unset so the child picks its own worktree per its own conventions.
- `context: "fresh"` — required. Per-issue sub-agents start from a clean context; they do not inherit the parent's transcript or each other's state.

Do **not** add `async: true`. Per the runtime's default, parallel `tasks` already run concurrently and the call returns when the fleet drains. Setting `async: true` here would orphan the runs and force you back into polling.

Record each returned run id in a `{ issue_id, id, branch, pr_url, status }` map. After wave 1 drains, start wave 2. After wave 2 drains, proceed to Phase 4.

## Phase 4 — Coordinate while sub-agents run

Each wave's `tasks` call returns once that wave has drained (because parallel mode is foreground by default — there is no `async: true` here). Phase 4 is therefore mostly bookkeeping: while a wave is in flight, the parent cannot do other work in the same turn. After the last wave returns, every run is already in a terminal state, so there is nothing to monitor in real time.

The parent's job during Phase 4 reduces to four things, each handled **after** the parallel call returns:

- **Collect the run map.** Each task result includes the run id, status, branch, and PR URL. Build the `{ issue_id, id, status, branch, pr_url, notes }` map.
- **Reconcile per-issue outcomes.** For each task: did it open a PR? Did it stop? Did it error? Pull the relevant facts from each child result.
- **Surface blockers silently.** A child that reports "I can't do this because of <X>" does not pause the run. The run still completes (or fails) on its own. The parent records the blocker in the issue's `notes` slot for the final report. Do **not** interrupt the user mid-run — the user gets a single end-of-milestone overview, not a stream of partial updates.
- **Cross-issue collisions.** If two issues touched the same file or the same symbol, the parent decides the stack ordering in Phase 6, not now. Mid-flight re-spawning is wrong: the original runs own their worktrees and branches, and re-ordering is what the stack is for.
- **Track CLI-review budget.** For Tier-2 milestones (where sub-agents run `coderabbit review --agent` locally before opening the PR), each sub-agent may burn 1-3 CLI review invocations. Record `cli_reviews_used_per_issue` in the run map and sum across the milestone. If the sum exceeds the plan's rolling-hourly CLI allowance (Free: 3/hr, Essentials: 5/hr, Team: 8/hr, Advanced: 10/hr, Enterprise: 12/hr), the orchestrator's Phase 6 stack review may have to wait until the window resets. For Tier 1 (Free, no per-issue review) every issue records zero — the bookkeeping is for future Tier rollouts, not for the current run.

If the user asks "what's happening" during the run, the parent reports the run map it has so far. The parent does not narrate every tool call, and it does not poll — once the `tasks` call is in flight, the only useful thing to do is wait for it to return.

## Phase 5 — Collect results

Because Phase 3 used parallel `tasks` mode without `async: true`, each wave has already returned by the time Phase 5 begins. There is no separate `subagent_wait` step — the wave calls themselves drained the runs.

If you ever spawn a sub-agent with `async: true` (for example to launch a late-arriving agentic issue), use `subagent_wait({ all: true })` to drain the exact current-session async fleet before proceeding to Phase 6. `subagent_wait` is a real tool with three forms:

- `subagent_wait()` — return when the next active run finishes or needs attention.
- `subagent_wait({ all: true })` — drain every active async run to completion.
- `subagent_wait({ id: "..." })` — block on a specific run by id or prefix.

In every case, pass a long `timeoutMs` (e.g. 30 minutes) so the wait does not bail early on long-running children. Do not sleep or busy-poll instead.

For each finished run, record:

- **Branch name** — for the stack in Phase 6.
- **PR URL** — for the stack in Phase 6 and the final report.
- **Result note** — any assumption the sub-agent made, any spec gap, anything that affects Phase 6 or the human-issue writeups.

For each failed or stopped run, record the failure in the run map. The user sees failures in the final report, not mid-flight. Do not silently retry — the user decides whether to re-spawn, reclassify, or skip.

## Phase 6 — Stack the pull requests

Load `/skill:gh-stack` and follow it. **Always one stack per milestone, never separate stacks.** Every PR from this milestone goes into the same stack, in dependency order from Phase 1.

- The bottom of the stack is the issue with no dependencies inside this milestone (or the dependency-graph root if the milestone has a single foundation).
- Each subsequent layer stacks above the issue(s) it depends on.
- Truly independent issues that have no relationship to each other are placed at the same logical layer in the same stack, in any order; they just live adjacent in the chain.

The `gh-stack` CLI requires a linear chain. To keep the chain linear even when two issues are independent, pick one as the layer's "lower" branch and the other as its "upper" branch.

Phase 3 children branched off `main` and opened PRs against `main`. `gh stack link` only retargets PR bases. That is **not** a git stack: `git merge-base --is-ancestor $parent $child` is false, `gh stack rebase` fails with "could not determine the previous base", and `coderabbit review --base main` from the top worktree reviews only the top layer. Do not skip the rest of this phase.

### 6a. Link

```
gh stack link --open <bottom-branch> <next-branch> ... <top-branch>
gh stack view --json
```

Confirm the PR chain matches Phase 1's order.

### 6b. Assemble

Spawn **one stack-assembly child per repo** in this milestone (`thinking: "off"`, `context: "fresh"`, no `async: true`). The parent does not rebase, resolve conflicts, or rewrite imports. The child prompt:

```
Assemble the GitHub stack for <repo> in milestone <title>.

Branches, bottom to top:
<branch>  PR #<n>  <ISSUE-ID>
...

File ownership (lowest owner wins for scaffold):
<path> — <ISSUE-ID>

Work in a fresh clone at ~/Code/workspaces/<milestone-slug>/<repo>-stack.
Do not use the per-issue worktrees.

1. gh stack checkout <any PR number in this stack>
   If that prompts, gh stack unstack --local first, then retry.
2. Ancestry. For each child, git merge-base --is-ancestor $parent $child
   must be true. Try `gh stack rebase --no-trunk` first. If it errors
   (unknown previous base, or parent is not an ancestor), for each
   child run:
     git rebase --onto "$parent" origin/main "$child"
   Do not resolve conflicts in the GitHub UI.
3. Scaffold policy while resolving add/add conflicts:
   - Lowest layer that introduced the toolchain keeps package.json,
     tsconfig.json, .gitignore, vitest.config.ts / equivalent, and
     the lockfile.
   - Later layers may only add unique dependencies and unique files.
   - Do not hand-merge lockfiles. Regenerate on the layer that added
     a unique dep.
   - One test runner for the repo. Drop a second one (for example
     node:test next to vitest).
4. Compose. Replace inlined copies of owned types with imports from
   the owner. Wire composition modules (register sources, import the
   writer). Empty registries and @ts-ignore sibling imports are bugs.
5. gh stack push
6. Gate, all required:
   - gh stack view --json: every branch needsRebase == false
   - git merge-base --is-ancestor parent child for every adjacent pair
   - gh pr view: mergeable == MERGEABLE for every stacked PR
   - git diff --name-only origin/main...$top is the union of layers,
     not the top commit alone
   - gh pr checks <n> --repo <owner>/<repo>: every layer PR's Test
     check status is "pass", not "fail" or "pending" / "expected".
     Treat a non-pass Test as a gate failure even when MERGEABLE is
     true and ancestors are correct.

Report: branch SHAs, files changed per layer vs parent, remaining
hazards you did not fix.
```

When the gate fails because a layer's Test check is red, the failure
almost always traces to a foundation commit (the layer with no
internal deps in the milestone) that pre-wrote dispatch for routes
owned by sibling layers. The fix is to reshape the foundation: the
foundation commit owns only its own routes and the 404 default, and
sibling dispatch + imports land as follow-up commits in each sibling
PR's own tip. Do not retarget by hand; spawn an assembly child to
reshape. Do not skip the gate by accepting a layer's CI as "expected
to fail until cascade lands" — that is the bug, not the cure.

If the assembly child fails, record it and stop Phase 6. Do not run CodeRabbit. Do not start Phase 7. The user decides in the final report.

### 6c. Review the cumulative diff

Only after 6b's gate passes. **This is the only CodeRabbit call in Tier 1.**

From a checkout of the **top branch after rebase**:

```
timeout 30m coderabbit review --agent --base main
```

Save the JSON to `~/Code/workspaces/<milestone-slug>/.cr-stack-review.json`.

Before treating findings as stack-wide, compare `reviewedFiles` (or `git diff --name-only origin/main...HEAD`) to the union of layer files. If that list is the top layer alone, the review is invalid — go back to 6b.

Do not use `--base-commit` (narrower). Do not use `coderabbit pullrequest` (reads an existing SaaS review; it does not run one). Time-box at 30 minutes; longer usually means hung or rate-limited.

Surface critical findings in Phase 8. Do not fix them mid-run. The user decides whether to re-spawn, rebase + fix, or accept.

## Phase 7 — Write human-issue writeups

Only after Phase 6 is complete (the stack is mergeable and the cumulative CodeRabbit review has run) does the parent touch the human issues. Linking without a cascade rebase is not complete.

For each issue classified human in Phase 2, update the Linear issue body to contain the full human procedure:

```
## Manual steps

A human must do the following in order. Each step has one action.

### 1. <action title>

<exact action — one verb, one object. Example: "Create a Stripe account at
https://dashboard.stripe.com/register using the company email
finance@<domain>.">

**Why a person is needed.** <one sentence: it's a paid account, or it needs
a phone-verified identity, or it requires a vendor relationship that only
the user can authorize.>

### 2. <action title>

...

## Context

<everything a person reading only this issue needs to know to act. Full
context, not cross-references. Include:>

- The goal of this issue and how it fits in the milestone.
- The state of the world after agentic work completed (which PRs
  landed, what the code now expects, which environment variables are
  already set, which are missing).
- The exact inputs the person must provide (account names, API keys,
  callback URLs — paste them inline).
- The exact outputs the person must produce (where to paste the API key,
  which file to commit, which PR to open if any).

**References** (cross-pointers only — not substitutes for context):

- Linear: <other-issue-id> — <one-line description of the relationship>
- PR: <pr-url> — <one-line description of what that PR does>
```

### Writing rules — read carefully

A person reading a Linear issue may not know what the agents did. Therefore:

- **Write the full context in the issue.** Do not replace context with a reference such as "as mentioned in SII-51". A reader who only has this issue open must be able to act.
- **A reference is correct only to show that an earlier note exists.** A reference is not a substitute for the context itself. Use references to acknowledge related issues, not to defer to them.
- **Give the steps in order.** Write one action for each step. If a step has two actions, split it.
- **Explain why the step needs a person.** One sentence per step. The reason should be specific (paid account, identity verification, vendor authorization) — not generic ("human judgment").
- **Do not paste secrets into the issue body.** If the person needs an API key, the body should say "paste the API key into `<env var>` in `<secret store>`" — not the key itself.
- **Do not include the PR URLs from agentic work in the human-step list.** Put them in the Context section. The human steps are about what the person does; the PRs are about what the agents already did.

Do **not** post the milestone comment yet. That happens after Phase 7b, once each human issue also has a walkthrough script path.

## Phase 7b — Walkthrough scripts for human issues

Only after Phase 7 is complete (Linear bodies contain the settled steps) does the parent spawn walkthrough-script children. Skip this phase when the milestone has no human issues.

The parent does **not** follow `/skill:walkthrough-script` itself. That skill writes a file. If the parent is about to write a `.sh`, stop and spawn.

Spawn **one sub-agent per human issue** in one parallel `tasks` block of its own (same spawn shape as Phase 3: no `async: true`, `context: "fresh"`, `thinking: "off"`). Do not fold these children into the Phase 3 agentic fleet. They cannot start until Phase 7 has written the Linear bodies. Do not give these children the agentic "open one pull request" rules.

Each task prompt:

```
Load /skill:walkthrough-script and follow it.
Read ~/.agents/skills/walkthrough-script/SKILL.md if the skill is not
already in context (also ~/.pi/agent/skills/walkthrough-script/SKILL.md).

Source: Linear <ISSUE-ID>
Output: ~/Code/workspaces/<milestone-slug>/human/<ISSUE-ID>.sh

The Linear body was just updated in Phase 7. Fetch it. Encode those
steps. Do not open a pull request. Do not run --live.

Report back: path, per-step classification (command | command+decision |
out-of-terminal), bash -n result, --dry-run result.
```

Create `~/Code/workspaces/<milestone-slug>/human/` before spawning if it does not exist. The child writes the file; the parent only creates the directory.

After the parallel call returns, collect `{ issue_id, script_path, status }` for the Phase 8 report. A failed walkthrough child is recorded, not silently retried.

Then post the milestone comment, now including each script path:

```
Human writeups complete for <milestone-title>:
- <ISSUE-ID>: <title> — <url>
  Script: ~/Code/workspaces/<milestone-slug>/human/<ISSUE-ID>.sh
- <ISSUE-ID>: <title> — <url>
  Script: ~/Code/workspaces/<milestone-slug>/human/<ISSUE-ID>.sh
```

Do not copy flag lists, step-type rules, or bash templates into this skill. Those live in `walkthrough-script`.

## Phase 8 — Report

Only after Phase 7b is complete — agentic work done, stack **mergeable**, human issues written, walkthrough scripts on disk — does the parent report to the user. Do not title the report "complete" while any stacked PR is `CONFLICTING` or `needsRebase: true`.

The report format:

```
## Milestone <title> — complete

### Pull requests stacked

- <ISSUE-ID>: <title> — <pr-url>  (layer <n> of <total>, MERGEABLE|CONFLICTING)
- <ISSUE-ID>: <title> — <pr-url>  (layer <n> of <total>, MERGEABLE|CONFLICTING)
- ...

Stack: <stack-url-if-available>

### Human work for you

For each human issue, include both the Linear link AND the actual steps,
inline. Do not make the user open Linear to see what they need to do.

#### <ISSUE-ID>: <title> — <linear-issue-url>

Walkthrough:

  ~/Code/workspaces/<milestone-slug>/human/<ISSUE-ID>.sh --dry-run
  ~/Code/workspaces/<milestone-slug>/human/<ISSUE-ID>.sh --live

1. **<step title>** — <one-line action>
   *Why a person:* <one sentence>
2. **<step title>** — <one-line action>
   *Why a person:* <one sentence>

(Context — the things a person needs to know to do the steps above —
goes here, not inside the step list. Same Context block as the Linear
issue body, abbreviated.)

#### <ISSUE-ID>: <title> — <linear-issue-url>

...

### Notes

- <assumption some sub-agent made>
- <spec gap that needs a decision>
- <mixed issue that must be split before a re-run>
- <anything the user should review before merging>
- <any failed or stopped runs, with their last useful transcript line>

### CodeRabbit CLI review

Tier 1 runs one orchestrator-level `coderabbit review --agent --base main` against the rebased top-of-stack HEAD in Phase 6c, after the ancestry/mergeable gate. Findings here are stack-wide only if `git diff --name-only origin/main...HEAD` is the union of layers. If the review saw only the top layer, say so and do not call it stack-wide.

- Source: `~/Code/workspaces/<milestone-slug>/.cr-stack-review.json`
- Critical: <N>
- Warning: <M>
- Info: <K>

If any of these warrant action before merge, list them below with file/line and one-line summary:

- <finding 1 — file:line — one-line summary>
- <finding 2 — ...>

If the milestone was Tier 2 (per-issue CLI reviews), also report:

- Tier-2 sub-agent reviews: ran on X of Y issues; the remaining Y-X issues did not review because the hourly CLI allowance was exhausted. The PR bodies of the unreviewed issues say so.
```

The user does not have to open Linear to know what to do. The report stands on its own.

If the report would be empty (e.g. nothing ran, everything blocked), report that. Do not invent work.

## Constraints

- **Disable thinking for sub-agents.** Pass `thinking: "off"` (or `model: "provider/model:off"`) on every per-issue sub-agent, including the Phase 6 assembly child and Phase 7b walkthrough-script children. The child prompt does not need to mention thinking — the parent owns that setting.
- **One branch per issue, one PR per issue.** This cap is for agentic issues. Never merge two sub-agents' work into one branch. If two issues touch the same code, the stack in Phase 6 orders them. Walkthrough-script children produce a script, not a pull request. The assembly child pushes the existing stack; it does not open a new PR.
- **Do not implement issues from the parent.** The parent coordinates. Feature commits, import rewrites, scaffold merges, and walkthrough `.sh` files are children. The parent may run `gh stack link|view|checkout|push` after assembly returns, and the CodeRabbit CLI review. If the parent is about to write a source file or a walkthrough `.sh`, stop and re-delegate.
- **One worktree per issue.** Path is `~/Code/workspaces/<slug>/<repo>-<issue-id>`. Two parallel children must never share a directory.
- **Do not skip Phase 7.** Human issues must be updated, not left as cross-references. The cross-reference rule is the point. A walkthrough script is not a substitute for the Linear body.
- **Do not skip Phase 7b.** After the Linear writeup, spawn a walkthrough-script child per human issue. The parent does not write that script and does not follow `/skill:walkthrough-script` itself.
- **Do not report before Phase 7b.** "Agentic work is done, human work pending" is not a complete report. The user wants one report after Linear writeups and walkthrough scripts are both on disk.
- **Do not treat a mixed issue as human.** If the body has agent-capable steps and human-only steps, it is a spec defect. Split it before this skill runs. Do not relabel it `human` to make it go away.
- **Do not pick a milestone without being told.** If the user invokes the skill without a URL, ask. Do not search history, do not pick the most recently active one.
- **Do not silently re-spawn failed sub-agents.** Record the failure; the user decides in the final report whether to re-spawn, reclassify, or skip.
- **Do not surface anything to the user mid-run.** One end-of-milestone report after all phases complete. Mid-flight escalations are anti-pattern.
- **Always one stack per milestone.** Never split a milestone's PRs into separate stacks. Independent issues go at the same layer in the same stack.
- **Do not run on primary checkouts.** Sub-agents use worktrees under `~/Code/workspaces/<milestone-slug>/`, never `~/Code/<repo>/` directly.
- **Do not start Phase 7 or title Phase 8 complete while any stacked PR is CONFLICTING.** Linking is not stacking.

## Anti-patterns

- **Serializing independent issues.** Independent issues in the same wave start in one parallel `tasks` invocation. Do serialize wave 1 (owned shared files) before wave 2. Turning the whole milestone into a single-file queue is still wrong.
- **Spawning with `async: true` when not needed.** Parallel `tasks` already drain in the foreground. `async: true` orphans the run ids and forces polling.
- **Writing human-issue steps before agentic work finishes.** Human writeups are Phase 7, not Phase 2. Premature writeups lock in stale assumptions.
- **Leaving human steps as a phase inside an agentic issue.** Split. Agent-capable work in an `agentic` issue. Human-only work in a `human` issue. Link them with a blocker relation.
- **Relabelling a mixed issue as `human`.** That hides agent work behind a human label and wrecks the dependency graph.
- **Cross-referencing instead of context.** "See SII-51 for the API key" is wrong. Paste the key location, the env var, the secret store path — all of it — in the human issue.
- **Reporting before Phase 7b.** "PRs are open, human issues pending" is half a report. Wait until Linear writeups and walkthrough scripts both exist.
- **Parent writes the walkthrough `.sh`.** Load is not follow. Spawn a child whose job is `/skill:walkthrough-script`. If the parent is writing bash, the parent has slipped out of orchestration.
- **Skipping the Linear body because a script exists.** The issue body stays the readable source of truth. The script is the thing the person runs.
- **Surfacing blockers to the user mid-run.** The orchestrator and sub-agents keep going. The user sees one final overview.
- **Splitting a milestone into multiple stacks.** Always one stack per milestone. Independent PRs live at the same layer.
- **Running per-PR CodeRabbit reviews through the CLI when only the orchestrator-level stack review is needed.** PR-by-PR CLI reviews burn the Free tier allowance in minutes (1 review per PR, 3 reviews/hour cap). The stack review is 1 review per milestone. For Tier 1, do only the stack review, and only after 6b's gate.
- **Calling `coderabbit review --base main` on an unrebased top branch.** That reviews the top layer, not the stack. Same for `--base-commit` and `coderabbit pullrequest`.
- **Linking a stack and calling it done.** `gh stack link` retargets PR bases. Without cascade rebase, GitHub shows CONFLICTING, `gh stack rebase` cannot find a parent, and CodeRabbit sees one file.
- **Resolving stack conflicts in the GitHub UI.** That creates merge commits and fights the next rebase. Use `git rebase --onto` in the assembly child.
- **Two parallel children in the same worktree.**
- **Recreating `package.json` / `tsconfig.json` / shared types because the branch must compile.**
- **Leaving empty registries or `@ts-ignore` imports for modules a sibling owns.**
- **Trusting `gh stack rebase` when `merge-base --is-ancestor` is already false.** Use `git rebase --onto "$parent" origin/main "$child"`.
- **Letting the parent implement an issue.** If the parent is editing a source file to land a feature, it has slipped out of orchestration. Re-delegate. Assembly is a child; walkthrough `.sh` is a child.
- **Polling instead of waiting.** Use `subagent_wait({ all: true })` once at the right boundary. Do not loop on `subagent({ action: "status", id })` to busy-wait.