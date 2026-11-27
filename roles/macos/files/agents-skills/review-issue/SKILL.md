---
name: review-issue
description: >
  Review an issue for implement-issue readiness. A root with
  sub-issues gets the root review: the root description (the plan), every
  sub-issue, comments, blocker relations, cross-referenced siblings and the
  parent story's acceptance criteria. An issue with no sub-issues (a
  standalone issue, a root done in one pass, or one sub-issue) gets the leaf
  review: the issue body as a complete spec. Verifies each claim against the
  repo and the web; reports every Linear change required before
  implement-issue. Writes
  that report to /tmp as actions then context, checks it with STE100 when
  that skill is installed, publishes it as an Artifact with the visual-aid skill, and ends with a
  list of questions for the user. Does
  not implement product work. Use when the user asks to review an issue or
  a root, prepare one for implement-issue, check if it is ready, or runs
  /review-issue.
triggers:
  - review issue
  - review root
  - prepare root
  - root ready
  - implement-issue ready
  - review linear root
---

# Review issue — implement-issue readiness

Review an issue and report every change Linear needs before
`implement-issue`. Default: report only. Do not edit Linear, do not
implement the product, unless the user explicitly asks to apply the report.

Typical order: this skill → the user answers the questions → apply (the
user asks) → `implement-issue`, usually in a new, clean chat. That chat has
only Linear, so everything it needs must be in Linear when this skill is
done.

## Invocation

```
/review-issue <ISSUE-ID | Linear issue URL>
```

The argument is the issue: a root, a standalone issue, or a sub-issue. If none is given, ask. Do not pick a root
from history or search for "the current one".

Use the claude.ai Linear connector for every Linear read and write.

## Project rules: reference, do not copy

Delivery rules live in the repo's own ways-of-working skill (any skill
named `*-ways-of-working`). If the repo has none, use the generic
`ways-of-working` skill. Load it before you review. Below,
"ways-of-working" means the skill you loaded. Judge the root against it. Do not restate its rules in
this skill or in the report; cite the file and section instead, so a change
there carries through.

You need at least:

- `SKILL.md` — vocabulary: root, sub-issue, story; ownership; backward
  compatibility; feature flags.
- `LINEAR.md` — "Planning a root" (the root description is the plan),
  "Lanes" (lane labels, and that the label is the approval), "States",
  "Done bars", "Acceptance criteria", "Sizing".
- `BRANCHING.md` — "The rule", "Sub-issue work", "PR shape", "Review
  tiers".
- Any extra page the repo's skill adds (for example cross-team contracts),
  when the story spans repos.

The review gate a PR must pass comes from the repo's PR-review skill (for
example `pr-review`); without one it is CI green. The Never list is in the
repo's `AGENTS.md`.

If ways-of-working and this skill disagree, ways-of-working wins. Say so in
the report.

## Mode

Fetch the issue first. Pick the mode the same way `implement-issue` does
(Phase 1b):

- **Root mode** — the issue has sub-issues. Everything below applies,
  except "Leaf checklist".
- **Leaf mode** — the issue has no sub-issues. Use "Leaf checklist"
  instead of "Per-sub-issue checklist" and the root table. "Ready",
  "Questions", "Evidence", "Report" and "Apply" still apply, read with
  "the issue" for "the root".

## Ready

Read `~/.claude/skills/implement-issue/SKILL.md` first. That file defines
how an issue is implemented (root mode: a fresh-context sub-agent per
sub-issue, one sub-PR into the root branch; leaf mode: one sub-agent, one
PR into the parent branch). Ready means: `implement-issue` can run from
Linear alone, and the issue (for a root, its plan) meets ways-of-working.

Also apply:

- A sub-issue is agent work or human work. Not both. Split a mixed
  sub-issue; do not give it the human lane to make it go away.
- A human sub-issue contains only steps a person must do. If an agent can
  perform a step, that step belongs in an agent sub-issue. That split is
  what makes blocker relations honest.
- One agent sub-issue produces one sub-PR into the root branch. That cap is
  hard.
- Human sub-issues are valid. Do not try to make them agent-implementable.
  Do check they are truly human-only, cohesive, and linked with blocker
  relations.
- A sub-issue blocked by work outside this root is valid to surface. Do not
  rewrite it into autonomy.
- Lane labels are the engineer's approval (ways-of-working `LINEAR.md`
  "Lanes"). The user runs this review before they set the label, to know
  that they can set it. A missing lane is the expected state: it is not a
  finding, not an action, not a blocker, and it does not make the verdict
  "not ready". When the issue is ready, say once which lane each issue can
  take. Report only a wrong lane (a label that is set and does not match
  the class) as an action for the engineer. Never plan to set one yourself.

## What implement-issue will load

Do not treat "the root" as its description alone. In leaf mode, load the
issue, its comments, its relations, its parent and the story above it (if
any) with its acceptance criteria, and cross-referenced siblings. In root
mode, load all of:

- the root description
- every sub-issue body under the root
- comments on the root and on each sub-issue
- `blockedBy` / `blocks` relations
- the parent story and its acceptance criteria
- sibling issues that bodies cross-reference, even outside this root

If a required fact lives only in a comment or a sibling, say so. If a
required fact lives only as "see <ISSUE-ID>", that is a must-fix. A reader who
has only that issue open must be able to act.

## Questions

Do not ask questions one by one while you review. Run the full review
first. Collect every question only the user can answer: preference,
policy, cost, naming, anything irreversible. End your chat reply with that
list (see Report).

Check each candidate question before you ask it:

- Ask it if only the user can answer it.
- Do not ask it if the codebase or the web already answers it. State the
  fact in the report instead.
- Do not ask it if it is a technical default. Put the default in the spec
  as an action.

## Evidence

You may use training data to form ideas. Do not write a conclusion until
you verify the fact. Verify each fact in the codebase or with web
research. The issue body can be stale; `main` cannot.

Find the repo the root names (the root's repo, paths in bodies). Read from
`origin/main` or a fresh worktree, never from the state of a primary
checkout.

Write files only under `/tmp`. Create a proof-of-concept only to settle a
specific doubt that blocks a finding. Do not keep the proof-of-concept as
a deliverable.

## Per-sub-issue checklist

| Check | Pass means |
|-------|------------|
| Class | Agent, human, or blocked-out-of-scope — and the class is correct |
| Lane | A lane label that is set matches the class (ways-of-working `LINEAR.md` "Lanes"). No label yet passes: name the lane the sub-issue can take, and do not set it |
| Mix | No agent-capable step sits inside a human sub-issue. No human-only step sits inside an agent sub-issue. Split instead of relabelling |
| Spec | Goal, steps and test plan are in this sub-issue body |
| Checks | Each completion check is verifiable without asking the user. Acceptance criteria themselves live on the story (ways-of-working `LINEAR.md` "Acceptance criteria") |
| Context | No required fact exists only as a cross-reference |
| Shape | One agent sub-issue → one sub-PR into the root branch; one human sub-issue → one cohesive human job |
| Blockers | If B cannot start until A lands on the root branch, A blocks B in Linear, not only in prose |

And for the root:

| Check | Pass means |
|-------|------------|
| Plan | The root description lists the sub-issues, their order and lanes, and matches the sub-issues in Linear |
| Size | Meets ways-of-working `LINEAR.md` "Sizing" |
| Parent | The root sits under a story; its PR target follows ways-of-working `BRANCHING.md` "The rule" |
| Tier | Paths that need an Ask-tier human (ways-of-working `BRANCHING.md` "Review tiers") are named in the plan |

## Leaf checklist

| Check | Pass means |
|-------|------------|
| Placement | A standalone issue belongs to no open story or root (ways-of-working `LINEAR.md` "What an agent creates"). A bug in open work is a sub-issue of that root instead |
| Class | Agent, human, or blocked-out-of-scope — and the class is correct |
| Lane | A lane label that is set on the issue matches the class (ways-of-working `LINEAR.md` "Lanes"). No label yet passes: name the lane the issue can take, and do not set it |
| Mix | Not a mix of agent-capable and human-only steps. Split into a root with sub-issues instead of relabelling |
| Spec | Goal, steps and test plan are in the issue body |
| Checks | Each completion check is verifiable without asking the user. With no story, these checks are the proof the PR must show |
| Context | No required fact exists only as a cross-reference |
| Shape | One repo, one PR into the parent branch (ways-of-working `BRANCHING.md` "The rule") |
| Size | Meets ways-of-working `LINEAR.md` "Sizing". Too big: plan it as a root with sub-issues |
| Blockers | Work it waits for is a blocker relation in Linear, not only prose |
| Tier | Paths that need an Ask-tier human (ways-of-working `BRANCHING.md` "Review tiers") are named in the body |

## Report

Write the review to `/tmp/<issue-id>-review.md`, with the issue ID in
lower case. That file is the review. The reader has not
seen the chat or the implementation. Put every fact needed to judge or
apply an action in that action's context.

```markdown
# <ISSUE-ID> <issue title> review

Issue: [<ISSUE-ID>](<url>). Story: [<ISSUE-ID>](<url>), or "none" for a standalone issue.

Checked on <YYYY-MM-DD>. `<owner/repo>` `main` is `<sha>`. <comment status>.

<Ready or not for `implement-issue`. If not ready, say not to start `implement-issue`.>

## Actions.

### <Imperative sentence>.

<The Linear change only. A few short sentences.>

## Context.

### <Same heading>.

<Current state, what is wrong, verified evidence, the exact text or values to write, and what to leave unchanged.>

## Questions.

1. <A question only the user can answer, with the options and their consequences in one or two sentences.>
```

- `## Actions.` is the skim list. One `###` per Linear change. Repeat that
  heading under `## Context.`, in the same order.
- An action body states the change. Evidence and the reason go in the
  matching context section.
- A context section is enough to apply that action. Repeat a short fact
  another action needs. For a long list, point at the context section that
  owns it and still state the decision.
- Turn checklist failures into these actions: root description, a missing
  sub-issue, a wrong lane, a blocker relation, a split.
- `## Questions.` holds every open question, numbered. An action that waits
  on a question says which one.
- Use short sentences in Actions. In Context, a bullet list is for parallel
  facts such as names, counts, or checks.

The actions, with the answers, have to leave the root in this state:

- A new, clean chat can run `implement-issue` from the issue, its
  sub-issues (if any), the comments, and the blocker relations alone.
- The implementer described in `implement-issue` can implement an agent
  sub-issue from that sub-issue alone.
- The user can do a human sub-issue from that sub-issue alone.

### STE100

This step is optional. Skip it when the `ste100-check` skill
(`~/.claude/skills/ste100-check/SKILL.md`) is not installed. When it is,
check the file with it before you build the Artifact.

- `text_type` `procedure` for `## Actions.`. `description` for the
  preamble, `## Context.` and `## Questions.`.
- Pass `glossaries`: every `*.yml` in `~/Code/asd-ste100-checker/glossary`,
  on one call. Follow that skill for the tool, the other arguments, and
  which findings to fix.
- Check a rewritten section again.

If the skill is installed but its tool is not available, say so in the
chat reply and continue. Do not skip the report.

### Artifact

Publish the review as an Artifact. Do not open it in Plannotator.

Follow the `visual-aid` skill (`~/.claude/skills/visual-aid/SKILL.md`)
with the review as the subject. That skill owns the look, the content
rules, the data rules and the publish step. Do not restate them here.

The `/tmp` file stays the source for the apply step. The page is how the
user reads the review, so it explains from zero and does not copy the file
one to one. The page has, in this order:

1. The verdict: ready or not for `implement-issue`, and what the user must
   do.
2. How the thing under review works, in plain steps, with the problem
   placed on it.
3. The evidence for each finding, as charts and numbers pulled now from
   the source of truth for live state (the project's monitoring, the repo
   on `origin/main`). A
   finding with no number behind it is stated as text, not charted.
4. What blocks `implement-issue`, one item per blocking action.
5. Every question from `## Questions.`, with its options, their
   consequences and the recommended option marked.
6. Next steps, numbered.

Leave out the exact replacement text for Linear. That text stays in the
`/tmp` file.

The chat reply is:

1. The Artifact link, the `/tmp` file path and the verdict sentence.
2. One line per section of the page, the data sources and time range, and
   each claim you dropped or corrected while checking.
3. The numbered questions from `## Questions.`, in full, so the user can
   answer them in the chat without opening the page.

When the user answers or asks for changes, update the `/tmp` file and
publish the page again to the same URL.

## Apply (only if asked)

If the user then says to apply, update, or fix Linear: execute the
report's Linear changes, with the user's answers to the questions written
into the issues they affect. Still do not implement product code. Still do
not run `implement-issue`.

Within ways-of-working's limits (`LINEAR.md` "What an agent creates"):

- You may write and revise the root description (the plan) and create
  sub-issues. New sub-issues are drafts.
- Never set a lane label. Tell the user which sub-issues are waiting for
  one; the label is their approval.
- Never change story, project or initiative states.
- Comments you post go out under the agent's identity.
