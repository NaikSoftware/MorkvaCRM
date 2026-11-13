# Firebase capabilities and limits for team collaboration and view sharing

Tags: **[V]** means checked against official docs (URL given) or repo code (file:line), on 2026-11-13. **[I]** means my own inference or composition, not checked. All repo paths are relative to `the repo`.

## 0. Repo facts that constrain the design
- **Rules today [V]:**
  - Everything is gated by `isWorkspaceOwner(wid)`, which is `request.auth.uid == workspaceId` (`firestore.rules:14-16`).
  - The comment at `firestore.rules:5-10` already plans a `memberships/{uid}` doc under the workspace, with no change to paths.
  - The existing `members/{uid}/{sub}/**` subtree holds per-member chat data and grants (`firestore.rules:115-131`). A collection-group rule on a collection named `members` would collide with it, so name the new collection `memberships` [I].
- **Workspace resolver [V]:** `UidWorkspaceResolver` returns the uid (`lib/api/workspace/workspace_resolver.dart:14-20`). The interface is already the seam for multi-workspace.
- **Data layout [V]:**
  - Cards are flat at `workspaces/{wid}/objects/{id}` with a `collectionId` field (`lib/api/firestore/firestore_refs_impl.dart:21-26`).
  - Cards are watched with `objectsByCollection(wid, collectionId)` (`lib/api/data/firestore_data_repository.dart:314-316`). The only indexes are `collectionId` plus `updatedAt`/`createdAt` (`firestore.indexes.json`), and `fieldOverrides` is empty.
  - Views live inside the collection schema doc as `views: [...]` (`lib/core/domain/collection.dart:51,128`). They carry filters with ops such as `contains`, `anyOf` and `onDay` (`lib/core/domain/view/view_definition.dart:18-30`).
  - **View filters are evaluated client-side, so the server never sees them.** Consequence: a view's filter cannot become a security boundary.
- **App Check [V]:** web activates reCAPTCHA Enterprise only when a site key define is set. Mobile activates only when the `_appCheckMobile` define is `debug` or `device` (`lib/main.dart:69-92`). Memroot says Android and iOS are not registered in App Check. Whether Firestore enforcement is on is a console setting the repo cannot show, so the owner must check it.
- **No Hosting config [V]:** `firebase.json` has no `hosting` block and no `.firebaserc`. The `morkvacrm.web.app` domain exists (per Memroot), but deploys are not in the repo.
- **Router [V]:** the redirect at `lib/app/router/app_router.dart:62-94` sends `AuthUnauthenticated` to `/sign-in` for every route. A public `/s/:token` route must be exempted there.
  - No `usePathUrlStrategy` call was found in `lib/`, so web URLs are likely hash-style (`/#/s/…`) [I]. Pretty `/s/…` links need path strategy plus a Hosting SPA rewrite.
- **Packages [V]:** `url_launcher` is already present (`pubspec.yaml:61`), so `mailto:` costs nothing. `share_plus` is not in pubspec. `firebase_app_check` is pinned at 0.4.5 (`pubspec.yaml:70`).
- **Persistence [V]:** offline persistence is on (`lib/main.dart:54-55`). A member who is removed keeps already-cached data on their device. Rules cannot claw it back [I].

## 1. Capability matrix

| Need | Spark (now) | Blaze | Verdict |
|---|---|---|---|
| Membership check in rules | Yes, via `get()`/`exists()` on a membership doc [V] | same | **Core mechanism** |
| Roles in custom claims | No: Admin SDK only [V] | Yes, with a Function | Skip; use Firestore docs |
| Row filtering by view in rules | No: rules are not filters [V] | No | Use snapshots or whole-collection grants |
| Hiding fields from a reader | No: impossible with rules alone [V] | No (only a server-made projection) | Use a separate projection doc |
| Public unauthenticated read of one doc | Yes, `allow get: if true` [V] | same | Fine with a token as the doc id |
| Block enumeration of public docs | Yes, `allow list: if false` [V] | same | Required |
| "Shared with me" (collection group + rules) | Yes [V], needs a CG-scope index | same | Works |
| Find invites by the signed-in user's email | Yes, via `request.auth.token.email` [V field exists] | same | Works; snippet composed [I] |
| Send an invite email automatically | Effectively no (see §5) | Function + SMTP | Spark: `mailto:`/share sheet |
| Deep links into the mobile app | App Links / Universal Links via Hosting `.well-known` [V] | same | No Dynamic Links (shut down) |
| Abuse protection for public links | App Check enforcement on Firestore [V] | same | All clients must send tokens first |
| Server-refreshed snapshots | No | Firestore-triggered Function | Spark: refreshed by the owner's client |

## 2. Security rules (Q1)

### Not possible
- **Rules are not filters.** The docs: "security rules are not filters---queries are all or nothing." "If a query could potentially return documents that the client does not have permission to read, the entire request fails." https://firebase.google.com/docs/firestore/security/rules-query
- **No field-level reads.** The docs: "It is impossible using security rules alone to prevent users from reading specific fields within a document." The fix is a separate doc or subcollection. https://firebase.google.com/docs/firestore/security/rules-fields
- **Rules cannot see query filters.** `request` has `auth, method, path, query, resource, time`, and `request.query` exposes only `limit`, `offset` and `orderBy`. https://firebase.google.com/docs/reference/rules/rules.firestore.Request
  - Rules cannot read where-clauses or URL query params, so **a link token must be a path segment (the doc id).**

### Access-call limits and billing [V]
Source: https://firebase.google.com/docs/firestore/security/rules-structure
- Limits:
  - **10** `get`/`exists`/`getAfter` calls for single-doc requests and queries.
  - **20** for multi-doc reads, transactions and batched writes, with each op in a batch still capped at 10.
  - Going over returns permission-denied. Cached calls do not count.
- Other limits:
  - 1,000 expressions per request.
  - Function call depth 20 and at most 7 arguments.
  - No recursion.
  - Ruleset source up to 256 KB, compiled ruleset up to 250 KB.
- Billing:
  - Each dependent doc is billed as **one read per request**, "even if your rules refer to that document more than once." https://firebase.google.com/docs/firestore/pricing
  - It is billed "even if your rules reject the request." https://firebase.google.com/docs/firestore/security/rules-conditions
- A query costs at least one read even when it returns nothing [V, pricing page].

### Membership patterns
- **Separate doc per member** (scales; the docs recommend "roles … stored in their own collection" for large groups):
  - **[V] Verbatim from the docs:** `allow create: if request.auth != null && exists(/databases/$(database)/documents/users/$(request.auth.uid));` and `allow delete: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.admin == true;` https://firebase.google.com/docs/firestore/security/rules-conditions
- **Roles map on the doc** (`roles: {uid: "owner"|"writer"|"reader"|"commenter"}`, read with `rsc.data.roles[request.auth.uid]` and `get()` on the parent). https://firebase.google.com/docs/firestore/solutions/role-based-access
  - It counts against the 1 MiB doc limit, and every uid key becomes an index entry [I].
- **By email:** the token fields `email`, `email_verified` and `firebase.sign_in_provider` exist [V]. https://firebase.google.com/docs/rules/rules-and-auth
  - I found **no official snippet** using `token.email`, so the snippets below are composed.
  - Google sign-in accounts normally carry `email_verified == true` [I].
  - Lower-case emails when writing invites, because I could not confirm token email casing [I].

### Granular operations [V]
`read` splits into `get` and `list`; `write` splits into `create`, `update` and `delete`. Docs example: `allow list: if request.query.limit <= 10 && authorOrPublished(); allow get: if authorOrPublished();` https://firebase.google.com/docs/firestore/security/rules-query

## 3. Custom claims (Q2) [V]
- Set them "only … from a privileged server environment by the Firebase Admin SDK". There is no client API.
- The payload is capped at 1000 bytes.
- Claims reach the client on the next token: sign-in, hourly refresh, or `getIdToken(true)`.
- Source: https://firebase.google.com/docs/auth/admin/custom-claims
- On Spark this means no claims at all. Roles must live in Firestore.

## 4. Public links without a server (Q3)
- **Public doc pattern [V]:** the docs' mixed public/private example is `allow read: if true`. https://firebase.google.com/docs/rules/insecure-rules
  - Split it into `allow get: if true; allow list: if false;` so that only someone who knows the id can read.
- **Unguessable ids [I]:** Firestore auto-ids are 20 chars from a 62-char alphabet, about 119 bits. The SDK AutoId source was not re-checked; generating 128-bit random tokens yourself is safer.
- **Expiry and revocation [I]:** rules have `request.time` [V], so `resource.data.expiresAt > request.time` works for expiry. Deleting the doc revokes the link.
- **Live public reads of `objects` [I, unverified]:** a list rule would need something like `get(.../links/$(resource.data.collectionId))`. I could not confirm that the engine proves this against a `collectionId ==` query. It also cannot apply view filters or hide fields. **Recommendation: use snapshot docs for public links.**
- **Anonymous auth [V]:** enable the Anonymous provider and use `linkWithCredential` to upgrade later. Automatic 30-day cleanup needs the Identity Platform upgrade. There is a limit of 100 new accounts per hour per IP. https://firebase.google.com/docs/auth/web/anonymous-auth and https://firebase.google.com/docs/auth/limits
  - It is not needed for public links. It is only useful if viewers need a uid, for example for comments [I].
- **App Check [V]:**
  - Supported for Firestore, RTDB, Storage, Auth (Preview), AI Logic and callable Functions. https://firebase.google.com/docs/app-check
  - Once enforced, "all unverified requests to that product will be rejected", and it takes up to 15 minutes. https://firebase.google.com/docs/app-check/enable-enforcement
  - reCAPTCHA Enterprise is free for 10k assessments a month, then paid.
  - The docs say it "prevents some, but not all, abuse vectors".
  - **Before enforcing on Firestore:** register Android and iOS and ship builds that send tokens, or those clients break (`lib/main.dart:69-92`). It does work for unauthenticated web viewers, because App Check is independent of Auth.
- **Billing exposure on Spark [V]:**
  - The free tier is 50k reads, 20k writes and 20k deletes per day, reset around midnight Pacific. https://firebase.google.com/docs/firestore/quotas
  - On Spark, an exhausted quota shuts the product off **for the whole project** (https://firebase.google.com/docs/projects/billing/firebase-pricing-plans). That page words it as "for the remainder of that month", but the Firestore quota is daily [I: the daily reset applies to Firestore].
  - **A scripted loop of `get` calls on a public link can take Firestore down for every user that day.**
  - A single snapshot doc costs 1 read per open, while live rows cost N reads per open [V pricing].
  - On Blaze the risk becomes a bill instead. Budget alerts "do not cap your usage or charges" [V, same page].

## 5. "Shared with me" discovery (Q4) [V for the mechanism]
- **Collection-group rule:** use `rules_version = '2'` with `match /{path=**}/posts/{post} { allow read: if request.auth != null; }`. https://firebase.google.com/docs/firestore/security/rules-query
- **Indexes:** a filtered collection-group query needs a single-field index with collection-group scope ("not maintained by default"). https://firebase.google.com/docs/firestore/query-data/index-overview
  - Add `fieldOverrides` for `memberships.uid` and `invites.email` to `firestore.indexes.json`.
- **Store `uid` and `email` as fields** rather than relying on the doc id. Filtering a collection group by `documentId()` needs a full path [I].
- **Invite lookup** is `collectionGroup('invites').where('email', '==', myEmail)`. The rule must restrict `resource.data.email == request.auth.token.email` (composed below). After that, `ref.parent.parent.id` gives the `wid`.
- **Other query limits [V]:** at most 30 disjunctions (`in`, `array-contains-any`, `or`); `not-in` takes at most 10 values; at most one `array-contains` per disjunction. https://firebase.google.com/docs/firestore/query-data/queries

## 6. Email (Q5) [V]
- **Trigger Email extension:**
  - It needs **Blaze** plus your own SMTP provider (SendGrid, Mailgun or Gmail OAuth2). It sends one email per doc written to `mail/`. https://extensions.dev/extensions/firebase/firestore-send-email
  - **The Firebase Extensions service shuts down on 2027-03-31.** Installed extensions keep running but can no longer be updated, reconfigured or uninstalled. The suggested replacement is "function kits" (Cloud Functions). https://firebase.google.com/docs/extensions/faq-and-troubleshooting
  - Do not build on it. If email is needed, write one small Function using a Firestore trigger and SMTP (Blaze).
- **Email-link sign-in as an invite carrier:**
  - Spark allows **5 sign-in-link emails a day**; Blaze allows 25,000. https://firebase.google.com/docs/auth/limits
  - It requires enabling the **Email/Password** provider, which breaks the "Google only" rule. https://firebase.google.com/docs/auth/flutter/email-link-auth
  - `ActionCodeSettings`: `url` (state can be passed in it), `handleCodeInApp`, `linkDomain` (a Hosting domain; it replaced Dynamic Links), `androidPackageName`, `iOSBundleId`.
  - The docs warn not to pass the email in the URL.
  - **Not viable.**
- **Recommended on Spark:**
  - The invite doc is the real grant. The invitee sees it in-app after a Google sign-in with that email.
  - Delivery is the sender's own channel: `mailto:` through `url_launcher` (already a dep), the OS share sheet (would need `share_plus`), or "copy link".

## 7. Snapshot projections (Q6)
- **Document limits [V]:** 1 MiB (1,048,576 bytes) per doc, field depth 20, 40k index entries per doc. https://firebase.google.com/docs/firestore/quotas
- **Proposed shape [I]:** `publicViews/{token}` holds `{wid, collectionId, viewId, columns:[{id,label,type}], rows:[[...]], rowCount, truncated, generatedAt, generatedBy, expiresAt}`.
  - Only the shared fields and filtered rows go in, so hiding happens at write time.
  - Above roughly 800 KB, split into `publicViews/{token}/pages/{n}` (one read per page).
- **Who refreshes it on Spark:** only the owner's or members' clients.
  - Options: on share, on "Refresh now", or debounced after edits to that collection while a member has the app open.
  - It goes stale while nobody is online, so show "Updated <time>" in the UI.
  - A Firestore-triggered Function would make it live but needs Blaze.
- **Write rule [I]:** only members of `resource.data.wid` / `request.resource.data.wid` may write. Each write is 1 write plus 1 billed membership read.
- **Signed-in teammates** should read live `objects` through membership, not snapshots. Snapshots are for links to outsiders or for field-hidden views.

## 8. Hosting and links (Q7) [V]
- **Dynamic Links shut down on 2025-08-25.** Links now return 404 and new ones cannot be created. Email-link Auth needs the newest SDKs. https://firebase.google.com/support/dynamic-links-faq
- **Replacement: App Links (Android) and Universal Links (iOS).** https://firebase.google.com/support/guides/app-links-universal-links
  - Put `public/.well-known/assetlinks.json` and `public/.well-known/apple-app-site-association` (no extension, uncompressed) in Hosting.
  - Headers: `{"source":"/.well-known/assetlinks.json","headers":[{"key":"Content-Type","value":"application/json"}]}`, and the same for the AASA file.
  - Lost compared with Dynamic Links: store routing, deferred deep links after install, click analytics and short links.
- **SPA rewrite [V]:** `"rewrites":[{"source":"**","destination":"/index.html"}]`. Static files win over rewrites, so `.well-known` is served first. https://firebase.google.com/docs/hosting/full-config
- **Flutter:** add a `/s/:token` GoRoute outside the auth gate (`app_router.dart:62-94`). Use path URL strategy so the link is `https://morkvacrm.web.app/s/<token>` [I]. Mobile needs intent filters and associated domains [I].

## 9. Spark vs Blaze (Q8)

**Spark covers the full MVP:**
- memberships and roles in rules
- in-app invites by email
- "Shared with me"
- public snapshot links written by clients
- `mailto:`/share delivery
- Hosting (10 GB stored, 360 MB/day transfer)
- Auth up to 50k MAU [V]

**Blaze adds:**
- Cloud Functions (2M invocations a month free, then $0.40 per million [V]). Uses: automatic invite email over SMTP, server-refreshed snapshots, custom claims, rate limiting and cleanup.
- No daily Firestore cap.
- Storage, needed later for files.

**Prices [V]:** Standard edition in us-central1 is $0.03 per 100k reads, $0.09 per 100k writes and $0.01 per 100k deletes. https://firebase.google.com/docs/firestore/standard-edition
- Other regions differ, and the project's database location is not in the repo.
- Storage is about $0.15/GiB-month. That figure is a search summary of cloud.google.com/firestore/pricing, not a page I fetched [I].

**Rough small-team estimate [I]:**
- Load: 10 users, about 200k reads a day.
- Reads: about 150k a day over the free tier, roughly $0.05 a day, about $1.5 a month.
- Writes, Functions and Hosting: about $0.
- **Total: about $0–5 a month.** The real risk is runaway listeners or abuse, so set budget alerts and use App Check.

## 10. Rule snippets

**[V] verbatim from docs:**
```
allow list: if request.query.limit <= 10 && authorOrPublished();   // rules-query
match /{path=**}/posts/{post} { allow read: if request.auth != null; } // rules-query (CG)
allow create: if request.resource.data.keys().hasOnly(['name','hours']);              // rules-fields
allow update: if request.resource.data.diff(resource.data).affectedKeys().hasOnly(['name','hours']);
allow delete: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.admin == true; // rules-conditions
```

**[I] composed for MorkvaCRM, untested.** Test them on the emulator; deploying rules is the owner's step.
```
function membership(wid) { return get(/databases/$(database)/documents/workspaces/$(wid)/memberships/$(request.auth.uid)); }
function isMember(wid)    { return request.auth != null && (request.auth.uid == wid
                              || exists(/databases/$(database)/documents/workspaces/$(wid)/memberships/$(request.auth.uid))); }
function canWrite(wid)    { return request.auth != null && (request.auth.uid == wid
                              || membership(wid).data.role in ['editor','admin']); }

match /workspaces/{wid}/memberships/{uid} {
  allow get: if isMember(wid);
  allow list: if isMember(wid);
  allow create: if request.auth.uid == uid                                  // invitee accepts
      && request.resource.data.uid == uid
      && get(/databases/$(database)/documents/workspaces/$(wid)/invites/$(request.resource.data.inviteId)).data.email
         == request.auth.token.email
      && request.auth.token.email_verified == true
      && request.resource.data.role == get(/databases/$(database)/documents/workspaces/$(wid)/invites/$(request.resource.data.inviteId)).data.role;
  allow update, delete: if request.auth.uid == wid || request.auth.uid == uid; // owner manages / member leaves
}
match /{path=**}/memberships/{uid} {             // "shared with me"
  allow list: if request.auth != null && resource.data.uid == request.auth.uid;
}
match /{path=**}/invites/{id} {                  // invitee discovers invites
  allow list, get: if request.auth != null && request.auth.token.email_verified == true
      && resource.data.email == request.auth.token.email;
}
match /publicViews/{token} {                     // link = capability
  allow get: if resource.data.get('expiresAt', null) == null || resource.data.expiresAt > request.time;
  allow list: if false;
  allow create, update: if isMember(request.resource.data.wid);
  allow delete: if isMember(resource.data.wid);
}
```

Notes on the composed snippets:
- The two `get()` calls on the same invite doc count as one call, because cached calls are free [V].
- When a member opens one doc, every per-request check costs one extra billed read.
- A listener is checked against the rules when the query starts. Whether a revoked member's open listener drops immediately is [I]; test it on the emulator.

I did not re-check the Firestore AutoId entropy, token email casing, whether a list rule can use `get()` on a `resource.data`-derived path, or Flutter's default URL strategy under go_router. Risk: enforcing App Check on Firestore before Android and iOS are registered would lock those clients out. The durable limits are saved to Memroot (m1.3gNpVfj8…).