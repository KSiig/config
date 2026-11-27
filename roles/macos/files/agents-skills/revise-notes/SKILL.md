---
name: revise-notes
description: "Revise a research/plan document based on inline 'NOTE FROM USER:' annotations. Strikes through outdated conclusions and adds REVISED blocks. Triggers on: 'revise notes', 'process my notes', 'update the doc with my notes'."
disable-model-invocation: true
---

# Revise Notes

Process a document that contains inline `NOTE FROM USER:` annotations and update the document to reflect the user's corrections.

## Input

The user provides a path to a markdown file that contains `NOTE FROM USER:` lines interspersed with the original content.

## Rules

1. **Never delete original content.** Strike through outdated lines with `~~...~~` instead.
2. **Add a `REVISED:` block** after each corrected section that summarizes the new understanding based on the user's note.
3. **Preserve all `NOTE FROM USER:` lines** verbatim — they are the audit trail.
4. **Propagate corrections forward.** If a user note in section 1 invalidates conclusions in sections 2–4, strike through and revise those downstream sections too.
5. **Tables:** When a table has multiple corrected cells, strike through the whole table and write a new one labeled "REVISED table:".
6. **Open questions:** Remove questions that the user's notes already answered. Add new questions if the revised understanding surfaces them.
7. Keep revisions concise — one short paragraph per `REVISED:` block is usually enough.
