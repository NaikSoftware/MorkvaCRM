# Epic 2 — Google Drive Storage & Sync

## Goal
The user signs in with Google, picks a folder, and their collections live as JSON in their own
Google Drive — synced on startup, periodically, and on change — with an offline cache so the
app works without a connection.

## Why
Per the PRD, the user owns their data: it lives in *their* Drive, not our backend. We commit to
Drive from day one so there is never a storage migration later.

## In scope
- **Google sign-in** working on both web and mobile.
- **Folder selection**: the user picks (or the app creates) a Drive folder that holds the app's
  data. Remember it across sessions.
- **Read/write** the Epic 1 JSON: load collections + objects on startup; write changes back.
  Choose a clear file layout (e.g. per-collection files) and document it.
- **Sync triggers**: on startup, periodically, and on change (debounced so rapid edits don't
  thrash Drive).
- **Offline cache**: a local copy so the app opens and is editable offline; changes queue and
  flush when connectivity returns.
- **Conflict handling**: a defined, simple strategy (e.g. last-write-wins with a clear,
  surfaced warning, or per-object versioning) — pick one, document it, and make data loss
  visible rather than silent. Full multi-user merge is a future epic.
- **Sync status** surfaced to the UI (synced / syncing / offline / error) via a bloc.

## Out of scope
- Firebase auth/admin, feature flags (future epic) — this epic is Drive + Google sign-in only.
- Real-time multi-user collaboration / CRDT merge (future epic).

## Key concepts
- **Source of truth is Drive; the local cache is a mirror.** The data layer hides this behind a
  repository interface so the rest of the app just asks for collections/objects and saves them.
- **Repository boundary**: Epics 3–6 talk to a storage interface, never to Drive APIs directly.
  This keeps the engine testable and lets the backend change without touching features.

## Deliverables
- Google sign-in + folder-picker flow (web + mobile).
- A storage repository implementing load/save of collections and objects against Drive, with
  the documented file layout.
- Sync scheduler (startup / periodic / on-change debounced) and an offline write queue.
- A sync-status bloc the UI can observe.
- Tests for the repository (against a faked Drive) and for the offline queue/flush logic.

## Acceptance criteria
- A user can sign in, pick a folder, create data, close the app, reopen it, and see the same
  data — loaded from their Drive.
- Edits made offline are retained and pushed once back online.
- A conflicting edit is handled by the chosen strategy and the user is informed, never silently
  losing data.
- The rest of the app uses only the repository interface (no direct Drive calls leak into
  features).

## Dependencies & design notes
- Depends on Epic 1 (the JSON model it persists).
- **Use `/design`** for the sign-in screen, folder-picker, and the sync-status indicator —
  these are the user's first touchpoints and should feel polished and trustworthy.
- Isolate platform differences (web vs mobile Google sign-in / Drive access) behind the
  repository interface per the project conventions.
