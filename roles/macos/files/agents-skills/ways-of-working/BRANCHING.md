# Branching and PRs

Where a branch forks from, what its PR targets, and how it merges. There is no `develop` branch.
Optional project branches collect a project's roots before they reach `main`.

## The rule

**One root, one repo, one branch, one PR, into its parent.** The parent is the project branch for
a root inside a project that has one, and `main` for everything else. A root PR targets its
parent, never another root branch. Never stack a PR on another open PR. Three levels at most:
project, root, sub-issue.

| Level | Branch | Forks from | Merges into | Method | Lifetime |
|---|---|---|---|---|---|
| Project (optional) | `project/<slug>` | `main` | `main`, once, when released | merge commit | until released, then deleted |
| Root in a project | `<author>/<issue-id>-<slug>` | the project branch | the project branch | squash | days |
| Standalone root or issue, spike, hotfix | `<author>/<issue-id>-<slug>` | `main` | `main` | squash | days |
| Sub-issue | a commit on the root branch, or `<author>/<issue-id>-<slug>` | the root tip | the root branch | squash | hours to a day |

User stories get no branch.

## Sub-issue work

A sub-issue lands on its root branch in one of two ways: a direct commit, or a short sub-branch
with a PR into the root. **Agent work defaults to the PR**: small pieces, reviewed while they are
fresh. Sub-branches fork from the root tip, squash back, and are deleted.

Open the root PR once its sub-PRs have merged and the root is complete. The root PR is the human
read of the whole. Sub-PRs are the machine gate: CI green and the repo's review gate, no human
required, except on Ask-tier paths.

## Naming

Use the branch name Linear generates: `<author>/<issue-id>-<slug>`. The identifier gives the
autolink, and the worktree slug matches the branch slug. Spikes and hotfixes use the same format;
the label and the parent branch say what they are. Exactly one issue identifier per branch: the
root's on a root branch, the sub-issue's on a sub-branch.

`project/<slug>` matches the Linear project slug. Bot branches (release tooling, Dependabot) are
exempt.

## PR shape

Title in conventional-commit form with the identifier in parentheses:

```
feat(audit): list events (<ISSUE-ID>)
```

Squash makes the title the commit. If the repo uses release tooling such as release-please, the
title drives the version: `fix` bumps patch, `feat` bumps minor, and `!` after the type (`feat!:`)
marks a breaking change and bumps major. A break needs the owner's confirmation before it is
built (backward compatibility in [SKILL.md](SKILL.md)).

Body opens with the Linear reference, and the project name on the next line if there is one:

```
Linear: <ISSUE-ID>
<Project name>
```

Carry proof that matches the story's acceptance criteria, or the standalone issue's completion
checks: tests for logic, a screenshot or recording for UI, a query or log excerpt for data
changes. Run the repo's test and lint commands before you open the PR.

Delete the branch on merge. Update from the parent daily. Target under three days open; past a
week, split the root.

## Review tiers

| Tier | Applies to | Merges when |
|---|---|---|
| Ship | Docs, config, test-only changes | CI green |
| Show | Everything else | CI green and the review gate the repo's PR-review skill names (default: CI green alone). A human reads it after merge; revert is the remedy |
| Ask | Auth, billing, data deletion, migrations, cross-repo contracts, the project merge, the release PR | A human approves. The AI that wrote it does not count |

The reviewer reads the plan the agent worked from, not only the diff.

## Project branch

Optional. Use one when a project should collect its roots before it reaches `main`. Create it from
`main` in each repo the project touches. It merges into `main` when released, with a **merge
commit**, never squashed: a squash collapses the project into one commit, hides a `feat!` inside
it from release tooling, and erases the root PRs from `main`'s history.

Keep it current by merging `main` into it, daily and after every hotfix. Resolve conflicts in a PR
a human approves, never unattended.

Leave release-tooling files (such as `CHANGELOG.md` and a release manifest) alone on a project
branch. The tooling owns them on `main`, and an edit conflicts on every back-merge.

## Hotfix

1. Branch from `main`, `fix(...)` title, squash into `main`.
2. Release it the way the repo releases.
3. Merge `main` into every open project branch the same day.

Broken `main`: revert first, fix forward second. Anyone may revert.

## Before the first commit

- The Linear issue exists, is In Progress, and has an assignee.
- The work is on a worktree of its parent branch, never a primary checkout and never `main`.
- `git branch --show-current` shows the branch you meant.
