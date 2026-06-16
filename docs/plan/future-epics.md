# Future Epics (deferred)

These are out of scope for the current plan but are the natural next steps once Epics 0–7 land.
Listed so the foundation is built without painting them into a corner. Order is indicative, not
fixed.

## Automation & triggers
Side effects when data changes — e.g. moving an order to "shipped" decrements stock, or a status
change stamps a date. This is what the morkvawear setup uses Trello's Butler for (auto-numbering
already moves into Epic 6; this covers the rest). Generic rule model: *when* condition *then*
action, configured per collection. Build on the calculated-field dependency model from Epic 6.

## Full formula engine
Generalize Epic 6's concrete operation set into a richer expression language: conditionals,
more functions, multi-step and cross-field expressions. Epic 6 deliberately leaves its
definition format extensible so this is additive.

## Firebase: admin & feature flags
The admin side from the PRD: email verification, admin roles, and per-user feature flags
(admins enable/disable features per user). Builds on the Firebase Auth that already ships in
Epic 2; keep it behind the same kind of interface boundary as the storage layer.

## JS-module marketplace
Runtime-loaded JS modules distributed via a Firebase-backed marketplace — the PRD's
extensibility story. Needs a module runtime, a distribution/marketplace surface, and a safe
extension API into the engine. Large; its own multi-epic effort.

## Additional view modes
More renderers in the Epic 4 view system — calendar (group/place by a date field), gallery
(image-forward cards), maybe timeline. Each is an additive mode, not a rewrite, because Epic 4
separates query/grouping from rendering.

## Shared workspaces & multi-user collaboration
Sharing a workspace with other accounts (Firebase Storage rules already make this possible —
Epic 2 lays the path layout for it) and, beyond that, real-time or merge-based collaboration
past Epic 2's single-user conflict handling (e.g. CRDT/operational merge, presence). Granting
access is the near step; live merge is the significant one and depends on a firmer sync
foundation.

## Template sharing
Promote Epic 7's local templates into shareable/published templates (overlaps with the
marketplace).
