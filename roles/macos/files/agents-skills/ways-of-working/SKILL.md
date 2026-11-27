---
name: ways-of-working
description: How delivery work is structured by default: the Linear hierarchy (optional project, user story, root, sub-issue, standalone issue), what an agent may create, branch and PR structure (optional project/<slug>, root branches, sub-PRs into the root), PR format, merge methods, review tiers, backward compatibility and feature flags. Use before creating or updating a Linear issue, planning a root, naming a branch, choosing a PR base, opening or merging a PR, deciding on a feature flag, or making a breaking change. A repo's own *-ways-of-working skill overrides this one.
---

# Ways of working

## Override

A repo's own `*-ways-of-working` skill overrides this one. If the repo you work in has one, load
it and stop reading here. This file is the default for repos without one.

This file holds the structure of the work. A repo's own skills and rules hold its code
conventions.

## Reach for the right page

| You are about to | Read |
|---|---|
| Create or update a Linear issue, plan a root into sub-issues, set a lane label | [LINEAR.md](LINEAR.md) |
| Name a branch, pick a PR base, open or merge a PR, hotfix | [BRANCHING.md](BRANCHING.md) |

## The levels

| Level | Answers | Created by | Git artifact |
|---|---|---|---|
| Project (optional) | One deliverable a user can use, and what it excludes | A human | `project/<slug>`, if the project wants one |
| User story | What the end user can do, see, or expect | The human owner, or an agent they run | none |
| Root | One person's scope for the story in one repo | The human owner, or an agent they run | `<author>/<issue-id>-<slug>` |
| Sub-issue | One task, picked up by a human or an agent | The root's owner, normally by having an agent plan the root | a commit on the root branch, or a short sub-branch |
| Standalone issue | A bug, or a small change to something already shipped | The human owner, or an agent they run | `<author>/<issue-id>-<slug>` from `main` |

Standalone work needs no project and no story. It goes straight to `main`.

A **spike** is one timeboxed decision, a sub-issue of the story beside its roots.

A repo-specific skill may add cross-team contracts between roots in different repos. This file
has none.

## The ownership rule

Every item in Linear has one named human owner, whatever tool wrote it.

- Agents create issues only: user stories, roots under a story, sub-issues under a root (from a
  plan the root's owner approved), and standalone issues. Never a project, milestone or
  initiative. A story you create carries its acceptance criteria.
- Lane labels belong to the human owner. Never set one.
- A story is never a root. A story has one root per repo it touches.
- Propose anything you may not create **in a comment** on the item, for its owner to act on.
- Whatever you write belongs to the human who ran you, in Linear and in code.

## Where the work lands

One root, one repo, one branch, one PR, into its parent. The parent is the project branch for a
root inside a project that has one, and `main` for everything else. Sub-issue work lands on the
root branch. As an agent, default to a short sub-branch with a PR into the root, so it is
reviewed in small pieces while it is fresh. Three levels at most: project, root, sub-issue.

[BRANCHING.md](BRANCHING.md) has the naming, the PR format, the merge method per level, and the
review tiers.

## Backward compatibility

Build every schema, API and behaviour change backward compatible by default: additive fields,
optional new inputs, old paths kept working until their consumers have moved.

When a change cannot be made compatible, stop before you build it. Tell the human who ran you
what breaks and who consumes it, and wait for their confirmation. A confirmed break carries `!`
in its PR title ([BRANCHING.md](BRANCHING.md) "PR shape").

## Feature flags

Unfinished work that reaches `main` goes behind a feature flag. That includes project work that
lands ahead of its project, and any project released dark. Standalone work (a bug fix, a hotfix,
a one-off change) ships unflagged unless the owner asks for a flag.
