# Epic 8 — Ask Morkva: implementation plan

Spec: `docs/superpowers/specs/2026-11-10-epic-08-ai-assistant-design.md` (architecture, task table
T0–T14 with files per task) and `…-ux.md` (UI states). Mockups: `docs/superpowers/mockups/epic-08/`.
Branch: `feat/epic-08-ai-assistant`.

## Execution model

Tasks run as **waves** of multi-agent workflows. Each task agent works in its own git worktree,
touches only the files its spec row lists, writes unit/bloc/widget tests, runs `flutter analyze`
and its tests, and commits on its worktree branch. An independent reviewer checks each task
against the spec and re-runs the tests; findings are fixed before the branch is merged into the
feature branch. Between waves the full suite and `flutter analyze` run on the merged branch.

| Wave | Tasks | Why together |
|---|---|---|
| 1 | T1a domain extractions · T1b data layer · T1c design token + dialog | roots, disjoint files |
| 2 | T2 harness core · T2b seed fixture | need T1a / T1b |
| 3 | T3 cache · T4 strict input · T8a contracts · T10 persistence + config | need T2 / T2b |
| 4 | T5a query engine · T8 agent runtime · T9 Gemini adapter · T12 assistant UI · T13a views deep links | need wave 3 |
| 5 | T5b read ops · T6 plans | need T5a |
| 6 | T7 commit + journal | needs T6 |
| 7 | T11 bloc layer → T13b app integration | need everything above |
| 8 | T14 verification: rules deploy, e2e on web with real Gemini, parity + design critic, analyze, PR | — |

T0 (console spike) runs inline before T9 lands: the proxy call, schema-shape acceptance, 429
samples. **Blocked on App Check**: AI Logic has App Check *enforced* with no app registered, so every
Gemini call returns 401 until the owner registers the web app (reCAPTCHA) and/or adds a debug token.

## Cut order if the build stalls

journal restore-after-reload → `setFrom` formulas → `views.*` ops (the user's asks survive).

## Verification gates

- Per task: tests + `flutter analyze` clean on touched files; reviewer verdict.
- Per wave: full `flutter test` + `flutter analyze` on the merged branch.
- Wave 4 (UI): design parity screenshots of the panel against the Main/Empty artboards.
- Wave 8: e2e on web with real Gemini (ask, analyze, approve 2 of 3, undo, create a linked
  collection, delete test cards), design critic on running-app screenshots vs all 8 artboards,
  5k-card timings on the VM fixture (web uses a few hundred `seed:true` cards, deleted after).
