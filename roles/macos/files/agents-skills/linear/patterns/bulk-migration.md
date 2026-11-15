# Pattern — Bulk migration

When asked to migrate many items at once (e.g. *"upload all the other ideas"*):

- Iterate through each item and call `save_issue` for each one. Print `#N -> VEL-XXX  state=Backlog labels=[Infrastructure]` per row using the response data.
- After all creates, write the `**Linear:** [VEL-XXX](url)` links back into the source file so we don't double-create.
- For very long source documents, read the file in chunks (`offset` + `limit` on Read).
