# Future Epics (deferred)

These are out of scope for the current plan but are the natural next steps once Epics 0–7 land.
Listed so the foundation is built without painting them into a corner. Order is indicative, not
fixed.

## Automation & triggers → Epic 9
Moved to [`epic-09-automations.md`](epic-09-automations.md): sandboxed JS modules, buttons and
card-event triggers. What stays future:
- **Scheduled and date triggers** ("every Monday", "3 days before Due"). The app is client-only on
  the Spark plan, so they need either a foreground scheduler with cross-device claims or Cloud
  Functions + Scheduler (Blaze).
- **Module network access**: a host op `http.fetch` gated by a manifest `network.domains` list
  and logged per request; the sandbox CSP stays `connect-src 'none'`.
- **Triggers on calculated-value changes** and on writes from other devices or external tools.

## Full formula engine
Generalize Epic 6's concrete operation set into a richer expression language: conditionals,
more functions, multi-step and cross-field expressions. Epic 6 deliberately leaves its
definition format extensible so this is additive.

## Firebase: admin & feature flags
The admin side from the PRD: email verification, admin roles, and per-user feature flags
(admins enable/disable features per user). Builds on the Firebase Auth that already ships in
Epic 2; keep it behind the same kind of interface boundary as the storage layer.

## JS-module marketplace
A Firebase-backed catalog of published modules (read-only to clients, admin-written), installed
through the same consent sheet as an import. Epic 9 ships the module format (`*.morkva.json`), the
runtime, consent and the SDK docs; the marketplace adds distribution, publisher identity, review
and update notifications. Open risk: App Store guideline 2.5.2 for downloadable code on iOS.

## Additional view modes
More renderers in the Epic 4 view system — calendar (group/place by a date field), gallery
(image-forward cards), maybe timeline. Each is an additive mode, not a rewrite, because Epic 4
separates query/grouping from rendering.

## Shared workspaces & multi-user collaboration → Epic 10 (designed)
Designed in [`../superpowers/specs/2026-11-13-team-collaboration-design.md`](../superpowers/specs/2026-11-13-team-collaboration-design.md)
(mockups: `../superpowers/mockups/collaboration/`): workspace members with Owner/Admin/Editor/Viewer
roles, invites by email or link, a workspace switcher, teammate links to views, and read-only
**published copies** of a view for outsiders (by link or email list). Owner chose the single Share
button (UI-1) and copies only for outsiders (no live public view). Not built yet; five owner
decisions open (Spark vs Blaze first). What stays future beyond that design: presence, real-time
merge (CRDT/OT), comments + a Commenter role, per-collection guests, audit log.

## Template sharing
Promote Epic 7's local templates into shareable/published templates (overlaps with the
marketplace).

## Global AI assistant — "Ask Morkva"
A workspace-wide AI chat where the user asks anything in plain language and the assistant
answers, analyzes, and (with a confirm gate) acts on collections/cards via repository-bound
tools — the Anthropic key held server-side in a Firebase function. Fully scoped in
[`epic-08-ai-assistant.md`](epic-08-ai-assistant.md). Depends on Epic 2 (repository + auth +
backend); richer with Epics 4 and 6.
