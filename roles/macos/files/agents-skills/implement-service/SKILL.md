---
name: implement-service
description: "Onboard a new service onto browser-extension input protection (guardrails) via the human-in-the-loop capture → analyze → descriptor → QA pipeline. Triggers on: 'implement service <name>', 'add input protection for <name>', 'guardrail <name>', '/implement-service <name>'."
disable-model-invocation: false
---

# Implement service — guardrail onboarding pipeline

Drives `velatir-browser-extension/tools/service-onboarding/` (capture.js, analyze.js, qa.js)
to take a service from signal-only detection to full input protection. The human handles
login, driving the UI and QA approval; you handle analysis, codegen and registration.

**Requires a headed browser on this machine.** If running headless/remote, stop and tell
the user to run this from a workstation session.

## 0. Pre-task ritual (mandatory)

1. If this is a follow-up, check PR status first (`gh pr list --state all --search <branch>`).
2. `git checkout main && git pull origin main` in `velatir-browser-extension` and `velatir-coordination`.
3. Worktrees under `workspaces/implement-<service-slug>/` for both repos, task branch from main.
4. Work from the worktree paths for everything below.

## 1. Find the start URL

Look the service up in `src/services.json` (`domains`, `pathPatterns`) — most onboarding
targets already exist in `"mode": "trace"`. Confirm the entry URL with the user if ambiguous.

## 2. Capture round(s)

```bash
npm run onboard:capture -- --service <slug> --url <https://...>            # round 1
```

Tell the user what to do before launching: log in if needed, start a NEW conversation,
paste the canary (auto-copied to clipboard), wait for the full response, click OK.

## 3. Analyze, and loop

```bash
npm run onboard:analyze -- --service <slug> --canary <VELATIR-CANARY-XXXX>
```

- **READY** → continue to step 4. Still prefer one extra round (`--round r2`, same canary,
  "second prompt in the SAME conversation") so the session id is confirmed, using the exact
  command the report prints.
- **NEEDS MORE** → run the suggested capture round, re-analyze. Repeat (max ~3 rounds).
- **Canary not found / WebSocket transport / encoded body** → descriptor alone won't do.
  Read the capture bundle yourself (`tools/service-onboarding/captures/<slug>/`), find the
  prompt in the traffic, and write the bespoke parts as engine `overrides` (see
  `src/guardrails/deepseek.js` — descriptor + overrides). If the prompt is genuinely
  unreachable (native app traffic, cross-extension), report honestly and stop: this
  service is desktop-app territory or out of scope.

## 4. Register the guardrail

Review `captures/<slug>/descriptor-draft.json` — fix `name`/`provider`, add
`newConversationEndpoints` if the capture showed a separate create-session call. Then wire
ALL touch points:

1. `src/guardrails/<slug>.js` — IIFE calling `window.VelatirGuardrailEngine.register(descriptor[, overrides])`; copy the duplicate-guard + engine-missing-guard from `deepseek.js`.
2. `src/guardrails/index.js` — `GUARDRAIL_MODULES` entry.
3. `src/manifest.json` AND `src/manifest.template.json` — `web_accessible_resources`.
4. `src/background.js` — `SUPPORTED_GUARDRAILS` array.
5. `src/services.json` — flip the service entry to `"mode": "guardrails"` + `endpoints`.
6. `tests/fixtures/<slug>/` — SANITISED fixture derived from the capture (synthetic ids,
   canary as prompt; never real user text, cookies or account ids).
7. `tests/unit/<slug>-guardrail.test.js` — model on `guardrail-engine.test.js` (vm-load
   engine.js + the new module, assert matchesUrl/extractPrompt/session against the fixture);
   chain it into `test:unit` in package.json.

## 5. Verify offline

`npm test` and `npm run build` must both pass.

## 6. QA round (human approval gate)

```bash
npm run onboard:qa -- --service <slug> --url <https://...>
```

Remind the user: the loaded extension must be configured against a **dev backend** (API
key via popup). They prompt naturally; the tool prints captured traces. Expected: Signal →
Request (their words) → Response. The user approves or rejects in the terminal. On reject,
take their observation back to step 3.

## 7. Finish

- Commit, push, `gh pr create --base main` (extension repo). PR body: descriptor summary,
  capture rounds used, QA outcome, fixture note. Link the Linear ticket if there is one.
- Mention in the PR that the service should join the e2e daily health-check rotation
  (`tests/e2e/`) as a follow-up if no spec was added.
- Clean up is the user's call (`/cleanup` after merge).

## Failure modes to respect

- Never commit anything from `tools/service-onboarding/captures/` or `profiles/` — they
  hold raw traffic and live logins. Fixtures must be hand-sanitised copies.
- Enterprise services with no accessible tenant (Salesforce Einstein, BlackLine, Karnov):
  don't fake it — report that access is the blocker and stop.
- A green unit test is NOT done — done is QA approval (step 6).
