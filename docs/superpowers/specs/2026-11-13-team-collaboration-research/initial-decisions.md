# Team collaboration + sharing views — conductor decisions (input for spec + mockups)

Owner ask (2026-11-13): "Refine next task: collaboration with team, sharing views by link or email.
Not implement, just imagine design (maybe several variants) and think about architecture, tech
decisions and limitations. Use Claude Design… Fill doc with superpowers for the future
implementation." Owner is away; every call below is "my call" unless it is listed under OWNER DECISIONS.

Research digests (read them, they hold the file:line evidence): data.md, ui.md, features.md,
firebase.md, product.md in this folder.

## The product model (recommended = Variant A + B, phased; C and D documented as alternatives)

Two layers, like Notion/Airtable:

1. **Team workspace (live, signed-in).** A workspace gets a name and a member list. Roles:
   - **Owner** (one; the workspace creator; delete workspace, AI consent, billing-type decisions)
   - **Admin** (invite/remove up to Admin, schema, views, automations, modules, templates, import, publish links)
   - **Editor** (cards only: create/edit/delete cards; personal view prefs; run button automations under own consent; use Ask Morkva with editor grants; copy teammate links)
   - **Viewer** (read everything; personal view prefs; Ask Morkva read-only; copy teammate links)
   - Commenter deferred until the comments feed exists (owner memory: feed planned).
   Every member sees every collection (no per-collection scoping in v1 → references/lookups/calculated
   fields keep working; field hiding on live data is impossible with Firestore rules anyway).
2. **Share a view.**
   - **With teammates:** "Copy link" → `https://<origin>/w/{wid}/collections/{cid}?view={viewId}` — live,
     opens only for members (non-members get "Request access"-less screen: "You don't have access — ask
     <owner> to invite you").
   - **With outsiders: publish the view** as a read-only **published copy** (projection): only the
     view's visible fields, only the rows that pass its filters, reference chips as titles only,
     calculated values materialized. Audience:
     - "Anyone with the link" (no sign-in), or
     - "Only people I add" (email allow-list; they sign in with Google; rules check
       `request.auth.token.email in emails && email_verified`). This is "share by email".
     Settings: expiry (Never / 7 days / 30 days / date), "Show Download CSV" (off; helper "Viewers can
     still copy what they see"), Regenerate link, Unpublish. Status line "Updated 3 min ago · Update now".
     Refreshed by members' clients (Admin/Editor) — on publish, on "Update now", and debounced ~10 s after
     a change to that collection while any editor has the app open. Outsiders see "Updated <time>".

**Invite by email (no server):** the invite doc IS the grant. Admin types emails + role → we write
`invites/{id}` docs → the invitee sees the invite in-app after Google sign-in with that email (banner +
switcher entry). Delivery is the sender's own channel: "Copy invite link", "Email it" (prefilled
`mailto:` via url_launcher), native share sheet (share_plus on mobile). Honest copy: "Morkva doesn't send
emails yet — we'll open your email app." Plus one resettable **invite link** per workspace carrying a role
(default Viewer), expiry (7 days default), optional "Only emails from @domain".

**Workspace switching:** sidebar wordmark area becomes a workspace switcher (name + role pill); menu lists
"Your workspace", "Shared with you" (workspaces you joined), pending invites ("Join"), "Create… " NOT in v1.
Personal workspace id stays = owner uid (no migration; owner memory says no clients, breaking is fine
anyway). Joining someone's workspace never deletes your own.

## Architecture (Spark plan, no Cloud Functions)

- `workspaces/{wid}`: `{name, ownerUid, counters, createdAt}`. Editors may update only `counters`
  (`affectedKeys().hasOnly(['counters'])`). Pins move off it.
- Roster: reuse `workspaces/{wid}/members/{uid}` (doc itself is unused today; per-member subtrees already
  live under it): `{uid, email(lowercase), name, photoUrl, role, joinedAt, invitedBy, inviteId}` +
  member-private `prefs` subdocs (pins, per-collection view prefs: collapsed groups, last view).
  Owner's own member doc is created on first boot (owner = `wid == uid` also accepted by rules).
- Invites: `workspaces/{wid}/invites/{id}` `{kind:'email'|'link', email?, domain?, role, invitedBy,
  createdAt, expiresAt}`; link invites use a 128-bit random id as the token in the URL
  `/join/{wid}/{token}`. Accept = the invitee creates their own `members/{uid}` doc with `inviteId`;
  rules `get()` the invite and check email match (or link validity/domain) and `role == invite.role`.
  Email invite is deleted on accept; link invite stays until reset/expiry.
- Discovery ("Shared with you", pending invites): collection-group queries
  `collectionGroup('members').where('uid','==',me)` and
  `collectionGroup('invites').where('email','==',myEmail)` + CG rules + CG single-field index overrides.
- Rules: `role(wid)` helper = `get(members/$(auth.uid)).data.role` (owner shortcut `auth.uid == wid`);
  canRead / canEditCards / canAdmin. 10/20 get() budget → W0 emulator spike for 450-write batches.
- Cards gain `createdBy`, `updatedBy` (rule: `updatedBy == request.auth.uid`); saveObject writes them
  (whole-doc set would otherwise drop them).
- Conflict model hardening for two humans: inline table/board edits send only changed keys (field-level
  merge, like the editor already does); edit of a card deleted by a teammate must not resurrect it
  ("Deleted by Ann" instead); conflict banner names the other member. Presence ("Ann is editing") = later.
- Views: shared definitions stay in the collection doc (Admin writes). Per-member prefs
  (collapsed groups, active view, ad-hoc sort/filter) go to `members/{uid}/viewPrefs/{cid}`. Viewers and
  Editors get "Save as new view" only if Admin.
- Published views: public doc `shares/{token}` `{wid, collectionId, viewId, title, columns[], audience:
  'link'|'emails', emails[], expiresAt, allowDownload, rowCount, chunkCount, generatedAt, generatedBy}`
  + `shares/{token}/chunks/{n}` (rows, ≤ ~800 KB each). Rules: `allow get` (expiry + audience check),
  `allow list: if false` on `shares`; chunks readable under the same check via `get()` of the parent.
  Workspace-side registry `workspaces/{wid}/publishedViews/{token}` (members read, admins write) powers
  the "Shared links" list and the refresher. Public route `/s/{token}` sits OUTSIDE the auth gate,
  `noindex`, "Report abuse" mailto, Morkva footer "Made with Morkva".
- Routing: path URL strategy; routes gain a workspace segment `/w/:wid/...` (unprefixed = current
  workspace); `/join/:wid/:token`, `/s/:token` public; preserve `next` through `/sign-in` and `/loading`
  (today a cold deep link is lost — lands on `/`).
- Session: workspace switch = the sign-out teardown + sign-in boot with the new wid (all singletons
  re-bind; AutomationRunner needs reset()). Sign-out and "removed from workspace" purge the local cache
  (`terminate()` + `clearPersistence()`); a membership-doc listener detects removal.
- Automations: author/edit = Admin; consent stays per member (code-hash pinned); fix `_pause` (members may
  update only pause keys); run log readable by Admin or own runs; prune/expire only own runs or Admin.
  UI shows "Runs for members who allowed it".
- Ask Morkva: `config/assistant` write = Owner only; role → `Grants` mapping (viewer = schema:read,
  data:read, ui:navigate); per-member daily turn counter (advisory). Outsiders: no assistant.
- Files (Storage, deferred): path `workspaces/{wid}/files/...` + storage.rules cross-service
  `firestore.get()` membership; download URLs are bearer tokens (removed member keeps old URLs) — limitation.

## Limitations to state plainly
- No field/row privacy on LIVE data for members (rules can't hide fields) → teammates see everything;
  outsiders only ever get the published copy.
- Published copies are stale while no editor has the app open (Spark has no server).
- No emails sent by Morkva on Spark (email-link sign-in: 5/day on Spark + needs Email/Password provider;
  Trigger Email extension needs Blaze and Extensions shut down 2027-03-31).
- Public links read from the project's Spark quota (50k reads/day); a scripted loop can exhaust it for
  every user that day → App Check enforcement (needs Android/iOS registered first) + chunked docs; "Anyone
  with the link" is a conscious risk.
- Offline cache keeps a removed member's data on their device until purge runs; download URLs persist.
- Firestore transactions fail offline → card creation with auto-numbers is online-only already; more
  contention on the workspace `counters` doc with many editors.
- Last-write-wins per field remains; no real-time co-editing/CRDT.
- Google sign-in only: invitees need a Google account (can be created for any email address).
- Dynamic Links are dead → App Links / Universal Links via Hosting `.well-known` (owner step: Hosting).

## Variants (document all; mockups show the share-surface variants)
- **Arch A — Team workspace only** (live, all members see all).
- **Arch B — Published views** (projection copies for outsiders by link/email) — on top of A.
- **Arch C — Collection guests** (live, per-collection grants, `collectionId in member.collections`;
  breaks references/lookups to hidden collections; schema docs leak names) — deferred.
- **Arch D — Blaze + Cloud Functions**: callable `getSharedView(token)` renders the view LIVE with the
  Admin SDK (exact filters + field projection, no snapshot staleness), invite emails via SMTP, custom
  claims for roles (cheaper rules), rate limiting. ~$0–5/month at small-team scale. Replaces B's client
  refresher; same UI.
- Recommendation: A then B on Spark now; D as the upgrade path when the owner moves to Blaze (Storage
  already needs Blaze at project end).

UI share-surface variants (for mockups):
- **UI-1 "One Share button" (recommended):** collection header "Share" (between Customize and + New)
  opens an anchored 400-px popover (phone: bottom sheet): top "Invite to <Workspace>" email field + role;
  "People with access" (facepile + "Manage team"); "Link to this view" section with General access
  select: "Team members only" (live link) / "Anyone with the link" / "Only people I add" (published copy),
  with the published-copy settings collapsed beneath; footer "Copy link".
- **UI-2 "Two doors":** header Share opens a 560 dialog with tabs "Teammates" | "Publish view".
- **UI-3 "Minimal":** no header button; "Share view…" in the view tab's ⋯ menu only; team lives in
  Settings › Team; invite only from there.

## OWNER DECISIONS (the spec must list these up front, each with my recommendation)
1. Stay on Spark (client-refreshed published copies, no emails) or move to Blaze now (Arch D)?
   Rec: Spark now, D when Storage forces Blaze.
2. Allow anonymous "Anyone with the link" at all, given the shared daily quota risk? Rec: yes, behind
   App Check enforcement; until then, require Google sign-in for published views.
3. Public origin/Hosting for links (`morkvacrm.web.app` vs custom domain) — owner deploy step.
4. Role set (Owner/Admin/Editor/Viewer) — rec as above; Commenter with the feed.
5. Per-collection guests (Arch C) — rec: defer until asked.

## Files to produce
- Spec: `docs/superpowers/specs/2026-11-13-team-collaboration-design.md` (worktree
  the repo).
- Mockups canvas (Claude Design): artboards written to
  (session scratch)
  and later copied to `docs/superpowers/mockups/collaboration/`.
