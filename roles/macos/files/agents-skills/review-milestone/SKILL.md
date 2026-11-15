---
name: review-milestone
description: >
  Review a Linear milestone for coordinate-implementation readiness. Reads
  the milestone, every issue body, comments, blocker relations, and
  cross-referenced siblings; verifies each claim against the repo and the
  web; reports every Linear change required before refine-linear-questions
  and coordinate-implementation. Writes that report to /tmp as actions
  then context, checks it with STE100, and opens it in Plannotator. Does
  not implement product work. Use when the user asks to review a
  milestone, prepare a milestone for coordinate-implementation, check if
  a milestone is ready, or runs /review-milestone.
triggers:
  - review milestone
  - prepare milestone
  - milestone ready
  - coordinate-implementation ready
  - review linear milestone
---

# Review milestone — coordinate-implementation readiness

Review a Linear milestone and report every change Linear needs before
`refine-linear-questions` and `coordinate-implementation`. Default: report
only. Do not edit Linear, do not implement the product, unless the user
explicitly asks to apply the report.

Typical order: this skill → Linear edits (user or a follow-up “apply”) →
`refine-linear-questions` → `coordinate-implementation`.

## Invocation

```
/review-milestone <linear-milestone URL>
```

Accept the same URL forms as `coordinate-implementation`:

- `https://linear.app/<workspace>/project/<slug>-<id>/overview#milestone-<uuid>`
- `https://linear.app/<workspace>/milestone/<uuid>`

If no URL is given, ask. Do not pick a milestone from history.

Resolve Linear MCP the same way `coordinate-implementation` does
(`linear.app/velatir` → Velatir MCP; any other workspace, e.g. `siig` →
`linear-personal`).

## Ready

Read `~/.pi/agent/skills/coordinate-implementation/SKILL.md` first. That
file is the definition of ready, including who implements an agentic issue
(fresh-context sub-agent, thinking off, one issue, one PR). Do not invent a
second definition of that model in this skill or in the report.

Also apply:

- An issue is agent work or human work. Not both. Split mixed issues; do
  not relabel a mixed issue as `human`.
- A human issue contains only steps a person must do. If an agent can
  perform a step, that step belongs in an agentic issue. That split is
  what makes blocker relations honest.
- Every issue must have exactly one of the Linear labels `agentic` or
  `human`.
- One agentic issue produces one pull request. That cap is hard.
- Human issues are valid. Do not try to make them agent-implementable. Do
  check they are truly human-only, cohesive, labelled `human`, and linked
  with blocker relations.
- Blocked-by-other-milestone issues are valid to surface. Do not rewrite
  them into autonomy.

## What the orchestrator will load

Do not treat “the milestone” as the description alone. Load all of:

- the milestone description
- every issue body in the milestone
- comments on those issues
- `blockedBy` / `blocks` relations
- unassigned siblings that bodies cross-reference, even if those siblings
  are not on the milestone

If a required fact lives only in a comment or a sibling, say so. If a
required fact lives only as “see SII-xx” (or any other issue id), that is
a must-fix. A reader who has only that issue open must be able to act.

## Open-ended questions

Most issues have an `## Open-ended questions / decisions` section. That
section is for questions only the user can answer (preference, policy,
cost, naming, anything irreversible).

`refine-linear-questions` (`~/.pi/agent/skills/refine-linear-questions/SKILL.md`)
runs after this review and locks answers, then deletes those sections.
Leftover open questions are expected. They are not defects.

Do check each question:

- Keep it if only the user can answer it.
- Flag it if the codebase already answers it (a fact parked as a fake
  human blocker).
- Flag it if it is a technical default that should live in the spec, not
  in that section.

## Evidence

You may use training data to form ideas. Do not write a conclusion until
you verify the fact. Verify each fact in the codebase or with web
research. The issue body can be stale; `main` cannot.

Find the repo the issues name (project GitHub URL, paths in bodies). Do
not assume `velatir-coordination`.

Write files only under `/tmp`. Create a proof-of-concept only to settle a
specific doubt that blocks a finding. Do not keep the proof-of-concept as
a deliverable.

## Per-issue checklist

| Check | Pass means |
|-------|------------|
| Class | Agentic, human, or blocked-out-of-scope — and the class is correct |
| Label | `agentic` or `human`, and it matches the class |
| Mix | No agent-capable step sits inside a human issue. No human-only step sits inside an agentic issue. Split instead of relabelling. |
| Spec | Goal, steps, acceptance, and test plan are in this issue body |
| Acceptance | Each criterion is checkable without asking the user |
| Decisions | Preference items live under `## Open-ended questions / decisions`; facts are not parked there |
| Context | No required fact exists only as a cross-reference |
| Shape | One agentic issue → one pull request; one human issue → one cohesive human job |
| Blockers | If B cannot start until A lands, A blocks B in Linear, not only in prose |

## Report

Write the review to `/tmp/<milestone-slug>-review.md`. That file is the
review. The reader has not seen the chat or the implementation. Put every
fact needed to judge or apply an action in that action's context.

```markdown
# <milestone> review

Milestone: [<name>](<url>).

Checked on <YYYY-MM-DD>. `<owner/repo>` `main` is `<sha>`. <comment status>.

<Ready or not for `refine-linear-questions`. If not ready, say not to start `coordinate-implementation`.>

## Actions.

### <Imperative sentence>.

<The Linear change only. A few short sentences.>

## Context.

### <Same heading>.

<Current state, what is wrong, verified evidence, the exact text or values to write, and what to leave unchanged.>
```

- `## Actions.` is the skim list. One `###` per Linear change. Repeat that heading under `## Context.`, in the same order.
- An action body states the change. Evidence and the reason go in the matching context section.
- A context section is enough to apply that action. Repeat a short fact another action needs. For a long list, point at the context section that owns it and still state the decision.
- Turn checklist failures into these actions. Milestone text, a missing issue, a label, a blocker relation, and an open question belong to an action. After the last context section, state whether any open question remains and whether `refine-linear-questions` still has work.
- Use short sentences in Actions. In Context, a bullet list is for parallel facts such as names, counts, or checks.

The actions have to leave the milestone in this state:

- A new session can coordinate from the milestone, the issues, the comments, and the blocker relations.
- The implementer described in `coordinate-implementation` can implement an agentic issue from that issue alone.
- The user can do a human issue from that issue alone.

### STE100

Check the file with `~/.claude/skills/ste100-check/SKILL.md` before you open it.

- `text_type` `procedure` for `## Actions.`. `description` for the preamble and `## Context.`.
- Pass `glossaries`: every `*.yml` in `~/Code/asd-ste100-checker/glossary`, on one call. Follow that skill for the tool, the other arguments, and which findings to fix.
- Check a rewritten section again.

### Plannotator

Run `plannotator annotate /tmp/<milestone-slug>-review.md`. Read the localhost URL and the share URL from the first output, then send the chat reply. The reply is the file path, the verdict sentence, and those URLs. Leave the command running. When it exits, follow `~/.agents/skills/plannotator-annotate/SKILL.md`.

## Apply (only if asked)

If the user then says to apply, update, or fix Linear: execute the
report’s Linear changes. Still do not implement product code. Still do
not run `coordinate-implementation`. Leave real preference questions in
place for `refine-linear-questions`.
