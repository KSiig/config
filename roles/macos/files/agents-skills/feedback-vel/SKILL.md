---
name: feedback-vel
description: Submit workflow feedback as a Linear issue in the Workflow Feedback project. Triggers on "feedback", "workflow feedback", "something could be better", "I have a suggestion", or any ask to file feedback about the Codex/AI workflow.
disable-model-invocation: false
---

# Workflow Feedback — submit to Linear

Collects feedback from the user and creates a tracked issue in the **Workflow Feedback** project.

## Step 1 — Categorise

Ask the user to pick a category using `AskUserQuestion`:

| Category | Label | When to use |
|---|---|---|
| Bug | `feedback:bug` | Something broken or producing wrong results |
| Improvement | `feedback:improvement` | Existing feature that could work better |
| Idea | `feedback:idea` | Net-new capability or workflow suggestion |
| Question | `feedback:question` | Unsure how something works or why it does X |

If the user already stated a clear category in their message, skip the question and use it.

## Step 2 — Collect the feedback

If the user already provided a description alongside `/feedback-vel`, use that. Otherwise ask them to describe the feedback in a single free-form message.

Don't over-structure this — one question is enough. The user should not feel like they're filling out a form.

## Step 3 — Draft the issue

Shape the feedback into a Linear issue:

- **Title:** short, imperative sentence (under 80 chars)
- **Description:** use this template:

```
## Feedback

<User's feedback, lightly cleaned up for clarity. Preserve their words.>

## Category

<Bug / Improvement / Idea / Question>

_Submitted via `/feedback-vel`_
```

## Step 4 — Create the issue

Show the draft to the user and ask for confirmation before creating.

Then create with:

```
save_issue(
  title: "<title>",
  team: "Velatir",
  description: "<description>",
  labels: ["<category-label>"],
  project: "Workflow Feedback",
  state: "Backlog"
)
```

Where `<category-label>` is one of: `feedback:bug`, `feedback:improvement`, `feedback:idea`, `feedback:question`.

**Important:** These labels must exist in Linear before use. If `save_issue` fails because a label doesn't exist, create the label first using `mcp__claude_ai_Linear__create_issue_label` with `team: "Velatir"`, then retry.

## Step 5 — Confirm

Report the issue URL back to the user. Done.

## Defaults

- **Team:** Velatir
- **Project:** Workflow Feedback (id: `d9ce6609-7ee9-40e5-8beb-dc6a69178128`)
- **State:** Backlog
- **Assignee:** not set (Kasper triages the backlog)
- **Priority:** not set
- **Cycle:** do NOT set
