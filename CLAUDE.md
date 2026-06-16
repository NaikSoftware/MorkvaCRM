# MorkvaCRM

A universal CRM for small business. Not tailored to any specific business — everything is built on generic **collections** of **cards**. See `docs/PRD.md` for the full product vision.

## What it is

- **Flutter** app targeting both **web** and **mobile** from one codebase.
- **Data**: stored as JSON in **Firebase Storage**, under each user's workspace and guarded by security rules (user signs in with Firebase Auth — email or Google). Cloud storage lets a workspace be shared across accounts/teams; the data stays portable JSON the user can export. Synced on startup, periodically, and on change.
- **Backend**: Firebase end to end — Auth + Storage for data (above), plus the admin side: email verification and feature flags (admins enable/disable features per user). Firebase also backs the module marketplace.
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
