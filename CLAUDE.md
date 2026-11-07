# MorkvaCRM

A universal CRM for small business. Not tailored to any specific business — everything is built on generic **collections** of **cards**. See `docs/PRD.md` for the full product vision.

## What it is

- **Flutter** app targeting both **web** and **mobile** from one codebase.
- **Data**: stored in **Cloud Firestore**, under each user's workspace (`workspaces/{uid}/…`) and guarded by security rules (user signs in with Firebase Auth — **Google only**). Collections/cards are typed Firestore documents (a card's field values use native Firestore types; dates as `Timestamp`), so they stay queryable and losslessly exportable to JSON. Firestore's built-in offline persistence + automatic write queue handle sync (startup/continuous/offline); a `rev` counter gives last-write-wins with a visible conflict warning. File-field blob uploads use **Firebase Storage** (later epic). The workspace path is membership-ready so it can later be shared across accounts/teams.
- **Backend**: Firebase end to end — Auth + Firestore for data (above), plus the admin side: email verification and feature flags (admins enable/disable features per user). Firebase also backs the module marketplace.
- **Collections & cards**: a collection holds cards; each card has typed fields (text, number, date, file, reference to a collection/card, etc.). Fields can be **calculated** (derived from other fields or from another card by id).
- **Extensibility**: dynamic **JS modules** loaded at runtime; distributed via a Firebase-backed marketplace.

## Architecture

- **core** — main logic, collections, data management.
- **api** — data access layer.
- **marketplace** — JS modules (SPA) on top of Firebase.

## Conventions

- **State management: use BLoC.** Keep widgets dumb; logic lives in blocs/cubits.
- **UI: Material Design**, modern and polished — not generic buttons and tables. Use the `/design` skill for any UI work.
- Null-safe, idiomatic Dart. Compose small widgets.
- Keep platform-agnostic code shared; isolate web-/mobile-specific bits.
- Run `flutter analyze` and tests before considering work done.
- Review changes after they are made to avoid broken logic, missed requirements, etc.
- **Design parity gate:** UI work is mocked in Claude Design first; during the build (after each UI
  milestone) and before calling it done, screenshot the running app and compare it with the mockup
  side by side. Every difference is either fixed in code or the mockup is updated to the agreed
  design — content shown as a field in the mockup must come from that field in the app.

## Coding

Use **jbcontext** to find and navigate code: when the file or symbol is not known yet, start with
`jbcontext search "<descriptive query>"` (narrow with `-p <path>`), then switch to direct reads
or exact search once you know where to look. The index covers committed `main`; code that only
exists on a feature branch is found by reading files directly.
