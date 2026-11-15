#!/usr/bin/env python3
"""
generate_dependency_graph.py

Render a Linear-style, vertically-flowing dependency-graph SVG from a JSON
spec describing a project's milestones, issues, statuses and blocking edges.

Design goals (do not change without reason):
  - Responsive (width="100%") so it scales to its container (Linear, docs, etc.).
  - Flows downward. Each milestone is a labelled box; its name lives inside it.
  - Issues laid out in ROWS: issues on the same row can be worked on in
    parallel; an arrow means the target is blocked until the source finishes.
  - Linear's real dark palette + Linear status icons, for visual cohesion.

Usage:
    python generate_dependency_graph.py spec.json out.svg
    python generate_dependency_graph.py            # writes the built-in example

The JSON schema is documented in SKILL.md. A complete worked example lives in
EXAMPLE at the bottom of this file.
"""

import json
import sys
import math

# --------------------------------------------------------------------------
# Palette  (sampled directly from the Linear dark UI — keep these exact)
# --------------------------------------------------------------------------
BG          = "#0f0f10"   # page background
BAND_FILL   = "#141416"   # milestone container
BAND_STROKE = "#262629"
CHIP_FILL   = "#1a1a1c"
CHIP_STROKE = "#262629"
CHIP_DONE_FILL   = "#161620"
CHIP_DONE_STROKE = "#2a2a3a"
CHIP_OPT_STROKE  = "#34343a"
FG       = "#e7e7e9"   # primary text
FG_2     = "#b9babe"
FG_MUT   = "#8a8f98"   # secondary text / ids
FG_DIM   = "#62656c"   # tertiary / captions
LINE       = "#3a3a40"   # intra-milestone arrows
LINE_CROSS = "#4a4a52"   # cross-milestone arrows
# status colours
C_DONE    = "#5e6bd3"   # Linear indigo
C_GOLD    = "#f1bf00"   # in progress
C_ORANGE  = "#f2994a"   # blocked
C_GREEN   = "#28a645"   # in review
C_GRAY_IC = "#8a8d94"   # todo / unstarted / refining outline
C_BACKLOG = "#6c6f78"   # backlog dashed
C_CANCEL  = "#95a3b3"   # cancelled / duplicate

# --------------------------------------------------------------------------
# Layout constants
# --------------------------------------------------------------------------
W        = 676
OUTER    = 18           # horizontal page margin
BAND_W   = W - 2 * OUTER
CW       = 178          # chip width
CH       = 46           # chip height
GAP_X    = 14           # gap between chips in a row
ROW_GAP  = 26           # vertical gap between chip rows (room for arrows)
HEAD_TOP = 13           # band padding above header
HEAD_H   = 18           # band header height
HEAD_GAP = 13           # gap header -> first chip row
BOT_PAD  = 16           # band padding below content
NOTE_GAP = 11
NOTE_H   = 14
BAND_GAP = 14           # gap between milestone bands
TITLE_BLOCK_H = 66      # top title + subtitle area
LEGEND_H = 46


# --------------------------------------------------------------------------
# Small helpers
# --------------------------------------------------------------------------
def esc(s):
    return (str(s).replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;").replace('"', "&quot;"))


def approx_w(s, size, bold=False):
    """Rough Inter advance width — good enough to place inline labels."""
    f = 0.56 if bold else 0.53
    return len(str(s)) * size * f


def wrap(text, max_chars):
    words, lines, cur = str(text).split(), [], ""
    for w in words:
        if len(cur) + len(w) + 1 <= max_chars:
            cur = (cur + " " + w).strip()
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


# --------------------------------------------------------------------------
# Status icons — 14x14, drawn at the given top-left (x, y)
# Mirrors Linear's status set: backlog / unstarted / started / done / etc.
# --------------------------------------------------------------------------
def status_icon(status, x, y):
    g = f'<g transform="translate({x:.1f},{y:.1f})">'
    s = (status or "backlog").lower()
    if s in ("done", "completed", "complete"):
        body = (f'<circle cx="7" cy="7" r="6" fill="{C_DONE}"/>'
                f'<path d="M4.2 7.1 L6.1 9 L9.8 4.9" fill="none" stroke="#fff" '
                f'stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>')
    elif s in ("backlog",):
        body = (f'<circle cx="7" cy="7" r="5.2" fill="none" stroke="{C_BACKLOG}" '
                f'stroke-width="1.6" stroke-dasharray="1.5 1.7" stroke-linecap="round"/>')
    elif s in ("todo", "unstarted", "refine", "ready", "ready_for_refinement"):
        body = (f'<circle cx="7" cy="7" r="5.2" fill="none" stroke="{C_GRAY_IC}" '
                f'stroke-width="1.6"/>')
    elif s in ("in_progress", "started", "inprogress"):
        body = (f'<circle cx="7" cy="7" r="5.2" fill="none" stroke="{C_GOLD}" stroke-width="1.6"/>'
                f'<path d="M7 7 L7 2.4 A4.6 4.6 0 0 1 11.6 7 Z" fill="{C_GOLD}"/>')
    elif s in ("blocked",):
        body = (f'<circle cx="7" cy="7" r="5.2" fill="none" stroke="{C_ORANGE}" stroke-width="1.6"/>'
                f'<path d="M7 7 L7 2.4 A4.6 4.6 0 1 1 2.7 8.6 Z" fill="{C_ORANGE}"/>')
    elif s in ("in_review", "review", "inreview"):
        body = (f'<circle cx="7" cy="7" r="6" fill="{C_GREEN}"/>'
                f'<path d="M4.2 7.1 L6.1 9 L9.8 4.9" fill="none" stroke="#fff" '
                f'stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>')
    elif s in ("canceled", "cancelled", "duplicate"):
        body = (f'<circle cx="7" cy="7" r="6" fill="{C_CANCEL}"/>'
                f'<path d="M4.8 4.8 L9.2 9.2 M9.2 4.8 L4.8 9.2" stroke="{BG}" '
                f'stroke-width="1.4" stroke-linecap="round"/>')
    else:
        body = (f'<circle cx="7" cy="7" r="5.2" fill="none" stroke="{C_BACKLOG}" '
                f'stroke-width="1.6" stroke-dasharray="1.5 1.7"/>')
    return g + body + "</g>"


def diamond(cx, cy, filled):
    r = 6.5
    pts = f"{cx} {cy-r} L{cx+r} {cy} L{cx} {cy+r} L{cx-r} {cy} Z"
    if filled:
        return f'<path d="M{pts}" fill="{C_DONE}"/>'
    return f'<path d="M{pts}" fill="none" stroke="{FG_MUT}" stroke-width="1.3"/>'


# --------------------------------------------------------------------------
# Main renderer
# --------------------------------------------------------------------------
def render(spec):
    issues = spec["issues"]
    parts = []
    geom = {}          # issue id -> {cx, top, bottom}

    # ---- measure total height ----
    def band_height(m):
        nrows = len(m["rows"])
        h = HEAD_TOP + HEAD_H + HEAD_GAP
        h += nrows * CH + (nrows - 1) * ROW_GAP
        if m.get("note"):
            h += NOTE_GAP + NOTE_H * len(wrap(m["note"], 92))
        h += BOT_PAD
        return h

    total = TITLE_BLOCK_H
    band_tops = []
    for m in spec["milestones"]:
        band_tops.append(total)
        total += band_height(m) + BAND_GAP
    total += LEGEND_H

    # ---- title block ----
    title = esc(spec.get("title", "Dependency graph"))
    parts.append(f'<text x="{OUTER}" y="24" font-size="15" font-weight="600" '
                 f'fill="{FG}" letter-spacing="-0.01em">{title}</text>')
    sub = spec.get("subtitle",
                   "Issues side by side can be worked on in parallel. An arrow means "
                   "the issue it points to is blocked until the source finishes. "
                   "Each box is a project milestone.")
    sy = 44
    for ln in wrap(sub, 84)[:2]:
        parts.append(f'<text x="{OUTER}" y="{sy}" font-size="12" fill="{FG_MUT}">'
                     f'{esc(ln)}</text>')
        sy += 16

    # ---- bands ----
    for m, top in zip(spec["milestones"], band_tops):
        bh = band_height(m)
        complete = m.get("state") == "complete"
        # container
        parts.append(f'<rect x="{OUTER}" y="{top:.1f}" width="{BAND_W}" height="{bh:.1f}" '
                     f'rx="8" fill="{BAND_FILL}" stroke="{BAND_STROKE}" stroke-width="1"/>')
        # header
        hy = top + HEAD_TOP + HEAD_H / 2
        dx = OUTER + 14
        parts.append(diamond(dx, hy, complete))
        nx = dx + 11
        parts.append(f'<text x="{nx:.1f}" y="{hy:.1f}" font-size="13" font-weight="600" '
                     f'fill="{FG}" dominant-baseline="central" '
                     f'letter-spacing="-0.01em">{esc(m["name"])}</text>')
        # blocked-by, inline after the name
        bb = m.get("blocked_by") or []
        if bb:
            bx = nx + approx_w(m["name"], 13, bold=True) + 12
            parts.append(f'<text x="{bx:.1f}" y="{hy:.1f}" font-size="11" '
                         f'dominant-baseline="central" fill="{FG_DIM}">'
                         f'blocked by <tspan fill="{FG_MUT}" font-weight="500">'
                         f'{esc(" · ".join(bb))}</tspan></text>')
        # meta, right-aligned
        xr = OUTER + BAND_W - 16
        cnt = m.get("issue_count", sum(len(r) for r in m["rows"]))
        cnt_txt = f"{cnt} issue" + ("" if cnt == 1 else "s")
        parts.append(f'<text x="{xr:.1f}" y="{hy:.1f}" font-size="11" text-anchor="end" '
                     f'dominant-baseline="central" fill="{FG_MUT}">{cnt_txt}</text>')
        left_of_cnt = xr - approx_w(cnt_txt, 11) - 9
        if complete:
            tag = "COMPLETE"
            tw = approx_w(tag, 10, bold=True) + 16
            parts.append(f'<rect x="{left_of_cnt-tw:.1f}" y="{hy-8:.1f}" width="{tw:.1f}" '
                         f'height="16" rx="8" fill="none" stroke="{C_DONE}" '
                         f'stroke-opacity="0.5"/>')
            parts.append(f'<text x="{left_of_cnt-tw/2:.1f}" y="{hy:.1f}" font-size="10" '
                         f'font-weight="600" letter-spacing="0.06em" text-anchor="middle" '
                         f'dominant-baseline="central" fill="{C_DONE}">{tag}</text>')
        else:
            pct = f'{m.get("percent", 0)}%'
            parts.append(f'<text x="{left_of_cnt:.1f}" y="{hy:.1f}" font-size="11" '
                         f'text-anchor="end" dominant-baseline="central" '
                         f'fill="{FG_DIM}">{pct}</text>')
        # chip rows. Chips shrink to fit a row, so 4+ across still fit the band.
        content_top = top + HEAD_TOP + HEAD_H + HEAD_GAP
        usable = BAND_W - 32
        for r, row in enumerate(m["rows"]):
            row_y = content_top + r * (CH + ROW_GAP)
            n = len(row)
            cw = min(CW, (usable - (n - 1) * GAP_X) / n)
            row_w = n * cw + (n - 1) * GAP_X
            start_x = OUTER + (BAND_W - row_w) / 2
            for i, iid in enumerate(row):
                cx = start_x + i * (cw + GAP_X)
                _chip(parts, iid, issues[iid], cx, row_y, cw)
                geom[iid] = {"cx": cx + cw / 2, "top": row_y, "bottom": row_y + CH}
        # note
        if m.get("note"):
            ny = content_top + len(m["rows"]) * CH + (len(m["rows"]) - 1) * ROW_GAP + NOTE_GAP + 9
            for ln in wrap(m["note"], 92):
                parts.append(_note_line(ln, OUTER + BAND_W / 2, ny))
                ny += NOTE_H

    # ---- edges (drawn last so arrows sit on top) ----
    for e in spec.get("edges", []):
        a, b = e[0], e[1]
        opt = e[2] if len(e) > 2 else {}
        if a not in geom or b not in geom:
            continue
        ga, gb = geom[a], geom[b]
        ax, ay = ga["cx"], ga["bottom"]
        bx, by = gb["cx"], gb["top"] - 1.5
        my = (ay + by) / 2
        cross = opt.get("cross")
        col = LINE_CROSS if cross else LINE
        dash = ' stroke-dasharray="3 3"' if opt.get("dashed") else ""
        marker = "ahc" if cross else "ah"
        parts.append(f'<path d="M{ax:.1f},{ay:.1f} C {ax:.1f},{my:.1f} {bx:.1f},{my:.1f} '
                     f'{bx:.1f},{by:.1f}" fill="none" stroke="{col}" stroke-width="1.4"{dash} '
                     f'marker-end="url(#{marker})"/>')

    # ---- legend ----
    ly = total - LEGEND_H + 14
    parts.append(f'<line x1="{OUTER}" y1="{ly-8:.1f}" x2="{OUTER+BAND_W}" y2="{ly-8:.1f}" '
                 f'stroke="#202022" stroke-width="1"/>')
    lx = OUTER + 2
    for status, label in [("done", "Done"), ("todo", "Todo / refining"),
                          ("backlog", "Backlog")]:
        parts.append(status_icon(status, lx, ly + 4))
        parts.append(f'<text x="{lx+20:.1f}" y="{ly+12:.1f}" font-size="11" fill="{FG_MUT}" '
                     f'dominant-baseline="central">{label}</text>')
        lx += 20 + approx_w(label, 11) + 26
    parts.append(f'<line x1="{lx:.1f}" y1="{ly+11:.1f}" x2="{lx+22:.1f}" y2="{ly+11:.1f}" '
                 f'stroke="{LINE_CROSS}" stroke-width="1.4" marker-end="url(#ahc)"/>')
    parts.append(f'<text x="{lx+32:.1f}" y="{ly+12:.1f}" font-size="11" fill="{FG_MUT}" '
                 f'dominant-baseline="central">blocks / finish first</text>')

    # ---- assemble ----
    defs = (
        '<defs>'
        f'<marker id="ah" viewBox="0 0 8 8" refX="6.2" refY="4" markerWidth="6.5" '
        f'markerHeight="6.5" orient="auto-start-reverse"><path d="M1 1.4 L6 4 L1 6.6" '
        f'fill="none" stroke="{LINE}" stroke-width="1.3" stroke-linecap="round" '
        f'stroke-linejoin="round"/></marker>'
        f'<marker id="ahc" viewBox="0 0 8 8" refX="6.2" refY="4" markerWidth="6.5" '
        f'markerHeight="6.5" orient="auto-start-reverse"><path d="M1 1.4 L6 4 L1 6.6" '
        f'fill="none" stroke="{LINE_CROSS}" stroke-width="1.3" stroke-linecap="round" '
        f'stroke-linejoin="round"/></marker>'
        '</defs>'
    )
    H = math.ceil(total)
    head = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" '
            f'width="100%" '
            f'font-family="Inter, -apple-system, BlinkMacSystemFont, system-ui, sans-serif">')
    bgr = f'<rect x="0" y="0" width="{W}" height="{H}" rx="10" fill="{BG}"/>'
    return head + defs + bgr + "".join(parts) + "</svg>"


def _chip(parts, iid, issue, x, y, cw=CW):
    optional = issue.get("optional")
    status = issue.get("status", "backlog")
    if optional:
        fill, stroke, dash = "none", CHIP_OPT_STROKE, ' stroke-dasharray="4 3"'
    elif status in ("done", "in_review"):
        fill, stroke, dash = CHIP_DONE_FILL, CHIP_DONE_STROKE, ""
    else:
        fill, stroke, dash = CHIP_FILL, CHIP_STROKE, ""
    parts.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{cw:.1f}" height="{CH}" rx="6" '
                 f'fill="{fill}" stroke="{stroke}" stroke-width="1"{dash}/>')
    parts.append(status_icon(status, x + 10, y + 8))
    id_col = FG_DIM if optional else FG_MUT
    parts.append(f'<text x="{x+30:.1f}" y="{y+16:.1f}" font-size="11" font-weight="500" '
                 f'fill="{id_col}">{esc(iid)}</text>')
    if issue.get("tag"):
        tg = esc(issue["tag"])
        tw = approx_w(tg, 9.5) + 10
        tx = x + cw - 10 - tw
        parts.append(f'<rect x="{tx:.1f}" y="{y+7:.1f}" width="{tw:.1f}" height="14" rx="3" '
                     f'fill="none" stroke="{CHIP_STROKE}"/>')
        parts.append(f'<text x="{tx+tw/2:.1f}" y="{y+15:.1f}" font-size="9.5" font-weight="500" '
                     f'text-anchor="middle" fill="{FG_DIM}">{tg}</text>')
    t_col = FG_2 if status in ("done", "in_review") else (FG_MUT if optional else FG)
    parts.append(f'<text x="{x+12:.1f}" y="{y+34:.1f}" font-size="12.5" fill="{t_col}" '
                 f'letter-spacing="-0.005em">{esc(issue["title"])}</text>')


def _note_line(text, cx, y):
    return (f'<text x="{cx:.1f}" y="{y:.1f}" font-size="10.5" text-anchor="middle" '
            f'fill="{FG_DIM}">{esc(text)}</text>')


# --------------------------------------------------------------------------
# Built-in worked example (the "Service discovery and capability automation"
# project). Run with no args to regenerate it.
# --------------------------------------------------------------------------
EXAMPLE = {
    "title": "Dependency graph",
    "subtitle": ("Issues side by side can be worked on in parallel. An arrow means "
                 "the issue it points to is blocked until the source finishes. "
                 "Each box is a project milestone."),
    "milestones": [
        {"id": "M0", "name": "M0 — Research & cluster", "state": "complete",
         "issue_count": 4,
         "note": "Hard gate. Unlocks the infrastructure track (M1–M4) and the capability track (M5–M6).",
         "rows": [["VEL-634", "VEL-637", "VEL-636", "VEL-635"]]},
        {"id": "M1", "name": "M1 — K8s + Claude API", "blocked_by": ["M0"], "percent": 0,
         "issue_count": 2, "rows": [["VEL-633"], ["VEL-640"]]},
        {"id": "M2", "name": "M2 — Production agents", "blocked_by": ["M1"], "percent": 0,
         "issue_count": 2, "rows": [["VEL-639"], ["VEL-638"]]},
        {"id": "M3", "name": "M3 — Mac Mini + Ollama", "blocked_by": ["M0"], "percent": 0,
         "issue_count": 6,
         "rows": [["VEL-632"], ["VEL-682", "VEL-631"],
                  ["VEL-684", "VEL-685", "VEL-681"], ["VEL-683"]]},
        {"id": "M4", "name": "M4 — Model switchover", "blocked_by": ["M1", "M2", "M3"],
         "percent": 0, "issue_count": 1, "rows": [["VEL-630"]],
         "note": "Converges VEL-684, VEL-685, VEL-631 and VEL-638."},
        {"id": "M5", "name": "M5 — Capability tracking", "blocked_by": ["M0"], "percent": 0,
         "issue_count": 1, "rows": [["VEL-359"]]},
        {"id": "M6", "name": "M6 — Capability expansion", "blocked_by": ["M5"], "percent": 0,
         "issue_count": 1, "rows": [["VEL-244"]]},
    ],
    "issues": {
        "VEL-634": {"title": "Kapsule cluster", "status": "done"},
        "VEL-637": {"title": "Model spike", "status": "done"},
        "VEL-636": {"title": "Runtime spike", "status": "done"},
        "VEL-635": {"title": "Network spike", "status": "done"},
        "VEL-633": {"title": "Deploy OpenClaw", "status": "backlog"},
        "VEL-640": {"title": "Restructure skills", "status": "backlog"},
        "VEL-639": {"title": "Multi-tenant isolation", "status": "backlog"},
        "VEL-638": {"title": "Deploy agents", "status": "backlog"},
        "VEL-632": {"title": "Provision Mac Mini", "status": "backlog"},
        "VEL-682": {"title": "Install Ollama", "status": "backlog"},
        "VEL-631": {"title": "Network link", "status": "backlog"},
        "VEL-684": {"title": "Benchmark inference", "status": "backlog"},
        "VEL-685": {"title": "Validate tool calling", "status": "backlog"},
        "VEL-681": {"title": "Ollama monitoring", "status": "backlog"},
        "VEL-683": {"title": "Evaluate vllm-mlx", "status": "backlog",
                    "optional": True, "tag": "if needed"},
        "VEL-630": {"title": "Switch to local model", "status": "backlog"},
        "VEL-359": {"title": "Capability progress", "status": "todo"},
        "VEL-244": {"title": "Clipboard assessment", "status": "todo"},
    },
    "edges": [
        ["VEL-633", "VEL-640"],
        ["VEL-639", "VEL-638"],
        ["VEL-632", "VEL-682"], ["VEL-632", "VEL-631"],
        ["VEL-682", "VEL-684"], ["VEL-682", "VEL-685"], ["VEL-682", "VEL-681"],
        ["VEL-682", "VEL-683", {"dashed": True}],
        ["VEL-684", "VEL-630", {"cross": True}], ["VEL-685", "VEL-630", {"cross": True}],
        ["VEL-359", "VEL-244"],
    ],
}


if __name__ == "__main__":
    if len(sys.argv) >= 2:
        with open(sys.argv[1]) as f:
            spec = json.load(f)
        out = sys.argv[2] if len(sys.argv) >= 3 else "dependency-graph.svg"
    else:
        spec = EXAMPLE
        out = "dependency-graph.svg"
    with open(out, "w") as f:
        f.write(render(spec))
    print(f"wrote {out}")
