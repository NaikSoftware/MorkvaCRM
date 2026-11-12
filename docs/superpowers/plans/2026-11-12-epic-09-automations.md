# Epic 9 — Automations: implementation plan

Spec: `docs/superpowers/specs/2026-11-12-epic-09-automations-design.md` (decisions D1–D19, flags,
the task table T0a–T18 with files, dependencies and tests per task, and the Critique log) and
`…-ux.md` (screens, states, copy, 13 artboards). Mockups: `docs/superpowers/mockups/epic-09/`.
Branch: `feat/epic-09-automation`. The task table in the design spec is the source of truth for
files; this plan only orders and gates the work.

## Before the build

1. **Mockups** in Claude Design for the 13 artboards of the UX spec (local copies under
   `docs/superpowers/mockups/epic-09/`).
2. **Design critic gate:** an independent critic accepts the artboards against the UX spec and
   `lib/design/DESIGN.md` before wave 3 (the first UI wave) starts. Findings are fixed in the
   mockups or, where the mockup is right, in the UX spec.

## Execution model

Tasks run as **waves** of multi-agent workflows. Each task agent:

1. works in its **own git worktree**, which starts from `main`; its **first step** is
   `git merge --ff-only feat/epic-09-automation` (main is an ancestor, so it fast-forwards; memory
   "Workflow worktree base");
2. touches **only the files its spec row lists** (a file it needs that the row omits is reported
   to the lead, not edited);
3. writes its unit / bloc / widget tests (and `--platform chrome` or `qjs`-tagged tests where the
   row says so);
4. runs `$HOME/Dev/flutter/bin/flutter analyze` and its own tests until clean, formatting **only
   the files it edited** (`dart format <files>`, memory "Format only edited files");
5. commits on its worktree branch with
   `git -c user.name="Nickolay Savchenko" -c user.email=naiksav4enko@gmail.com commit …`
   (no other git identity exists on this machine);
6. reports: files touched, tests added, commands run and their results, anything it could not do.

Code search: start with `jbcontext search` when the index is available (put that rule in every
brief); otherwise `rg` and direct reads. The index covers committed `main`, so code from earlier
waves is read directly.

An **independent reviewer per task** checks the branch against its spec row (files, behaviour,
tests, the decisions it touches), re-runs `flutter analyze` and the task's tests, and lists
findings. The task agent fixes them; the lead then merges the branch into
`feat/epic-09-automation` (`git merge --no-ff`, same identity). After each wave the lead runs the
**full** `flutter test` and `flutter analyze` on the merged branch (plus the chrome suite from wave 2
on and the `qjs` suite from wave 3 on) and fixes breakage before the next wave starts.

| Wave | Tasks | Why together |
|---|---|---|
| 1 | T0a domain records + runner contract · T0b engine contracts + frame protocol · T1 write seam · T2 harness v2 core · T3 PlanCard decoupling | roots, disjoint files |
| 2 | T4 stores + rules · T5 module items, ops, catalog · T6 web engine + SDK core + conformance cases · T8 trigger evaluator + loop guard · T9 cubits + shared widgets | need T0a/T0b (+ T1/T2/T3) |
| 3 | T7 QuickJS engine · T10 committer + `HarnessSession` · T11 bridge + card shaper + run log · T12 Automations pages · T13 editor, buttons, indicator, review sheet | need T6 (T7), T1/T5 (T10), T5 (T11), T9 (T12/T13) |
| 4 | T14 runner · T15 assistant on the shared session | need T8/T10/T11 (T14), T4/T5/T10 (T15) |
| 5 | T16 app integration · T17 SDK docs + examples | wiring and docs on the finished core |
| 6 | T18 verification | — |

Wave-level ownership that is easy to get wrong (checked against the spec rows: no two tasks of a
wave share a file, and every symbol a task uses is created in an earlier wave):
- `sdk_core.dart` and `test/automation/conformance/cases.dart` belong to **T6**; T7 runs them and
  reports divergences, it never edits them.
- `status_chip.dart` and `reason_copy.dart` are **T9**'s (wave 2), so T12 and T13 share them read-only.
- `object_editor.dart` / `object_editor_cubit.dart`: T1 (wave 1, origins) then T13 (wave 3,
  Save and run + in-editor banner).
- `lib/app/app.dart`: T15 (wave 4, construction at `:126-133` only) then T16 (wave 5, runner and
  lifecycle). `test/widget_test.dart`: T1 (wave 1) then T16 (wave 5).
- `lib/core/domain/ids.dart` (`runId`, `writeId`) is **T1**'s, because T1 mints write ids in wave 1.
- `HarnessSession` is created by **T10** (wave 3), so the runner (T14) and the assistant (T15) both
  build on it in wave 4; the editor validates through `AutomationRunnerApi.validate` (T0a contract),
  never by importing T5's harness file; `RunnerHooks` types live in the domain (T0a).
- `pubspec.yaml` / `pubspec.lock`: T0a (wave 1, `crypto`, `web`) then T7 (wave 3, `flutter_qjs_next`).
- The descriptors golden: T2 (wave 1) then T5 (wave 2); T18 refreshes it and reruns
  `tool/gen_sdk_types.dart`.
- `chat_item.dart` / `applied_card.dart` / `chat_list.dart`: T3 (wave 1) then T15 (wave 4).

## Verification gates

- **Per task:** its tests + `flutter analyze` clean on the worktree; reviewer verdict; findings
  fixed before merge.
- **Per wave:** full `flutter test` + `flutter analyze` on the merged branch; from wave 2
  `flutter test --platform chrome test/automation/web` (headless `/usr/bin/google-chrome`; the
  first compile takes ~1–2 min); from wave 3 the `qjs` tag with
  `FLUTTER_QJS_NEXT_LIBRARY=build/qjs/libflutter_qjs_next_plugin.so` (built by
  `tool/build_qjs_test_lib.sh`).
- **Wave 3 (first UI wave):** design parity — screenshot the widgets of T12/T13 (widget-test
  screenshots or the running app) and compare side by side with artboards 1–8 and 10; every
  difference is fixed in code or the mockup is updated to the agreed design.
- **Wave 4:** T4's `firebase deploy --only firestore:rules --dry-run` still passes on the merged
  rules; the assistant suite is green on the shared `HarnessSession`.
- **Wave 6 (T18):**
  - deploy rules: `firebase deploy --only firestore:rules`;
  - **e2e on web** (`run-for-web` profile, driven over CDP, `seed:true` data only, deleted after):
    the E2E list in the design spec's Testing strategy — import + consent with an explicit scope,
    card button with a dirty form → Save and run → review → approve → Undo; an Auto event
    automation stamping a date (no self-loop row); the three-automation chain stopping with a
    visible row; Ask Morkva writing, approving and test-running a module (test-run card shows); the
    offline card-button Auto run failing `offline` with Run again; Stop on a busy-loop module;
  - one sandbox run on the **release** web build (dart2js; static build + CDP as in Epic 8);
  - QuickJS `qjs` suite on the gcc-built lib (or the gap reported);
  - **design parity + critic gate:** screenshots of the running app (web, wide/tablet/phone widths,
    light and dark) compared with all 13 artboards by an independent critic; differences fixed or
    the mockup updated;
  - golden refresh, then `dart run tool/gen_sdk_types.dart`;
  - `flutter analyze`; full `flutter test`; `flutter test --platform chrome test/automation/web
    test/features/collections/id_generator_web_test.dart`;
  - **PR** to `main`: summary, test evidence, the flags (F1–F13) and the stated gaps — Android/iOS
    builds with `flutter_qjs_next` not compiled here (follow-up: `flutter build apk --release`,
    `readelf -lW` LOAD align 0x4000 on `libflutter_qjs_next.so`, an iOS pod/SPM build, one device
    run) and Safari/WebKit CSP inheritance unverified (the probe fails closed).

## Cut order if the build stalls

`modules.testRun` (and the chat test-run card) → AppliedCard "Started N automation runs" →
assistant `runs.*` ops → module export → collection-scope buttons → rate breaker (keep the depth
cap) → QuickJS engine real build (keep the seam + fake, report the gap).

## Environment notes

- Flutter at `$HOME/Dev/flutter/bin`; no git identity configured (use the `-c` flags above).
- No Android SDK or Xcode: mobile builds are out of reach; the QuickJS engine is tested on the host
  through the gcc-built library only.
- Chrome tests: `@TestOn('browser')` files are skipped by the VM run; a bare
  `flutter test --platform chrome` would compile VM-only tests, so always pass paths.
- Firestore writes in e2e go through the signed-in web app over CDP (memory "Seed test data");
  every seeded doc carries `seed: true`.
