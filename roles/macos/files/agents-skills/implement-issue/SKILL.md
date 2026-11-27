---
name: implement-issue
description: "Implement an issue. A root with sub-issues runs in root mode: its approved sub-issues fan out to Claude Code sub-agents in waves (one sub-agent, worktree and sub-PR into the root branch each, through CI and the repo's review gate), each wave merges into the root branch before the next, ready-for-human sub-issues get walkthrough scripts, then the root PR opens and one report follows. An issue with no sub-issues (a standalone issue, a root done in one pass, or one sub-issue) runs in leaf mode: one sub-agent, one worktree, one PR into its parent branch, through CI and the repo's review gate. Use when the user asks to implement, coordinate, orchestrate or fan out an issue or root. Expects an issue ID (or its URL). Run review-issue first."
metadata:
  author: KSiig
  harness: claude-code
  triggers:
    - implement issue
    - implement root
    - coordinate root
    - fan out root
    - run root
    - orchestrate sub-issues
disable-model-invocation: true
---

# Implement issue — root fan-out or a single PR

The skill has two modes, picked from the issue (Phase 1b):

- **Root mode** — a root with sub-issues. Phases 2 to 8 below.
- **Leaf mode** — an issue with no sub-issues: a standalone issue, a root done in one pass, or one sub-issue run on its own. The "Leaf mode" section; it skips Phases 2 to 8.

In root mode: take a root issue, fan out one sub-agent per approved agent sub-issue, and land every sub-issue on the root branch as its own reviewed sub-PR. Human work lives in its own human sub-issues — never as a phase inside an agent sub-issue — and is written into those Linear issues themselves, never as cross-pointers. A person reading only that issue must be able to act. After the Linear writeup, a sub-agent per human sub-issue follows `walkthrough-script` and writes a runnable walkthrough.

This is an **orchestration skill**. The parent does not implement sub-issues, author feature commits, or write walkthrough scripts. It resolves the root, spawns and waits, merges finished sub-PRs into the root branch, opens the root PR, and reports.

Usually run in a new, clean chat after `review-issue` and its apply step. Everything needed is in Linear; do not rely on chat history.

## Invocation

```
/implement-issue <ISSUE-ID | Linear issue URL>
```

The argument is the issue: a root, a standalone issue, or a sub-issue. If none is given, ask. Do not pick a root from history.

Use the claude.ai Linear connector for every Linear read and write. Run from where the repo's task contract says (for a project with a coordination repo, a worktree of it), so sibling repos and `.claude/agents/` are reachable. Without one, run from the target repo.

## Project rules: reference, do not copy

Delivery rules live in the repo's own ways-of-working skill (any skill named `*-ways-of-working`). If the repo has none, use the generic `ways-of-working` skill. Load it at the start. Below, "ways-of-working" means the skill you loaded. Follow it for everything below that names it; do not restate its rules in prompts or reports, cite the file and section. If it and this skill disagree, ways-of-working wins.

Other project specifics come from the repo too, with a default when it has none:

| Specific | From the repo | Default |
|---|---|---|
| Review gate on every PR | its PR-review skill (for example `pr-review`) | CI green |
| Worktree and issue setup | its `start-task` skill | worktree from latest `main`, issue In Progress with an assignee |
| The Never list | its `AGENTS.md` | no `terraform apply`/`destroy`, no push to `main`, no secrets in a diff |
| Agent types | its `.claude/agents/` | the built-in agent types |

Where each delivery rule lives in ways-of-working:

| Topic | Where it lives |
|---|---|
| Root, sub-issue; the root description is the plan | `LINEAR.md` "Planning a root" |
| Standalone issues | `LINEAR.md` "What an agent creates" |
| Lane labels on sub-issues, roots done in one pass and standalone issues; the label is the approval; unlabelled = draft | `LINEAR.md` "Lanes" |
| Linear states to move, Done bars | `LINEAR.md` "States", "Done bars" |
| Branch names, where a sub-branch forks, PR target, merge method, no stacks | `BRANCHING.md` "The rule", "Sub-issue work", "Naming" |
| PR title and body | `BRANCHING.md` "PR shape" |
| Who must approve what | `BRANCHING.md` "Review tiers" |

Repo conventions (Terraform, Kustomize, EF, Flux, …) load from the repo's `.claude/rules/` when matching files are touched.

## Your task

1. Resolve the issue (Phase 1) and pick the mode (Phase 1b). In leaf mode, follow "Leaf mode" and skip the rest of this list. In root mode, classify each sub-issue (Phase 2). Start immediately; `review-issue` already ran. Do not pause for confirmation.
2. Set up the root branch (Phase 3).
3. Spawn agent sub-issues in waves (Phase 4). Merge each wave's sub-PRs into the root branch before the next wave starts (Phase 5).
4. Write human sub-issues up and spawn their walkthrough children (Phase 6).
5. Review the whole root diff and open the root PR (Phase 7).
6. Report once, at the end (Phase 8).

## Sub-agent rules

Every **agent** sub-issue sub-agent gets these rules verbatim in its prompt. Walkthrough children and the review child get their own prompts.

1. **Build the exact specification in the sub-issue.** Change the specification only when a test shows that it is wrong.
2. **Act only on facts from a codebase search or a web search.** Do not assume. Do not use training data as a source.
3. **Do all work that does not depend on a later wave.**
4. **Open one PR for the issue, into the base branch the prompt names.** Never into any other branch. Never stacked on another PR.
5. **Use what is already on the base branch.** Do not recreate files, types or resources another issue owns. Branch from the current base tip, which already has them.
6. **Run the repo's PR-review loop** (its PR-review skill, for example `pr-review`) until CI is green and its review gate passes on your head commit, or you have answered every finding. If the repo has no PR-review skill, the gate is CI green. Do not merge.
7. **Follow the Never list in the repo's `AGENTS.md`, and in the coordination repo's if the task runs from one.** At least: no `terraform apply`/`destroy`, no push to `main`, no secrets in a diff.

Each agent sub-agent owns one sub-issue, one worktree, one sub-PR. Sub-agents do not coordinate with each other; they report to the parent. Cross-sub-issue problems are the parent's.

## Phase 1 — Resolve the issue

Fetch, with the Linear connector:

- **The issue** — title, URL, description (for a root, the plan), state, labels, assignee, `gitBranchName`, repo, parent.
- **The parent story** — its acceptance criteria, if there is a story above the issue (directly for a root, through the root for a sub-issue). Proof in PRs matches these (ways-of-working `BRANCHING.md` "PR shape"). A standalone issue has no story; its own completion checks are the proof.
- **Every sub-issue** — identifier, title, state, labels, assignee, `gitBranchName`, body.
- **Comments** on the root and every sub-issue. Comments are part of the spec.
- **Blocker relations** inside the root, and any to issues outside it.
- **File ownership** — from bodies and blocker relations, which sub-issue creates each shared file or resource.

Go to Phase 1b before you print anything. In root mode, print this summary for your own bookkeeping and the final report. Do not pause.

```
# Root — <ISSUE-ID> <title>
  <n> sub-issues · <a> ready-for-agent · <h> ready-for-human · <d> drafts (no lane) · <x> mixed · <b> blocked outside the root

## Sub-issues
### <ISSUE-ID> — <title>  [agent | human | draft | mixed | blocked]
  State: <state> · Lane: <label | none> · Wave: <n | –>
  <one-line spec summary>

## Dependencies
- <ISSUE-A> → <ISSUE-B>

## Worktrees
- ~/Code/workspaces/<root-slug>/<repo>            → <root branch>
- ~/Code/workspaces/<root-slug>/<repo>-<sub-id>   → <sub-branch>
```

`<root-slug>` is the slug of the root's `gitBranchName` (the part after `<author>/`).

## Phase 1b — Pick the mode

- **Root mode** — the issue has sub-issues. Continue with Phase 2.
- **Leaf mode** — the issue has no sub-issues. Go to "Leaf mode" below. Phases 2 to 8 do not apply.

## Phase 2 — Classify

Classification is per sub-issue. A sub-issue is agent work or human work. Not both.

- **Agent** — lane label is the agent lane (ways-of-working `LINEAR.md` "Lanes"), and the body is a complete spec an agent can do: checkable completion, no privileged decision, no human-only action. One sub-issue, one sub-PR.
- **Human** — lane label is the human lane, and every step needs a person: a paid account, personal credentials, cluster or cloud access agents don't have, a vendor portal, a decision. 
- **Draft** — no lane label. The label is the approval, so a draft is **not implemented**, even if this or another agent wrote it. Report it.
- **Mixed (spec defect)** — agent-capable and human-only steps in one body. Do not spawn. Report it; the fix is a split, done before this skill runs.
- **Blocked outside the root** — depends on an unfinished issue outside this root. Surface it; do not plan around it.

Waves come from blocker relations: wave 1 is every agent sub-issue with no unfinished blocker; wave N+1 is every agent sub-issue whose blockers all landed in waves ≤ N. A sub-issue blocked by a human sub-issue waits; record it.

Human writeups are Phase 6, not now. The agent work often changes what the person must do.

## Phase 3 — Root branch

The root branch is the root's `gitBranchName`, forked from `main` (ways-of-working `BRANCHING.md` "The rule").

- If it exists on `origin`, use it. Otherwise set it up for the root with the repo's `start-task` skill if it has one (it may add a coordination worktree beside it). Without one: Linear In Progress and assigned, worktree at `~/Code/workspaces/<root-slug>/<repo>` from latest `main`. Push the empty root branch.
- Move the root to In Progress if it isn't (ways-of-working `LINEAR.md` "States").

## Phase 4 — Spawn agent sub-issues, one wave at a time

Spawn every sub-issue of the wave with parallel `Agent` calls in **one** message. They run in the background; you are notified as each finishes. Do not poll, do not sleep, do not read their output files.

**Pick the agent type per sub-issue.** Read the definitions in the repo's `.claude/agents/` (name, description, model, tools) and choose the one that fits the work. If the repo defines none, use the built-in agent types (`general-purpose` for code). Typical choices:

- `implementation-worker` — well-scoped code with existing patterns to follow. The usual choice.
- `researcher` — the sub-issue is an investigation whose output is findings, not code.
- `docs-writer` — stable documentation under a repo's `docs/`.
- `general-purpose` — none of the above fits.

Record the choice and the reason in the run map. Do not override the agent's model unless the sub-issue says to.

Task prompt for each agent sub-issue:

```
You are implementing <SUB-ID> under root <ROOT-ID> (<root-url>), repo <repo>.

## Sub-issue spec
<full body>

## Comments that pin down the spec
<relevant comments>

## Story acceptance criteria (proof in the PR matches these)
<criteria>

## Already on the root branch from earlier waves
<SUB-ID> — <what it added, key paths>. Use it. Do not recreate it.

## Branch and PR
- Root branch: <root-branch>. Fetch it; branch from its current tip.
- Your branch: <sub-issue gitBranchName>, in a fresh worktree at
  ~/Code/workspaces/<root-slug>/<repo>-<sub-id>.
- One PR, base <root-branch>. Title and body per <ways-of-working skill>
  BRANCHING.md "PR shape" (Linear: <SUB-ID> on the first line).
- Move <SUB-ID> to In Progress when you start and In Review when the PR is
  open (<ways-of-working skill> LINEAR.md "States").

## Rules
<the seven sub-agent rules, verbatim>

## Report back
Branch, PR URL, CI status, review gate result, findings fixed
and ignored (with reasons), anything that needs the parent: assumptions,
spec gaps, files you needed but another sub-issue owns.

Do not coordinate with other sub-agents. Do not touch their worktrees. If
cross-sub-issue work has to happen, report it and stop.
```

Keep a run map: `{ sub_id, agent_type, branch, pr_url, ci, review_gate, notes }`.

In the prompt, replace `<ways-of-working skill>` with the name of the skill you loaded.

## Phase 5 — Merge the wave into the root branch

When every sub-agent of the wave has reported:

- A sub-PR **merges** into the root branch when CI is green, the repo's review gate passes on its head (default: CI green), and it needs no Ask-tier human (ways-of-working `BRANCHING.md` "Review tiers"). Merge it with the method ways-of-working gives for sub-issues; delete the sub-branch. The sub-issue moves to Done (its change is on the root branch).
- A sub-PR that needs an Ask-tier human **is not merged**. Record it. Sub-issues it blocks do not start.
- A failed or stopped sub-agent is recorded, not silently re-spawned. Sub-issues it blocks do not start.

Then start the next wave from the new root tip, with the "already on the root branch" section filled in. Stop the waves when nothing else can start.

Merging into the root branch is the parent's only write to git. Never merge into `main`.

## Phase 6 — Human sub-issues

After the last wave, for each human sub-issue, update the Linear body:

```
## Manual steps

A person must do the following in order. Each step has one action.

### 1. <action title>
<exact action — one verb, one object.>

**Why a person is needed.** <one specific sentence: paid account, personal
credentials, cluster access agents don't have, a decision only you make.>

### 2. …

## Context

<Everything a person reading only this issue needs: the goal and how it fits
the root; the state after the agent work (which sub-PRs landed on the root
branch, what the code now expects, which config or secrets exist and which
are missing); exact inputs and outputs. Full context, not cross-references.>

**References** (pointers only, not substitutes for context):
- Linear: <ISSUE-ID> — <relationship>
- PR: <url> — <what it did>
```

Writing rules: full context in the issue; a reference only acknowledges a related note; one action per step, in order; a specific reason a person is needed; never paste secrets — name the secret store and key instead; agent PR URLs go in Context, not in the steps.

Then spawn one child per human sub-issue, in one message of parallel `Agent` calls (`general-purpose`), with this prompt:

```
Load the walkthrough-script skill and follow it.

Source: Linear <SUB-ID>
Output: ~/Code/workspaces/<root-slug>/human/<SUB-ID>.sh

The Linear body was just updated. Fetch it. Encode those steps. Do not
open a pull request. Do not run --live.

Report back: path, per-step classification (command | command+decision |
out-of-terminal), bash -n result, --dry-run result.
```

Create `~/Code/workspaces/<root-slug>/human/` first. The parent never writes the `.sh` itself.

## Phase 7 — Review the root and open the root PR

When every agent sub-issue is merged into the root branch (or recorded as stopped):

1. Spawn one `reviewer` agent (from the repo's `.claude/agents/`; else `general-purpose` told to review only) on the cumulative diff `origin/main...origin/<root-branch>`, with the story's acceptance criteria and the root description. It reports findings; it does not fix them. Record them for the report.
2. If every agent sub-issue is on the root branch and no human sub-issue must happen before the root reaches its parent, open the root PR into its parent per ways-of-working (`BRANCHING.md` "The rule", "PR shape"), and run the repo's PR-review loop on it (default: wait for CI green). Do not merge it: the root PR is the human read of the whole (`BRANCHING.md` "Sub-issue work").
3. Otherwise do not open it. Say in the report what it waits for.

## Phase 8 — Report

Report only now: no wave can start, every merged sub-PR is on the root branch, every human sub-issue has a Linear writeup and a walkthrough script, and the root PR is open or its blocker is named. Do not report part-way.

```
## <ROOT-ID> <title> — <done | stopped: reason>

### Sub-PRs into <root-branch>
- <SUB-ID>: <title> — <pr-url> · wave <n> · <agent type> · <merged | waiting for Ask-tier review | failed>

### Root PR
<url, CI and review gate status, and who must approve (Review tiers) — or what it waits for>

### Human work for you
#### <SUB-ID>: <title> — <url>
  ~/Code/workspaces/<root-slug>/human/<SUB-ID>.sh --dry-run
  ~/Code/workspaces/<root-slug>/human/<SUB-ID>.sh --live
1. **<step>** — <one-line action>. *Why a person:* <reason>
(Short context.)

### Not started
- Drafts without a lane: <SUB-IDs> — the lane label is your approval.
- Mixed, to split: <SUB-IDs>
- Blocked outside the root: <SUB-IDs and what blocks them>

### Root review
<reviewer findings worth acting on: file:line — one line each, or "none">

### Notes
- <assumptions a sub-agent made, spec gaps, review findings ignored and why, failed runs>
```

The user should not need to open Linear to know what to do. If nothing ran, say so. Do not invent work.

## Leaf mode

One issue, one sub-agent, one worktree, one PR into the issue's parent branch. The parent still does not implement.

### L1 — Classify the issue

Same classes as Phase 2, applied to the issue itself (ways-of-working `LINEAR.md` "Lanes"):

- **Agent** (`ready-for-agent`, complete spec) — continue with L2.
- **Human** (`ready-for-human`) — do not spawn an implementer. Spawn the walkthrough child from Phase 6 for this issue (skip the Linear rewrite: no agent work changed what the person must do), with the script at `~/Code/workspaces/<slug>/human/<ISSUE-ID>.sh`. Then report (L4).
- **Draft** (no lane label), **mixed**, or **blocked** by an unfinished issue — do not spawn. Report it (L4).

`<slug>` is the slug of the issue's `gitBranchName` (the part after `<author>/`).

### L2 — Find the base branch

The base is the issue's parent branch (ways-of-working `BRANCHING.md` "The rule"):

| Issue | Base branch |
|---|---|
| Standalone issue (no parent) | `main` |
| Root with no sub-issues | the project branch if the story sits in a project with one, else `main` |
| Sub-issue run on its own | its root's `gitBranchName`. It must exist on `origin`; if not, report and stop |

Move the issue to In Progress, with an assignee, if it is not (ways-of-working `LINEAR.md` "States"). If the repo's `start-task` skill asks for a coordination worktree, make sure it exists at `~/Code/workspaces/<slug>/<coordination-repo>`. Do not create the repo worktree; the sub-agent does.

### L3 — Spawn one sub-agent

One `Agent` call. Pick the agent type as in Phase 4. Use the Phase 4 task prompt with these changes:

- First line: `You are implementing <ISSUE-ID> (<url>), repo <repo>.`
- "Sub-issue spec" is the issue body. "Story acceptance criteria" is the story's criteria if there is a story, else the line "No story. The completion checks in the issue body are the proof."
- Drop "Already on the root branch from earlier waves".
- Branch and PR: base branch `<base>`, fetched, branch from its current tip. Branch `<gitBranchName>`, worktree `~/Code/workspaces/<slug>/<repo>`. One PR, base `<base>`.
- The seven sub-agent rules, verbatim.

Wait for the notification. Do not poll.

**Never merge the PR.** A PR into `main` or a project branch is a human merge. A sub-issue PR into its root branch also waits: say in the report whether it meets the Phase 5 merge bar.

### L4 — Report

```
## <ISSUE-ID> <title> — <done | stopped: reason>

PR: <url> into <base> · <agent type> · CI <status> · review gate <result>
Who must approve: <Review tiers in BRANCHING.md>

### Human work for you            (human lane only)
  ~/Code/workspaces/<slug>/human/<ISSUE-ID>.sh --dry-run
  ~/Code/workspaces/<slug>/human/<ISSUE-ID>.sh --live

### Not started                   (draft, mixed or blocked: what is needed)

### Notes
- <assumptions, spec gaps, review findings ignored and why, a failed run>
```

## Constraints

- **Never implement from the parent.** If the parent is about to edit a source file or write a `.sh`, stop and delegate.
- **One sub-issue, one worktree, one branch, one sub-PR into the root branch.** Two children never share a directory.
- **No stacks.** Every sub-branch forks from the root tip; a dependent sub-issue waits for its blocker to merge into the root.
- **Never implement a draft.** No lane label, no work. This holds in leaf mode too.
- **Never set a lane label, and never change story, project or initiative states.**
- **Never merge into `main`.** The parent merges sub-PRs into the root branch only, and only after CI and the review gate pass and no Ask-tier review is needed.
- **Follow the Never list in the repo's `AGENTS.md`.**
- **One report, at the end.** Do not surface blockers mid-run; record them. Questions belong to `review-issue`, which runs before this skill.
- **Do not silently re-spawn a failed sub-agent.** The user decides.
- **Do not skip Phase 6** in root mode. A walkthrough script is not a substitute for the Linear body, and the Linear body is not a substitute for the script.
- **Do not run on primary checkouts.** Worktrees under `~/Code/workspaces/<slug>/` only.

## Anti-patterns

- **Serializing independent sub-issues.** A wave starts in one message of parallel `Agent` calls.
- **Starting the next wave before the previous one is merged into the root branch.** It would branch from a tip that lacks its dependencies.
- **Polling background agents.** Wait for the notifications.
- **Writing human steps before the agent work settles.** Phase 6, not Phase 2.
- **Leaving human steps inside an agent sub-issue, or giving a mixed sub-issue the human lane.**
- **Cross-referencing instead of context.** "See <ISSUE-ID> for the key" is wrong; write the store and key name.
- **Merging a sub-PR whose review gate has not passed on its head, or that needs an Ask-tier human.**
- **Copying project rules into prompts.** Point at ways-of-working.
