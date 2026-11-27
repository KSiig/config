# Linear structure

What you may create, how a root becomes sub-issues, and the Done bar at each level.
Vocabulary and the ownership rule are in [SKILL.md](SKILL.md).

All Linear operations go through the claude.ai Linear connector (`save_issue`, `get_issue`,
`list_issues`, `save_comment`). Use the workspace and team the repo names. Without one, the default workspace is `siig`; ask which team if it is unclear.
Handed an `<ISSUE-ID>`? Re-read the issue and work from it, not from the chat summary. If the
repo has a `linear` skill, it holds the tool map, the defaults and the per-operation patterns.

## What an agent creates

| Item | You may | Owner |
|---|---|---|
| User story, in a project or standalone | Create it, for the human who ran you | The human who ran you |
| Root under a user story | Create it, for the human who ran you | That human |
| Sub-issue under a root | Create it, from a plan its owner approved | The root's owner |
| Standalone issue: a bug or the like, with no parent | Create it | The human who ran you |
| Root description (the plan) | Write and revise it | The root's owner |
| Spike research, option comparison | Write it as a comment | The spike's owner |
| Acceptance criteria on a user story | Write them on the story | The story's owner |
| Everything else | Propose in a comment | Its owner |

Agents work on issues, never at project level. A human creates projects, milestones and
initiatives.

Standalone work (a bug, or a similar small fix that belongs to no open story or root) is filed as
a parentless issue and lands on `main`. A bug in work still open is not standalone. It becomes a
sub-issue of that root, or a comment for its owner.

Any other issue you create sits directly under a user story as a root, or under a root as a
sub-issue. Never hang an issue on a story except as its root.

A story is never its own root, even when only one repo is touched. Before work starts, create one
root per repo under the story, and plan, branch and open the PR from that root.

Every Linear comment and issue you write posts under the agent's own identity, never a person's.

## Planning a root

The loop as it normally runs:

1. The owner creates the root, or has you create it under the story, and asks you to plan it.
2. You write the plan into the **root's description**: sub-issues, order, a suggested lane per
   sub-issue. The description is the current plan. Comments are for discussion.
3. The owner edits it in place, rejects it, or accepts it.
4. You may create the sub-issues as you plan. Until labelled they are **drafts**.
5. The owner sets one lane label per accepted sub-issue. **The label is the approval.**

The gate is the lane label, not the moment of creation. Wait for the label before you implement a
sub-issue, even one you wrote yourself. Drafts still unlabelled when the root closes are Canceled.

Create sub-issues only when the root needs more than one pass. A root done in one pass has none.

## Lanes

A ready sub-issue, a root done in one pass, or a standalone issue carries exactly one label:

- `ready-for-agent`: an agent picks it up and opens a PR into its parent branch.
- `ready-for-human`: a person picks it up and may commit directly to the root branch.

Linear is the queue and the one context for agent and human alike. Filter `ready-for-agent` to
find work.

## States

One state machine, read three ways.

| State | Story | Root | Sub-issue |
|---|---|---|---|
| Todo | Criteria written, roots created | Created by its owner | Lane label set |
| In Progress | First root In Progress | Worktree exists | Picked up by its lane |
| In Review | n/a | PR open | Sub-PR open |
| Blocked | n/a | Waiting on something outside the assignee, reason in a comment | Same |
| Done | All roots Done, criteria verified | PR merged into its parent branch | Its change is on the root branch |

Move sub-issues, roots and standalone issues. Leave story, project and initiative states to their
owners.

## Done bars

| Level | Done means |
|---|---|
| Sub-issue | Its change is on the root branch, by commit or merged sub-PR |
| Spike | A decision comment: what we learned, what we do, follow-up issues created or explicitly none |
| Root | Merged into its parent branch, testable there or behind a flag |
| Standalone issue | Merged into `main` |
| Story | All roots Done, criteria verified on the integrated parent branch |
| Project | On `main`, released, docs and release notes written |

## Acceptance criteria

On the story, never on a root or a sub-issue. Each one is user-observable (what the user can do,
see, or expect) and independently verifiable. Whoever creates the story writes them. A story in a
project narrows the project's criteria to this story rather than restating or contradicting them.

A story with an unknown is not Todo. The unknown becomes a spike.

A standalone issue has no story. Its own completion checks are the proof its PR must show.

## Spikes

One decision, timeboxed, with the box in the title: `[spike 2d] ...`. A spike is a sub-issue of
the story, beside the roots, not under one. Its branch forks from `main` and its PR may close
unmerged. Done is the decision comment. Research and option comparison are yours to write; the
decision is the owner's.

## Sizing

Split a root when either holds:

- One reviewer cannot hold the diff and the acceptance criteria in their head in one sitting.
- It cannot land on its parent branch without waiting for another root.

Target under three days with the branch open; past a week, split. Effort is not a criterion: AI
makes building cheap, not review. Splitting a root sizes the PR, not the feature, so split roots
without asking. Only the project's owner changes what a project contains.
