# Writing Task Briefs

How the orchestrator communicates work to workers.

## Inline vs file-based

Workers already have full conversation context from the forked conversation. This changes when you need a brief file:

**Inline instructions** (send via tmux directly):
- Single-purpose tasks with clear scope
- The worker already discussed or planned this work in the orchestrator's conversation
- Fits in a few sentences

**File-based briefs** (`tasks/worker-task-N.md`):
- Multi-step work with several acceptance criteria
- Tasks that reference specific files, patterns, or constraints worth listing
- Work where scope boundaries matter ("do X, don't touch Y")

## Brief structure

When you do write a file-based brief:

- **Goal**: what this slice accomplishes and how to verify it
- **Scope**: which files to create or modify
- **Out of scope**: what NOT to touch
- **Conventions**: any rules the worker should follow (quote directly — don't reference files the worker might not re-read)

You can skip the **Context** section — the worker already has it from the forked conversation.

## Principle

Briefs describe WHAT to achieve, not the exact output. If you're writing the exact code, either do it yourself or rewrite the brief as a goal.

## When to skip delegation entirely

If the work is < 10 lines and purely mechanical, do it yourself. But if a worker is idle, send small tasks its way — the overhead is near-zero.
