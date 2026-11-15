Long sessions lose context silently. Flush early and often using `/flush` to checkpoint accumulated knowledge before it gets compacted away.

- After completing each major milestone (finishing a subtask, getting tests passing, completing a research phase), run `/flush`.
- As a fallback, flush roughly every ~30 tool calls even if no clear milestone was reached.
- If the conversation is getting long or you're working through a multi-step plan, flush at each phase boundary rather than waiting until the end.
- After flushing, continue working — `/flush` is a checkpoint, not a stop signal.
