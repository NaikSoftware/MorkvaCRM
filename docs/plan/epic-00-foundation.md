# Epic 0 — Foundation & Design System

## Goal
A runnable Flutter app (web + mobile) with the architectural skeleton, theme, and quality
gates in place, so every later epic plugs into a consistent foundation.

## Why
The repo currently has docs and tooling but no Flutter project — no `pubspec.yaml`, no `lib/`.
Nothing can be built until the skeleton, state-management pattern, and design language exist.

## In scope
- Initialize the Flutter project for **web and mobile** from one codebase.
- Establish the folder/layer structure the team will follow (core engine, data/api layer,
  feature UI, shared widgets). Keep platform-agnostic code shared; isolate platform-specific
  bits behind interfaces.
- Set up **BLoC** as the state-management foundation with one trivial example bloc proving the
  wiring (e.g. an app-shell/navigation cubit).
- App shell: navigation/routing structure, a home scaffold, and where collections will later
  be listed.
- **Design system base** (via `/design`): color scheme, typography, spacing, core component
  styles (buttons, inputs, cards, app bar). Modern and distinctive — not stock Material.
- Quality gates: `flutter analyze` clean, a test harness that runs, and the conventions from
  the project `/test` skill honored.

## Out of scope
- Any real data model (Epic 1), storage (Epic 2), or screens beyond an empty shell.

## Key concepts
- **Layered structure:** a domain/engine layer that knows nothing about UI; a data layer
  behind interfaces; a presentation layer of features + shared widgets.
- **Design tokens** centralized so every later screen draws from one source of truth.

## Deliverables
- A Flutter app that launches on web and on a mobile device/emulator showing a themed,
  empty app shell.
- Documented folder structure and the BLoC pattern to follow.
- A reusable theme/design-system module and a small set of styled base widgets.
- Passing `flutter analyze` and a green test run.

## Acceptance criteria
- The app builds and runs on **both** web and mobile from the single codebase.
- A new contributor can see where a feature, a bloc, and a shared widget each belong.
- The app shell uses the design system (no default-Material look).
- `flutter analyze` reports no issues; the test suite runs green.

## Dependencies & design notes
- Depends on nothing.
- **Use `/design`** to define the visual language and base components — this sets the tone for
  every later UI epic, so do it deliberately here rather than per-screen later.
