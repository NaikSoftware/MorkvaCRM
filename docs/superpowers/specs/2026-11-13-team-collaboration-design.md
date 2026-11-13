# Team collaboration & view sharing — design

Owner ask (2026-11-13): "Refine next task: collaboration with team, sharing views by link or email.
Not implement, just imagine design (maybe several variants) and think about architecture, tech
decisions and limitations. Use Claude Design… Fill doc with superpowers for the future
implementation."

**Status:** Design only — not implemented; mockups: Claude Design canvas https://claude.ai/artifact/ErurPzfo3C5h3PDgAREHAJ (copies in docs/superpowers/mockups/collaboration/)

**Date:** 2026-11-13 · Written while the owner was away. *my call* marks a decision taken without an
approval round-trip (owner preference "work autonomously"); **[verify in W0]** marks a platform claim
that was not run and must be proven on the emulator before the build depends on it; **[V]** marks a
fact read in code or in the Firebase docs. Code anchors are `path:line` on `main` @ 3e754b8; most are
relayed from the research digests in [`2026-11-13-team-collaboration-research/`](2026-11-13-team-collaboration-research/) (data/ui/features/firebase/product), and the ones this doc leans on
hardest (`app.dart` bind/unbind, router redirect, `saveObject`, `moveToGroup`, the editor banners,
`_pause`, capabilities, rules) were opened while writing it.
The canvas and this doc tell one story (fixture below). Where a mockup and this doc disagree on
copy or layout, **the mockup wins** and this doc is updated — **except** for the items in
"Mockup redraws" (end of §6): there the review round changed the product, this doc won, and
the artboards were redrawn on 2026-11-13 and re-checked by an independent critic (16 artboards).

Fixture used by every example and artboard: workspace **Morkva Wear** (owner **Olena Koval**,
olena@morkvawear.com); **Taras Melnyk** Admin; **Iryna Bondar** (iryna.bondar@gmail.com) Editor;
**Max Shevchenko** (max.shevchenko@gmail.com, staff) Viewer; pending invite nadia@morkvawear.com as
Editor (`Switcher` is drawn from Olena's side — other workspaces she joined and an invitation from
another shop; `PhoneInvitation`/`PhoneJoin` from Nadia's side). Client **Sunflower Studio** is never a member: its people (sales@sunflower.studio,
anna@sunflower.studio) appear only in the published copy's "Only people I add" list. A stranger
signed in with the wrong account is **ivan.p@gmail.com**.
Collection **Orders**; views "All orders", "Open orders" (board by Status), "For Sunflower Studio"
(Order #, Item, Size, Status, Due; Total and Phone hidden; filter Customer is Sunflower Studio).

**FLAG — where this spec departs from the initial decisions brief** ([`2026-11-13-team-collaboration-research/initial-decisions.md`](2026-11-13-team-collaboration-research/initial-decisions.md)) (each for a reason in the section named):
- `shares/{token}` is split into a public **stub** (gating fields only) + `viewers/{email}` +
  `gens/{gen}` + `chunks/{n}` instead of one doc with `columns`/`emails[]` — the stub lets the outsider
  page tell expired/off/needs-sign-in/no-access apart, generations prevent torn reads (§8, §10.8).
- Email audience is proven with `exists(viewers/<email>)`, not `email in emails[]` — a readable
  array would leak the list to every link holder (§9).
- `/w/:wid/…` is an entry **redirector**, not a prefix on every route (§10.2).
- Cache purge = local flag + reload (web) / next cold start (mobile), not `terminate()` in place,
  until W0 proves in-process re-use (§10.9).
- No owner name on the non-member screen and no deleter name on a deleted card — neither has a
  readable source (§6, §10.6).
- Invite links grant Editor or Viewer only; Admin only by email invite (§9).
- Viewer's assistant grants include `modulesRead` (to explain buttons it can't run) (§7).
- Board drag by Editors moves cards between groups but never writes the shared `manualOrder` (§6).
- After the review round (see "Review log"):
  - The share popover has **no inline workspace invite** (the initial brief's UI-1 put one at the
    top). Typing a client's email there made them an Editor of everything; it is now a text button
    that opens the Invite sheet, and the default role is Viewer everywhere (§6).
  - The single "General access" select became a fixed **Teammates** row plus a **Published copy**
    select, so the teammate link stays copyable while a copy is published (§6).
  - Published copies use a **frozen definition** (filters/sort/grouping copied into the registry at
    publish), so editing the live view never changes what outsiders see (§8, §10.8).
  - Stubs are **never deleted**: Unpublish turns them into tombstones first, so nobody can re-create
    an old token (§9).
  - The roster doc carries no invite token (`inviteId` moved to the member-private
    `prefs/join`) and no `lastWorkspaceId` (moved to `prefs/session`) (§8).
  - Signed out, the invite and outsider pages are **generic** (no workspace, inviter or role): the
    `invites` and `shares` stubs are readable only when signed in (§6, §9).
  - Everyone's sort/filter edits go to personal prefs; Admins promote them with "Save for everyone"
    (§10.7).

---

## 2. Owner decisions needed

Everything else in this doc is decided. These five change cost, exposure or scope, so they are the
owner's. Each has my recommendation; the build can start on the recommendation and switch later.

1. **Stay on Spark, or move to Blaze now (Approach D)?**
   *Recommendation: Spark now; D when Storage forces Blaze at project end.*
   - Spark (recommended): published copies are refreshed by members' open apps (stale when nobody
     on the team has Morkva open), Morkva sends no emails (invites go through the sender's own email
     app / share sheet), roles are read from Firestore in rules (one billed read per checked request).
   - Blaze: add W6 (Approach D) — a callable `getSharedView(token)` renders the view live, a
     Firestore-triggered function emails invites over SMTP, custom claims carry roles. UI unchanged;
     the client refresher (§10.8) and its lease are deleted. ~$0–5/month at small-team scale + budget
     alerts (they do not cap spend).
2. **Allow anonymous "Anyone with the link" at all?** Context first: the Spark read quota (50k
   reads/day, project-wide) can **already** be exhausted by any Google user, whatever the answer —
   every account that signs in owns a personal workspace and can loop reads on it, and even reads
   denied by rules are billed. The real control is App Check enforcement plus a budget-guarded Blaze
   plan (decision 1). Anonymous links add only the "no account needed" delta.
   *Recommendation: yes, but only after App Check is enforced on Firestore (needs Android and iOS
   registered in App Check first). Until then the build ships `kAnonymousLinks = false`: "Anyone
   with the link" means "anyone with the link who signs in with Google" (copy: "Read-only copy · any
   Google account").* With the constant off, **no signed-out request can read any document**:
   `shares/{token}` stubs are `get`-able signed out only when `signInRequired == false`, and
   `invites/{id}` only when signed in (§9), so the signed-out landing pages are generic ("Sign in to
   open this link"). An Admin with a modified client could still write `signInRequired: false`.
   - Yes now: flip the constant; accept the delta.
   - Never: drop the "Anyone with the link" option; published copies are email-list only.
3. **Public origin for links + Hosting.** Links look like `https://<origin>/s/<token>`,
   `/join/<wid>/<id>`, `/w/<wid>/collections/<cid>?view=<id>`. Needs a Hosting deploy (SPA rewrite,
   `noindex` headers, `.well-known` for app links) and an abuse mailbox for "Report abuse".
   *Recommendation: `morkvacrm.web.app` now, custom domain later; abuse address = the owner's support
   email.* Changing the origin later breaks every sent link (tokens survive; the host does not).
4. **Role set: Owner / Admin / Editor / Viewer.** *Recommendation: exactly these four; add Commenter
   with the planned card comments feed.* A fifth role (e.g. "Editor without delete") is one enum value
   + one rules helper + one matrix column.
5. **Per-collection guests (Approach C).** *Recommendation: defer until a user asks.* If wanted now:
   +1 wave, the reference/lookup breakage in §5.C, and the schema-name leak are accepted.

---

## 3. Intent & why

Morkva today is one person's workspace: `workspaceId == uid` everywhere (`firestore.rules:14-16`,
`lib/api/workspace/workspace_resolver.dart:19`). Small businesses are rarely one person: the owner
wants a seamstress to move orders along, a partner to change fields, a client to see "their" orders.
Two different needs hide in "sharing":

- **Teammates** work *inside* the workspace, live, signed in — they need roles.
- **Outsiders** (clients, suppliers) need to *see a slice* — one view, some fields, some rows — and
  must never see the rest. Firestore rules cannot hide fields of a readable document and cannot
  filter rows by a view [V: rules-fields, rules-query docs], so an outsider can only ever get a
  **published copy** written for them.

### Goals
- G1. Invite people to a workspace by email or by an invite link, with a role; they join with Google.
- G2. Four roles enforced by security rules, mirrored by the UI (nothing offered that rules reject).
- G3. "Copy link" to any view that opens live for teammates — for every role, published or not.
- G4. Publish a view as a read-only copy for outsiders: by link, or only for listed emails.
- G5. One place that lists every member, pending invite, invite link and published link.
- G6. Switch between your own workspace and the ones you joined, without signing out.
- G7. Two people editing at once never silently lose a change or resurrect a deleted card.
- G8. Works on Spark (no Cloud Functions); Blaze is a clean upgrade, not a rewrite.

### Non-goals (v1)
- Real-time co-editing of one field (CRDT), presence/cursors, comments, notifications.
- Creating additional workspaces; transferring ownership; per-collection or per-field access for
  members; audit log; SSO/domain auto-join; seat billing.
- Morkva sending email.

### Anti-goals (must never happen)
- A **teammate link** that opens data for someone who is not a member. Teammate links carry no
  capability: they are plain routes behind the auth gate + membership rules.
- **Hidden fields that aren't hidden.** A field hidden in a published copy must not be anywhere in
  what the outsider downloads — not in a column, not in a reference id, not in a JSON key. On live data
  we never *claim* hiding: members see every field, and the UI never offers "hide from teammates".
- An outsider enumerating published copies (`list` is denied everywhere; tokens are 128-bit).
- A removed member keeping *server* access (their client cache is a stated limitation, not a goal).
- Any member opting the whole team into AI data processing (owner only).
- A share link indexed by search engines (`X-Robots-Tag: noindex` on `/s/**` and `/join/**`).

---

## 4. Vocabulary

| Term | Meaning |
|---|---|
| **Workspace** | `workspaces/{wid}`: collections, cards, views, automations. v1 invariant: every workspace is a user's personal one, so `wid == ownerUid`. A team = someone's workspace with members. |
| **Member** | A user with a roster doc `workspaces/{wid}/members/{uid}`. The owner has one too (created on first boot). |
| **Role** | `owner` · `admin` · `editor` · `viewer`, a field on the member doc. Matrix in §7. |
| **Invite** | `workspaces/{wid}/invites/{id}` — the grant itself. `kind: 'email'` (one person, deleted on accept) or `kind: 'link'` (the invite link). |
| **Invite link** | The one reusable `kind:'link'` invite per workspace: `https://<origin>/join/{wid}/{id}`; carries a role, an expiry, optional email domain. Reset = new id. |
| **Teammate link** | `https://<origin>/w/{wid}/collections/{cid}?view={viewId}` — a live deep link; opens only for members. |
| **Published copy** | A read-only projection of one view written for outsiders: only the chosen fields, only the rows its **frozen definition** passes (the view's filters/sort/grouping copied at publish time), references as titles, calculated values as values. User-facing nouns *my call*: "published copy" for the thing, "public link" for its URL, "Shared links" for the list page. ("Published view" appears nowhere in the UI.) |
| **Token** | 128-bit random id (22 chars base64url, `Random.secure()`) of a published copy: `shares/{token}`; also the id of every invite. The token *is* the capability. A used share token is never reusable: its stub becomes a tombstone on Unpublish. |
| **Audience** | Who may open a published copy: `link` (anyone with the link; sign-in required while `kAnonymousLinks == false`) or `emails` (only listed emails, Google sign-in). |
| **Generation (gen)** | One complete written version of a published copy: `shares/{token}/gens/{gen}` + its chunks. The stub points at the current gen; refresh writes a new gen and flips the pointer. |
| **Refresher** | Client service on Admin/Editor devices (`PublishRefresher`) that rebuilds a published copy after changes. One device at a time holds its **lease**. |
| **Registry** | `workspaces/{wid}/publishedViews/{token}` — the members-side record of a published copy (settings, frozen definition, freshness, lease). Powers Shared links and the refresher. |

---

## 5. Approaches

Three things vary: what access attaches to (workspace / view / collection), whether the reader sees
live data or a copy, and who computes the copy (client vs server).

### A — Team workspace (live, members see everything)
- Roster docs under the workspace; rules swap `isWorkspaceOwner` for role helpers (the swap the rules
  header already plans, `firestore.rules:3-10`). Paths do not change.
- Every member reads every collection and card, live, with offline cache. References, lookups,
  calculated fields and the assistant keep working because nothing is partially visible.
- Trade-offs: simplest; real-time; but "share with a client" is impossible — a Viewer still reads
  every field of every card (rules cannot hide fields).
- Spark: **yes**. Cost: +1 billed read per checked request for non-owners (the member-doc `get()`).

### B — Published views (projection copies for outsiders), on top of A
- An Admin publishes a view; members' clients write a projection to `shares/{token}` (+ gens/chunks).
  Rules: `get` only, never `list`; expiry and audience checked from the stub; email audience proven
  by an `exists()` on a per-email doc so the list is never readable.
- Trade-offs: hiding is *real* (the data is simply not in the copy); outsiders need nothing installed;
  but the copy is **stale while no Admin/Editor has the app open**, read-only, and each refresh costs
  writes. Hiding is enforced by whichever member's client writes the copy — an Editor with a modified
  client could publish anything they can read (they could also just paste it into an email).
- Spark: **yes** (freshness is the weak spot). Cost per outsider open ≈ 1 (stub) + 2 (gen + rules
  get) + 2 × chunks (+1 per request for the email `exists()`): a 3-chunk view ≈ 9–12 reads.

### C — Collection guests (live, per-collection grants) — deferred
- `members/{uid}.collections: [cid…]`; object rules check `resource.data.collectionId in
  member.collections` (provable against the existing `where collectionId ==` query,
  `firestore_refs_impl.dart:57-62`).
- Breaks: `watchCollections()` lists the whole `collections` subcollection
  (`firestore_data_repository.dart:194-210`) → must become `documentId in [≤30]` or every schema
  readable (then hidden collections' names, fields and options leak); references/lookups/aggregates
  into a hidden collection stay **blank forever** (`derivation.dart:25-27` treats a missing source as
  loading); one denied listener flips the app-global sync indicator to error
  (`firestore_data_repository.dart:353-355`); a required reference into a hidden collection makes card
  creation impossible; run logs and assistant threads leak across.
- Still no field hiding — a guest who needs field hiding needs B anyway.
- Spark: partly. Deferred (owner decision 5). If built: mark calculated fields "Restricted" via the
  existing `readsUngranted` (`query_engine.dart:910-930`), chips as "Restricted card", and refuse a
  scope that excludes a dependency (`Derivation.sourcesOf`).

### D — Blaze + Cloud Functions (upgrade path)
- Callable `getSharedView(token)`: Admin SDK reads the live collection, applies the view (shared Dart
  logic ported to TS, or the snapshot builder compiled for Node — *my call:* port `applyView` +
  projection, ~400 lines, with golden fixtures shared between both implementations), returns only
  the projected rows. No staleness, no chunks, no client refresher, App Check on the callable,
  per-IP rate limiting.
- `onCreate(invites/{id})` sends the invite email over SMTP (one small function; **not** the Trigger
  Email extension — Firebase Extensions shut down 2027-03-31 [V]).
- Custom claims `{w: {wid: role}}` (≤1000 bytes) → rules check claims instead of `get()`; cheaper,
  no 20-access batch ceiling. Claims lag one token refresh (≤1 h or forced `getIdToken(true)`).
- Same UI; Shared links loses "Update now" and "Updated 3 min ago". Cost ~$0–5/month for 10 users
  (≈200k reads/day → ≈$1.5/month reads; functions within the free 2M invocations).

### Recommendation
**A → B now on Spark; D as the upgrade when Blaze arrives; C deferred.** A is the foundation every
other approach needs and maps onto the rules swap already planned. B is the only Spark-feasible way to
give outsiders a real slice. C costs a wave, degrades the core experience (blank aggregates, empty
pickers), and still cannot hide fields. D removes B's two weak spots (staleness, emails) at a small
bill and is additive.

---

## 6. UX

All surfaces reuse existing components: anchored popover `showViewPopover`
(`lib/features/views/widgets/view_popover.dart`; wide = hangs from the anchor, phone = bottom sheet),
responsive sheet `showAutomationSheet` (`lib/features/automation/view/consent_sheet.dart:22-55`;
560 dialog on wide, bottom sheet on phone), `MorkvaConfirmDialog`, `ListTileCard`, `OptionPill`
(role pills), `UserAvatar` (`lib/app/shell/shell_sidebar.dart:802-890`; other people get a tint from
the 8 collection tint pairs hashed by uid, the signed-in user keeps the leaf disc), snackbars at 480 px
with `persist:false` + 5 s (memory "Snackbar persist trap"). Sentence case, ≥44 px targets.

### Share-surface variants

| | UI-1 "One Share button" (**recommended**) | UI-2 "Two doors" | UI-3 "Minimal" |
|---|---|---|---|
| Artboard | `Main` | `VariantTwoDoors` | `VariantMinimal` |
| Entry | OutlinedButton `person_add` "Share" in the collection header between "Customize" and "+ New order", with a 3-avatar facepile before it | Same header button | No header button; "Copy link for teammates" and "Publish view…" in the active view tab's ⋯ menu (`view_tabs.dart:123-139`) |
| Surface | 400-px anchored popover (phone: bottom sheet) | 560 dialog with tabs "Teammates" \| "Publish view" | 560 dialog for publishing; team only in Settings › Team |
| Invite | Text button "Invite to Morkva Wear…" → Invite sheet (was: inline email field — removed in review) | "Teammates" tab | Settings › Team only |
| Pros | One place for who has access and what the link does | Clear split between live access and public copy; room for settings; a workspace invite can't be mistaken for sharing this view | Least UI, no header clutter, nothing to learn until needed; no path from a client-facing view to a workspace invite |
| Cons | Dense popover; two kinds of email entry with different reach (workspace vs this copy) — must be separated visually; the teammate link must stay copyable while published | Extra click to see members; two surfaces to learn | Sharing is undiscoverable; inviting from a view impossible |

*my call:* **UI-1, conditional on the invite fix.** Prior art is split: Notion/Drive invite to the
page itself, while Airtable — the closest model — keeps base collaborators ("Share") apart from a
view's share link ([`2026-11-13-team-collaboration-research/product.md`](2026-11-13-team-collaboration-research/product.md) §1). In Morkva an email typed into Share would grant the **whole
workspace**, so UI-1 keeps one Share button but takes the workspace invite out of the popover's
input row: the popover's only email field is the published copy's allow-list.

### Share popover (UI-1) — artboards `Main`, `PublishPeople`, `Dark`

Opened from the header "Share" (wide: icon-only below 720 content width, `_narrowContent`
`collection_views_page.dart:56`, semantics label "Share “For Sunflower Studio”"; phone: **only** the
first item of the `more_vert` menu, "Share…" with the `person_add` icon — no extra AppBar button,
`_PhoneFrame` already has five trailing actions). The view in the title is the **active** view tab.
Summary views can't be published: their popover shows only rows 1–3 plus the helper "Summary views
can't be published yet." Calendar and list views publish as a table sorted by the date/sort field.

Layout, top to bottom:
1. Title "Share “For Sunflower Studio”" (titleMedium) + close ×.
2. **People with access**: facepile (OK TM IB MS, semantics "4 members: Olena Koval, Taras Melnyk,
   Iryna Bondar, Max Shevchenko; 1 pending invite") "4 members · 1 pending" + text button
   "Manage team" (→ `/settings/team`). Admin/Owner also get a text button "Invite to Morkva Wear…"
   that opens the Invite sheet (§ Invite dialog). Solo owner: "Only you" + "Invite to Morkva Wear…".
   There is **no email field for workspace invites in the popover** (review fix: typing a client's
   address there made them an Editor of every collection).
3. Divider. **Teammates** row, always shown, every role: lock icon · "Teammates" / "Opens live, for
   members of Morkva Wear" · trailing text button "Copy link" → snackbar "Link copied".
4. **Published copy** row (Admin/Owner): public icon · "Published copy" · select:
   - "Off" (default) — no copy;
   - "Anyone with the link" — "Read-only copy · any Google account" (while `kAnonymousLinks` is
     false; "Read-only copy · no sign-in" after it flips);
   - "Only people I add" — "Read-only copy · they sign in with Google".
   Setting it to "Off" on a published copy runs the Unpublish confirm.
5. **Published-copy block** (quiet fill `surfaceContainerLow`, radius 12), only when the select is
   not Off:
   - Summary "5 of 8 fields · 5 orders · filters locked" + text button "Choose fields". The counts
     come from the **saved** view (not yet published) or the registry's frozen definition
     (published) — never from what is on screen. When a transient filter or personal pref is
     active on the page: warning line "Temporary filters aren't published — the copy will show 42
     orders." + text button "Save as view first" (the existing "Save as view" action).
   - Published and the live view's filters/sort/grouping differ from the frozen definition: info
     line "The view changed since you published it." + text button "Update the copy" (a settings
     change; confirm below when it adds rows or fields).
   - "Only people I add": email chips input "Add emails" (lower-cased on entry; invalid →
     "Check this email address"; max 50 *my call*), each chip with ×. Helper under the chips:
     "Morkva doesn't email them — send the link yourself. They sign in with Google as that
     address." After publishing (or adding a chip to a published copy) each new chip gets "Email it"
     (mailto subject `Morkva Wear shared “For Sunflower Studio” with you`, body `Open this link and
     sign in with Google as <email>:\n<link>`) and "Share…" on Android/iOS. With zero emails the
     primary is disabled with helper "Add at least one email."
   - "Expires" select: "Never" / "In 7 days" / "In 30 days" / "On a date…" (default Never).
     Expired: "This link expired on 30 Nov." + the select acts as "Extend".
   - Switch "Show Download CSV" (off) + helper "People with the link can still copy what they see."
   - Status line (published): "Updated 3 min ago · Update now"; while refreshing "Updating…"; on
     error "Couldn't update — Retry".
   - Text buttons "Regenerate link" · "Unpublish" (error tint).
   - Info line (always, once published): "Copies refresh while an admin or editor has Morkva open."
   - Forced columns note when applicable: "Status is shown because the board groups by it."
   - Size note: "This view has 6,240 orders. The copy shows the first 5,000."
6. Footer: hint — Off: "Teammates can open every field of every card."; copy options: "Hidden fields
   stay hidden. Linked cards show their title only." Primary:
   - Off → no primary (the Teammates row has "Copy link").
   - Copy option, not yet published → "Publish and copy link".
   - Published → "Copy public link".
   Clipboard writes need fresh user activation on the web (Safari/Firefox reject late writes), and
   the token is generated on the client, so **the link is written to the clipboard synchronously in
   the click handler, before any await**; snackbar "Link copied · publishing…", then "Published", or
   on failure a persistent "Couldn't publish — Retry" with a "Copy link" button. Regenerate does
   the same ("New link copied · publishing…").
7. Settings on a published copy save on change (no Save button) when they **narrow** exposure
   (untick a field, shorter expiry, "Only people I add" from "Anyone", remove an email). Changes
   that **widen** it ask first (`MorkvaConfirmDialog`):
   - audience → Anyone: "Let anyone with the link open this copy?" / "The 2 people you added keep
     access, and so does anyone they forward it to." / "Allow";
   - adding a field: "Add Phone to the copy?" / "Everyone who can open the link will see it within a
     minute." / "Add field";
   - expiry → Never, or "Update the copy" that adds rows: "Show 42 orders in the copy?" / same body
     as above / "Update copy".

States:
- **Non-admin (Editor/Viewer)**: rows 2 and 3 only, row 2 as "4 members" with no pending count (and
  no "; 1 pending invite" in its semantics label) — `invites` is `list: canAdmin`, so `ShareCubit`
  subscribes to it only when `role.canManageTeam`; if the view has a published copy, a read-only
  row "Published copy · Anyone with the link · Updated 3 min ago" with "Copy public link" (+ "Update
  now" for Editors, who may refresh, §7); hint "Only admins can publish views."
- **Offline**: Invite/Publish/Update now disabled; helper "You're offline — connect to share."
  ("Copy link" still works.)
- **Choose fields** (nested popover page with back arrow, "Fields in the copy"): checkboxes of the
  view's visible fields only (hidden-in-view fields are not offered), the board's group field and the
  calendar date field locked on with the note above; reference fields labelled "Customer (title only)";
  calculated fields "Total (value only)"; file fields "Attachments (file names only)".
- **Unpublish confirm** (`MorkvaConfirmDialog`, destructive): title "Unpublish “For Sunflower
  Studio”?", body "The link stops working for everyone right away. You can publish again later — with
  a new link.", confirm "Unpublish". Snackbar "Unpublished". (True: the first write turns the stub
  into a tombstone, §10.8.)
- **Regenerate confirm**: title "Make a new link?", body "The current link stops working. People you
  sent it to will need the new one.", confirm "Make new link".
- **Published view tab**: a published view's tab shows a small `public` icon after its name
  (tooltip and semantics "Published · Anyone with the link" / "Published · 2 people"). Deleting a
  published view, or a collection with published views, adds "Deleting it also turns off its public
  link." to the delete confirm and unpublishes in the same flow.

### Team page — artboard `Team`

Route `/settings/team` (new; `ShellPlace` settings). Settings gets a "Team" `ListTileCard`
("Members, invites and roles", `group` icon) and a "Shared links" one ("Published copies of your
views", `public` icon) above the Automations card (`settings_page.dart:12-50`).
- Header: "Team" (headlineSmall) + subtitle "Everyone here sees every collection in Morkva Wear.
  Roles decide who can change what." + editable workspace name for Owner/Admin ("Workspace name"
  field, helper "Teammates see this name in their workspace switcher.", saves on blur, 1–60 chars,
  error "Give the workspace a name") + Primary "Invite people".
- **Members (4)**: rows avatar · name · email · role. Role select for Owner/Admin (Admin, Editor,
  Viewer, each with its one-line description; the owner's row shows a fixed "Owner" pill and the
  bodySmall line "You own this workspace, so you can't leave it." on the owner's own view) ·
  "Joined 12 Oct" (bodySmall) · ⋯ menu "Remove from Morkva Wear". Your own row says "(you)".
  - Role change → snackbar "Iryna is now a Viewer". Demoting a member whose `joinedVia == 'link'`
    shows the confirm "Make Max a Viewer?" / "He joined with the invite link and could rejoin through
    it at its role." + checkbox "Also reset the invite link" (on) / "Change role".
  - **Own role** (an Admin changing their own): confirm "Make yourself an Editor?" / "You'll lose
    admin access right away. Only Olena Koval or another admin can give it back." / "Change my role".
  - Remove confirm: title "Remove Iryna Bondar?", body "She loses access to Morkva Wear right away.
    Anything already on her devices stays there until they next go online.", checkbox "Also reset the
    invite link" (shown and **on** when an invite link exists — stops rejoining through an old link),
    confirm "Remove". Remove also deletes pending email invites addressed to her email.
  - Phone row: two lines, "Iryna Bondar" / "iryna.bondar@gmail.com · Joined 3 Oct", trailing role
    pill; tapping the row (Owner/Admin) opens a bottom sheet with the role choices (each with its
    description) and "Remove from Morkva Wear" in error tint.
- **Pending invites (1)**: email · role pill · "Invited by Olena · Expires in 6 days" · "Copy link" ·
  "Email it" · "Revoke". Expired invites show "Expired" + "Renew" (resets `expiresAt`). Pending rows
  whose email matches a member are hidden (and deleted by the next Admin who opens the page).
- **Invite link** card: "Anyone with this link can join as [Viewer ▾]" · "Expires [In 7 days ▾]"
  (1 day / 7 days / 30 days; no "never" *my call*: stale links are the top complaint in the prior
  art) · "Only emails from @[          ]" (optional, one domain) · buttons "Copy link", "Reset link",
  "Turn off". Off state: "No invite link" + "Create invite link". Expired: "This invite link expired
  on 20 Nov." + "Renew".
- Every non-owner (Admin included) gets, at the bottom, SecondaryButton "Leave Morkva Wear" →
  confirm "Leave Morkva Wear?" / "You'll lose access right away. To come back, you'll need a new
  invite." / "Leave" — plus ", or the team's invite link" when an invite link is on (a link-joined or
  link-holding member can rejoin through it, §11). After leaving: switch to the personal workspace, run the §10.9 purge (same
  path as removal, no "removed" dialog), snackbar "You left Morkva Wear".
- Editors/Viewers: read-only member list (no selects, no ⋯), no pending/link sections.
- Loading: skeleton rows. Error: "Couldn't load the team. Try again." + "Try again". Offline:
  banner "You're offline — changes are paused." and every action disabled.

### Invite dialog + delivery — artboard `Invite`

`showAutomationSheet` frame, opened from Team "Invite people" and from the share popover's
"Invite to Morkva Wear…". Step 1 "Invite people to Morkva Wear":
- Callout above the field (info tint): "Everyone you invite sees every collection, card and field in
  Morkva Wear. To show a client only one view, close this and publish a copy from that view's Share
  button."
- Chips input "Email addresses" (placeholder "name@company.com"; comma/space/Enter commits; paste of
  a list splits; max 20 per send).
- Role select, default **Viewer** from every entry point *my call* (the cautious default), with
  descriptions: Admin "Manage the team, collections, views and automations", Editor "Add, edit and
  delete cards", Viewer "See everything, change nothing".
- Inline row errors: "Check this email address" · "That's you — you're already in Morkva Wear." ·
  "Iryna Bondar is already a member" · "Already invited — sending again renews it". Row warning
  (warning tint, not blocking) when the email's domain matches no current member and isn't the
  owner's: "sunflower.studio isn't your team's domain. Sharing with a client? Publish a copy
  instead." — text button "Publish a copy" (closes the sheet; from the popover it switches the
  Published copy select to "Only people I add" with that email as a chip).
- Footer hint "They'll see the invite after signing in with Google as that email." + Primary
  "Invite 1 person". Offline: Primary disabled, helper "You're offline — connect to invite."

Step 2 "Send the invites" — shown only after the batch **commits on the server** (await
`commit()`; never from the cache), so a link sent right away always works:
- Info banner (info tint): "Morkva doesn't send emails yet — we'll open your email app."
- One row per email: "nadia@morkvawear.com · Editor" + "Copy link" + "Email it" (+ "Share…" on
  Android/iOS via `share_plus`).
- "Email it" = `url_launcher` `mailto:` (`pubspec.yaml:61`), prefilled:
  - subject `Join Morkva Wear on Morkva`
  - body `Hi! I've invited you to Morkva Wear as an Editor.\n\nOpen this link and sign in with
    Google using nadia@morkvawear.com:\nhttps://morkvacrm.web.app/join/<wid>/<id>\n\nThe invite
    expires on 27 Nov.\n— Olena Koval`
- Footer "Done". Snackbar on copy "Invite link copied".

### Invite landing — artboards `InviteLanding`, `PhoneJoin`

Route `/join/:wid/:id`, outside the auth gate (§10.2). Layout = sign-in page card
(`lib/features/auth/sign_in_page.dart`: centered `SurfaceCard`, max 400, padding 32; phone: no card,
full-width buttons). **Signed out the page is generic** — it names no workspace, inviter, role or
address (memory "Email-invite landing shows nothing before sign-in"): invite docs are readable only
signed in, and an email invite only by its own verified address (§9), so a forwarded link reveals
nothing. A denied `get` cannot tell "not for you" from "withdrawn", so those share one state.
State machine (`JoinCubit`), evaluated in this order:

| State | Detected by | Copy | Actions |
|---|---|---|---|
| Loading | — | skeleton | — |
| Signed out | auth state | "You've been invited to a Morkva workspace" / "Sign in with Google using the address the invite was sent to. You'll see who invited you, the workspace and your role once you're signed in." · footnotes "No Google account for this address? Create one with your current email." (link to Google's sign-up with an existing email) and "Signing in creates a free Morkva account. You don't have to use it." | "Continue with Google" (keeps `next=/join/…`) |
| Offline | the read fails with `FirebaseException.code == 'unavailable'` | "You're offline — connect to join." | Join disabled |
| Already member | own `members/{uid}` exists in `wid` (self-`get` is always allowed) | "You're already in Morkva Wear" | "Open Morkva Wear" |
| Unavailable | invite `get` denied, or not-exists with `!metadata.isFromCache` | "This invitation isn't for this account" / "It isn't for ivan.p@gmail.com, or it was withdrawn or replaced. Switch to the Google account it was sent to, or ask for a new invite." | "Switch account" · "Back to my workspace" |
| Expired | `expiresAt < now` | "This invite has expired" / "Ask Olena Koval for a new one." | "Go to Morkva" |
| Wrong domain | link invite with domain, email domain differs | "This link is for @morkvawear.com accounts" / "You're signed in as ivan.p@gmail.com." | "Switch account" |
| Ready | otherwise | "Join Morkva Wear" / "Olena Koval (olena@morkvawear.com) invited you as an Editor." | Primary "Join Morkva Wear" · text "Not now" |
| Join failed | accept batch rejected | "Couldn't join — the invite may have just changed. Try again." | "Try again" |

"Switch account" = sign out; on web sign-out reloads (§10.9) and the reload keeps the current URL,
so the user lands back on this page in the Signed-out state and picks the other account in Google's
picker.

Join = batch: create own member doc + own `prefs/join` proof + delete **every** email invite of the
caller to this workspace (the CG invitations query filtered to `wid`; for an email invite the accepted
one must be among them, §9), for both kinds — a leftover invite from a second Admin would otherwise
let a member who leaves rejoin through it → switch session to
`wid` → Home with snackbar "Welcome to Morkva Wear — you're an Editor". "Not now" → own workspace;
the invite stays in the switcher.

### Workspace switcher, other workspaces, invitations — artboard `Switcher`

- The sidebar `BrandWordmark` row (`shell_sidebar.dart`) becomes a 52-px button: 28-px tile with the
  workspace initial (tint hashed from wid) · name "Morkva Wear" (labelLarge) · role pill "Owner" ·
  `unfold_more`. *my call:* the wordmark leaves the sidebar (it stays on sign-in, join and public
  pages); its collapse action moves to a `left_panel_close` icon at the row end (36-px glyph,
  44×44 hit area).
- Rail: the workspace tile only (tooltip name + role).
- Menu (popover 320 wide):
  - "YOUR WORKSPACE" (caps label) — your personal workspace (check mark when current).
  - "OTHER WORKSPACES" — joined workspaces: tile · name · role pill. (Not "Shared with you": that
    phrase belongs to published copies on `/s/`.)
  - "INVITATIONS" — "Morkva Wear · Olena invited you as Editor" + "Join" / "Decline" (decline
    deletes the email invite after confirm "Decline the invite to Morkva Wear?").
  - Footer: "Manage team" (→ `/settings/team`) · "Shared links" (→ `/settings/shared-links`).
  - Offline: other workspaces disabled with subtitle "Connect to switch workspaces".
- Pending-invite banner on Home (top of All collections, info tint) for each invitation: "Olena Koval
  (olena@morkvawear.com) invited you to Morkva Wear as an Editor." + "Join" + "Not now" (hides the
  banner for this session; the switcher keeps it). The inviter's **email** is rule-verified (§9); the
  name is the inviter's Google name.
- Switching shows the `/loading` interstitial "Opening Morkva Wear…" and lands on Home (`/`). A failed
  switch: interstitial error "Couldn't open Morkva Wear. Check your connection and try again." /
  "Try again" · "Back to my workspace".
- Phone: switcher row at the top of Settings and as a header tap target on Home ("Morkva Wear ▾").
- Personal workspace default name `"<given name>'s workspace"` ("Olena's workspace"); the fixture's
  owner renamed hers "Morkva Wear".

### Teammate link and its failure states

- "Copy link" (Teammates row; and "Copy link to view" in the view tab's ⋯ menu for **every** role)
  builds `https://<origin>/w/{wid}/collections/{cid}?view={viewId}` via `collectionLink`
  (`lib/features/views/view_link.dart:15`) + the `/w/{wid}` prefix.
- Member, other workspace current → switch interstitial, then the view.
- Signed out → sign-in with `next` kept → same.
- Non-member → `/no-access?wid=…&next=…` (`NoAccessPage`, outside the shell). It first looks up the
  user's invitations for that `wid` (the CG invites query, §10.3 `watchInvitations`):
  - invitation found: "Olena Koval invited you to Morkva Wear as an Editor." / Primary "Join and
    open" (joins, then goes to `next`) · text "Not now";
  - none: "You don't have access to this workspace" / "You're signed in as ivan.p@gmail.com. Ask the
    person who sent the link to invite you." / "Go to my workspace" · "Switch account". (No owner
    name: a non-member cannot read the workspace doc. No "Request access" in v1.)
- Collection gone: existing `_NotFound` (`collection_views_page.dart:1118`).

### Shared links — artboard `SharedLinks`

Copy settings live in the popover (above); "Shared links" is the workspace-wide list.
Route `/settings/shared-links`: header "Shared links" + subtitle "Published copies of your views and
their public links. Copies refresh while an admin or editor has Morkva open."
- Table (wide) / cards (phone) — columns: **View** ("For Sunflower Studio" + "Orders · 5 of 8 fields"
  bodySmall) · **Audience** ("Anyone with the link" / "2 people") · **Published by** (avatar + name) ·
  **Updated** ("3 min ago"; stale >24 h or `dirtyAt != builtDirtyAt` for >24 h as a
  warning-container chip "Stale · 26 h" — onWarningContainer #5A4410 on #FBF3DC, ≥4.5:1; "Couldn't
  update" in error tint) · **Expires** ("Never" / "30 Nov" / "Expired 2 days ago" in error tint) ·
  ⋯ menu: "Copy link", "Open view" (→ the collection with the share popover open, `?share=1`),
  "Update now", "Unpublish".
- Row states: registry `revokedAt` set (an Unpublish that didn't finish) → tag "Unpublishing…" +
  "Retry" (resumes the cleanup, §10.8), ⋯ empty; source view deleted → tag "View deleted" (the copy keeps serving its frozen
  definition), ⋯ offers "Copy link" and "Unpublish" only; source collection deleted (by a path that
  skipped the delete-flow unpublish) → registry `lastError: 'source_gone'`, tag "Collection deleted",
  ⋯ "Unpublish" only.
- Fixture rows: "For Sunflower Studio" · Orders · Anyone with the link · Olena · 3 min ago · Never;
  "Fabric stock" · Fabrics · 1 person · Taras · Stale · 26 h · 30 Nov.
- Footer notes (from the artboard): "Teammate links aren't listed — they only open for members." ·
  "Unpublish deletes the copy. The old link then shows “This link was turned off”."
- Empty: EmptyState `public_off` "No published copies yet" / "Publish a view from its Share button
  to give a client a read-only copy."
- Loading skeleton rows; error "Couldn't load shared links. Try again."; offline banner "You're
  offline — changes are paused." with actions disabled.
- Editors: ⋯ "Copy link" and "Update now". Viewers: "Copy link" only.

### Outsider page — artboards `PublicView`, `PhonePublic`

Route `/s/:token`, outside the auth gate and outside the shell; no sidebar, no Ask Morkva, no sync
chip. Hosting serves `X-Robots-Tag: noindex, nofollow` and `Referrer-Policy: no-referrer` for
`/s/**` (§13 owner steps; a `<meta>` set after Flutter boots is too late for crawlers).
- Header: caps label "MORKVA WEAR" · title "For Sunflower Studio" (headlineMedium) · "5 orders ·
  Updated 3 min ago · Only people Morkva Wear added can open this" (link audience: "· Anyone with
  the link can open this") · "Signed in as sales@sunflower.studio · Sign out" · intro line "A
  read-only copy shared by Morkva Wear. It refreshes while their team works in Morkva." · search
  field "Search this view" (client-side, all columns) · SecondaryButton "Download CSV" when allowed.
- Body (wide): read-only table (same table styling as the app, no row actions, no card editor);
  board views render as grouped sections by the group column (*my call*: one renderer); select values
  as `OptionPill`s with their tints; references as plain text; dates formatted in the viewer's locale.
  Phone: one card per row, first column as the card title.
- Footer: "Made with Morkva" (link to origin) · "Report abuse" (`mailto:<abuse>?subject=Report%20shared%20view%20<token>`).
- States (`PublicViewCubit`; Offline/Off are classified from the read itself — `unavailable` →
  Offline, not-exists only when `!metadata.isFromCache`; there is no workspace sync status here):
  - Loading: skeleton rows.
  - Needs sign-in (signed out and the stub is not `get`-able — always, while `kAnonymousLinks` is
    false): generic, names no workspace: "Sign in to open this link" / "Someone shared a Morkva view
    with you. Sign in with Google to open it." / "Continue with Google" / footnotes "Use the email
    address it was shared with, if they gave you one.", "Signing in creates a free Morkva account.
    You don't have to use it." and "No Google account for this address? Create one with your current
    email."
  - Preparing (stub present, `gen == null` — the first generation hasn't landed): "This view is being
    prepared — try again in a minute." / "Try again".
  - Stale: info line under the title when `generatedAt` > 24 h: "Updated 3 days ago — this copy may
    be out of date."
  - Truncated: "Showing the first 5,000 of 6,240 orders."
  - Turned off (stub is a tombstone): "This link was turned off" / "Ask the person who shared it for
    a new link."
  - Not found (stub missing): "This link doesn't work" / "Check that you copied the whole address, or
    ask the person who shared it for a new link."
  - Expired: "This link has expired" / "Ask the person who shared it for a new link."
  - No access (gen `get` denied): "You don't have access to this view" / "You're signed in as
    ivan.p@gmail.com. Ask the person who shared it to add ivan.p@gmail.com, or switch account." /
    "Switch account".
  - Empty (0 rows): "Nothing to show right now."
  - No search results: "No orders match “zip”."
  - Error: "Couldn't open this view. Check your connection and try again." / "Try again".

### Viewer and Editor restrictions — artboard `ViewerMode`

Rules are the boundary; the UI just never offers what rules reject. One source:
`WorkspaceRole` getters (`canEditCards`, `canEditSchema`, `canManageTeam`, `canPublish`,
`canAuthorAutomations`) read through `context.select<WorkspaceCubit, …>`. A disabled role-gated
control shows its reason as inline helper text in its menu or sheet, not only as a tooltip
(tooltips are weak on touch).
- **Viewer**: no "+ New", "Customize", "Actions" authoring, "From template", "New collection",
  collection card menu, view tab ⋯ (except "Copy link to view"), "+" new view; inline cells not
  editable; board drag off; card editor opens read-only (`readOnlyFieldIds` = all,
  `object_editor_state.dart:69`) with banner "You can view this card. Editing needs Editor access.";
  header role chip "Viewer · read-only". Sort/filter/collapse changes are personal (as for every
  role, §10.7): a chip "Your sort & filters are only for you · Reset" appears on the toolbar.
  Action buttons hidden. Ask Morkva read-only. Toolbar keeps Filter and Sort (personal); Columns and the mode switch edit the shared view,
  so Viewers and Editors don't get them.
- **Card editor header** (every role): "Order · created 3 Nov · edited 2 h ago by Iryna Bondar" from
  `createdAt`/`updatedAt`/`updatedBy` (§10.6); unknown uid → "edited 2 h ago".
- **Editor**: everything a Viewer has + create/edit/delete cards (any number — rules can't count),
  inline edits, board drag between groups (it edits a field; `moveToGroup`,
  `collection_views_cubit.dart:755-795`, skips its `manualOrder` view write for non-admins, so the
  card lands at the group's end), run button actions it consented to. No Customize, no view
  create/rename/delete, no manual reorder (helper "Only admins can reorder this view"), no
  publish settings, no Trello import, no templates, Automations page read-only except consent.
- **Admin**: everything except workspace AI consent, the owner's row and ownership.
- **Role changed while open**: `WorkspaceCubit` emits a one-shot `roleChanged` → snackbar "You're now
  a Viewer in Morkva Wear" (`persist:false`, 5 s); the session rebinds on the same workspace and
  returns to the same page (§10.1). A card editor with unsaved edits defers that rebind until it
  closes; on a demotion it shows the warning banner "Your role changed to Viewer — you can't save
  these changes. Copy anything you need, then close." with Save disabled.

### Removed from a workspace

The client listens to its own member doc (§10.1). On delete while the workspace is open:
modal (not dismissible) "You're no longer a member of Morkva Wear" / "You left or were removed.
Morkva will clear its data from this device." / Primary "Go to my workspace" → switch to the
personal workspace + cache purge (§10.9). Same dialog if a listener gets `permission-denied` on the
member doc. If removed while elsewhere, the workspace silently disappears from "Other workspaces".

### Phone variants — artboards `Phone`, `PhonePublic`, `PhoneJoin`, `PhoneInvitation`

- Share = bottom sheet with the popover's sections stacked; "Choose fields" pushes a second sheet
  page; footer button full width. Entry: "Share…" as the first `more_vert` item (no AppBar button);
  a page-overflow test at 360 dp guards the header (memory "Page overflow tests").
- Team page full-screen under Settings with the two-line rows above; invite delivery offers "Share…"
  (system share sheet) first.
- Public view: card list, sticky search, Download CSV in an overflow menu.
- Join: no card, full-width buttons (`PhoneJoin`); the Home invitation banner on phone is
  `PhoneInvitation`.
- Dark (`Dark`): tokens only — `sheetSurface` #241D17 for the popover/sheet, depth from surface steps.

### Mockup redraws (done 2026-11-13)

After the review round the artboards were redrawn to this doc and checked by an independent critic
against §6: `Main`, `Dark`, `Phone`, `PublishPeople` (no inline invite; Teammates row + "Published
copy" select; "any Google account"; "Copy public link"; published `public` icon on the tab;
`PublishPeople` also draws the "Fields in the copy" page as a second state), `Team`, `Invite` (new
fixture, Viewer default, client-domain warning, Leave), `ViewerMode`, `Switcher` ("OTHER
WORKSPACES", Home invitation banner), `SharedLinks` ("Stale · 26 h"), `PhoneInvitation` (was
`PhoneJoin`: the Home invitation banner) and a new `PhoneJoin` (phone `/join` landing, Ready state).
`VariantTwoDoors` and `VariantMinimal` were refreshed to the reviewed fixture and copy as the
**alternatives** UI-2 / UI-3 (the owner may still pick one); they are parity targets only if chosen.

States the canvas does not draw (this doc's copy is the source): the non-admin share popover ("4
members" without a pending count), the Shared links "Unpublishing… Retry" row, and the Leave
confirm dialog itself (the `Team` board quotes its copy in an annotation).

Details settled while redrawing (*my call*):
- The share popover is 400 wide with max height 808 on wide (it outgrows `showViewPopover`'s
  360×520 — give it its own constraints) and scrolls inside.
- The sidebar workspace row uses the workspace initial ("M"), not two letters.
- On phone Home the header's logomark/title is replaced by the switcher (tile · name · ▾).
- The Home invitation banner uses the info (sky) tint #DCEAF3, radius 12.

---

## 7. Roles & permissions matrix

✓ allowed · – not allowed · "rules" = enforced by Firestore rules; "UI" = UI-only (rules cannot or
need not enforce). Nobody can grant a role above Admin; the owner's row is untouchable.

| Capability | Owner | Admin | Editor | Viewer | Enforced by |
|---|---|---|---|---|---|
| Read all collections, cards, views | ✓ | ✓ | ✓ | ✓ | rules |
| Create / edit / delete cards (incl. inline, board drag between groups) | ✓ | ✓ | ✓ | – | rules |
| Auto-number on card create (writes workspace `counters`) | ✓ | ✓ | ✓ | – | rules (`counters` key only) |
| Collection delete (cascade; also unpublishes its copies) | ✓ | ✓ | – | – | rules (collection) + UI |
| Delete any number of cards (multi-select, Ask Morkva plans — plans still go through plan review) | ✓ | ✓ | ✓ | – | rules (per card; rules can't count) |
| Schema: create/rename/delete collection, fields, layout | ✓ | ✓ | – | – | rules |
| Shared views: create/rename/delete/duplicate, "Save for everyone" (sort/filter), manual order | ✓ | ✓ | – | – | rules (collection doc) |
| Personal view prefs (active view, collapsed groups, sort/filter — every role's edits land here first) | ✓ | ✓ | ✓ | ✓ | rules (own `members/{uid}/…`) |
| Pins (personal) | ✓ | ✓ | ✓ | ✓ | rules (own) |
| Automations: create/edit/delete, enable/disable, set Auto | ✓ | ✓ | – | – | rules |
| Automations: own consent for a module (per member, code-hash pinned) | ✓ | ✓ | ✓ | ✓ (moot) | rules (own `grants`) |
| Automations: run buttons / card triggers fire on own writes | ✓ | ✓ | ✓ (own consent; module caps ∩ role caps) | – | rules (writes) + UI |
| Automations: persist a pause (pause keys only) | ✓ | ✓ | ✓ | – | rules |
| Run log: read | all | all | own runs | own (none) | rules |
| Run log: prune / expire reviews | all | all | own | – | rules |
| Modules: install / import / edit / delete | ✓ | ✓ | – | – | rules |
| Templates: create collections from a template | ✓ | ✓ | – | – | rules (schema) |
| Import from Trello | ✓ | ✓ | – | – | rules (schema) |
| Ask Morkva: use | ✓ all caps | ✓ all caps | data read/write/delete, no schema/views/modules/automations | read + navigate | Grants (UI/harness) + rules |
| Ask Morkva: workspace AI consent (`config/assistant`) | ✓ | – | – | – | rules |
| Ask Morkva: own threads | own | own | own | own | rules |
| Invite (email or link), revoke invites, reset/turn off link | ✓ | ✓ (roles ≤ Admin) | – | – | rules |
| Change roles, remove members | ✓ | ✓ (not the owner) | – | – | rules |
| Copy teammate link | ✓ | ✓ | ✓ | ✓ | — |
| Publish / change settings / "Update the copy" to the live view / regenerate / unpublish | ✓ | ✓ | – | – | rules |
| Refresh a published copy ("Update now" in the popover and Shared links, automatic) | ✓ | ✓ | ✓ | – | rules (content keys only) |
| Copy a published link | ✓ | ✓ | ✓ | ✓ | — |
| Rename workspace | ✓ | ✓ | – | – | rules |
| Delete workspace | ✓ (no UI in v1) | – | – | – | rules |
| Leave workspace | – (own workspace) | ✓ | ✓ | ✓ | rules |
| Files (Storage, later) read / upload | ✓ | ✓ | ✓ / ✓ | ✓ / – | storage.rules (later) |

Ask Morkva grants per role (`lib/core/harness/api/capability.dart`), **superseding** the Epic 8 spec's
"editor = everything except schema:delete" (`2026-11-10-epic-08-ai-assistant-design.md:292-300`) so
the assistant can never plan what the member's rules reject:
- Viewer: `schemaRead, dataRead, uiNavigate, modulesRead`.
- Editor: Viewer + `dataWrite, dataDelete`.
- Admin / Owner: `kAssistantCaps` (all but `hostCommit`).
- Commit (`assistant_bloc.dart:1691` uses `Grants.all()` today) → role grants + `hostCommit`.
- Button runs: the runner intersects the module's granted caps with the role caps; a button whose
  manifest needs a cap the role lacks is shown disabled with tooltip "Needs admin rights".

---

## 8. Data model

v1 invariant (*my call*): **`wid == ownerUid`** — workspaces are only ever personal ones, no creation,
no transfer. It makes "is owner" free in rules (`request.auth.uid == wid`) and needs no migration
(memory "No clients: break freely" — shapes change directly). Lifting it (create workspace, transfer)
is a later epic that replaces `isOwner` with `role == 'owner'`.

### `workspaces/{wid}` (changed)
| Field | Type | Notes |
|---|---|---|
| `name` | string 1–60 | new; default `"<given name>'s workspace"` |
| `ownerUid` | string | new; `== wid` |
| `createdAt` | timestamp | new |
| `counters` | map `{cid: {fid: int}}` | unchanged (`firestore_data_repository.dart:458-475, 807-852`) |
| ~~`pinnedCollections`~~ | — | **removed** → `members/{uid}/prefs/pins` (`firestore_data_repository.dart:212-238` already carries the shortcut comment) |

Created on the owner's first boot if missing (`TeamRepository.ensurePersonalWorkspace`): batch of the
workspace doc + the owner's member doc. ~200 B + counters.

### `workspaces/{wid}/members/{uid}` (new doc; its subtrees exist today)
The doc itself matches no rule today — only `members/{uid}/{sub}/{rest=**}` (`firestore.rules:115-131`)
covers its subcollections — so it is free to become the roster doc; one tree, no parallel
`memberships`. *my call* (initial-decisions.md over [`2026-11-13-team-collaboration-research/firebase.md`](2026-11-13-team-collaboration-research/firebase.md)'s `memberships`). A collection-group rule on
`{path=**}/members/{uid}` matches only docs whose parent collection is named `members`, not
`members/{uid}/grants/{id}` [verify in W0].
| Field | Type | Notes |
|---|---|---|
| `uid` | string | `== doc id`; queried by the CG "Other workspaces" query |
| `email` | string | lower-cased `token.email` |
| `name` | string ≤ 100 | rules-bound to the ID token's `name` (or the email when absent) — no impersonating the owner in banners |
| `role` | `'owner'|'admin'|'editor'|'viewer'` | |
| `joinedAt` | timestamp | |
| `invitedBy` | string? | inviter uid |
| `joinedVia` | `'owner'|'email'|'link'` | how they joined; drives the "rejoin through the link" warning on demotion |
~250 B. **Nothing on the roster is secret-bearing**: every member, Viewers included, can `list` it,
so the invite token used to join (the accept proof) lives in the member-private `prefs/join` and the
last-opened workspace in `prefs/session` (below). `photoUrl` and `lastActiveAt` are dropped
(`UserAvatar` is initials-only; no artboard shows "last active").

Member-private subdocs (existing generic rule shape, now `isMember && auth.uid == uid`, with the
subcollection name allow-listed — §9):
- `members/{uid}/prefs/pins` — `{ids: [cid…], updatedAt}`.
- `members/{uid}/prefs/join` — `{inviteId}`: written in the accept batch; the member `create` rule
  reads it with `getAfter` (own rule, since the joiner is not a member yet — §9).
- `members/{uid}/prefs/session` — `{lastWorkspaceId}`, **only under the personal workspace**
  `workspaces/{uid}/members/{uid}/prefs/session`: the workspace to open on boot (synced across
  devices, no `shared_preferences` dependency).
- `members/{uid}/viewPrefs/{collectionId}` — `{activeViewId?: string, views: {viewId:
  {collapsedGroups?: [string], sort?: [..ViewDefinition sort json..], filters?: [..filter json..]}},
  updatedAt}`. Per-member overrides layered on the shared `ViewDefinition` (`view_definition.dart:116-171`).
  `manualOrder` stays shared and Admin-written *my call* (a team's priority order is shared by intent).
- `members/{uid}/usage/{yyyy-MM-dd}` — `{turns: int}` (Ask Morkva advisory counter, `FieldValue.increment`).
- Existing: `members/{uid}/assistantThreads/…`, `members/{uid}/grants/{moduleId}`.

### `workspaces/{wid}/invites/{id}` (new)
`id` = 128-bit token (22 chars) for both kinds — it travels in `/join/{wid}/{id}`.
| Field | Type | Notes |
|---|---|---|
| `kind` | `'email'|'link'` | at most one `link` per workspace (client-enforced; Reset deletes + creates) |
| `email` | string? | `kind=='email'`; lower-cased |
| `domain` | string? | `kind=='link'`; lower-case, no `@` (e.g. `morkvawear.com`) |
| `role` | `'admin'|'editor'|'viewer'` | |
| `invitedBy` | string | uid |
| `inviterName` | string | denormalized; rules-bound to the inviter's token `name` |
| `inviterEmail` | string | rules-bound to the inviter's verified email — shown on the banner/landing |
| `workspaceName` | string ≤ 60 | denormalized (non-members cannot read the workspace doc); a rename does not update pending invites (Limitations) |
| `createdAt` | timestamp | |
| `expiresAt` | timestamp | email: +14 days *my call*; link: +1/7/30 days (default 7) |
~400 B. Email invites are deleted on accept (the member `create` rule **requires** it — §9) or
decline; renew = update `expiresAt`. Readable only signed in; an email invite only by its address.

### `workspaces/{wid}/publishedViews/{token}` (new — registry, members-side)
| Field | Type | Notes |
|---|---|---|
| `collectionId`, `viewId` | string | |
| `title` | string | the view's name, frozen with `definition` (publish / "Update the copy"); Admin-written only — renaming the live view doesn't change it |
| `definition` | map | **frozen** at publish / "Update the copy": the view's `type`, `filters`, `sort`, `groupBy`/date field id and `manualOrder` (ViewDefinition json subset). The builder uses only this + `fieldIds`; edits to the live view never reach the copy. Admin-written only |
| `fieldIds` | [string] | chosen fields (subset of the view's visible fields + forced group/date field); a field deleted from the schema drops out on the next refresh, which flips as narrowing (§10.8) |
| `settingsRev` | int | Admin-only; `1` at publish; every settings write (fields, "Update the copy", audience, viewers, expiry, download) increments it **and** sets `dirtyAt = serverTimestamp()` in the same write |
| `builtSettingsRev` | int? | the `settingsRev` the current gen was built from; a build whose rev differs flips as narrowing (§10.8) |
| `audience` | `'link'|'emails'` | mirror of the stub |
| `viewerCount` | int | number of listed emails |
| `expiresAt` | timestamp? | mirror |
| `allowDownload` | bool | mirror |
| `createdBy`, `createdAt` | string, timestamp | |
| `gen` | string | current generation id |
| `generatedAt`, `generatedBy` | timestamp, string | |
| `rowCount`, `totalCount`, `truncated` | int, int, bool | |
| `dirtyAt` | timestamp? | server time, set by any Admin/Editor device after a relevant local write (`update()`, never `set(merge)` — a queued write must not re-create a deleted registry), by every settings write, and by the publish batch (so a new copy is born dirty) |
| `builtDirtyAt` | timestamp? | the `dirtyAt` value the current gen was built from; **dirty ⇔ `dirtyAt != builtDirtyAt`** |
| `leaseBy`, `leaseUntil` | string?, timestamp? | refresher lock (§10.8) |
| `lastError` | string? | `'too_large'|'permission'|'failed'|'source_gone'` |
| `gens` | map `{genId: chunkCount}` | every generation not yet deleted (current, previous, failed deletes) — the only way to name chunk ids, since `list` is denied |
| `revokedAt` | timestamp? | Admin-only; set in Unpublish's first batch with the tombstone. Refreshers and the rename fan-out skip the row; Shared links shows "Unpublishing… Retry" |
~600 B. The token as doc id is fine: every member may copy the link anyway.

### `shares/{token}` (new, top-level — public stub)
Readable by anyone holding the token, so it holds **only gating and display-safe fields**:
| Field | Type | Notes |
|---|---|---|
| `v` | int | `1` |
| `wid` | string | write-rule anchor; reveals the workspace id (= owner uid, not a secret) |
| `audience` | `'link'|'emails'` | |
| `signInRequired` | bool | `true` for `emails`; for `link` = `!kAnonymousLinks` |
| `expiresAt` | timestamp? | |
| `allowDownload` | bool | |
| `workspaceName` | string 1–60 | the outsider page header caps label (signed in). A signed-in user who isn't listed can still `get` the stub and so learns the workspace name |
| `gen` | string? | current generation; `null` until the first generation lands ("being prepared") |
| `prevGen` | string? | previous generation, served only until `prevGenUntil` so a reader mid-flip finishes; `null` after a narrowing refresh |
| `prevGenUntil` | timestamp? | `generatedAt + 60 s` (client clock; rules accept up to `request.time + 90 s`, so a device whose clock runs ≤ 30 s ahead can still flip) |
| `generatedAt` | timestamp? | |
| `revoked` | bool? | `true` = tombstone. Unpublish's **first** write; stubs are never deleted, so a used token can't be re-created by anyone |
~300 B. No title, no emails, no data. Readable signed out only when `signInRequired == false`.

- `shares/{token}/viewers/{emailLower}` — `{addedBy, addedAt}`. Audience proof via `exists()`; a
  reader can `get` only the doc named after their own email, so the list never leaks. (Not named
  `allow`: a keyword in the rules language.)
- `shares/{token}/gens/{gen}` — `{wid, title, collectionName, columns: [{id:'c0', label, type:
  'text'|'number'|'date'|'datetime'|'bool'|'select'|'multi'|'ref'|'file', format?, options?: [{label,
  tint}], }], groupBy?: 'c3', rowCount, totalCount, truncated, chunkCount, generatedAt}`. Column ids
  are opaque (`c0…`), never field ids. ≤ 20 KB.
- `shares/{token}/gens/{gen}/chunks/{n}` — `{wid, n, data: string}`; `data` = JSON
  `[[v0, v1, …], …]` (display-ready primitives: text; number; ISO date; bool; option index;
  list of option indexes; list of reference **titles**; materialized calculated value; file
  **names**). Card ids are not published. Each chunk ≤ 700,000 UTF-8 bytes (1 MiB doc cap minus
  headroom); `wid` on every chunk keeps orphans deletable after the parent is gone.

Budget *my call*: ≤ 5,000 rows and ≤ 8 chunks per copy; beyond → `truncated: true` and the size note.
`data` as one string (not nested arrays) keeps index entries at 1 per chunk, far under the 40k
index-entries-per-doc limit [V: quotas]; it is also exempted from indexing below.

### Cards `workspaces/{wid}/objects/{id}` (changed)
Add `createdBy: uid` and `updatedBy: uid` (rules-checked). Every object write path is in
`lib/api/data/firestore_data_repository.dart` and must write them, or rules reject it:
- `saveObject` txn `transaction.set(docRef, doc)` (`:483`) — whole-doc set: carry `createdBy` from
  `current` (or the writer on create) and set `updatedBy`.
- `saveObjectsBatch` create `batch.set` (`:773`) and update `batch.update` (`:786`) — add both / `updatedBy`.
- Callers that go through those (plan committer + undo journal, templates `WriteKind.template`,
  Trello import on `feat/trello-import` `trello_import_cubit.dart:250,462,493`, automations) inherit
  it; `FirestoreDataRepository.initialize(workspaceId, {required String uid})` gets the uid.
- Fakes: `test/features/collections/fake_data_repository.dart` mirrors the fields.

### Indexes (`firestore.indexes.json`)
```json
{
  "indexes": [
    { "collectionGroup": "objects", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "collectionId", "order": "ASCENDING" }, { "fieldPath": "updatedAt", "order": "DESCENDING" } ] },
    { "collectionGroup": "objects", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "collectionId", "order": "ASCENDING" }, { "fieldPath": "createdAt", "order": "ASCENDING" } ] },
    { "collectionGroup": "runs", "queryScope": "COLLECTION", "fields": [
      { "fieldPath": "by", "order": "ASCENDING" }, { "fieldPath": "startedAt", "order": "DESCENDING" } ] }
  ],
  "fieldOverrides": [
    { "collectionGroup": "members", "fieldPath": "uid", "indexes": [
      { "order": "ASCENDING", "queryScope": "COLLECTION" },
      { "order": "ASCENDING", "queryScope": "COLLECTION_GROUP" } ] },
    { "collectionGroup": "invites", "fieldPath": "email", "indexes": [
      { "order": "ASCENDING", "queryScope": "COLLECTION" },
      { "order": "ASCENDING", "queryScope": "COLLECTION_GROUP" } ] },
    { "collectionGroup": "chunks", "fieldPath": "data", "indexes": [] }
  ]
}
```
The runs composite serves the non-admin run log `where('by', ==, 'user:<uid>').orderBy('startedAt',
desc).limit(200)`.

---

## 9. Security rules

Full proposed `firestore.rules` (replaces the file; unchanged helpers `revIsMonotonic`,
`moduleWires`, `runShapeOk` are elided as `…`). Composed, **not run** — every line is
**[verify in W0]** by the rules test suite (§12) before W1 merges. Deploy is the owner's step
(memory "Firebase deploy needs owner").

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ---------- helpers ----------
    function signedIn() { return request.auth != null; }
    function myEmail() { return request.auth.token.email.lower(); }
    function verified() { return request.auth.token.email_verified == true; }
    function memberPath(wid) {
      return /databases/$(database)/documents/workspaces/$(wid)/members/$(request.auth.uid);
    }
    // v1 invariant: a workspace's id is its owner's uid — owner checks cost no get().
    function isOwner(wid) { return signedIn() && request.auth.uid == wid; }
    // get() of a missing member doc errors its operand: `error && x` denies, `error || true` still
    // allows — so a rule with a non-member branch puts that branch first (no wasted billed read).
    function role(wid) { return get(memberPath(wid)).data.role; }   // [verify in W0] Q0
    function isMember(wid) { return isOwner(wid) || (signedIn() && exists(memberPath(wid))); }
    function canEdit(wid) { return isOwner(wid) || (signedIn() && role(wid) in ['admin', 'editor']); }
    function canAdmin(wid) { return isOwner(wid) || (signedIn() && role(wid) == 'admin'); }
    function changed() { return request.resource.data.diff(resource.data).affectedKeys(); }
    function isToken(id) { return id.size() >= 22 && id.size() <= 64; }
    function revIsMonotonic(existing, incoming) { … }   // unchanged
    function moduleWires() { … }                         // unchanged
    function runShapeOk(d) { … }                         // unchanged

    // ---------- workspace ----------
    match /workspaces/{wid} {
      allow get: if isMember(wid);
      allow list: if false;
      allow create: if isOwner(wid) && request.resource.data.ownerUid == wid
          && request.resource.data.name is string
          && request.resource.data.name.size() >= 1 && request.resource.data.name.size() <= 60;
      allow update: if request.resource.data.get('ownerUid', wid) == wid
          && (!changed().hasAny(['name']) || (request.resource.data.name is string
              && request.resource.data.name.size() >= 1 && request.resource.data.name.size() <= 60))
          && (
          isOwner(wid)
          || (canAdmin(wid) && changed().hasOnly(['name', 'counters']))
          || (canEdit(wid) && changed().hasOnly(['counters'])));   // auto-number txn only
      allow delete: if isOwner(wid);

      // Roster. Every member can list it, so it holds nothing secret (no invite token).
      match /members/{uid} {
        // Self-get always: removal must arrive as "doc gone", not permission-denied.
        allow get: if signedIn() && (request.auth.uid == uid || isMember(wid));
        allow list: if isMember(wid);
        allow create: if signedIn() && request.auth.uid == uid
            && request.resource.data.uid == uid
            && request.resource.data.email == myEmail()
            && nameOk(request.resource.data)
            && request.resource.data.keys().hasOnly(['uid', 'email', 'name', 'role',
                 'joinedAt', 'invitedBy', 'joinedVia'])
            && ((uid == wid && request.resource.data.role == 'owner'
                 && request.resource.data.joinedVia == 'owner')                // first boot
                || inviteAllows(wid, uid, request.resource.data.role,
                                request.resource.data.joinedVia));
        allow update: if
            // self: display name only (never role), still bound to the token
            (signedIn() && request.auth.uid == uid
              && changed().hasOnly(['name']) && nameOk(request.resource.data))
            // admin: role only, never the owner's doc, never to owner
            || (canAdmin(wid) && uid != wid
              && request.resource.data.role in ['admin', 'editor', 'viewer']
              && changed().hasOnly(['role']));
        allow delete: if (signedIn() && request.auth.uid == uid && uid != wid)  // leave
            || (canAdmin(wid) && uid != wid);                                  // remove

        // Member-private data, allow-listed by name **and depth** (a free `{sub}` or a `{rest=**}`
        // tail let any user plant `members/{me}/invites/…` or `…/prefs/x/members/…` docs that the
        // collection-group rules below would serve to a victim as fake invitations or workspaces).
        // The only nested path today is threads → messages (firestore_thread_repository.dart:24,32).
        match /{sub}/{docId} {
          allow read, write: if isMember(wid) && request.auth.uid == uid
              && sub in ['prefs', 'viewPrefs', 'usage', 'assistantThreads'];
        }
        match /assistantThreads/{t}/messages/{m} {
          allow read, write: if isMember(wid) && request.auth.uid == uid;
        }
        // Accept proof: written in the accept batch, before the joiner is a member (update: a
        // rejoin after leaving finds the old doc).
        match /prefs/join {
          allow create, update: if signedIn() && request.auth.uid == uid
              && request.resource.data.keys().hasOnly(['inviteId'])
              && existsAfter(/databases/$(database)/documents/workspaces/$(wid)/members/$(uid));
        }
        // Module consent (unchanged body, membership instead of ownership).
        match /grants/{moduleId} {
          allow read, delete: if isMember(wid) && request.auth.uid == uid;
          allow create, update: if isMember(wid) && request.auth.uid == uid
              && … ;                                       // unchanged caps/via/autoApply checks
        }
      }
      function nameOk(d) {
        return d.name == request.auth.token.get('name', myEmail()) && d.name.size() <= 100;
      }

      // Invites. The id is a 128-bit token. Readable only signed in; an email invite only by
      // its own verified address (the signed-out landing is generic).
      match /invites/{inviteId} {
        // Invitee branch first: canAdmin() errors for a non-member (see role()).
        allow get: if (signedIn() && (resource.data.kind == 'link'
            || (verified() && resource.data.email == myEmail()))) || canAdmin(wid);
        allow list: if canAdmin(wid);
        allow create: if canAdmin(wid) && isToken(inviteId)
            && request.resource.data.invitedBy == request.auth.uid
            && request.resource.data.inviterEmail == myEmail()
            && request.resource.data.inviterName == request.auth.token.get('name', myEmail())
            && request.resource.data.workspaceName is string
            && request.resource.data.workspaceName.size() <= 60
            && request.resource.data.expiresAt is timestamp
            && ((request.resource.data.kind == 'email'
                  && request.resource.data.email == request.resource.data.email.lower()
                  && request.resource.data.role in ['admin', 'editor', 'viewer'])
                || (request.resource.data.kind == 'link'
                  && request.resource.data.role in ['editor', 'viewer']));     // no admin by link
        allow update: if canAdmin(wid) && changed().hasOnly(['role', 'expiresAt', 'domain'])
            && request.resource.data.role in
               (resource.data.kind == 'link' ? ['editor', 'viewer'] : ['admin', 'editor', 'viewer']);
        allow delete: if (signedIn() && verified() && resource.data.kind == 'email'
                && resource.data.email == myEmail())                           // accept / decline
            || canAdmin(wid);
      }
      function inviteAllows(wid, uid, r, via) {
        let inviteId = getAfter(/databases/$(database)/documents/workspaces/$(wid)/members/$(uid)/prefs/join).data.inviteId;
        let invPath = /databases/$(database)/documents/workspaces/$(wid)/invites/$(inviteId);
        let inv = get(invPath).data;                       // pre-batch: the invite still exists
        return verified() && inv.role == r && inv.expiresAt > request.time && via == inv.kind
          && ((inv.kind == 'email' && inv.email == myEmail()
               && !existsAfter(invPath))                   // consumed in the same batch
              || (inv.kind == 'link'
                  && (inv.get('domain', null) == null || myEmail().split('@')[1] == inv.domain)));
      }

      // Schemas (+ the shared views array).
      match /collections/{collectionId} {
        allow read: if isMember(wid);
        allow create, update, delete: if canAdmin(wid);
      }

      // Cards.
      match /objects/{objectId} {
        allow read: if isMember(wid);
        allow create: if canEdit(wid)
            && request.resource.data.keys().hasAll(['collectionId', 'rev'])
            && request.resource.data.createdBy == request.auth.uid
            && request.resource.data.updatedBy == request.auth.uid;
        allow update: if canEdit(wid)
            && revIsMonotonic(resource, request.resource)
            && request.resource.data.updatedBy == request.auth.uid
            && request.resource.data.collectionId == resource.data.collectionId
            && request.resource.data.get('createdBy', null) == resource.data.get('createdBy', null);
        allow delete: if canEdit(wid);
      }

      match /modules/{moduleId} {
        allow read: if isMember(wid);
        allow delete: if canAdmin(wid);
        allow create, update: if canAdmin(wid) && … ;        // unchanged shape checks
      }

      match /automations/{automationId} {
        allow read: if isMember(wid);
        allow delete: if canAdmin(wid);
        allow create, update: if canAdmin(wid) && … ;        // unchanged shape + autoBy == auth.uid
        // Another admin may switch an Auto automation on/off or resume it without taking over its
        // Auto stamp: these keys don't change what runs or under whose consent (modules_cubit
        // setEnabled and runner resume save the whole doc with the old autoBy).
        allow update: if canAdmin(wid)
            && changed().hasOnly(['enabled', 'pausedReason', 'brokenDetail', 'updatedAt']);
        // Any writer's device may persist a pause (runner `_pause`, automation_runner.dart:1264-1269);
        // pausing only — clearing a pause is an admin edit.
        allow update: if canEdit(wid)
            && changed().hasOnly(['pausedReason', 'brokenDetail', 'updatedAt'])
            && request.resource.data.pausedReason != null;
      }

      match /runs/{runId} {
        // Non-admin queries must carry `where('by', '==', 'user:<uid>')` (FirestoreRunStore scope,
        // §10.10) or the whole query is denied — rules are not filters.
        function mine() { return resource.data.by == 'user:' + request.auth.uid; }
        allow get, list: if canAdmin(wid) || (isMember(wid) && mine());
        allow delete: if canAdmin(wid) || (isMember(wid) && mine());
        allow create: if canEdit(wid)
            && request.resource.data.by == 'user:' + request.auth.uid
            && … ;                                            // unchanged status + runShapeOk
        allow update: if canEdit(wid) && (canAdmin(wid) || mine())
            && request.resource.data.by == resource.data.by
            && … ;                                            // unchanged lifecycle transitions
      }

      match /publishedViews/{token} {
        allow read: if isMember(wid);
        allow create, delete: if canAdmin(wid);
        allow update: if
            // a lease can't be parked in the future (would freeze refreshes) — for every role, and
            // checked only when it moves, so an admin's skewed lease can't block unrelated writes
            (!changed().hasAny(['leaseUntil'])
              || request.resource.data.get('leaseUntil', null) == null
              || request.resource.data.leaseUntil <= request.time + duration.value(120, 's'))
            && (canAdmin(wid)
                || (canEdit(wid) && !('revokedAt' in resource.data)     // being unpublished
                    && changed().hasOnly(['gen', 'generatedAt', 'generatedBy', 'rowCount',
                         'totalCount', 'truncated', 'dirtyAt', 'builtDirtyAt', 'builtSettingsRev',
                         'leaseBy', 'leaseUntil', 'lastError', 'gens'])));
      }

      // Workspace Ask Morkva consent: the owner only.
      match /config/assistant {
        allow read: if isMember(wid);
        allow write: if isOwner(wid);
      }
    }

    // ---------- collection-group discovery ----------
    // The client also accepts a CG result only when its path is exactly
    // workspaces/{w}/members/{uid} or workspaces/{w}/invites/{id} (4 segments).
    match /{path=**}/members/{uid} {           // "Other workspaces"; scope [verify in W0] Q3
      allow list: if signedIn() && resource.data.uid == request.auth.uid;
    }
    match /{path=**}/invites/{inviteId} {      // pending invitations for my email
      allow list: if signedIn() && verified() && resource.data.email == myEmail();
    }

    // ---------- published copies ----------
    match /shares/{token} {
      // Functions declared in a match read its wildcards (`token`, `gen`) [verify in W0].
      function stub() { return get(/databases/$(database)/documents/shares/$(token)).data; }
      function readable() {
        let s = stub();
        return s.get('revoked', false) == false
          && (s.get('expiresAt', null) == null || s.expiresAt > request.time)
          && (s.audience == 'link'
                ? (s.signInRequired == false || signedIn())
                : (signedIn() && verified()
                   && exists(/databases/$(database)/documents/shares/$(token)/viewers/$(myEmail()))));
        // email ('@', '.', '+') as a path segment inside $() [verify in W0]
      }
      // An outsider reads only the current gen, or the previous one for ~60 s after a flip,
      // and only a gen that belongs to the stub's workspace.
      function current(gen) {
        let s = stub();
        return resource.data.wid == s.wid
          && (gen == s.get('gen', '')
              || (gen == s.get('prevGen', '') && request.time < s.get('prevGenUntil', request.time)));
      }
      function stubKeys() {
        return ['v', 'wid', 'audience', 'signInRequired', 'expiresAt', 'allowDownload',
                'workspaceName', 'gen', 'prevGen', 'prevGenUntil', 'generatedAt', 'revoked'];
      }
      // Signed out: only stubs that don't need sign-in (none while kAnonymousLinks is false).
      allow get: if signedIn() || resource.data.get('signInRequired', true) == false;
      allow list: if false;
      // `create` applies only to a doc that does not exist: stubs are never deleted, so a used
      // token can never be re-created by someone else.
      allow create: if isToken(token) && canAdmin(request.resource.data.wid)
          && request.resource.data.keys().hasOnly(stubKeys())
          && request.resource.data.get('revoked', false) == false
          && request.resource.data.workspaceName is string
          && request.resource.data.workspaceName.size() >= 1
          && request.resource.data.workspaceName.size() <= 60
          && (request.resource.data.audience == 'link' || request.resource.data.signInRequired == true);
      allow update: if resource.data.get('revoked', false) == false      // a tombstone is final
          && request.resource.data.wid == resource.data.wid
          && request.resource.data.keys().hasOnly(stubKeys())
          && (request.resource.data.get('revoked', false) == true
              // Unpublish: tombstone keeps every key, only `revoked` flips
              ? (canAdmin(resource.data.wid) && changed().hasOnly(['revoked']))
              : ((request.resource.data.audience == 'link'
                  || request.resource.data.signInRequired == true)
                 // the prevGen window: clients write +60 s; +90 s absorbs a clock ≤ 30 s ahead
                 && (!changed().hasAny(['prevGenUntil'])
                     || request.resource.data.get('prevGenUntil', null) == null
                     || request.resource.data.prevGenUntil <= request.time + duration.value(90, 's'))
                 && (!changed().hasAny(['workspaceName'])                    // rename fan-out
                     || (request.resource.data.workspaceName is string
                         && request.resource.data.workspaceName.size() >= 1
                         && request.resource.data.workspaceName.size() <= 60))
                 && (canAdmin(resource.data.wid)
                     || (canEdit(resource.data.wid)
                         && changed().hasOnly(['gen', 'prevGen', 'prevGenUntil', 'generatedAt'])))));
      allow delete: if false;

      match /viewers/{email} {
        allow get: if signedIn() && myEmail() == email;
        allow list, delete: if canAdmin(stub().wid);
        // getAfter: the publish batch creates the stub and its viewers together [verify in W0].
        allow create, update: if canAdmin(getAfter(/databases/$(database)/documents/shares/$(token)).data.wid);
      }
      match /gens/{gen} {
        // Members read any gen of their workspace (admin preview of an email-only copy, cleanup).
        allow get: if (readable() && current(gen)) || isMember(resource.data.wid);
        allow list: if false;
        // No new gens once the stub is a tombstone: a refresher still mid-build when Unpublish
        // lands can't leave an unnamed orphan (§10.8).
        allow create: if request.resource.data.wid == stub().wid && stub().get('revoked', false) == false
            && canEdit(request.resource.data.wid);
        // A missing doc deletes as a no-op, so cleanup can batch the chunk ids `gens` names even
        // when a crashed build wrote fewer [verify in W0] Q8.
        allow delete: if resource == null || canEdit(resource.data.wid);
        match /chunks/{n} {
          allow get: if (readable() && current(gen)) || isMember(resource.data.wid);
          allow list: if false;
          allow create: if request.resource.data.wid == stub().wid
              && stub().get('revoked', false) == false && canEdit(request.resource.data.wid);
          allow delete: if resource == null || canEdit(resource.data.wid);   // orphans: wid on the chunk
        }
      }
    }

    // Unchanged: global /config/assistant (read signed-in, write false), /featureFlags/{uid}.
  }
}
```

Notes on the sketch:
- `kAnonymousLinks == false` is enforced client-side by always writing `signInRequired: true`; the
  rules accept `false` only for `audience == 'link'`, so flipping the constant needs no rules change.
- A non-admin member creating a share is impossible (`create` needs `canAdmin` on the claimed `wid`,
  and the claimed `wid` cannot later change). A member of workspace X cannot write gens into a share
  of workspace Y: `request.resource.data.wid == stub().wid`.
- **Tokens are single-use.** Stubs are never deleted (`delete: if false`); Unpublish's first write
  sets `revoked: true`, after which the stub is frozen. Because `create` only applies to a missing
  doc, nobody — including a stranger holding an old link — can re-create `shares/<oldToken>` and
  point it at their own content. Outsider reads of a gen also check `resource.data.wid == stub.wid`,
  so a stub can never name another workspace's leftover gen.
- **Invites are consumed atomically.** The member `create` for an email invite requires
  `!existsAfter(invite)` — the same batch must delete it — so a removed or demoted member can't
  re-create their doc from a leftover invite. The accept proof is read from the member-private
  `prefs/join` via `getAfter`, so the roster (listable by Viewers) never carries the live invite-link
  token.
- Names shown to others are rules-bound: roster `name` and invite `inviterName` = the ID token's
  `name`, invite `inviterEmail` = the verified email; `workspaceName` ≤ 60 chars (an inviter can
  still name *their own* workspace anything — the banner therefore shows the verified email).
- Per-request access calls (limit 10 single / 20 batch; cached calls don't count [V]):
  member-doc `get` + `exists` (same doc), invite `get` + `existsAfter`, `prefs/join` `getAfter`,
  stub `get`, viewer `exists` — ≤ 5 distinct docs per request. Batches lean on the same assumption
  across ops — an Editor's `saveObjectsBatch`, and for a **non-owner Admin** (the owner needs no
  `get()`) publish with up to 50 `viewers` creates, a 20-email invite send, the rename fan-out and
  Unpublish cleanup; W0 Q1 measures both.
- `storage.rules` (later, Storage deferred): `allow read: if firestore.get(/databases/(default)/
  documents/workspaces/$(wid)/members/$(request.auth.uid)).data.role in [...]` or `request.auth.uid ==
  wid`; writes for owner/admin/editor. Download URLs from `getDownloadURL()`
  (`firebase_attachment_store.dart:77-78`) bypass rules — a removed member keeps URLs they saw.

### W0 emulator spike questions (each answered by a test in `tool/rules_test/`)
0. **Rules language:** `$(myEmail())` with `@ . +` as a doc-path segment in `exists()`; functions
   declared inside `match /shares/{token}` reading `token`/`gen` and `resource`; `let` + ternary in
   functions; `.lower()` and `split()` on strings; `request.auth.token.get('name', …)`;
   `duration.value`; `get()` of a missing member doc errors its operand — `error && x` denies
   (a non-member's `canEdit`) while `error || true` allows (an invitee's invite `get`/`delete` with
   `canAdmin` second); `resource.data.…` on a missing doc (stub/invite `get`) denies.
1. **get() budget in batches:** a 450-write `saveObjectsBatch` by an Editor (each write: member-doc
   `exists` + `get`) — does it pass (cached same-doc calls not counted) or hit the 20-access limit?
   Same for a 450-write template import with auto-number counters, and for a **non-owner Admin**
   publishing with 50 `viewers` and sending 20 email invites in one batch. Fallback if it fails:
   non-owner batches capped at the measured limit (9 writes per commit if no caching) in
   `saveObjectsBatch`, `firestore_share_repository` (stub + registry first, viewers in follow-up
   batches) and `inviteEmails` (slow but correct), and an Admin-only import note; **this decides
   `maxBatchWrites` for members**.
2. **List-rule provability:** do `objects where collectionId == X orderBy updatedAt` and the
   `runs where by == 'user:<uid>'` queries pass with `isMember`/`mine()`, and is an Editor's
   **unfiltered** `runs.orderBy('startedAt').limit(200)` (today's `watchRecent`) denied? Does the CG
   `members` query pass the `{path=**}` rule while the direct-path rule also exists?
3. **CG rule scope:** `{path=**}/members/{uid}` does not match `members/{uid}/grants/{id}` or
   `members/{uid}/viewPrefs/{cid}`; writing `workspaces/<me>/members/<me>/invites/x`,
   `…/members/<me>/members/<victim>` (depth 1), `…/members/<me>/prefs/x/invites/y` or
   `…/members/<me>/assistantThreads/t/members/<victim>` (depth 2) is denied (subtree allow-list by
   name and depth), so no injection reaches a victim's CG query; own threads and messages still
   read/write.
4. **Listener on revocation:** an Editor's open `objects` listener — after their member doc is
   deleted, does the listener error (`permission-denied`) or keep serving the cache? Does the
   self-`get` listener see "doc missing"?
5. **`token.email` casing:** is a Google ID token's `email` always lower-case? (The rules lower-case
   anyway; confirm `.lower()` exists on rules strings and `split('@')[1]` works.)
6. **Chunk `get()` from the parent:** `readable()` in `gens`/`chunks` evaluates `get(shares/token)`
   + `exists(viewers/email)` — cost, and behaviour on a tombstoned stub (must deny).
7. **Accept batch:** member `create` + `prefs/join` `create` (each checks the other with
   `getAfter`/`existsAfter`) + invite `delete` in one batch — `get()` sees the pre-batch invite,
   `existsAfter()` sees it gone; the same batch **without** the delete is denied; re-creating the
   member doc after removal from the same email invite is denied; a rejoin through the link after
   leaving (prefs/join exists → update) passes; a Viewer cannot read the invite-link token from
   any member-readable doc (roster, another member's `prefs/join`, `invites` list/get). An invitee
   (no member doc) can `get` and decline their email invite, and an accept batch that also deletes a
   second email invite to the same address passes.
8. **Same-batch publish:** stub `create` + `viewers/*` `create` (via `getAfter`) + registry in one
   batch. **Tombstones:** after Unpublish, a stranger's `create`/`set` of `shares/<oldToken>` is
   denied; a squatter-style stub can't make an orphan gen of another workspace readable; a reader's
   `get` of `prevGen` after `prevGenUntil`, or after a narrowing refresh, is denied; a `prevGenUntil`
   of `request.time + 90 s` passes and +120 s is denied. **Unpublish:** after the tombstone a gen or
   chunk `create` is denied and an Editor's registry update of a `revokedAt` row is denied; deleting a
   never-written chunk id passes as a no-op. **Lease cap:** an Admin's `leaseUntil` past +120 s is
   denied, and an Editor's `dirtyAt` update under a far-future lease it didn't touch passes.
9. **Batch size for a refresh:** the step-1 batch of §10.8 (gen + ≤ 8 × 700 KB chunks ≈ 5.6 MB) —
   under the commit request size limit? If not, one batch per chunk, gen doc last. Separately: the
   step-2 flip txn (registry re-read + stub + registry) passes for an Editor.
10. **Cache after `terminate()`:** after `terminate()` + `clearPersistence()`, can
   `FirebaseFirestore.instance` be used again in the same process on web / Android / iOS (the app
   holds it in `late final` singletons, `app.dart:131-219`)? What does a second open web tab do
   (IndexedDB owned by another tab → `clearPersistence` fails)?
11. **Auth emulator Google popup** works with the web `signInWithPopup` path for two-user e2e.

---

## 10. Client architecture

### 10.1 Workspace resolution and the workspace session
- `MembershipWorkspaceResolver` (new, `lib/api/team/membership_workspace_resolver.dart`) implements
  the existing seam `WorkspaceResolver` (`workspace_resolver.dart:7-11`, injected at `app.dart:143`),
  whose return type changes from `Future<String>` to `Future<({String wid, WorkspaceRole role})>`
  (the bind needs the role; no clients — break freely):
  1. `ensurePersonalWorkspace(user)` (creates `workspaces/{uid}` + owner member doc if missing;
     no-op offline when cached).
  2. Read `workspaces/{uid}/members/{uid}/prefs/session.lastWorkspaceId` (cache-first).
  3. If set and `≠ uid`: `get workspaces/{last}/members/{uid}` — exists → `(last, its role)`;
     missing/denied → clear `lastWorkspaceId`, return `(uid, owner)`. Never throws (contract at
     `:9-10`).
- **`WorkspaceSession`** (new, `lib/app/workspace_session.dart`) owns the bind/unbind code that
  lives privately in `_MorkvaAppState` today (`app.dart:244-296`; a cubit can't call it there). It
  holds the singletons and runs **one serialised queue** of `bind(user)`, `unbind()`,
  `switchTo(wid, {next})` and `rebind({next})`; the app's auth `BlocListener` and `WorkspaceCubit`
  both enqueue on it. Once a wid is bound for a uid, further `AuthAuthenticated` emissions for the
  same uid are ignored (only sign-out unbinds). It also holds `pendingNext` (default `/`), the route
  `/loading` leaves to once ready (§10.2).
  - Bind order: repo → attachment store → `AutomationWorkspace(wid, uid, role)` → assistant
    (`initialize(wid, user:, role:)`) → runner → refresher. Unbind runs the exact reverse
    (refresher → runner → assistant → … — today's "runner `reset()` before assistant `reset()`" is
    kept), repo `dispose()` before re-`initialize()` (`initialize` alone does not cancel live
    listeners, `firestore_data_repository.dart:181-187`). The refresher binds after the assistant
    because it leases the harness `WorkspaceCache`, whose lifecycle `AssistantSession` owns
    (`harness_session.dart:85-94`).
- **Switching = unbind + bind(newWid)**: `sessionReady=false` bounces the router to `/loading` and
  unmounts every page/shell cubit (`CollectionsListCubit`, `PinnedCollectionsCubit`, per-page cubits
  keyed by route) — they rebuild on the new repo. `pendingNext` is set before the unbind (`/` for a
  switcher switch, the target for a `/w/` link). Singletons that re-bind and how:
  | Holder | Re-bind |
  |---|---|
  | `FirestoreDataRepository` | `dispose()` → `initialize(wid, uid:)` |
  | `FirebaseAttachmentStore` | `initialize(wid)` (plain reassignment) |
  | `AutomationWorkspace` | `initialize(workspaceId:, uid:, role:)` — the run store reads its scope from here (§10.10) |
  | `AssistantSession` | `reset()` → `initialize(wid, user:, role:)` (already resets the harness cache) |
  | `AutomationRunner` | `reset()` (exists, `automation_runner.dart:263`) → `initialize(...)` |
  | `_AutomationCubits` | closed and recreated (as sign-out/sign-in) |
  | `SyncStatusCubit` | new `reset()` — a sticky `SyncConflict` must not cross workspaces |
  | `PublishRefresher` (new) | `reset()` → `initialize(wid, uid, role)` |
  | `WorkspaceCubit` (new) | emits the new `CurrentWorkspace` |
  | crash breadcrumb `morkva.automation.crash` (`crash_marker_web.dart:10-40`) | key unchanged: `reset()` already clears it on an in-process switch (`automation_runner.dart:282`); after a crash + reload into another workspace, `_recoverCrash` drops a breadcrumb whose `automationId` is not in the bound workspace (ids are random) |
  The `_initializedWorkspaceId` guard (`app.dart:253`) moves into the session; a successful switch
  writes `prefs/session.lastWorkspaceId`.
- `WorkspaceCubit` (app-level, provided above the router) state `CurrentWorkspace {wid, name, role:
  WorkspaceRole, isPersonal, ownerName}`; watches the workspace doc (name) and the own member doc
  (role; **removal**: snapshot `!exists` from server, or `permission-denied` → `removed` event →
  dialog §6 → `switchTo(uid)` + purge flag §10.9).
- **Role changes = a rebind of the same wid** (`rebind(next: <current location>)`), not a per-service
  `setRole`: the run store's query scope, the TeamCubit `invites` listener (`list: canAdmin`), the
  assistant's grants (`AgentLoop._grants` is final and tool sets are cached per thread,
  `agent_loop.dart:144, 373`) and the refresher all depend on the role, and the rebind is the same
  tested path as a switch. `WorkspaceCubit` first emits a one-shot `roleChanged` (snackbar, §6).
  A card editor with unsaved edits **defers** the rebind until it closes (`WorkspaceSession.hold()`
  while dirty); during the hold the UI already re-gates from the new role, so a demoted editor's
  Save is disabled with the banner in §6, and listeners that the new role may no longer open
  (admin-only runs/invites) may error until then — their pages show their error state.
- Pending writes on switch: the unbind first awaits `waitForPendingWrites()` with a 5 s timeout
  (queued plain writes such as view prefs); on timeout the switch proceeds — the writes stay queued in
  the cache and land later (paths are workspace-qualified, so they cannot leak across).
- Offline: the switcher disables other workspaces ("Connect to switch workspaces"); a switch that
  fails mid-way rebinds the previous wid and shows the interstitial error (§6).

### 10.2 Routing (`lib/app/router/app_router.dart`)
- **Path URL strategy:** `usePathUrlStrategy()` in `main.dart` (`flutter_web_plugins` SDK dep);
  Hosting rewrites `** → /index.html`. Today's hash URLs (`#/collections/…`) stop working — no
  clients; update e2e scripts (memory "Web e2e on emulator" uses `#/automations?tab=`).
- **Public routes** outside the shell and the gate: `/s/:token` (`PublicViewPage`) and
  `/join/:wid/:id` (`JoinPage`). The redirect (`:62-94`) returns `null` for them in every auth state;
  the pages render their own sign-in buttons and loading. A signed-in outsider still gets their
  personal workspace booted in the background: signing in on `/s/` or `/join/` creates a Morkva
  account with an empty personal workspace (`ensurePersonalWorkspace`); the pages say so in a
  footnote ("Signing in creates a free Morkva account. You don't have to use it.", §6).
- **Preserve `next`** only where it is lost today — an **unauthenticated** visit or a **cold start**
  on a deep link: unauthenticated → `/sign-in?next=<encoded location+query>`; on sign-in or cold
  boot the session's `pendingNext` is set from `next` if safe (starts with `/`, not `//`, not
  `/sign-in`/`/loading`) else `/`. Authenticated not-ready → `/loading` (no `next`); ready on
  `/sign-in` or `/loading` → `pendingNext`, then reset to `/`. An unbind caused by a switch, a role
  rebind or sign-out never captures the current location (a switch made from `/collections/<A's
  cid>` must land on Home in B, not on A's collection). Fixes today's cold deep link landing on `/`
  (`:88`). Sign-in page passes `next` through Google sign-in.
- **Workspace prefix** *my call*: only an entry redirector, not a prefix on every route (keeps all
  existing routes and keys, e.g. `ValueKey('/collections/$id')`, untouched). Declared as
  `GoRoute(path: '/w/:wid/:rest(.*)', redirect: …)` (+ `/w/:wid` → Home) — go_router 14.8.1 supports
  regex params (`path_utils.dart:8`); the redirect reads `state.uri` (`matchedLocation` is not
  meaningful there) and forwards `state.uri.query`:
  - `wid == current` → `/<rest>?<query>`;
  - else → `session.switchTo(wid, next: '/<rest>?<query>')` (scheduled, not awaited) and return
    `/loading`; `/loading` leaves to `pendingNext` once ready. Non-member (the switch's member `get`
    is missing/denied) → the session stays on the current wid and routes to
    `/no-access?wid=<wid>&next=…` (`NoAccessPage`, outside the shell, behind auth; §6).
  Limitation: the address bar shows workspace-less paths; a URL copied from the address bar opens
  in the *recipient's* current workspace. "Copy link" always writes the `/w/` form. Upgrade path: a
  real `/w/:wid` prefix on every route when this bites.
- New routes `/settings/team`, `/settings/shared-links`, `/no-access`, `/w/…`, `/s/:token`,
  `/join/:wid/:id` — **all registered by T3** with placeholder page widgets in their final files, so
  later tasks fill those files without touching the router. `?share=1` on `/collections/:id` opens
  the share popover (dropped with `_dropParams` like `view`/`card`).
- Mobile deep links (W5, needs owner step): Android intent filter with `autoVerify` for
  `https://<origin>` paths `/s/`, `/join/`, `/w/` (`AndroidManifest.xml:23-26`), iOS associated domains
  `applinks:<origin>`, Hosting `.well-known/assetlinks.json` + `apple-app-site-association`. Until
  then links open the web app on phones.

### 10.3 New modules and files
```
lib/api/team/
  workspace_role.dart             enum WorkspaceRole {owner, admin, editor, viewer} + can* getters + grants()
  team_records.dart               Member, Invite, WorkspaceInfo, JoinedWorkspace, Invitation (+ codecs)
  team_repository.dart            interface
  firestore_team_repository.dart  ensurePersonalWorkspace, watchWorkspace, rename, watchMembers,
                                  watchMyMembership, changeRole, remove, leave, watchInvites,
                                  inviteEmails, renewInvite, revokeInvite, getInvite, linkInvite
                                  create/reset/turnOff, accept, decline, watchJoined (CG members),
                                  watchInvitations (CG invites; only 4-segment paths accepted,
                                  decoded defensively), setLastWorkspace
  membership_workspace_resolver.dart
  invite_links.dart               joinUrl / teammateUrl / shareUrl builders (origin constant), mailto body
lib/api/share/
  share_records.dart              PublishedView (registry), ShareStub, ShareGen, column/row codecs
  share_repository.dart           interface
  firestore_share_repository.dart publish, updateSettings, setViewers, regenerate, unpublish
                                  (tombstone first), renameWorkspace fan-out to live stubs,
                                  watchRegistry, markDirty, tryLease/releaseLease, writeGeneration,
                                  readStub/readGen/readChunks (outsider side)
lib/core/share/
  share_token.dart                128-bit Random.secure() → base64url (22 chars)
  snapshot_builder.dart           pure: (Collection, frozen definition, fieldIds, derived objects,
                                  reference title resolver, now) → ShareGen + chunks
  publish_deps.dart               publishDeps(entry, collections) = collection ∪ sourcesOf ∪
                                  targets of published reference columns and definition filters
  publish_refresher.dart          session service (§10.8)
lib/app/
  workspace_session.dart          serialised bind/unbind/switch/rebind queue, pendingNext, hold() (§10.1)
lib/features/team/
  bloc/{workspace_cubit,team_cubit,invite_cubit,join_cubit,switcher_cubit,no_access_cubit}.dart
  view/{team_page,invite_sheet,join_page,no_access_page,workspace_switcher,invitation_banner,
        removed_dialog,role_select}.dart
lib/features/share/
  bloc/{share_cubit,shared_links_cubit,public_view_cubit}.dart
  view/{share_popover,share_fields_page,shared_links_page,public_view_page,public_table,
        csv_export}.dart
```
Touched: `lib/app/app.dart`, `lib/app/router/app_router.dart`, `lib/main.dart`,
`lib/app/shell/{shell_sidebar,app_shell_scaffold}.dart`, `lib/features/settings/settings_page.dart`,
`lib/features/views/{collection_views_page,collection_views_cubit}.dart`,
`lib/features/views/widgets/{view_tabs,view_toolbar}.dart`, `lib/features/objects/object_editor_cubit.dart`,
`lib/features/collections/editor/collection_editor_cubit.dart`, `lib/core/domain/morkva_object.dart`,
`docs/domain-json-schema.md`, `lib/api/workspace/workspace_resolver.dart`,
`lib/api/automation/firestore_docs.dart` (`AutomationWorkspace` gains uid + role),
`lib/features/collections/list/*`, `lib/api/data/{data_repository,firestore_data_repository}.dart`,
`lib/api/sync/sync_status_cubit.dart`, `lib/core/automation/automation_runner.dart`,
`lib/api/automation/firestore_{automation,run}_store.dart`, `lib/features/assistant/bloc/{assistant_session,assistant_bloc}.dart`,
`lib/api/assistant/assistant_config_repository.dart`, `firestore.rules`, `firestore.indexes.json`,
`firebase.json` (hosting), `web/index.html` (nothing — headers live in Hosting), `pubspec.yaml`
(`share_plus`, `flutter_web_plugins: sdk: flutter`, `path_provider` — today only transitive, and
`depend_on_referenced_packages` flags a direct import; §10.9).

### 10.4 Cubits (BLoC; widgets stay dumb)
| Cubit | Scope | State |
|---|---|---|
| `WorkspaceCubit` | app | `CurrentWorkspace` + `removed` / `roleChanged` one-shots; `switchTo(wid)` enqueues on `WorkspaceSession` |
| `SwitcherCubit` | shell | own workspace, joined list (CG members + N workspace gets for names), invitations (CG invites, unexpired) |
| `TeamCubit` | `/settings/team` | members, pending invites, link invite; actions with per-row busy/error |
| `InviteCubit` | invite sheet | parsed emails + per-row validation, role, step, created invites |
| `JoinCubit` | `/join` | the state table in §6 (Offline from the read error, not the sync status) |
| `NoAccessCubit` | `/no-access` | my invitations for that wid → "Join and open", else no access |
| `ShareCubit` | share popover | access mode, registry entry (if any), draft settings, publish/refresh status, offline |
| `SharedLinksCubit` | `/settings/shared-links` | registry list |
| `PublicViewCubit` | `/s/:token` | stub → gen → chunks; search query; states in §6 (Offline/Off from the read itself) |

### 10.5 Role gating, Ask Morkva, feature flag
- `WorkspaceRole` is the single mapping: UI getters, `grants()` (§7 list), and the runner's role cap
  set. Widgets read it via `context.select((WorkspaceCubit c) => c.state.role.canEditCards)`.
- Ask Morkva: `AssistantSession.initialize` takes the role → `Grants(role.grants())`; commit uses
  role grants + `hostCommit`. `grantConsent` (`assistant_config_repository.dart:53-60`) is shown only to
  the owner; others see "Ask Olena Koval (owner) to turn on Ask Morkva for Morkva Wear." (owner name
  from the roster).
- Per-member counter: before each turn `members/{uid}/usage/{yyyy-MM-dd}` `turns` is read
  (cache) and incremented after; at `dailyTurnsSoft` (`assistant_config.dart:43`, default 200,
  parsed but unenforced today) the composer shows "You've used today's 200 questions. More
  tomorrow." Advisory: a member can reset their own doc — it is a guard rail, not a quota.
- Feature flag stays per user (`featureFlags/{uid}`): a member without the flag sees no assistant in
  any workspace (limitation; per-workspace flags are out of scope).

### 10.6 Conflict model for two humans
Today's model (traced in research, `firestore_data_repository.dart:448-487, 962-999`) was built for one
writer. Changes:
1. **Changed keys only — no new parameter.** `saveObject` already merges `{...stored, ...encoded}`
   in its txn (`:457`) and `MorkvaObject.copyWith` does not re-normalise, so a caller that passes a
   partial object writes only those keys. The editor already sends its draft keys
   (`object_editor_cubit.dart:592-601`) and `_revertField` one key via `saved:`
   (`collection_views_cubit.dart:1003-1016`). The only whole-values writers are `moveToGroup`
   (`:784-790`) and `moveToDay` (`:831-835`): they pass `saved: object.copyWith(values: {field.id:
   value})`, the `_revertField` pattern. Field-level last-write-wins everywhere.
2. **No resurrection.** `DataRepository.saveObject(object, {bool mustExist = false, MorkvaObject?
   base})`. `mustExist: true` is passed only by paths that edit a loaded card: the editor's
   existing-card save, `setChildValue` (`object_editor_cubit.dart:304`), `_revertField`, and
   `moveToGroup`/`moveToDay` (the views cubit's only other object writers are quick add `:970` and
   delete-undo `:995`). Creates (templates `collections_list_cubit.dart:99`, quick add
   `collection_views_cubit.dart:970`, the editor's create `object_editor_cubit.dart:601`) and the
   **undo of a delete** (`collection_views_cubit.dart:989-996`, which re-creates the whole card) keep
   the default `false`. With `mustExist` the txn sees `current == null` → throws
   `ObjectDeletedException` (no write, no new auto-number) → the editor sets `remoteDeleted` and shows
   its existing banner ("This order was deleted elsewhere." / "Save as new to restore it."); only the
   user's explicit second Save writes it back (`mustExist: false`). Board/calendar drag → snackbar
   "This order was deleted by someone else." *my call:* no deleter name — a hard delete leaves no author,
   and a tombstone would add a filter to every query.
3. **Attribution.** `MorkvaObject` gains nullable `createdBy`/`updatedBy` (constructor,
   `fromJson`/`toJson`, equality — equality drives the `decoded[id] != object` diffing at
   `firestore_data_repository.dart:331`); `_objectFromData` (`:930-948`) decodes both;
   `docs/domain-json-schema.md` updated. Harness card shaping does **not** expose them to modules or
   the LLM in v1 *my call*. The editor's field-conflict banner (`object_editor_cubit.dart:370-410`)
   names the other member from the incoming object's `updatedBy` via the roster: today "Status was
   changed elsewhere." / "Saving will overwrite it with your value." → "Iryna Bondar changed Status."
   / same second line (own uid → "You changed Status on another device."; unknown → "Someone
   changed Status."). The editor header shows "edited 2 h ago by Iryna Bondar" (§6).
4. **Conflict warning at write time, not from listeners.** The passive detector — a server rev jump
   past `_localRev` in `processSnapshotMeta` (`:962-999`) — goes away with `_localRev`: card saves
   are transactions that re-read and merge, so a teammate's concurrent write to *another* field is
   merged, not lost (a false alarm), and snapshots with `hasPendingWrites` skip the check entirely.
   Instead `saveObject` takes `base` (the card as the writer loaded it): inside the txn, for each
   written key whose server value differs from `base`'s, the write still lands (LWW) and the repo
   reports `SyncConflict(objectId, fieldIds, by: current.updatedBy)` to the existing global banner —
   "Iryna Bondar changed Status a moment before you — your value replaced it." (own uid: "You
   changed Status on another device a moment before — this value replaced it."). Same-field races
   are the only ones flagged, for teammates and for one person on two devices alike (the case
   71d213f protected). `_pendingObjects` stays for the pending indicator. The pinned test
   `firestore_data_repository_test.dart:529-546` ("a remote jump past a server-seen baseline still
   is one") is rewritten: a passive jump raises nothing; a same-field overwrite in `saveObject`
   raises one with attribution. `saveObjectsBatch` updates (`:786`, blind per-key `batch.update`:
   plans and their undo, automations, imports) are **not** checked (Limitations). Names come from an
   injected `String? Function(String uid) nameOf` on the repo/editor (T2, defaults to "Someone"),
   which T3 wires to the roster.
5. **Schema and views writes** (Admins only now) move to the existing transactional
   `updateCollection`/`updateViews` (`:854-886`) so two admins merge instead of overwrite — with
   `apply` merging, not replacing: the collection editor (`collection_editor_cubit.dart:299-302`,
   today `saveCollection(draft.withNewFieldsInViews(saved))`) uses `updateCollection(id, (server) =>
   draft fields + layout, server's views with the new field ids appended)`; `apply: (_) => toSave`
   would still wipe another admin's view edits. `CollectionViewsCubit._updateView(viewId, update)`
   → `updateViews((server) => [for v in server: v.id == viewId ? update(v) : v])`. Creating a
   collection stays on `saveCollection` (`updateCollection` throws on a missing doc). Transactions
   fail offline, so Admin schema/view edits need a connection (Limitations); personal prefs
   (§10.7) still queue offline.
6. Batches: one `not-found` fails a 450-write chunk (`:653-662`); with teammates deleting cards this
   is likelier — the plan/automation error copy says "Some cards were deleted by someone else" for
   `not-found` ids. No retry logic change.
7. Presence ("Iryna is editing") — later.

### 10.7 Personal view prefs and pins
- `ViewPrefsRepository` (in `lib/api/data/`) watches `members/{uid}/viewPrefs/{cid}`;
  `CollectionViewsCubit` layers prefs over the shared `ViewDefinition` before `applyView`
  (`view_query.dart:146-196`). Prefs replace the shared value **per key** (sort replaces sort,
  filters replace filters).
- **One path for every role** *my call*: sort/filter edits and collapsed groups always go to prefs,
  and the toolbar shows "Your sort & filters are only for you · Reset". Admins additionally get
  "Save for everyone" on that chip, which writes the prefs into the shared view via `updateViews`
  and clears them. (Admins could otherwise not sort a view for themselves without changing it for
  the team.)
- Prefs apply everywhere, including when a teammate's `?view=` link is opened *my call* — the chip
  makes the difference visible, and a second mode would cost more than it explains.
- Active view per collection persisted in prefs (today in-cubit only); `?view=` still wins.
- Pins: `PinnedCollectionsCubit` reads/writes `members/{uid}/prefs/pins` (replacing the workspace doc
  field at `firestore_data_repository.dart:212-238`).

### 10.8 Published-copy publisher and refresher
- **Frozen definition** *my call*: on publish and on "Update the copy", the view's name (→ registry
  `title`, which the gen copies) and its `type`, `filters`, `sort`, `groupBy`/date field and
  `manualOrder` are copied into the registry's `definition`. The
  builder never reads the live view, so an Admin who edits "For Sunflower Studio" for internal use
  (drops the Customer filter, renames it) changes nothing outsiders see — "filters locked" is
  literal. Deleting the live view leaves the copy working (Shared links tags it "View deleted");
  deleting it through the app's delete flows unpublishes the copy too (§6).
- **Dependencies** (`publishDeps`): the collection ∪ `Derivation.sourcesOf` (calculated sources
  only, `derivation.dart:87-106`) ∪ the target collections of every published reference column and
  of every reference filter in the definition. Plain reference targets are not sources, so without
  them renaming the "Sunflower Studio" customer card would never refresh the Orders copy.
- **Snapshot builder** (`lib/core/share/snapshot_builder.dart`, pure, no Firestore):
  1. Inputs: `WorkspaceCache.derive(cid, today:)` (`workspace_cache.dart:221-235`: the collection +
     its sources with calculated values) plus a `lease` on the remaining `publishDeps` targets.
  2. `applyView(definition, derived)` — filters (incl. on fields not published), sort, manual order;
     relative date filters evaluated at `now` (the copy is a snapshot; the outsider sees
     "Updated …").
  3. Project `fieldIds` (+ forced board group field / calendar date field) to opaque columns; a
     `fieldIds` entry no longer in the schema is skipped; values to display primitives (§8);
     references → target titles via `objectLabels` (the views cubit's `_labelsFor` path,
     `collection_views_cubit.dart:404-418`); select → option index + column option table (only that
     field's options); files → names.
  4. JSON-encode rows, cut into chunks ≤ 700,000 bytes; stop at 5,000 rows or 8 chunks →
     `truncated`.
- **Publish** (Admin, online): the token is generated client-side and the link copied in the click
  handler (§6) → batch: stub (`gen: null`) + `viewers/*` + registry (with `definition`,
  `settingsRev: 1`, `dirtyAt: serverTimestamp()`, so it is born dirty and any Admin/Editor device
  builds it if the publisher's first refresh never lands) → then the first refresh (lease taken by
  the publisher). Outsiders opening the link before it lands see "being prepared".
- **Settings writes** (Admin): fields, "Update the copy", audience, viewers, expiry, download — each
  is one registry write that also does `settingsRev: increment(1)` + `dirtyAt: serverTimestamp()`
  (with the stub mirror in the same batch where it applies). Audience, viewers and expiry gate on the
  stub, so they bite at once; fields and filters bite at the rebuild.
- **Refresh kinds.** A **content** refresh (data edits) flips with `prevGen: old, prevGenUntil:
  generatedAt + 60 s`. A **narrowing** refresh flips with `prevGen: null` and deletes the old gen
  right after the flip, so data the admin just removed is never served again (rules serve `prevGen`
  only before `prevGenUntil`). A build is narrowing when its `startSettingsRev != builtSettingsRev`
  (a settings change since the current gen), or when a `fieldIds` entry is missing from the schema
  (a published field was deleted — decidable by any builder, Editors included, so no window). An
  Admin device that sees such a missing id also prunes it from `fieldIds` with a settings write, so
  later refreshes are content again. A reader caught mid-flip re-reads the stub once (below).
- **Refresh triggers** (Admin/Editor devices only, online):
  a. a local card write (`DataRepository.changes`, any origin) in any `publishDeps` collection, or a
     schema change of one of them (the refresher's `WorkspaceCache` collections stream, compared by
     schema) → debounce 2 s → `registry.dirtyAt = serverTimestamp()` (one plain write, queues
     offline). Live **view** edits are not a trigger (frozen definition);
  b. the device watches `publishedViews` (small listener); any entry with `dirtyAt != builtDirtyAt`
     and a free lease schedules a refresh after 10 s debounce + 0–5 s jitter (so the writer's device
     usually wins and others back off); a dirty entry whose lease is held gets a re-check timer at
     its `leaseUntil` + jitter (an expiring lease emits no snapshot, so a dead holder would otherwise
     strand it); expired entries and entries with `revokedAt` are skipped;
  c. "Update now", publish, settings change → immediate on that device (kind per the rule above);
     if the lease is held elsewhere, (b) picks it up when the lease frees — the entry is dirty;
  d. a definition with relative date filters ("next 7 days") is rebuilt once a day (first online
     Admin/Editor device after midnight), since `dirtyAt` never moves for those.
- **Lease** (one device rebuilds at a time): txn on the registry doc — take it if `leaseUntil == null
  || leaseUntil < now || leaseBy == me`; set `leaseBy = uid:sessionKey`, `leaseUntil = now + 90 s`
  (rules cap it at now + 120 s for every role); from this same read remember `startDirtyAt`,
  `startSettingsRev` **and the `fieldIds`/`definition` the build uses** (a separate read would let a
  settings change slip between them). Clock skew between devices is absorbed by the 30 s margin. A
  lost lease or an aborted flip is not silent data loss: the entry stays dirty, so (b) rebuilds it.
- **Build** reads through the harness `WorkspaceCache` (`workspace_cache.dart:175` `lease([...])`) —
  the same cache the assistant and runner use; listeners on the deps, so a session pays the initial
  read once and deltas after.
- **Write a generation** (no torn reads): `gen = <base36 millis><4 random>`;
  1. batch: `gens/{gen}` + `gens/{gen}/chunks/{0..k}` (if over the commit size limit, one batch per
     chunk, gen doc last — W0 Q9);
     Before step 1 the registry's `gens` map gets `{new: k+1}` (so a crash leaves a nameable orphan).
  2. txn: re-read the registry; abort (release the lease, keep the new gen in `gens` for cleanup)
     if the lease isn't ours, `settingsRev != startSettingsRev` (settings changed mid-build — the
     build used old columns/filters; `dirtyAt` moved with it, so the entry stays dirty) or
     `revokedAt` is set; else stub `{gen: new, prevGen, prevGenUntil, generatedAt}` (per the refresh
     kind) + registry `{gen, generatedAt, generatedBy, rowCount, totalCount, truncated,
     builtDirtyAt: startDirtyAt, builtSettingsRev: startSettingsRev, leaseBy: null, leaseUntil:
     null, lastError: null}`;
  3. cleanup: delete every entry of `gens` except `gen` (and `prevGen` for a content refresh; it goes
     on the next refresh) — chunks `0..count-1`, then the gen doc — then drop those keys from the
     map; failures stay in the map and are retried next refresh *my call*. Outsiders can read only
     `gen`, and `prevGen` for ~60 s, of the stub's own workspace, so an undeleted older gen is
     unreadable to them.
  An edit that lands during the build moves `dirtyAt` past `startDirtyAt`, so the entry stays dirty
  for every device and gets rebuilt — even if this builder dies after the flip.
  Outsider reader: reads stub → gen → chunks; a missing or denied chunk (refresh raced) → re-read
  stub once.
- **Errors**: `too_large` (single row > chunk budget), `permission` (role changed), `source_gone`
  (collection deleted outside the delete flow), `failed` → registry `lastError` → Shared links
  "Couldn't update — Retry" (or the tag in §6).
- **Unpublish** (Admin): (1) one batch: **tombstone the stub** (`revoked: true`) + registry
  `revokedAt: serverTimestamp()` — from this write on the link is dead for everyone, which makes the
  confirm copy "stops working right away" true even if the rest crashes; rules then deny new gen and
  chunk creates under the stub and Editor registry writes, so a refresher still mid-build can neither
  flip nor leave an unnamed orphan, and refreshers and the rename fan-out skip the row; (2) for each
  id in registry `gens` (read after step 1, so every gen that could have been written is named),
  delete its chunks then the gen doc (a never-written id deletes as a no-op); (3) viewers (ids from a
  `list`, allowed to admins); (4) registry last. A crash leaves the row with `revokedAt` → Shared
  links "Unpublishing… Retry", which resumes at step 2 (the tombstone is final, so step 1 is never
  re-sent). The stub is never deleted. **Regenerate**: publish a new token with the same settings
  (its registry born dirty, like any publish), then unpublish the old one.
- **Workspace rename** (Owner/Admin) = one batch: the workspace doc + `workspaceName` on each live
  stub named in the registry (rows without `revokedAt` — a tombstone denies every update and would
  fail the batch; Admin-writable; ≤ a few dozen). Pending invites keep the old name until
  they expire (Limitations).
- Viewers never refresh (no write access); a view with only Viewers online stays stale.
- Cost per refresh ≈ 1 gen + k chunks + 2 metadata writes + (k+1) deletes; with the 10 s debounce a
  busy hour of edits is ~360 refreshes max per published copy → ~2k writes; the 20k/day Spark write
  quota bounds this at a handful of very active published copies (stated in Limitations).

### 10.9 Sign-out and removal cache purge
- On sign-out, removal and leave: set a local flag (`localStorage` `morkva.purge=1` on web via
  `package:web`; a file in the app support dir on mobile via `path_provider` — today only a
  transitive dependency, so T3 adds it to `pubspec.yaml` *my call*), then:
  - web: `window.location.reload()` → `main.dart` sees the flag and calls `clearPersistence()`
    **before** any other Firestore call, clears the flag, boots normally. The reload keeps the current
    URL (a "Switch account" on `/join/` or `/s/` comes back to that page, signed out);
  - mobile: the same check on next cold start (data stays on the device until the app restarts —
    limitation).
- Before sign-out: `waitForPendingWrites()` with 10 s timeout; on timeout dialog "Some changes
  haven't synced yet. Sign out anyway?" / "Sign out" · "Stay". Removal skips this (writes would be
  denied anyway).
- If W0 Q10 shows `terminate()`+`clearPersistence()` + re-use works in-process, replace the reload
  with that; the flag path stays as the crash-safe fallback.
- The emulator e2e cannot exercise the purge (`main.dart:54-57` turns persistence off under
  `MORKVA_FIRESTORE_EMULATOR`); T0b's probe answers it on a persistence-on build, and the e2e does not
  assert it.

### 10.10 Automations under teams
- `_pause` (`automation_runner.dart:1264-1269`) stops saving the whole doc; new
  `AutomationStore.pause(id, reason, detail)` updates only `pausedReason`, `brokenDetail`,
  `updatedAt` — today the whole-doc save is rejected for non-authors of Auto automations
  (`firestore.rules:82-83`) and the error swallowed, so a broken automation would re-fire on every
  member's device.
- **Another admin's Auto automation.** Saving it in the editor re-stamps `autoBy` to the saver
  (`automation_editor_cubit.dart:573`, today's behaviour), so Auto moves to the saver's device under
  the saver's own consent and the original author's device asks first; the editor sheet says so when
  `autoBy ≠ me`: "Saving makes Auto run on your device instead of Olena's." The on/off switch
  (`modules_cubit.dart:333`) and Resume (`automation_runner.dart:2018`) keep `autoBy` and pass the
  enable/pause carve-out in §9, which can't change what runs.
- Run log scope is a **store** concern: `FirestoreRunStore` reads `(uid, ownOnly)` from
  `AutomationWorkspace` (bound with the role, §10.1) and adds `.where('by', isEqualTo: 'user:$uid')`
  to `_newestFirst` (`firestore_run_store.dart:17-24`) when the role is below Admin. All six
  consumers of the unfiltered `watchRecent()` inherit it — `automation_runner.dart:249`
  (`_finalizeOwn` on every bind), `store_catalog.dart:38` (assistant `listRuns`),
  `review_sheet_cubit.dart:131`, `module_details_cubit.dart:170`, `automation_runs_cubit.dart:206`,
  `run_log_cubit.dart:357` — instead of each being denied for Editors (rules are not filters). The
  composite index in §8 covers it. `prune()` (`firestore_run_store.dart:45-63`) uses the same scope
  (admins prune all); `_finalizeOwn` (`automation_runner.dart:1380-1405`) therefore expires only own
  runs. A role change rebinds (§10.1), so the scope never goes stale. "Review not available here" copy
  (`reason_copy.dart:300-303`) becomes "This review is waiting on <name>'s device" when `by ≠ me`.
- Triggers keep firing only on the writer's device (`data_repository.dart:126-128`), under the
  writer's own consent; an Auto automation runs Ask-first on other members' devices
  (`apply_policy.dart:53-55`). Automations page subtitle: "Runs on the device of whoever changes the
  card — for members who allowed it." An Editor with missing consents sees a banner "2 automations
  need your OK to run on your device." + "Review".
- Loop budget stays per device (`loop_guard.dart:166-180`): N members → N× budget (Limitations).

### 10.11 Files (Storage, deferred)
Path stays `workspaces/{wid}/files/{attachmentId}/{name}` (`firebase_attachment_store.dart:38`);
`storage.rules` gets the cross-service membership check (§9 note) when Storage is enabled at project
end (memory "Storage deferred"). Download URLs are bearer tokens — a removed member keeps URLs they
already saw (Limitations).

---

## 11. Limitations

Plain list; the UI copy above already says the user-facing ones.
- Members see **every field of every card** in the workspace; there is no field or row privacy on live
  data (Firestore rules cannot hide fields or filter by a view). Outsiders only ever get a published copy.
- Published copies are **stale while no Admin/Editor has Morkva open** (no server on Spark); the
  outsider sees "Updated …".
- Field hiding in a copy is enforced by the member client that writes it — not by the server.
- **Morkva sends no emails** (Spark: email-link sign-in is 5/day and needs the Email/Password
  provider; the Trigger Email extension needs Blaze and Extensions shut down 2027-03-31). Invites are
  delivered by the sender's own email app, copy link or share sheet.
- **Google sign-in only:** invitees and email-audience outsiders need a Google account (one can be
  created for any existing email address). Email matching is exact: Gmail dots/aliases and Workspace
  aliases don't match ("Switch account" / "ask to invite this email instead").
- The Spark read quota (50k reads/day, project-wide) can be exhausted by **any Google user** — on
  their own personal workspace, with or without published copies (denied reads are billed too). A
  public link adds ~9–12 reads per open. Mitigation is App Check enforcement (after Android/iOS are
  registered) and a budget-guarded Blaze plan, not rules (owner decision 2).
- Each refresh costs writes from the 20k/day Spark write quota; a few very busy published views are
  the practical ceiling.
- A removed member keeps what their device cached until the purge runs (web: immediately via reload;
  mobile: next cold start) and keeps any file download URLs they saw (later, Storage).
- A removed member's private subtree (`members/{uid}/assistantThreads`, `prefs`, `viewPrefs`,
  `grants`, `usage`) stays in the workspace: rules no longer let them delete it, and admins cannot
  read or delete another member's private docs. Harmless but unbounded; a cleanup needs a server (D).
- Assistant threads keep result tables a member saw before losing access (they are private to that
  member and deleted only by them).
- Card transactions fail offline (already true): creating a card with an auto-number needs a
  connection; the workspace `counters` doc is a shared hot spot under many simultaneous creators.
- An Editor can rewrite `counters` (rules can't tell a legit bump from a reset).
- Last-write-wins per field; no real-time co-editing, no presence. A same-field overwrite by a
  single-card save is flagged after the fact (§10.6), not prevented. Bulk writes (Ask Morkva plans
  and their undo, automations, imports) are not checked for same-field races.
- Admin schema and shared-view edits are transactions, so they need a connection (personal sort,
  filter and collapse still work offline).
- After a content refresh a published copy's previous generation stays readable for ~60 s (rules
  allow up to 90 s for clock skew), so a row that just left the filter can still be fetched in that
  window by someone who holds the link. Audience, viewers, expiry and Unpublish bite immediately;
  field and filter changes take effect at the next rebuild — at once on the Admin's device when it
  gets the lease, otherwise within ~1–2 min while an Admin/Editor is online (the old gen, with the
  removed field, keeps serving until then).
- Anyone who holds the invite link — including a member who joined with it, then left or was
  demoted — can (re)join through it at the link's role until it is reset or expires (≤ 30 days);
  demoting or removing such a member offers "Also reset the invite link".
- Renaming the workspace updates live published copies but not pending invites (they show the old
  name until they expire, ≤ 14 days).
- An Editor's client can rewrite a registry's `gens` map and so hide orphan chunks from cleanup
  (storage cost only — outsiders still can't read them).
- No "who deleted this card".
- Ask Morkva availability follows the user's own feature flag, not the workspace's; turn limits are
  advisory; the Gemini quota is project-wide.
- Automation triggers run on the writer's device under the writer's consent → behaviour differs per
  member; the loop budget is per device.
- The address bar shows workspace-less URLs; only "Copy link" links carry the workspace.
- One invite link per workspace; one email domain per link; no "request access" flow.
- Workspaces are personal only: no "create team workspace", no ownership transfer, owner cannot leave.
- Dynamic Links are dead; phone links open the web app until App Links / Universal Links are set up
  (owner step).
- The share link reveals the workspace id (the owner's Firebase uid; not a credential).

## 11b. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| `get()`-based rules exceed the 20-access budget in 450-write batches | Editors' imports/plans/automations fail; non-owner Admins' publish (50 viewers) and invite batches fail | W0 Q1 decides; fallback: small non-owner batches in the data, share and team repos |
| Rules sketch wrong somewhere (composed, not run) | data exposure or broken app | W0 harness + a test per allow/deny row before W1 merges; owner deploys only after green |
| Session re-bind misses a singleton | data of workspace A shown/written in B | rebind table §10.1 + a `WorkspaceSession` test that switches A→B (and rebinds A on a role change) and asserts every store's wid and role; `MorkvaApp` with fakes never touches the real instance |
| Router change (path strategy, `next`, public routes) regresses deep links and every e2e script | broken navigation | `app_router_test.dart` gains cold-link-through-auth tests; e2e scripts updated in W5 |
| Conflict model changes cause lost edits | silent data loss | two-repo tests (§12) for each traced case before the change; `mustExist` defaults to `false`, so a missed caller keeps today's behaviour |
| Refresher bugs publish hidden fields | privacy breach | builder is pure + golden-tested: every published JSON is checked to contain no unpublished field id, value or option label |
| Quota exhaustion (any Google user, or public-link loops) | app down for all users that day | only App Check enforcement + budget-guarded Blaze mitigate; `kAnonymousLinks=false` makes every read need sign-in; owner decision 2 |
| A leaked link is re-used after Unpublish/Regenerate | attacker content under the owner's name | stubs are tombstoned, never deleted; rules tests in W0 Q8 |
| An admin narrows a copy but old data stays fetchable | hidden fields leak | settings writes bump `settingsRev` + `dirtyAt`; a build that straddles a settings change aborts; narrowing refreshes drop `prevGen` and delete the old gen; `prevGenUntil` bounds the rest; W0 Q8 + refresher tests |
| Lease never released (device dies mid-refresh) | copy stuck stale | `leaseUntil` expiry (90 s) + a re-check timer at `leaseUntil` on every device that sees the entry dirty |
| Mobile purge deferred to cold start | removed member's data readable offline | stated limitation; W0 Q10 may allow in-process purge |
| UI collection delete leaves orphan cards (`collections_list_cubit.dart:136` deletes only the schema; pre-existing) | orphan data visible to nobody but billed; a teammate mid-create races | out of scope here; noted for a fix (route through the plan cascade, `plan_committer.dart:1300-1360`) |
| Trello import branch merges without `createdBy`/`updatedBy` | its writes rejected | it uses `saveObjectsBatch` → covered once the repo writes them; W1 re-runs its tests |

---

## 12. Testing strategy

- **Rules (new harness, W0):** none exists today (no rules tests, no `@firebase/rules-unit-testing` in
  the repo). Create `tool/rules_test/` — Node 22 (`~/.nvm` v22; memory "Memroot script needs Node 22"
  shows system node 18 is too old), `package.json` with `@firebase/rules-unit-testing` + `vitest`,
  `firestore.test.ts` per match block; run:
  `firebase emulators:exec --only firestore --project demo-morkva "npm --prefix tool/rules_test test"`
  (`demo-` project = never production). One `it` per matrix row × role (owner/admin/editor/viewer/
  non-member/signed-out) for allow **and** deny, plus every W0 question as a test. CI-able; documented
  in `tool/rules_test/README.md`.
- **Unit (Dart):** `snapshot_builder` (projection, forced columns, references → titles, calculated
  materialized, option tables, chunk cut at the byte budget, truncation, **no leak**: serialize the
  output and assert no unpublished field id / value / option label / card id appears); `WorkspaceRole`
  getters and `grants()`; `share_token` entropy/format; invite email parsing; `next` sanitizer;
  `/w/` redirect parsing.
- **Repositories:** `fake_cloud_firestore` (does **not** enforce rules — that is the emulator suite's
  job): team repo (accept batch shape, CG queries), share repo (generation flip, unpublish order),
  `saveObject(mustExist, base)`, author fields on all three write paths and their decode into
  `MorkvaObject`, unpublish order (tombstone first), narrowing vs content flip, `publishDeps`.
- **Two-client conflict tests:** two `FirestoreDataRepository` instances with different uids over one
  `FakeFirebaseFirestore` (`test/api/data/two_writers_test.dart`): silent lost update via inline edit
  (must now merge — `moveToGroup`/`moveToDay` send one key), edit-after-delete (must throw, no
  resurrection, no new number), delete-undo re-creates (`mustExist: false`), a teammate's write to
  another field while ours is in flight (must **not** flag), a same-field race (flags once, with
  attribution, also for the same uid on two devices), attribution from `updatedBy`, undo restores
  only own keys, two admins editing views/schema concurrently (both survive).
- **Cubits (`bloc_test` + fakes):** `WorkspaceCubit` (switch, removal, role change), `TeamCubit`,
  `InviteCubit`, `JoinCubit` (every state row), `ShareCubit` (modes, offline, non-admin),
  `SharedLinksCubit`, `PublicViewCubit` (every state, Offline/Off classified from the read),
  `NoAccessCubit`, `WorkspaceCubit` demotion with a dirty editor (hold, Save disabled),
  `PublishRefresher` with `fake_async`
  (debounce, jitter, lease contention between two refreshers, dirty-after-build reschedule).
- **Widgets:** share popover per role and state (incl. widening confirms, zero-email publish
  disabled, transient-filter warning), Team page per role (Leave for Admin, self-demotion confirm),
  join page states, public page states; the collection header at 360 dp with "Share…" in the menu; tap targets on a pinned desktop platform (memory "Tap-target tests need a desktop platform");
  page overflow at phone width (memory "Page overflow tests").
- **App/router:** cold deep link through `/sign-in` and `/loading` keeps `next`; `/s/` and `/join/`
  never redirect; switch rebinds every singleton (assert wid on each fake store); **a switch made
  from inside a collection lands on Home in the new workspace** (no stale `next`); `/w/<other>/…`
  for a non-member lands on `/no-access`; a role change rebinds and returns to the same page.
- **Refresher:** a renamed referenced card refreshes the copy; editing the live view's filter does
  **not** change the copy until "Update the copy"; a narrowing refresh deletes the old gen; a
  relative-date definition rebuilds daily; a settings change during another device's build aborts
  that flip and the next build flips narrowing; a new copy whose first refresh never ran is built by
  another device; a dead lease holder's dirty entry is rebuilt after `leaseUntil`.
- **Run store:** an Editor's `watchRecent()` carries the `by` filter (fake asserts the query).
- **E2E (web, Firestore emulator):** memory "Web e2e on emulator": `firebase emulators:start --only
  firestore,auth` + run-for-web with `--dart-define=MORKVA_FIRESTORE_EMULATOR=127.0.0.1:8080` and a new
  `MORKVA_AUTH_EMULATOR=127.0.0.1:9099` define (W0 Q11) so two fake Google users exist; two Chrome
  profiles over CDP (memory "Web e2e driving"). Script: owner invites editor by email → editor signs in
  on the join link → edits a card while the owner edits another field of it → both see both edits →
  owner publishes "For Sunflower Studio" to one email → third user opens `/s/<token>` (sees 5 columns,
  no Total/Phone in the network payload) → editor changes a row → copy updates within ~15 s → owner
  removes editor → editor sees the removed dialog and lands in their own workspace (the device purge
  itself is not asserted: persistence is off under the emulator define; T0b covers it). Plus
  expired/off/tombstoned link states by editing docs on the emulator, and one release-build run of
  `/s/` including "Publish and copy link" on Firefox (clipboard activation; memory "Chrome tests miss
  dart2js").
- **Gates:** design parity (screenshot each artboard's screen vs the canvas, every difference fixed or
  the mockup updated) and the independent design critic before build and before PR (memories "Design
  parity gate", "Design critic gate"); `flutter analyze` + full `flutter test` + the rules suite green.

---

## 13. Implementation waves

Execution model as Epic 9: each task in its own worktree branched from main, first step `git merge
--ff-only feat/team-collaboration` (memory "Workflow worktree base"); within a wave no two tasks touch
the same file; each task writes its tests, runs `flutter analyze` + its tests, and is reviewed before
merge. Before W2 UI work: mockups accepted by the design critic.

| Wave | Task | Files (create / touch) | Depends on | Done when |
|---|---|---|---|---|
| **W0 spike** | T0a Rules harness + draft rules | create `tool/rules_test/{package.json,firestore.test.ts,README.md}`; draft `firestore.rules`, `firestore.indexes.json` on the spike branch | — | every §9 match block has allow+deny tests; Q0–Q9 answered with a test each (incl. tombstone squat, orphan-gen, prevGen expiry, invite consumption, subtree injection, unfiltered runs denied); findings appended to this spec ("W0 findings") |
| | T0b Platform probes | scratch only (`/tmp`/scratchpad): purge/terminate on web + Android emulator **with persistence on** (Q10), Auth emulator popup (Q11), path URL strategy under go_router dev server, late clipboard write on Firefox | — | Q10/Q11 answered in "W0 findings"; §10.9 and §12 adjusted |
| **W1 team foundation** | T1 Team data + rules | create `lib/api/team/*` (records, role, repo, `MembershipWorkspaceResolver` returning `({wid, role})` as a standalone class, links); touch `firestore.rules`, `firestore.indexes.json`, `tool/rules_test/*` (owner of the suite from here), `test/api/team/*` | W0 | repo tests; rules suite green on final rules |
| | T2 Card authorship + conflict model | touch `lib/api/data/{data_repository,firestore_data_repository}.dart` (`initialize(wid, {String? uid})` — optional until T3 passes it, author fields, `mustExist`, `base` + write-time conflict, `_localRev` drop, `updateCollection` merge), `lib/core/domain/morkva_object.dart` (+ test; `createdBy`/`updatedBy`), `docs/domain-json-schema.md`, `lib/features/views/collection_views_cubit.dart` (`moveToGroup`/`moveToDay` one key, `mustExist`, `_updateView` → `updateViews`), `lib/features/objects/object_editor_cubit.dart` (deleted banner, attribution via an injected `nameOf(uid)`, header line), `lib/features/collections/editor/collection_editor_cubit.dart` (merge `apply`), `lib/api/sync/sync_status_cubit.dart` (`reset`, attributed conflict), `test/features/collections/fake_data_repository.dart`, `test/api/data/{firestore_data_repository_test,two_writers_test}.dart` | — | two-client tests green; existing suites green |
| | T3 Session, routing, purge | create `lib/app/workspace_session.dart`, `lib/features/team/bloc/workspace_cubit.dart`, and **placeholder** widgets in their final files (`lib/features/team/view/{team_page,join_page,no_access_page,workspace_switcher}.dart`, `lib/features/share/view/{shared_links_page,public_view_page}.dart`); touch `lib/app/app.dart` (all session/role plumbing — the only task that ever edits it), `lib/app/router/app_router.dart` (every new route, public routes, `next`/`pendingNext`, `/w/` route — the only task that ever edits it), `lib/api/workspace/workspace_resolver.dart` (seam returns `({wid, role})`) + `lib/api/team/membership_workspace_resolver.dart` (`implements` the new seam), `lib/main.dart` (path strategy, purge flag, `MORKVA_AUTH_EMULATOR` define for the §12 e2e), `lib/features/auth/sign_in_page.dart` (`next`), `lib/api/automation/firestore_docs.dart` (`AutomationWorkspace` uid + role), `lib/features/assistant/bloc/assistant_session.dart` (`initialize(…, role:)`, stored), `pubspec.yaml` (`flutter_web_plugins`, `path_provider`); wires T2's `nameOf` to the roster; tests `test/app/*` | T1, T2 merged (W1b) | cold links keep `next`; switch from a collection lands on Home; A→B switch and role rebind re-bind all; removal → personal workspace |
| **W2 team UI + roles** | T5 Team page + invite sheet | create `lib/features/team/{bloc/{team_cubit,invite_cubit},view/{invite_sheet,role_select}}.dart`; fill `team_page.dart`; touch `settings_page.dart` (Team card + the phone switcher row at the top, mounting T3's `workspace_switcher.dart` widget that T6 fills), `pubspec.yaml` (`share_plus`) | W1 | widget + cubit tests; parity with `Team`, `Invite` |
| | T6 Join + switcher + banner + removed dialog | create `lib/features/team/{bloc/{join_cubit,switcher_cubit,no_access_cubit},view/{invitation_banner,removed_dialog}}.dart`; fill `join_page.dart`, `no_access_page.dart`, `workspace_switcher.dart`; touch `shell_sidebar.dart`, `app_shell_scaffold.dart` (mounts the Home invitation banner; T6 does not touch the collections list) | W1 | every join and no-access state; parity with `Switcher`, `InviteLanding`, `PhoneJoin`, `PhoneInvitation` |
| | T7 Role gating | touch `collection_views_page.dart`, `view_tabs.dart` ("Copy link to view" for all roles), `collections_list_view.dart`, `collection_card.dart`, object editor read-only, Automations pages (read-only for non-admins), Trello/template entries | W1 | per-role widget tests; parity with `ViewerMode` |
| | T8 View prefs + pins | create `lib/api/data/view_prefs_repository.dart`; touch pins in `firestore_data_repository.dart`, `PinnedCollectionsCubit`, prefs layer for every role + "Save for everyone" + non-admin `moveToGroup` skipping the `manualOrder` write in `collection_views_cubit.dart`, the prefs chip in `view_toolbar.dart` | W1 (T2 merged) | prefs tests; Viewer and Admin can sort/collapse without writes to the collection doc |
| **W3 automations + assistant** | T9 Automations under roles | touch `automation_runner.dart` (`_pause` → `pause()`, role caps, foreign crash breadcrumb dropped), `firestore_{automation,run}_store.dart` (pause; run scope from `AutomationWorkspace`), `reason_copy.dart`, automations page copy + the editor's "Saving makes Auto run on your device" line, `tool/rules_test/firestore.test.ts` (automations block; T1 is done by W3) | W1 | runner tests for pause by non-author, scoped `watchRecent`/prune; rules tests for pause keys and for Admin B toggling/resuming/editing Admin A's Auto automation |
| | T10 Ask Morkva grants + counter + consent | touch `assistant_session.dart` (role → `Grants`), `assistant_bloc.dart` (role grants, commit grants, usage counter), `assistant_config_repository.dart` (owner-only consent UI). No `app.dart` edit (T3 already passes the role; a role change rebinds) | W1 | viewer plan refused at plan time, not commit; counter blocks at `dailyTurnsSoft` |
| **W4 published views** | T11 Builder + token + records | create `lib/core/share/{share_token,snapshot_builder,publish_deps}.dart`, `lib/api/share/share_records.dart`, tests incl. the no-leak golden | — (can start in W2) | builder goldens green |
| | T12 Share repo + refresher | create `lib/api/share/{share_repository,firestore_share_repository}.dart`, `lib/core/share/publish_refresher.dart`; touch `lib/app/workspace_session.dart` (refresher slot, bound after the assistant) | T11, W1 | tombstone-first unpublish (+ `revokedAt`, resume at step 2), narrowing vs content flip by `settingsRev`, rename fan-out skips revoked rows; refresher `fake_async` tests |
| | T13 Share popover + Shared links | create `lib/features/share/{bloc/{share_cubit,shared_links_cubit},view/{share_popover,share_fields_page}}.dart`; fill `shared_links_page.dart`; touch `collection_views_page.dart` (header button, phone menu item, `?share=1`), `view_tabs.dart` (published icon, delete confirm), `collections_list_cubit.dart` (collection delete unpublishes), `settings_page.dart`, `team_cubit.dart` (rename → stub fan-out), `invite_sheet.dart` ("Publish a copy" hand-off) | T12, T7 | parity with `Main`, `PublishPeople`, `SharedLinks`, `Phone`, `Dark` |
| | T14 Outsider page | create `lib/features/share/{bloc/public_view_cubit,view/{public_table,csv_export}}.dart`; fill `public_view_page.dart` (no router edit) | T12 | every state; parity with `PublicView`, `PhonePublic` |
| **W5 verify + ship** | T15 Hosting + links | `firebase.json` hosting block (rewrite, headers below), `web/.well-known/*` placeholders, Android intent filter / iOS associated domains (behind owner values) | W4 | `firebase hosting:channel:deploy` dry config valid |
| | T16 Verification | fixes only: full e2e (§12) on the emulator, release-build `/s/`, rules suite, `flutter analyze`, full `flutter test`, parity + critic on all built artboards (14 — the UI-2/UI-3 variants are not parity targets), e2e scripts moved to path URLs, PR | all | everything green; PR lists owner steps |

(View prefs wait for W2 because the prefs layer touches `collection_views_cubit.dart`, which T2 owns in
W1. The post-review mockup redraws are done (§6 "Mockup redraws"); before W2 the design critic
re-accepts the canvas once more if the owner's decisions change any flow. `app.dart` and `app_router.dart` are edited only by T3.)

Hosting block for T15:
```json
"hosting": {
  "public": "build/web",
  "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
  "rewrites": [{ "source": "**", "destination": "/index.html" }],
  "headers": [
    { "source": "/s/**", "headers": [
      { "key": "X-Robots-Tag", "value": "noindex, nofollow" },
      { "key": "Referrer-Policy", "value": "no-referrer" } ] },
    { "source": "/join/**", "headers": [
      { "key": "X-Robots-Tag", "value": "noindex, nofollow" },
      { "key": "Referrer-Policy", "value": "no-referrer" } ] },
    { "source": "/.well-known/apple-app-site-association", "headers": [
      { "key": "Content-Type", "value": "application/json" } ] }
  ]
}
```

**Owner steps** (the agent cannot do these — production deploys are blocked for it):
1. Answer the five owner decisions (or accept the recommendations).
2. `firebase deploy --only firestore:rules,firestore:indexes --project morkvacrm` after the rules suite
   is green (CG index builds take minutes; queries fail until they finish).
3. Hosting: choose the origin, `flutter build web --release` + `firebase deploy --only hosting
   --project morkvacrm`; set the abuse mailbox constant.
4. App Links / Universal Links: Android release SHA-256 for `assetlinks.json`, Apple Team ID for the
   AASA file.
5. App Check: register Android + iOS, ship builds that send tokens, then enforce on Firestore; only
   then flip `kAnonymousLinks` (decision 2).
6. Blaze (decision 1) when Storage is enabled → schedule Approach D.

---

## 14. Out of scope / later

- **Presence** ("Iryna is editing") and live cursors.
- **Comments feed + Commenter role** (owner plans the feed; memory "Comments feed planned"); Trello
  comments stay a child collection until then.
- **Collection guests** (Approach C) and any per-collection or per-field member access.
- **Per-workspace feature flags** (`workspaceFlags/{wid}`, console-written) — the assistant flag stays
  per user.
- **Creating more workspaces per user** ("New team workspace") — lifts the `wid == ownerUid` invariant.
- **Ownership transfer** and owner leaving.
- **Audit log** (who invited/removed/published what, when).
- **SSO / verified-domain auto-join**, multiple domains per invite link, access requests ("Request
  access" → Approve/Decline).
- **Passwords on published links**, embeds (needs `frame-ancestors` decisions), live public editing,
  forms.
- **Person field type** (assign a card to a member) — natural follow-up; Trello members would map to it.
- **Approach D** (Blaze functions: live public views, invite emails, custom claims).

---

## Review log

Round 1 (2026-11-13): four review lenses. Each finding was checked against the repo @ 3e754b8 and
the canvas before it was applied. High and medium findings that held are all applied; cheap low
ones too.

- **Rules lens**
  - Stubs are never deleted. Unpublish writes the tombstone first, and outsider gen reads check
    `wid == stub.wid` (squatting an old token, orphan gens, Unpublish revoking last).
  - `prevGen` is time-boxed to 60 s, and a narrowing refresh drops it and deletes the old gen.
  - The email-invite accept must consume the invite (`!existsAfter`). Remove also deletes leftover
    invites for that member.
  - The accept proof moved off the roster into `prefs/join`, read with `getAfter`. The roster got
    `joinedVia`, and demoting a link-joined member warns about rejoining.
  - The member-private subtree is allow-listed, and the client accepts only 4-segment CG paths.
  - Invite `inviterName`/`inviterEmail`/`workspaceName` are rules-bound.
  - Run queries are scoped in `FirestoreRunStore` for all six consumers, and a role change rebinds.
  - Decision 2 is restated: the quota is exhaustible by any Google user. Stub `get` needs sign-in
    unless `signInRequired == false`, and invite `get` needs sign-in.
  - `lastWorkspaceId` moved to `prefs/session`.
  - Roster `name` is bound to the token.
  - Rules use `get()` defaults, and Editor `leaseUntil` is capped. Editor `gens` rewrites were
    accepted as a Limitation instead.
- **Code lens**
  - New `WorkspaceSession` (serialised queue, `pendingNext`, `hold()`).
  - The resolver returns `({wid, role})`.
  - Full bind/unbind order, with the refresher after the assistant.
  - Role change = rebind of the same wid (the per-service `setRole` is gone).
  - `next` is captured only on unauthenticated or cold-start visits, and `/switch` is replaced by
    `switchTo` from the `/w/` route plus `/no-access`.
  - `mustExist` defaults to `false`. `onlyKeys` is dropped: `moveToGroup`/`moveToDay` send one key,
    and the anchors are corrected.
  - Listener-based `SyncConflict` and `_localRev` are replaced by a same-field check inside the
    `saveObject` txn (the builder lens's variant; it keeps the project's "visible conflict warning").
  - `MorkvaObject.createdBy`/`updatedBy`.
  - `publishDeps` includes plain reference targets, titles come from `objectLabels`, and schema
    changes are a trigger.
  - Collection-editor `updateCollection` merges views from the server, and offline Admin edits are a
    Limitation.
  - Waves: T3 is the only task that edits `app.dart`/`app_router.dart`, and it registers all routes
    with placeholder pages. The crash marker keeps its key (a foreign breadcrumb is dropped in
    `_recoverCrash`).
  - `/w/:wid/:rest(.*)` route.
  - Offline is classified from the read on `/join` and `/s/`.
  - `path_provider` becomes a direct dependency, the purge is not asserted in the emulator e2e, and
    the reload keeps the URL for "Switch account".
- **UX lens**
  - No inline workspace invite in the popover, a Viewer default, the Invite-sheet callout and a
    client-domain warning. The fixture was fixed: the client is never a member, Max is staff, and
    the stranger is ivan.p@gmail.com.
  - Teammates row + "Published copy" select, and "Copy link to view" for every role.
  - Variants table rewritten.
  - Published icon on view tabs, and delete flows unpublish.
  - Join precedence with Already member first, NoAccessPage invitation lookup, and a link join
    deletes the joiner's own email invites.
  - States added: "That's you", offline invite (step 2 after server commit), offline switcher and
    switch failure.
  - Leave for Admins, what happens after Leave, the self-demotion confirm and the owner's line.
  - Role-changed snackbar and the dirty-editor hold.
  - Account-creation and no-Google-account footnotes.
  - Email-audience delivery (helper, Email it, zero-email guard).
  - All seven copy corrections.
  - Clipboard written synchronously, plus the "being prepared" state.
  - The summary counts come from the saved/frozen definition, with a transient-filter warning.
  - Phone Share only in the menu, plus a phone Team row.
  - Naming ("published copy", "OTHER WORKSPACES", "Viewer · read-only").
  - Widening changes confirm.
  - Expired, loading, error, no-results and summary-view states.
  - Accessibility: 44-px hit area, stale chip contrast, semantics labels, inline reasons.
  - "Mockup redraws owed" list added.
- **Builder lens**
  - `prevGen` (merged with the rules lens).
  - Frozen `definition` in the registry. This replaces the UX lens's "confirm before editing a
    published view"; "Update the copy" re-syncs it, and a deleted view keeps the copy working.
  - Conflict predicate moved into `saveObject`.
  - One prefs path for every role, with Admin "Save for everyone".
  - Reference targets are refresh dependencies.
  - Rename fans out to live stubs; pending invites are a Limitation.
  - Bulk delete narrowed to the collection cascade.

**Rejected or changed:**
- UX "keep the spec's named pre-sign-in landing; redraw the artboard". Reversed: the artboard and the
  recorded decision (generic landing, email-bound invite reads) win, and the spec's Signed out and
  Wrong account rows were rewritten.
- UX "Team artboard shows 'Last active'" and "'Only the owner can rename it.'". Neither string is in
  the current `Team`/`Invite` artboards, which show "Joined" and the rename helper. `lastActiveAt`
  and `photoUrl` were dropped instead.
- UX "confirm before changing a published view's filters". Superseded by the frozen definition.
- Code "drop the global SyncConflict entirely". The project keeps a visible conflict warning
  (CLAUDE.md), so the warning moved to write time instead.
- Code "key the crash marker by wid". The cheaper drop in `_recoverCrash` was used (no interface
  change).
- Rules "Editors may only add or remove `gens` keys they deleted". Not cheaply checkable in rules,
  and the effect is storage cost only, so it became a Limitation.
- Builder "`?view=` links ignore the recipient's prefs". Prefs apply everywhere, and the chip shows
  the difference.

Coherence pass after applying the findings:
- The copy's title is frozen with the definition, so refreshes no longer write `title`.
- `prevGenUntil` is capped at 60 s in the stub rule.
- Admins may `get` any invite.
- A W0 test checks that a Viewer can't read the link token.
- The resolver `implements` edit is owned by T3.
- `Phone` was added to the redraws, and the UI-2/UI-3 artboards were marked as not being parity
  targets.
- `mustExist` callers were re-anchored (`setChildValue` lives in `object_editor_cubit.dart:304`).

No new owner decisions: every finding was decidable as *my call*. Decision 2 was restated, not
added.

Coherence pass 2 (round-2 findings, 2026-11-13; checked against the repo @ 3e754b8):
- Applied:
  - Settings changes can't be lost. The registry gains `settingsRev` (Admin-only) and
    `builtSettingsRev`. Every settings write bumps the rev and `dirtyAt`, and so does the publish
    batch, which means a copy is born dirty. The builder reads `fieldIds`/`definition` in its lease
    txn, the flip aborts if `settingsRev` moved, and a build across a rev change flips as narrowing.
    Any builder flips as narrowing when a `fieldIds` entry left the schema, and an Admin device then
    prunes it. A re-check timer at `leaseUntil` replaces "abort silently". §11 now separates the
    stub-gated settings (immediate) from fields and filters (applied at the next rebuild).
  - The member subtree is limited to depth 1 plus explicit threads/messages. Q3 now covers depth-2
    planting.
  - Unpublish step 1 is one batch: tombstone plus registry `revokedAt`. Gen/chunk creates under a
    tombstone and Editor registry writes to a revoked row are denied. Refreshers and the rename
    fan-out skip revoked rows. Shared links shows "Unpublishing… Retry", which resumes at step 2.
    `markDirty` uses `update()`. Deleting a missing gen/chunk is a no-op (`resource == null`).
  - Clock skew: clients write `prevGenUntil` at +60 s and rules accept up to +90 s. The
    `leaseUntil` cap applies to Admins too, and both caps are checked only when the key changes.
  - Automations: an Admin carve-out lets anyone toggle or resume without taking over `autoBy`
    (`modules_cubit.dart:333` and runner `resume` save with the old stamp). An editor save re-stamps
    `autoBy` to the saver (`automation_editor_cubit.dart:573`), which is now stated in §10.10 with an
    editor line. T9 tests both.
  - Non-admins see "4 members" with no pending count, and `ShareCubit` subscribes to `invites` only
    for `canManageTeam`.
  - The `name`/`workspaceName` 1–60 bound is checked on update and in the stub fan-out.
  - Every accept batch deletes all of the caller's email invites to the workspace. The Leave copy no
    longer promises that only a new invite brings you back, and the §11 rejoin line covers any
    link holder.
  - Invite `get`/`delete` list the invitee branch first, the `role()` comment states `error || true`,
    and the case is added to Q0/Q7.
  - Q1 covers non-owner Admin publish (50 viewers) and 20-invite batches; the fallback now names the
    share and team repos.
  - The stub `workspaceName` note now refers to the outsider header and states what a non-listed
    user learns.
  - Q9 is split into the step-1 batch and the step-2 txn.
  - Bulk writes skip the same-field check (verified: `firestore_data_repository.dart:786` is a blind
    `batch.update`); this is stated in §10.6 and §11.
  - Waves: Q0 is in T0a. `tool/rules_test/*` is owned by T1 and touched by T9. T3 owns
    `MORKVA_AUTH_EMULATOR`, a placeholder `workspace_switcher.dart` (T5 mounts it in Settings, T6
    fills it) and the roster wiring for T2's injected `nameOf`.
- Rejected or changed:
  - Automations Option A ("any update leaving `autoBy`/`apply` unchanged"). It would let Admin B
    change what auto-applies under A's consent, so the carve-out is limited to
    `enabled`/pause keys. Option B already happens in the editor.
  - Unpublish "take the lease, wait out the old `leaseUntil`, re-read `gens`". Denying gen/chunk
    creates under a tombstone closes the race without a client-clock lease, which a capped Admin
    `leaseUntil` could reject on a skewed device. `gens` read after step 1 already names every gen
    that could exist.
  - "Admin rebuild retries after `leaseUntil`". It is subsumed by the dirty entry plus the
    `leaseUntil` re-check timer on every device.
  - `prevGenUntil` change-only check: added, but a content flip always changes the key, so the +90 s
    margin is the actual fix.
- Parity debt: three mockup copy/state updates are listed under §6 "Mockup redraws".
