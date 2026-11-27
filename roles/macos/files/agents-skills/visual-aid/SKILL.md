---
name: visual-aid
description: >
  Turn an explanation into a published Artifact with charts built from real,
  freshly pulled metrics. Bare invocation (/visual-aid with no text) visualises
  Claude's latest reply in this conversation; with text, the text says what the
  page should be about. Use when the user says "visual aid", "visual explainer",
  "make an artifact of that", "convert your last message into an artifact", or
  "with direct metrics". Slash command: /visual-aid.
---

# Visual aid

Build a page that a reader can skim and understand without the chat next to it. Every number on it comes from data you queried, not from memory or rounded recollection.

## 1. Decide what the page is about

- **No arguments:** the subject is your most recent substantive reply in this conversation (skip short acks and tool chatter). Follow its order and its claims. If there is no such reply, ask what to visualise and stop.
- **With arguments:** the arguments name the subject, the scope, or the question. They win over the latest reply. Use the conversation as background only.

Before you build, write down for yourself: the questions the page answers, and each claim it makes. Each claim needs a number or a source behind it.

## 2. Get direct metrics

"Direct metrics" means numbers pulled now, for this page, from the source of truth:

- App and infra telemetry (traces, logs, metrics): the project's telemetry and monitoring tools. Filter by environment, and state which one.
- Config, limits, alert rules: the repo file itself (cite path and line in your reply).
- Product data: a database helper or an API, read-only.

If the project's brand file (see "Look") lists its own sources, use those.

Rules:

- Pull series, not just totals, when a chart would show a trend, a threshold crossing or a burst. Save raw results to the scratchpad and build chart data from those files with a script; do not transcribe numbers by hand.
- Check every claim on the page against the data before publishing. Drop or correct a claim the data contradicts, and say so in the reply. Do not put a claim on the page that you have not checked ("nothing slowed down" needs a latency query).
- Anchor the mechanism on one real, timestamped example from the data (e.g. "18:25 memory crosses 85% → 18:45 alert fires → 18:56 pod OOMKilled").
- State the time range and environment the numbers cover.

## 3. Build the page

Call `Artifact` with `action: "quickstart"`, `intent: "other"` first, and follow what it returns (artifact-design / dataviz guidance, Data type if it suggests one). Then apply these on top.

### Content rules (from the user's feedback)

- **No title card.** Open on the answer: short answers to the questions asked (is it broken, who is affected, why, what to do).
- **Headings state the conclusion** ("Bursts stop at the pooler"), not the topic ("Connection counts").
- **Every number explains itself:** short label, big value, a context line under it ("was 1,229 MiB", "below the 5% alert line"). A number that needs a caption elsewhere is wrong.
- **No small grey text:** no spaced-caps eyebrows, no page numbers, no source footers. Chart labels 14px in the text colour. Sources go in the chat reply.
- **Explain from zero.** Do not assume the user remembers how an alert is configured, how a flow works, or what an endpoint is. Walk the flow in plain steps first, then place the problem on it. Plain names first (what a person experiences); internal codes and paths only after, never instead. Define every term ("the last 5 minutes the alert looks back over", not "window").
- End with next steps, if the explanation leads to actions. Number them, so the user can say "make an issue for next step 2".

- **Long or living pages:** overview first (skimmable, as above), deep dive second. A page you keep updating shows an "Updated <time>" line and its metrics are re-pulled on each update.
- **Voice:** British spelling, sentence case, digits for weighty numbers. No em dashes, exclamation marks, emoji, buzzwords or superlatives.

### Look

**Brand file.** If a brand file exists for the current project, follow it. Look for `~/.agents/brands/<project>.md` first. The project is the repo's org or name, for example the GitHub org of the current repo. Else use `~/.agents/brands/default.md`. If neither exists, use a plain, considered default: dark by default with a light toggle, tokens on `:root`. A brand file wins over the generic rules below where they differ, and may also name the project's sources of truth for metrics.

Generic rules, with or without a brand file:

- **Dark is the default.** Put the dark tokens on `:root`, and the light ones under `:root[data-theme="light"]`. Add a small light/dark toggle. Both themes must work.
- Never invent colours when a brand file gives them. Use the faded text levels only at body size or larger, never for small labels.
- **Shape:** 4px radius on small parts (chips, fields), 8px on cards. 1px border, no shadows, no gradients, no coloured card edges. The one exception is the accent edge for version changes (see below).

### Updating a page after feedback: mark what changed

When you republish a page the user has already read, every change must be visible on the page itself, so they can see what moved without rereading or diffing. The user confirmed this format works:

- **Version number.** Each republish after feedback is the next version (v2, v3, …). Pass it as the publish `label` ("v3: memory, autoscaling, cost model").
- **"New in version N" box at the top**, under the opening answer: one line per change, naming the section and saying what changed ("Section 6 corrected: …", "New section 8: …"). Earlier versions' lists go below it, each in a collapsed `<details>` ("Version 3 changes").
- **Badges on headings and paragraphs.** This version: "New in vN" for added content, "Corrected in vN", "Updated in vN" or "Withdrawn in vN" for changed content. Earlier versions' badges stay but turn neutral grey and read just "v2", "v3"; never delete them.
- **Section edge.** A section added or changed in this version gets an accent left edge; sections from earlier versions keep a neutral grey edge. This is the one allowed exception to "no coloured card edges".
- **Never silently replace a claim.** Keep the old text struck through, prefixed "Version N:", and put the replacement next to it with the reason and its source ("Your connection-pool investigation explains it: …"). Withdrawn recommendations and table rows stay visible, struck through, with a "Withdrawn" badge and why.
- **Tables:** tint new columns and rows, and say in a line above the table what the new columns mean.
- **Numbers that move:** where a headline number changes, the context line says what it was and why it moved ("v3 said €346, which needed the withdrawn ingress change").
- In the chat reply, list the changes in the same order as the box.

## 4. Publish and report

- Publish with `icon: "chart"` and a one-sentence `description`. Updates go to the same file path / URL, never a new artifact.
- Never call `Artifact` `action: "open"`, not even to check rendering. The user turned off browser auto-open because tabs popping up disturb their work; they open the link themselves. If you could not see it render, say so plainly.
- Reply in the chat: the link, one line per section of the page, the time range and data sources used, and any claim you dropped or corrected while checking.
- Never post or share the page anywhere; the user reviews it first.
- If they say "redesign" or ask for a different format (deck → one-pager), start from scratch rather than restyling the old layout, and re-pull the metrics.
