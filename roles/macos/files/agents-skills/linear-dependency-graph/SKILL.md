---
name: linear-dependency-graph
description: >
  Generate a Linear-style, vertically-flowing dependency-graph SVG from a
  Linear project's milestones, issues, statuses and blocking relationships.
  Output embeds cleanly in a Linear project or issue description (narrow,
  downward, real Linear dark palette and status icons). Use when someone
  wants a visual "what can run in parallel / what is blocked by what" map of
  a project's issues.
---

# Linear dependency graph

Turns a project's milestones + issues + blocking edges into a single SVG that
looks native to Linear and embeds in a description column without being too
wide.

## What the output looks like

- **Rendered as 2x PNG.** The SVG is rasterized to PNG at 2x scale so it
  displays at full size in Linear project descriptions (Linear renders inline
  SVGs very small). The PNG is ~1352px wide, which fills the description
  column cleanly.
- **One box per milestone**, with the milestone name *inside* the box, a
  Linear diamond marker, issue count, percent (or a `COMPLETE` tag), and an
  optional `blocked by …` note for milestone-level dependencies.
- **Issues are chips arranged in rows.** Chips on the **same row can be worked
  on in parallel**. An **arrow** means the issue it points to is **blocked
  until the source finishes**.
- **Real Linear status icons** (dashed backlog, gray todo, gold in-progress,
  purple done check, etc.) in the exact sampled Linear dark palette.

See `example-output.svg` for the reference render and `example.json` for the
spec that produced it.

## How to use

1. **Gather the data** for the target Linear project (via the Linear MCP/API,
   or whatever the user pasted): every milestone, every issue with its title +
   status + milestone, and the blocking relationships between issues.
2. **Build a spec JSON** (schema below). This is the only real work — getting
   the rows and edges right.
3. **Render SVG, then rasterize to PNG:**
   ```bash
   python3 scripts/generate_dependency_graph.py spec.json out.svg
   cairosvg out.svg -o out.png --scale 2
   ```
   Always rasterize to PNG at 2x — Linear renders SVGs tiny in project
   descriptions. Use `cairosvg` (installed at `~/.local/bin/cairosvg`).
   Run with no arguments to regenerate the built-in example.
4. **Upload the PNG to Linear** and embed it in the **project description.**
   The full flow:
   ```
   a. Get the file size:  wc -c < out.png
   b. prepare_attachment_upload(anchor_issue, filename, "image/png", size,
        title="Dependency graph",
        subtitle="Project dependency graph — updated <date>")
      → returns assetUrl + uploadRequest (signed URL + headers)
   c. curl -X PUT --data-binary @out.png \
        -H "content-type: image/png" \
        -H "x-goog-content-length-range: <size>,<size>" \
        -H "cache-control: public, max-age=31536000" \
        -H 'Content-Disposition: attachment; filename="<filename>"' \
        '<uploadRequest.url>'
   d. create_attachment_from_upload(anchor_issue, assetUrl, title, subtitle)
   ```
   The signed URL expires in 60 seconds — run steps b–d without delay.
   Use the first milestone's anchor issue (e.g. VEL-634) for the attachment.
5. **Add the image to the project description.** Use `save_project` to append
   a `## Dependency graph` section at the bottom of the existing description
   with a markdown image referencing the assetUrl:
   ```markdown
   ## Dependency graph

   ![Dependency graph](<assetUrl from step 4b>)
   ```
   When updating an existing graph, replace the old image URL in the
   description and delete the old attachment.
6. **Clean up old attachments.** Delete previous dependency graph attachments
   from the anchor issue so they don't accumulate.

## Spec JSON schema

```jsonc
{
  "title": "Dependency graph",
  "subtitle": "Issues side by side can be worked on in parallel. …",  // optional, wraps to 2 lines

  "milestones": [                       // one box each, in display order
    {
      "id": "M0",
      "name": "M0 — Research & cluster", // shown inside the box
      "state": "complete",               // "complete" => COMPLETE tag + filled diamond; else omit
      "blocked_by": ["M0"],              // milestone-level deps, shown in the header (optional)
      "percent": 0,                      // shown unless state is complete
      "issue_count": 4,                  // optional; defaults to number of chips
      "note": "Hard gate. …",            // optional caption centered under the rows
      "rows": [                          // EACH ROW = issues that can run in parallel
        ["VEL-634", "VEL-637"],          // row 0
        ["VEL-640"]                      // row 1 (must wait on row 0, per edges)
      ]
    }
  ],

  "issues": {                            // every id referenced in rows
    "VEL-634": { "title": "Kapsule cluster", "status": "done" },
    "VEL-683": { "title": "Evaluate vllm-mlx", "status": "backlog",
                 "optional": true, "tag": "if needed" }   // dashed chip + small tag
  },

  "edges": [                             // arrows: [from, to] or [from, to, opts]
    ["VEL-633", "VEL-640"],              // intra-milestone block
    ["VEL-682", "VEL-683", { "dashed": true }],            // conditional / soft link
    ["VEL-684", "VEL-630", { "cross": true }]              // crosses milestone boxes (lighter line)
  ]
}
```

### `status` values (mapped to Linear icons)

`done` · `in_review` · `in_progress` (`started`) · `todo` (`unstarted`) ·
`ready_for_refinement` (`refine`) · `backlog` · `blocked` · `canceled` ·
`duplicate`. Unknown values fall back to the backlog (dashed) icon.

## Rules for building a good spec

These decisions are the point of the skill — follow them.

1. **Keep chip titles short.** Abbreviate the Linear title to 2–4 words
   ("Install and configure Ollama on Mac Mini" → "Install Ollama"). The full
   id (e.g. `VEL-682`) is always shown, so the title is just a reminder.
2. **Assign rows by dependency depth *within the milestone*.** An issue with no
   blocking predecessor in its milestone goes in row 0. An issue goes one row
   below the lowest row of any issue that blocks it. Issues that end up on the
   same row are genuinely parallel — that is the main thing the reader wants.
3. **Draw intra-milestone edges always.** They carry the parallel-vs-sequential
   story inside a box.
4. **Prefer `blocked_by` headers for milestone-to-milestone dependencies**, and
   only *draw* cross-milestone edges that are short and clean (e.g. the last
   issue of one box into the first issue of the next). Tag those with
   `{"cross": true}`. This keeps the graph from turning into spaghetti. If a
   convergence issue is blocked by several things in earlier boxes, draw the
   1–2 clean ones and mention the rest in a `note`.
5. **Order milestones top to bottom** the way the work unlocks (the gate / done
   milestone first). The graph reads as a flow.
6. **Don't invent data.** Only show issues, statuses and links that exist in the
   project. If a dependency is conditional ("if concurrency is insufficient"),
   mark the issue `optional` with a short `tag` and use a `dashed` edge.

## Files

- `scripts/generate_dependency_graph.py` — the renderer. No dependencies beyond
  the Python standard library. All palette/layout constants live at the top and
  are sampled from the real Linear dark UI; do not change colours casually.
- `example.json` — a complete worked spec.
- `example-output.svg` — what that spec renders to.
