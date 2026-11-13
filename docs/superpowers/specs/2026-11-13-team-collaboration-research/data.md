# Data layer and security digest: collaboration and sharing

Checkout: `the repo` @ 3e754b8 (main). Read-only; nothing was edited.

**Labels used on each claim:**
- **[V]** I read it in this repo.
- **[I]** I inferred it from code I read. This includes behaviour traced by hand that no test covers.
- **[P]** Firebase platform fact. **[P✓]** means I checked it in the Firebase docs through context7; plain [P] is recalled and not checked.

---

## 1. Places that assume `workspaceId == uid`

The workspace id comes from one place: `UidWorkspaceResolver.resolveWorkspaceId(uid) => uid` (`lib/api/workspace/workspace_resolver.dart:19`), called once in `lib/app/app.dart:248`. Everything downstream takes a `workspaceId` parameter. Paths are already `workspaces/{wid}/…`, so the coupling sits mostly in **rules, per-member data that lives on shared docs, and the boot path**.

| # | Where | What it assumes | What breaks when user B writes into A's workspace |
|---|---|---|---|
| 1 | `firestore.rules:14-16` `isWorkspaceOwner(wid) = auth.uid == wid`; used on every match (40, 44, 49-54, 59-60, 76-77, 88-93, 116, 123-124, 135) | owner = uid | B is denied everywhere. Every rule has to become a membership/role check. [V] |
| 2 | `firestore.rules:5-10` comment promises a `memberships/{uid}` doc | — | Naming clash: per-member data already lives at `members/{uid}/{sub}/…` (115-131). The `members/{uid}` doc itself matches no rule today (only `{sub}/{rest=**}` below it), so it is free to become the role doc. [V/I] |
| 3 | `firestore.rules:39-40` workspace doc: `allow read, write` for the owner | one writer | This doc holds `counters` (auto-numbers) and `pinnedCollections`. Any editor who creates a numbered card must be able to write it, so the rule must restrict `affectedKeys()` or a member could rewrite counters or pins. [V/I] |
| 4 | `firestore_data_repository.dart:212-238` pins on the workspace doc. The code already carries `// shortcut: … move them to a per-member doc when memberships land` | single user | Pins become shared across all members. One member's re-pin overwrites everyone's (whole-list `set(merge:true)`, line 238). [V] |
| 5 | Auto-number counters: `firestore_data_repository.dart:458-475` (saveObject txn) and `807-852` (`_reserveSequences`), stored at `workspaces/{wid}.counters.{cid}.{fid}` | — | Correct under concurrency, because they are transactional. But: (a) editors need write access to the workspace doc (row 3); (b) it is one hot doc for every creator in the workspace [I]; (c) transactions fail offline, so offline card creation fails (§3). [V/P✓] |
| 6 | `firestore.rules:82-83` `autoBy == request.auth.uid` for `apply:'auto'` automations; `lib/core/automation/apply_policy.dart:53`; `automation_runner.dart:1150-1156` `_effectiveApply` | multi-member already designed | Works with members. Only the author's own runs auto-apply; another member's runs go to review. Card triggers fire **only on the writer's client**: `DataRepository.changes` is "never remote changes" (`data_repository.dart:126-128`), and the runner subscribes to it (`automation_runner.dart:207`). So A's auto automation does not auto-apply when B edits a card. B's client runs it in "ask" mode, which needs B's own consent (`grants` per uid). [V] |
| 7 | `members/{uid}/grants/{moduleId}` (`firestore.rules:122-131`, `lib/api/automation/firestore_grant_store.dart:15-16`) | per member | Already per member. Only the `isWorkspaceOwner` check must change. [V] |
| 8 | Assistant threads `workspaces/{wid}/members/{uid}/assistantThreads` (`lib/api/assistant/firestore_thread_repository.dart:18-25`; rules 115-119) | per member | OK. Only the rule prefix changes. [V] |
| 9 | Workspace AI consent `workspaces/{wid}/config/assistant {consentedBy: uid}` (`lib/api/assistant/assistant_config_repository.dart:54-59, 71-75`; rules 134-136) | owner consents | Any member with write access could consent to AI processing for the whole workspace. This needs an owner/admin-only rule. [V/I] |
| 10 | `featureFlags/{uid}`, global `config/assistant` (rules 141-149; `assistant_config_repository.dart:42-43`) | per user | Flags follow the signed-in user, not the workspace owner. A member without the flag sees no assistant in the owner's workspace. [V/I] |
| 11 | Run log `workspaces/{wid}/runs` (rules 87-110; `lib/api/automation/firestore_run_store.dart`) | — | Any member reads every run log, and logs contain card data. `prune` (`firestore_run_store.dart:45-63`) is run by each member's client (`_prune` in `runner.initialize`, `automation_runner.dart:257`), so N clients prune concurrently. Run `by: 'user:$uid'` is recorded (`automation_runner.dart:1137`). [V/I] |
| 12 | `storage.rules:8-12` `request.auth.uid == workspaceId`; path `workspaces/{wid}/files/{attachmentId}/{name}` (`lib/api/files/firebase_attachment_store.dart:38`) | owner = uid | Members can't upload or read files. The rule needs cross-service `firestore.get()` against the membership doc [P, unchecked]. `downloadUrl` uses `getDownloadURL()` (`firebase_attachment_store.dart:77-78`): a tokenized URL that bypasses rules for anyone holding it, so a removed member keeps access [P]. Storage is not enabled yet (memory: deferred). [V] |
| 13 | `firestore_data_repository.dart:80-83` `_epoch` comment ("The workspace id equals the uid…") | — | Only a comment. The epoch mechanism itself is identity-agnostic. [V] |
| 14 | Card docs carry no author: shape is `{collectionId, rev, createdAt, updatedAt, values}` (`firestore_data_repository.dart:476-482`, batch create 775-781). `WriteOrigin.actor == null` means "the signed-in user" (`data_repository.dart:258`) and is never persisted | single user | No "who changed this". Also, `saveObject` writes the **whole doc** with `transaction.set` (line 483, no merge), so any new top-level field (`updatedBy`, an ACL array, etc.) is wiped on the next save unless saveObject writes it too. [V] |
| 15 | Boot: `app.dart:244-279` resolves the workspace once per `AuthAuthenticated` and guards `_initializedWorkspaceId == workspaceId` (253) | one workspace per user | No path exists to change the workspace without an auth change (§5). [V] |
| 16 | Sign-out: `app.dart:281-296` disposes the repo, runner and assistant. A grep for `clearPersistence\|terminate()\|waitForPendingWrites` in `lib/` returned **nothing** | single owner per device | The Firestore cache (IndexedDB / SQLite, `cacheSizeBytes: UNLIMITED`, `lib/main.dart:54-57`) keeps the previous user's data on the device. A member removed from a workspace keeps whatever was cached, readable offline. Rules cannot revoke a cache. [V/P] |
| 17 | Client-local state: `morkva.sessionKey` in `sessionStorage` (`lib/api/automation/session_key_web.dart:5-19`); crash breadcrumb `morkva.automation.crash` in `localStorage` (`lib/api/automation/engine/web/crash_marker_web.dart:10-40`) | — | Neither is keyed by workspace or uid. A crash breadcrumb left in workspace A is "recovered" in `runner.initialize` for whatever workspace binds next (`automation_runner.dart:254-256`). This is minor, but real once switching exists. [V/I] |
| 18 | Collection delete from the UI: `collections_list_cubit.dart:136` deletes only the schema doc. The plan path cascades client-side (`plan_committer.dart:1300-1360`: lists server cards, batch-deletes them, then the schema) | single writer | UI delete leaves orphan objects. With the plan cascade, a teammate creating a card mid-delete either leaves an orphan or gets "N left, collection kept". [V/I] |

## 2. How data is read: queries versus rules-as-filters

All reads go through `FirestoreRefsImpl` (`lib/api/firestore/firestore_refs_impl.dart`) or the per-feature stores.

| Read | Query | File:line | Can a scoped reader run it? |
|---|---|---|---|
| Collections (schemas, **including all views**) | `collections(wid).snapshots()`: whole subcollection, no filter | `firestore_data_repository.dart:194-210`; also `getCollections` 241-244 | **No**, unless the reader may read every collection doc. One unreadable doc fails the whole listener (rules are not filters). Scoping needs `where(documentId, whereIn ≤30)`, a `readers` array-contains query, or per-doc listeners. [V/P] |
| Objects of one collection | `objects.where('collectionId', ==, cid).orderBy('updatedAt', desc)` | refs_impl:57-62; `watchObjects` 290-359, `getObjects` 389-398, `getServerObjects` 400-411 | **Yes, per collection.** The equality on `collectionId` lets a rule test `resource.data.collectionId` against a membership/grant doc [I; verify on emulator]. Index: `collectionId ASC, updatedAt DESC` exists (`firestore.indexes.json`). Row-level scoping would need an extra provable filter plus a new composite index with `orderBy updatedAt`. [V/I] |
| Single object | `objects/{id}` doc listener/get | 361-387, 413-423 | Yes. Doc-level rule. [V] |
| Pins | workspace doc listener | 216-234 | Needs read access to the workspace doc. [V] |
| Cross-collection reads | Views cubit watches **other collections' objects** for reference labels, lookups and `Derivation.sourcesOf` (`collection_views_cubit.dart:213-258`). Object editor does the same (`object_editor_cubit.dart:157-168`). Harness `WorkspaceCache` does one `watchObjects` per leased collection (`workspace_cache.dart:24-29, 345`) | | A member scoped to collection X who opens a view with a reference or lookup into Y gets permission-denied on Y. The views cubit shows "Couldn't load Y" (`collection_views_cubit.dart:251-255`). **Also**, `watchObjects` `onError` calls `_syncStatus.reportError` (`firestore_data_repository.dart:353-355`), so one unreadable target flips the **app-global** sync indicator to `SyncError`. [V] |
| Automations / modules | whole-subcollection listeners | `firestore_automation_store.dart:17`; `firestore_module_store.dart` `watch()` | Members need read access to all of them. [V] |
| Runs | `orderBy startedAt desc limit kWindow` | `firestore_run_store.dart:21-24` | Whole workspace. [V] |
| Grants / threads | per-uid subcollection | grant_store:15-16; thread_repo:18-25 | Fine. [V] |

**Takeaway [I]:** collection-level read access can be enforced by rules as the code stands, provided the schema list read changes (row 1 of the table). Field-level or row-level access cannot be enforced by Firestore rules with the current document shape: values sit in one `values` map per doc, and rules can't hide fields of a doc they allow. Hidden fields would need a separate doc or a projection copy.

## 3. Conflict model with two humans editing at once

**Mechanism [V]:**
- `saveObject` runs a transaction (`firestore_data_repository.dart:448-487`). It reads the server doc, computes `values = {...stored, ...encodedValues}` (457) and `rev+1`, then `set`s the whole doc. No base rev is compared, so it never refuses a stale write.
- Detection is listener-side only, in `processSnapshotMeta` (962-999). It flags an object when a server snapshot shows `incomingRev > _localRev+1` and the object is not pending.
- `SyncConflict` is sticky until dismissed (`sync_status_cubit.dart:11-12, 49-62`).
- The test `firestore_data_repository_test.dart:529-546` pins the intended rule: "a remote jump past a server-seen baseline still is one".

**Traced cases [I: hand traces over the cited lines, not run]:**
1. **Silent lost update.** B sets field X (rev 6). Before B's snapshot reaches A, A makes an inline table/board edit. The views cubit sends **all** values (`collection_views_cubit.dart:831-835, 1007-1011`: `{...object.values, field.id: value}`). The transaction merges A's stale X over B's X, giving rev 7. A sets `_localRev=7`. B sees 7 = 6+1, the "expected single-step" branch (984-988). **Neither client shows a banner.** The object editor sends only the changed draft keys (`object_editor_cubit.dart:592-601`), so it is field-level merge there; two people editing the same field is silent last-write-wins. Undo re-writes the whole prior object (`collection_views_cubit.dart:995`), reverting a teammate's edits made in between.
2. **False-positive banner.** A's listener on a card closes (navigated away, tab asleep, offline), but `_localRev` survives listener cancel. It is cleared only by `initialize`/`dispose` (181-187, 888-896). B edits twice (rev +2). When A comes back, the first cache snapshot is skipped (967), and the server snapshot shows rev 7 > 5+1, so A gets a conflict banner although A lost nothing. A batch update with `FieldValue.increment(1)` from a plan or automation produces the same effect when combined with any other edit. In a team this becomes routine noise.
3. **Delete versus edit resurrects the card.** A deletes a card. B, in the editor with draft keys only, saves: the txn sees `current == null` and takes the create path (458). The doc is recreated with **only B's draft values**, `rev 1`, and a **fresh auto-number**, because the draft lacks it and `allocateSequences` assigns when the value is not a `num` (`lib/core/domain/calc/sequences.dart:13-33`). The rules allow it: create needs only `collectionId` and `rev`. With an inline edit (all values), the old number is kept. No banner either way.
4. **Batch path.** `saveObjectsBatch` updates send only touched keys via `FieldPath(['values', fid])` plus `rev: increment(1)` (783-794): field-level merge. One `not-found` (a card deleted by a teammate) fails the **whole 450-write chunk** (653-662), reported per id as `not-found`. `_localRev` bumps assume this client is the only writer (640-645). The plan committer's undo journals capture `before` snapshots, so an undo after a teammate's edit restores stale values (journal at `plan_committer.dart:1300-1360`) [I].

**Whole-document and whole-array overwrites [V]:**
- `saveCollection` uses `set(…, merge:false)` with the whole schema (254-259). Its callers are the collection editor (`collection_editor_cubit.dart:302`) and the list cubit (74, 95, 132). Two people editing a schema: last writer wins on fields, layout **and views**.
- `saveViews` uses `update({'views': <entire list>})` (261-269). The views cubit sends its in-memory list on every view change, including drag reorders (`manualOrder`) and board collapse (`collection_views_cubit.dart:717-735, 790-792`). Concurrent view edits by two people drop one side.
- Transactional `updateCollection` / `updateViews` exist (854-886) but are used only by the plan committer.

**Single-writer and offline assumptions:**
- `saveObject`, auto-number reservation, `updateCollection` and `updateViews` are transactions. **Firestore transactions fail when the client is offline [P✓, Firebase docs via context7].** So interactive card saves are effectively online-only. The repo comment at 489-490 agrees, and spec D6 makes plan commits require a connection. The offline "write queue" applies only to plain writes: `saveViews`, pins, `deleteObject`, threads, automation stores.
- Contention: Firestore retries a transaction up to 5 times, then fails [P✓]. Fine at small-team scale; the workspace counters doc is the one shared hot spot.
- **Trello import** lives only on `feat/trello-import`, not in this checkout. Not checked.

**Rules cost of membership checks [P✓]:**
- Limits are 10 `get`/`exists` per single-doc or query request, and **20 per batch or transaction** in total. Docs: "Some document access calls may be cached."
- `maxBatchWrites = 450` (`data_repository.dart:154`). With a membership `get()` per write, whether the batch passes depends on that caching. The Firestore DML guidance warns that bulk writes hit the 20-lookup limit and recommends custom claims, which need the Admin SDK, which in turn needs a server/Functions the project does not have.
- **Must be verified on the emulator before choosing a `get()`-based rule design** [I].

## 4. Views: storage and evaluation

**Storage [V]:**
- Views are an array field `views` inside the collection schema doc `workspaces/{wid}/collections/{cid}` (`collection.dart:120-128`, `ViewDefinition.toJson` in `view_definition.dart:231-241`).
- No rule can target one view. Anyone who can read a view reads the **full schema and all sibling views**. Sharing one view by rules alone needs a separate doc per shared view [I].
- Per-person UI state is stored in that shared doc: `manualOrder` (167) and `collapsedGroups` (171). With members, one person's drag or collapse changes everyone's view and races through whole-array `saveViews`. The active view id is in-cubit only, not persisted. The URL carries `?view=&filter=&card=` (`collection_views_page.dart:111-123`; `app_shell_scaffold.dart:452-465`).
- **Routes carry no workspace id:** `/collections/:id` (`app_router.dart:184-193`). A link is only meaningful inside the current user's own workspace.

**Evaluation is entirely client-side [V]:**
- `applyView` (`lib/core/domain/view/view_query.dart:146-196`) filters, sorts or applies manual order over the in-memory list from the `collectionId` query.
- It runs over **derived** objects (`_derive`, `collection_views_cubit.dart:438-439`), because calculated fields are never stored (`_encodeValues` skips them, `firestore_data_repository.dart:920`).

**Could a view be a Firestore query? Mostly no [I]:**
- Stored values are domain JSON except dates, which are stored as `Timestamp` (`firestore_value_codec_impl.dart:23-36`; select = option id string, multi-select / reference = id arrays, per `docs/domain-json-schema.md:45-49`).
- Translatable: select `anyOf` → `in`; multi/reference `anyOf` → `array-contains-any`; number `>`/`<`/`==`; boolean; date before/after → Timestamp range.
- Not translatable:
  - `contains` / `notContains` and case-insensitive text `equals` (`view_query.dart:78-86`);
  - `isEmpty` (missing vs null);
  - `noneOf` / `notEquals` (Firestore `not-in` drops docs where the field is missing);
  - `onDay` (local calendar day, `calendarDayOf`);
  - any filter or sort on **calculated** fields;
  - "empties last" sort, `manualOrder`, sort by select option order or reference count (`_sortKey` 212-234).
- Each inequality or extra filter combined with `orderBy updatedAt` needs a composite index on `values.<fieldId>`. Field ids are user-defined, so indexes can't be pre-declared in `firestore.indexes.json` [P].
- Consequence: a view's filter cannot serve as a security boundary. Only a deliberately provable shape could, such as one equality on a denormalized field or a `shares` array on the object doc, and saveObject's whole-doc `set` would have to preserve it (§1 row 14).

## 5. Offline persistence and switching workspaces

**Firestore instance [V]:** one global `FirebaseFirestore.instance` with persistence on and unlimited cache (`main.dart:54-57`). Paths are the only thing tied to a workspace, so data from several workspaces can share one cache [P]. Nothing clears it on sign-out (§1 row 16).

**Who holds the workspaceId.** Each holder is a long-lived singleton built in `_MorkvaAppState` (`app.dart:131-219`), with no DI container and no workspace-scoped cubit:

| Holder | Field / method | Re-bind behaviour |
|---|---|---|
| `FirestoreDataRepository` | `_workspaceId`, 73 | `initialize` (181-187) bumps the epoch but does **not** cancel live listeners. Each `watch*` captures `wid` at call time (195, 219, 294, 367). **A switch must call `dispose()` and then `initialize()`.** |
| `FirebaseAttachmentStore` | `_workspaceId` | Plain reassignment (26); in-flight uploads keep the old path. |
| `AutomationWorkspace` | doc ref | `firestore_docs.dart:15-16`; plain reassignment. |
| `AssistantSession.initialize` | — | Resets itself first (`assistant_session.dart:108-118`). It binds the harness `WorkspaceCache` ("A workspace switch is reset then initialize", `workspace_cache.dart:121-128`; throws if already bound), the thread repo and the config repo. |
| `AutomationRunner.initialize` | — | Does **not** reset first: it appends subscriptions (`automation_runner.dart:203-257`). Needs `reset()` before re-binding. |
| `SyncStatusCubit` | — | App-global, not per workspace; a sticky conflict would carry across a switch. [V] |
| Shell cubits (`CollectionsListCubit`, `PinnedCollectionsCubit`) and per-page cubits (`CollectionViewsCubit` keyed `ValueKey('/collections/$id')`) | — | Created in route builders with `context.read<DataRepository>()` (`app_shell_scaffold.dart:84-90`; `app_router.dart:184-200`). They subscribe once, so they must be rebuilt. |

**Feasibility [I]:** a switch is feasible with the existing gate. Reproduce the sign-out sequence (`app.dart:281-296`: `sessionReady=false` bounces the router to `/loading` and unmounts every page and shell cubit; runner reset; assistant reset; repo dispose; close the automation cubits), then the sign-in sequence (247-279) with the new id.

What is missing:
1. A source of truth for the current workspace other than `AuthAuthenticated`. `_onAuthChanged` is keyed on auth state and the `_initializedWorkspaceId` guard.
2. A workspace segment in URLs.
3. Workspace-keyed local state (crash marker, §1 row 17).
4. A way to list the user's workspaces. A list query on `workspaces` needs a rules-provable filter, for example a member-uid array on the workspace doc or a per-user index doc; today's rule only allows the user's own doc [I].
5. Firebase Auth is Google-only (`firestore_auth_repository.dart`). For email invites, `request.auth.token.email` (verified by Google) is what rules could match against [P].

---

**Not checked:**
- Trello import branch.
- The `plan_committer` undo journal in depth.
- Whether a membership `get()` keyed on the `collectionId` equality is provable in list rules, and whether repeated `get()` of the same doc in a 450-write batch stays under 20 access calls. Both need emulator tests.
- Storage cross-service rules.
- How the harness redacts scoped data. I relied on the Epic 8 spec text (`docs/superpowers/specs/2026-11-10-epic-08-ai-assistant-design.md:290-300`).

**Risk:** the lost-update and false-banner behaviour in §3 is from hand traces, not tests. Write a two-client test against the emulator before relying on the current `rev` scheme for teams.