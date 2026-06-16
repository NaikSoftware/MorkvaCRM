# Epic 0 — Foundation & Design System ("Warm Carrot")

**Date:** 2026-06-16
**Branch:** `worktree-epic-00-design-system`
**Status:** Approved (aesthetic direction A — Warm Carrot)

## Goal

A runnable Flutter app (web + mobile) with a distinctive, reusable **design system** and a
themed **app shell** with routing, so every later UI epic (3–5) plugs into one source of truth
instead of hand-rolling Material widgets per screen.

## Context / what already exists

Epic 1's PR bootstrapped the bare project: `pubspec.yaml`, layered `lib/core/domain/`, `bloc`
+ `flutter_bloc` + `equatable` deps, a green test harness, and a placeholder `lib/main.dart`
that seeds a carrot-orange `ColorScheme.fromSeed`. Firebase is configured
(`firebase_options.dart`, `firebase.json`) but its runtime plugins are deferred to Epic 2.

**This epic does NOT touch data, storage, or auth.** It is design system + shell only.

## Visual identity — Warm Carrot

The brand is *Morkva* (carrot). The identity is a **warm carrot accent over calm, near-neutral
data surfaces**: warmth lives in the accent, primary actions, and micro-interactions; tables and
boards stay quiet so dense content reads cleanly without fatigue.

The concrete token values below are the **starting contract**. The `/design` skill (run by the
lead) finalizes exact values and may refine them — but the *structure* (token names, scales,
the warm-accent/neutral-surface split) is fixed so teammates can build against stable names.

### Color tokens (light; dark mirrors with adjusted surfaces)
- **Primary / Carrot:** `#E8821E` (seed). Tonal use for buttons, active nav, focus rings.
- **On-primary:** `#FFFFFF`.
- **Surfaces:** warm paper neutrals — background `#FBF7F2`, surface `#FFFFFF`,
  surfaceVariant `#F3ECE3`, outline `#E4D9CC`.
- **Text:** `#2B2018` (high), `#6B5E52` (medium), `#9C8E80` (low).
- **Semantic:** success `#2E8B57`, warning `#D4A017` (a distinct yellow-amber, kept clearly
  apart from the carrot primary so a warning never reads as a normal action), error `#C0392B`,
  info `#3A7CA5`. Use Material `ColorScheme` roles; do not invent ad-hoc colors in widgets.

### Typography
- Single distinctive sans (e.g. a Google Font such as **Inter** or **Plus Jakarta Sans**) for
  text; **tabular/monospace numerals** for numeric data cells (CRM shows lots of numbers).
- A defined type scale (display / headline / title / body / label) mapped onto `TextTheme`.

### Shape, spacing, elevation
- **Radius:** sm 8, md 12, lg 16, full (pills) — cards/inputs/buttons use md/lg.
- **Spacing scale:** 4 / 8 / 12 / 16 / 24 / 32 / 48 (a single `Spacing` constants source).
- **Elevation:** soft, low shadows (warm-tinted), not stock Material drop shadows.
- **Motion:** short, calm durations (fast 120ms, base 200ms, slow 320ms) as constants.

## Architecture / folder structure

New top-level layers under `lib/` (alongside the existing `core/`):

```
lib/
  core/domain/          # Epic 1 — untouched
  design/               # THE design system (shared, UI-only, no business logic)
    tokens/             # colors.dart, typography.dart, spacing.dart, radii.dart,
                        #   elevation.dart, motion.dart  (pure constants/values)
    theme/              # app_theme.dart -> light/dark ThemeData from tokens
    components/         # styled base widgets that wrap Material:
                        #   buttons (primary/secondary/text/icon),
                        #   inputs (text field, search field),
                        #   cards (surface card, list tile card),
                        #   app_bar, empty_state, loading/skeleton
    design.dart         # barrel export
  app/                  # app shell + wiring (no feature logic)
    app.dart            # MorkvaApp -> MaterialApp.router(theme: AppTheme.light, ...)
    router/             # route table (go_router) + route names
    shell/              # AppShell: responsive scaffold (nav rail on web/wide,
                        #   bottom nav on mobile/narrow), themed app bar
    navigation/         # NavigationCubit (proves BLoC wiring; tracks selected section)
  features/             # feature UI (mostly empty this epic)
    home/               # HomePage placeholder = "where collections will be listed"
                        #   (empty-state component, themed)
```

**Boundaries:**
- `design/` knows nothing about `core/domain` or `app/`. It is pure presentation primitives.
- `app/` composes `design/` into a shell and routes; holds the navigation cubit.
- `features/` builds screens from `design/` components inside the `app/` shell.
- A new contributor can point to where a feature, a bloc, and a shared widget each live.

## State management

- **BLoC/Cubit** per project convention. The proving example is `NavigationCubit` in
  `app/navigation/`: holds the selected shell section and drives the responsive nav. Widgets are
  dumb; the cubit owns selection state. (Real feature blocs arrive in later epics.)

## Routing

- Use **`go_router`** (add to pubspec) for declarative, web-URL-friendly routing shared across
  web and mobile. Define a small route table with a `ShellRoute` wrapping `AppShell` so the nav
  chrome persists across destinations. One real route this epic: `/` → `HomePage`.

## Responsiveness

- One breakpoint helper (e.g. `< 840` = compact/mobile → bottom nav; `>= 840` = expanded/web →
  navigation rail). Shell adapts; components are width-agnostic.

## Deliverables

1. Design tokens (colors, typography, spacing, radii, elevation, motion) — pure values.
2. `AppTheme` light + dark `ThemeData` built from tokens; wired into `MorkvaApp`.
3. A set of styled base components (buttons, inputs, cards, app bar, empty-state, loading).
4. Responsive `AppShell` (nav rail ⇄ bottom nav) + `go_router` routing + `NavigationCubit`.
5. A themed `HomePage` placeholder showing the empty-state ("no collections yet").
6. Widget tests for components, a cubit test for `NavigationCubit`, a smoke test that the app
   builds and shows the shell. `flutter analyze` clean.

## Acceptance criteria

- App builds and runs on **web and mobile** from one codebase, showing a themed shell — **not**
  a default-Material look.
- The shell, app bar, and home page draw entirely from `design/` tokens/components.
- `NavigationCubit` drives nav selection (BLoC wiring proven).
- A contributor can locate where a feature / bloc / shared widget belongs.
- `flutter analyze` reports no issues; test suite green.

## Agent-team execution plan

Lead (this session) first establishes the **shared contract** so teammates never collide:

**Phase A — Lead (serial, via `/design`):** create `design/tokens/*`, `design/theme/app_theme.dart`,
the `design/design.dart` barrel, add `go_router` to pubspec, and build **one worked exemplar
component** (primary button) end-to-end as the pattern. Commit. This is the contract.

**Phase B — Teammates (parallel `flutter-expert`, disjoint files):**
- **T1 — Buttons & actions:** secondary/text/icon buttons + tests (`design/components/buttons/`).
- **T2 — Inputs & cards:** text field, search field, surface card, list-tile card + tests
  (`design/components/inputs/`, `design/components/cards/`).
- **T3 — Feedback components:** app bar, empty-state, loading/skeleton + tests
  (`design/components/`).
- **T4 — App shell & routing:** `app/shell/`, `app/router/`, `app/navigation/NavigationCubit`,
  responsive nav + cubit test (depends only on tokens/theme from Phase A, not on B's components;
  uses placeholders for any component still in flight, lead swaps real ones in Phase C).

**Phase C — Lead (integration):** wire `features/home/HomePage`, update barrel exports and
`main.dart`, run `flutter analyze` + full test suite, fix integration gaps, then `/check`.

**No file conflicts:** each teammate owns a distinct directory; only the lead edits shared files
(barrels, `pubspec.yaml`, `main.dart`).

## Out of scope

- Any data model (Epic 1, done), storage/auth (Epic 2), or screens beyond the empty shell.
- The actual collections list / table / board UI (Epics 3–4).
