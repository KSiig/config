# Pattern — Create a new issue

## Description shape (mandatory for new issues)

Trim source material into this exact section order. Do NOT dump full chat-notes / open-item documents — they are working notes; the issue is the spec.

```
## Summary

One paragraph: what is being proposed and why. Should stand alone.

## Context (verified)

Bullets, each citing file/line where possible. Only things verified against the
code or the user. If something is asserted but unverified, put it under
"Context (stated, not yet verified)" instead — keep the trust signal honest.

## Problem

What goes wrong today, or what risk/cost we're carrying. Concrete.

## Proposal

Numbered steps or phased plan. Each step actionable.

## Open questions

Bullets. Things to decide / verify before / during execution.

_Source: <relative-path-to-source-file> §<section>_   (if migrated from a file)
```

Sections to drop when trimming from longer source docs: "Trade-offs / things to think through", "Why it suits a first-month project", any motivational framing. They belong in the source notes, not the tracked issue.

## Pattern A — Help define a new task from a description

Triggered by *"Help me define a new task: <description>"*. The user gives raw intent; help shape it.

1. **Clarify in one pass** if anything material is missing. Specifically: scope (single PR vs multi-phase), labels other than Infrastructure, whether this overlaps with an existing issue. Don't over-ask — one round of `AskUserQuestion` is enough.
2. **Draft the description** following the shape above. Verify any claim that has a "file/line" feel by actually grepping the codebase before writing it under "Context (verified)". Move guessed facts into "stated, not yet verified".
3. **Show the issue before creating it.** Creating an issue is visible to the team — confirm first unless the user already said "just create it". Display the title, description, label set, and state.
4. **Create the issue:**

   ```
   save_issue(
     title: "<title>",
     team: "Velatir",
     description: "<description>",
     labels: ["Infrastructure"],
     state: "Backlog"
   )
   ```

5. **Record the mapping** back wherever the task was sourced. If it came from a chat-note, append `**Linear:** [VEL-XXX](url)` near the top of that section so we don't double-create. If from a `docs/90-open-items/` file, add the same line at the top of that doc.

## Pattern B — Fetch task description from a file and create it

Triggered by *"Please fetch the task description from <file> and create it in Linear"*.

1. **Read the file** (or the specific section if the path is `path.md#section` or the file is large). If it's an entry in a numbered list (like `first-month-ideas.md §N`), read just that section.
2. **Check for an existing Linear link.** If the source already has a `**Linear:**` line pointing at an open issue, do NOT re-create — switch to the update pattern and tell the user. If the existing issue is closed/canceled, ask whether to re-open vs create new.
3. **Trim into the description shape.** Hard-drop trade-offs / "why it suits a first-month project" / motivational framing. Preserve verified facts with their file/line citations. Convert links to relative paths.
4. **Append a source reference** at the bottom: `_Source: <relative-path> §<section>_`. So a reader of the issue can find the working notes.
5. **Show before creating, then create** (Pattern A steps 3–4).
6. **Record the mapping back** in the source file as in Pattern A step 5.
