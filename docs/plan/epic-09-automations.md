# Epic 9 — Automations (sandboxed JS modules, buttons and triggers)

> **Status: specified.** Design: `docs/superpowers/specs/2026-11-12-epic-09-automations-design.md`
> (architecture, decisions, task table, critique log). UX: `…/2026-11-12-epic-09-automations-ux.md`.
> Plan: `docs/superpowers/plans/2026-11-12-epic-09-automations.md`. Branch: `feat/epic-09-automation`.

## Goal
Let a user — or Ask Morkva on their behalf — install small JS **modules** that add **actions**,
put those actions on **buttons** or run them automatically when **cards change**, safely and
visibly.

## Why
Real setups need side effects: stamp a date when an order ships, copy a total to the customer,
flag low stock. The morkvawear Trello used Butler for this. Hardcoding any of them breaks the
"no business-specific features" rule (README), so the engine needs a generic, user-extensible way
to run logic — sandboxed, permissioned and reviewable, because the code may come from the AI or a
stranger. Epic 8's Harness already gives a versioned, capability-scoped API with a preview gate;
this epic makes it the module SDK.

## In scope
- A `ScriptEngine` seam with two engines: **web** (sandboxed iframe + blob Worker, CSP with no
  network) and **Android/iOS** (QuickJS via `flutter_qjs_next` 1.5.2 on a worker isolate the engine owns and can kill). Fresh
  sandbox per run, wall-clock timeout, kill, user Stop, one conformance suite.
- **Modules**: manifest (strict allowlist: permissions, actions, inputs, timeout) + IIFE code;
  stored per workspace; import/export as `*.morkva.json`; read-only code viewer.
- **Consent** per member: capabilities, collections, auto-apply; pinned to the code hash, so new
  code needs consent again.
- **Automations**: one model, two kinds — **buttons** (card editor header / collection Actions
  menu) and **events** (card created / updated / deleted, conditions reusing the view filter JSON,
  `enters` or `matches`, field watch-list).
- **Runs** through the Harness: modules read with read ops and plan with plan ops; one Plan per
  run; **Ask** (PlanCard review) or **Auto** (host commits as the user, only card creates/edits,
  ≤ 20 low-risk items, only with UI consent); Needs review; Undo via the journal (same session);
  Run again; card buttons offer **Save and run** on an unsaved card.
- Loop safety (depth cap, chain, once per write, fan-out cap per commit, auto-apply budget, rate
  breaker) and a serial run queue (buttons ahead of events).
- **Visibility**: run indicator (sidebar pill, rail badge, phone pill), button spinners, finish
  snackbars (in-editor banners while the card editor is open), run log with a timeline (trigger,
  calls, console, plan, outcome, chain), and "last checks" explaining why an automation didn't run.
- **Assistant**: writes, tests and binds modules through new plan/read ops (`modules.*`,
  `automations.*`, `runs.*`) behind the same preview gate.
- **SDK docs** in `docs/sdk/` with generated `api.md` and `morkva.d.ts`, plus three examples
  tested through the real web engine.
- Harness apiVersion 2 (breaking; no migrations — there are no users yet).

## Out of scope
Scheduled/date triggers · module network access (`http.fetch`) · the marketplace and sharing
modules across workspaces · running while the app is closed · schema-change and
calculated-value-change triggers · OR conditions · a WebView engine · module state between runs.
See `future-epics.md`.

## Key concepts
- **Module** — JS bundle + manifest; declares **actions**.
- **Action** — `morkva.action(id, fn)`; receives `(input, ctx)`; reads and plans only through
  `morkva.call(op, args)` = the Harness.
- **Automation** — the user's binding of one action to a **button** or an **event** trigger.
- **Run** — one execution; ends `succeeded`, `failed`, `timed_out`, `skipped(reason)`,
  `awaiting_review` → `rejected` / `expired`; has a **run log**.
- **Consent** — what a member allowed a module to do; the effective grants are
  manifest ∩ consent ∩ automation scope.
- **The Plan gate stays the only write path**: module, assistant and user-approved changes all
  commit through `plans.commit` as the user.

## Deliverables
- `lib/core/domain/automation/` records + manifest parser; `lib/core/automation/` (engine seam,
  SDK core, bridge, trigger evaluator, loop guard, run queue, apply policy, runner);
  `lib/api/automation/` (Firestore stores, web and QuickJS engines);
  `lib/features/automation/` (cubits, Automations page, module details, consent, import/export,
  editor, buttons, indicator, review sheet, run detail); `HarnessSession` shared by the assistant
  and the runner.
- Write seam: `WriteOrigin` + `CardChange` emitted by `FirestoreDataRepository`.
- Harness v2: new capabilities and ops, explicit assistant grants, `no_change`, per-actor result
  handles, module/automation plan items, PlanCard reusable outside the chat.
- Firestore rules + indexes for `modules`, `automations`, `runs`.
- `docs/sdk/` (README, manifest, generated API reference and typings, examples) and
  `tool/gen_sdk_types.dart`.
- Tests: unit, bloc, widget, web-engine (`--platform chrome`), QuickJS (gcc-built lib or a
  reported gap), conformance on both engines, e2e on web with `seed:true` data.

## Acceptance criteria
- A module imported from a `.morkva.json` file shows its permissions in plain words and runs only
  after the user allows it; changing its code pauses its automations until allowed again.
- A card button runs an action on the stored card (an unsaved form is saved first via "Save and
  run"); the proposed changes appear in the PlanCard review sheet and are written only on approve;
  Undo reverts them in the same session.
- An event automation fires once when a card starts matching its condition, only on the device
  that made the change; with auto-apply consent it applies small card edits (≤ 20 cards, nothing
  cleared) without a prompt, and never applies deletes or structure changes without review.
- A module cannot reach the network, other collections than consented (cards it receives are
  shaped by its grants), or commit on its own; a busy loop is stopped by the timeout or the user's
  Stop without freezing the app.
- An automation that triggers itself stops at the depth cap or the breaker, visibly.
- While anything runs, the indicator shows it; every run has a readable log.
- Ask Morkva can write a module, test it on a card and bind it — all through previews.
- The SDK docs' examples run unchanged through the real web engine in CI tests.
- `flutter analyze` clean; unit, widget and chrome suites green; e2e passed on web.

## Dependencies & design notes
- **Hard:** Epic 8 (Morkva Harness, Plan gate, PlanCard, journal), Epic 2 (repository, rules),
  Epic 4 (filter JSON + FilterBuilder), Epic 6 (derived values for conditions).
- **Design:** UI mocked in Claude Design first (artboards in the UX spec), design critic gate
  before build and parity check before the PR (`/design`).
- **Platform:** the web engine is spike-verified in Chrome and Firefox; Safari/iOS and Android
  devices are unverified here — the engine probe fails closed (`engine_unavailable`). The QuickJS
  engine is tested against a gcc-built host library; Android/iOS builds can't be compiled on this
  machine (no Android SDK, no Xcode), so the PR lists them as a follow-up.
- **Free tier:** run logs are 1–3 writes per run, pruned to the last 200; auto-apply has a
  1,000-item per 10 min budget.
