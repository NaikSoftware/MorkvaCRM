# Epic 2 — Cloud Firestore & Sync

> **Architecture update (2026-06-16, user-approved):** this epic was implemented on **Cloud Firestore**, not JSON-in-Firebase-Storage as originally drafted below. Firestore provides built-in offline persistence, an automatic write queue, native typed/queryable fields, and transactions — replacing a hand-built cache + sync engine. Auth is **Google-only**. Conflicts use last-write-wins + a visible warning (a `rev` counter). File-field blob uploads will use Firebase Storage in a later epic. Data is stored as typed Firestore documents that map losslessly back to the canonical JSON, so the "exportable open JSON" requirement still holds. The authoritative design is `docs/superpowers/specs/2026-06-16-epic-02-firestore-design.md`. Read "Firebase Storage" below as "Cloud Firestore" except where it refers to file-blob uploads.

## Goal
The user signs in (Firebase Auth), and their collections live as JSON in **Firebase Storage**
under their workspace — synced on startup, periodically, and on change — with an offline cache
so the app works without a connection.

## Why
Data must be shareable across accounts and teams, not locked to one person's private device.
Firebase Storage gives us a single cloud backend we control: the same JSON files the engine
already produces, addressable by path and guarded by security rules, so a workspace can later
be shared with other users. (A user's *private* Google-Drive folder can't be shared with
other accounts, so it's the wrong primitive for a CRM.) The data stays portable JSON the user
can export at any time. We commit to Firebase from day one so there is never a storage
migration later, and Firebase Auth here is the same backend that the future admin/feature-flags
work builds on.

## In scope
- **Firebase Auth sign-in** working on both web and mobile (email and Google provider).
- **Workspace setup**: each signed-in user gets a workspace namespace in Firebase Storage
  (e.g. `workspaces/{workspaceId}/...`) that holds the app's data. Resolve/remember it across
  sessions.
- **Read/write** the Epic 1 JSON: load collections + objects on startup; write changes back to
  Firebase Storage. Choose a clear path layout (e.g. per-collection objects) and document it.
- **Sync triggers**: on startup, periodically, and on change (debounced so rapid edits don't
  thrash the network).
- **Offline cache**: a local copy so the app opens and is editable offline; changes queue and
  flush when connectivity returns. (Firebase Storage has no built-in offline mirror — we own
  the local cache and write queue.)
- **Conflict handling**: a defined, simple strategy (e.g. last-write-wins with a clear,
  surfaced warning, or per-object versioning) — pick one, document it, and make data loss
  visible rather than silent. Full multi-user merge is a future epic.
- **Security rules**: storage rules that scope a workspace's data to its owner (sharing other
  accounts into a workspace is a future epic, but the path layout must not preclude it).
- **Sync status** surfaced to the UI (synced / syncing / offline / error) via a bloc.

## Out of scope
- Firebase admin, feature flags (future epic) — this epic is Firebase Auth + Storage only.
- Real-time multi-user collaboration / shared-workspace access / CRDT merge (future epic).

## Key concepts
- **Source of truth is Firebase Storage; the local cache is a mirror.** The data layer hides
  this behind a repository interface so the rest of the app just asks for collections/objects
  and saves them.
- **Repository boundary**: Epics 3–6 talk to a storage interface, never to Firebase APIs
  directly. This keeps the engine testable and lets the backend change without touching
  features.

## Deliverables
- Firebase Auth sign-in flow (web + mobile, email + Google provider).
- A storage repository implementing load/save of collections and objects against Firebase
  Storage, with the documented path layout.
- Sync scheduler (startup / periodic / on-change debounced) and an offline write queue.
- Firebase Storage security rules scoping data per workspace.
- A sync-status bloc the UI can observe.
- Tests for the repository (against a faked storage backend) and for the offline queue/flush
  logic.

## Acceptance criteria
- A user can sign in, create data, close the app, reopen it, and see the same data — loaded
  from Firebase Storage.
- Edits made offline are retained and pushed once back online.
- A conflicting edit is handled by the chosen strategy and the user is informed, never silently
  losing data.
- Storage rules deny access to another user's workspace data.
- The rest of the app uses only the repository interface (no direct Firebase calls leak into
  features).

## Dependencies & design notes
- Depends on Epic 1 (the JSON model it persists).
- **Use `/design`** for the sign-in screen and the sync-status indicator — these are the
  user's first touchpoints and should feel polished and trustworthy.
- Isolate platform differences (web vs mobile Firebase Auth / Storage access) behind the
  repository interface per the project conventions.
