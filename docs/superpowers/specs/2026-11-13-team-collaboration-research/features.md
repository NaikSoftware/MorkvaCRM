# Features that become multi-user: digest

Repo read: `the repo` @ 3e754b8 (main). Nothing was edited.
Tags: **[V]** means I read it in the code. **[I]** means I inferred it.

## 0. Cross-cutting facts that drive every row

- **[V] Rules today are owner-only.** `firestore.rules:14-16` has `isWorkspaceOwner = auth.uid == workspaceId`, and every match uses it. The header comment (`:5-10`) plans to swap it for a membership `get()`, with paths unchanged. `members/{uid}/{sub}` (`:115-119`) and `members/{uid}/grants/{moduleId}` (`:122-131`) are already per-member and also check `request.auth.uid == uid`.
- **[V] Storage rules are owner-only too.** `storage.rules:8-13` uses `auth.uid == workspaceId`. The path is `workspaces/{wid}/files/{attachmentId}/{fileName}` (`lib/api/files/firebase_attachment_store.dart:9-10`). It contains **no collectionId**, so file access cannot be limited per collection without a path change. Storage itself is deferred (not enabled).
- **[V] The workspace is still the uid.** `lib/api/workspace/workspace_resolver.dart:13-19` (`UidWorkspaceResolver`).
- **[V] The workspace doc itself holds shared state that ordinary edits write:**
  - `pinnedCollections`: `firestore_data_repository.dart:211-213` has `// shortcut: pins live on the workspace doc, so a shared workspace would share them`.
  - Auto-number `counters`: these are bumped inside the `saveObject` transaction (`firestore_data_repository.dart:448-472`) and the batch path (`:804-838`). So **an editor creating a card in a collection with an auto-number field must write the workspace doc.** The rule needs `affectedKeys().hasOnly(['counters'])` for editors, and pins should move to `members/{uid}`.
- **[V] Object docs carry no author.** Doc keys are `collectionId, rev, createdAt, updatedAt, values` (`firestore_data_repository.dart:477-481`). There is no `createdBy`/`updatedBy`, so neither rules nor an activity log can attribute edits. Add `updatedBy == request.auth.uid` as a rule-checked key (no migration needed, per the "no clients" memory).
- **[V] Views are embedded in the collection schema doc.** See `Collection.views`, `collection.dart:46-51`. Collapsing a board group, manual drag order and (by the same path) sort and filter all rewrite the collection doc through `_updateView → _saveViews` (`lib/features/views/collection_views_cubit.dart:685-709, 792, 870`). Two consequences:
  - A viewer cannot collapse, sort or drag without schema-write rights.
  - One editor's personal tweak changes the view for everyone.

  Suggested fix: keep the shared view definition on the collection doc (admin-written) and put per-member overrides (collapsed, manual order, ad-hoc sort/filter) at `members/{uid}/viewPrefs/{collectionId}`.
- **[V] Queries are already shaped for per-collection rules.** Objects are read with `where collectionId == X` (`firestore_refs_impl.dart:61`), so a rule like `resource.data.collectionId in memberDoc.collections` would validate. **But** `watchCollections()` lists the whole `collections` subcollection (`firestore_data_repository.dart:193-209`). If schema docs were per-collection gated, that query fails as a whole, so it would need `documentId in [...]` (max 30). Recommendation: **every member can read all schema docs; only card data is gated.** The reasons are in §3.
- **[V] Field-level secrecy is impossible.** Rules cannot hide fields inside a doc. A view's hidden columns and its filters are UI-only, so anyone who may read a collection's objects can read every field of every card in it. Sharing one view therefore really shares the whole collection, unless a copy or projection is published (§3, last bullet).
- **[V] Admin is the console only.** `config/assistant` (global) and `featureFlags/{uid}` are `allow write: if false` (`firestore.rules:141-149`). No in-app admin exists.

## 1. Automations (`lib/core/automation`, `lib/api/automation`, `lib/features/automation`)

**Whose device runs a card-event trigger? [V]** The device of the member who made the write, and nobody else's.
- `DataRepository.changes` emits only "every card write this instance made… never remote changes" (`lib/api/data/data_repository.dart:126-128`). The runner subscribes to it (`automation_runner.dart:133-135`).
- `TriggerEvaluator.watches` accepts only origins `ui | plan | automation` (`trigger_evaluator.dart:88-91`). Template and Trello-import writes (`WriteKind.template`, `collections_list_cubit.dart:102`; trello branch `trello_import_cubit.dart:250`) and undo never fire triggers.
- So **two members' devices never both fire for one write**, and loops cannot ping-pong across devices.
- The run executes under the **writer's own consent**: `stores.grants.get(uid, moduleId)` (`automation_runner.dart:692`). If the writer has not consented, the run is skipped as `needsConsent` (`:696-699`).
- **Team impact:** an "on card created" automation silently works for some members and not others, depending on who consented. Viewers never write, so they never fire triggers. Writers who are offline run the trigger after their write resolves.

**Auto-apply. [V]**
- `_effectiveApply` gives `auto` only when `a.autoBy == _uid` and that uid's consent has `autoApply` (`automation_runner.dart:1150-1156`).
- `ApplyPolicy` returns review `'auto-apply was set by another member'` (`apply_policy.dart:53-55`).
- Firestore enforces `apply=='ask' || autoBy == request.auth.uid` (`firestore.rules:81-83`).
- **Impact:** an owner's Auto automation becomes Ask-first on every editor's device. Every editor edit lands in **Needs review on the editor's device**, and the editor may not understand the module.
- Options:
  - (a) accept this and show "Auto for <owner> only";
  - (b) a per-member "adopt auto", where each member grants their own `autoApply` (it is per-member already);
  - (c) a team auto delegated by an admin. This breaks the current security model, so it is not recommended without Functions.

**Latent bug when members land. [V]**
- `_pause` saves the **whole** automation doc from whichever device hit the problem (`automation_runner.dart:1264-1269`, `.catchError(_ignore)`).
- For an `apply:auto` automation, `autoBy` is the original author, so the rule at `firestore.rules:82-83` **rejects** the pause write from any other member. The error is swallowed. Result: no persisted pause, and every member keeps re-hitting the broken or looping automation.
- Fix: allow members an update whose `affectedKeys().hasOnly(['pausedReason','pausedDetail','pausedAt',…])`, or store pause state per member.

**Leases / visibility. [V]** The runner leases the trigger collection and the reference targets (`automation_runner.dart:1296-1331, 1357-1376`). A restricted member's lease of a hidden collection fails, and the run ends as `notPermitted` or `broken`. `_problems` with a scope-only failure does not pause (`:715-724`). Module bridge reads also go through the member's own Firestore access, so rules are the real boundary.

**Run log. [V]**
- `workspaces/{wid}/runs`: one shared collection, `watchRecent` = newest 200 (`stores.dart:54`, `firestore_run_store.dart:18-22`).
- A run doc holds `by: user:<uid>`, `device`, `sessionId`, `params`, the trigger snapshot and `log` (a JSON string of ≤ 64 KB with module console output and errors) (`run_record.dart:340-380`, `firestore.rules:33-37`). **[I]** A module's console can print any card data, so the run log leaks data from collections a reader cannot see.
- `prune()` from any device deletes everything beyond the newest 200, **including other members' runs** (`automation_runner.dart:1251-1261`; `firestore_run_store.dart:46-47`).
- `_finalizeOwn` expires **any session's** review older than 8 h (`automation_runner.dart:1380-1405`), so it updates other members' run docs.
- Reviews are session-memory only (`PlanStore`), so another member sees "Review not available here" (`reason_copy.dart:300-303`, `run_log_cubit.dart:90-101`). The copy says "another window", which is wrong for "another member".
- **[V] The auto budget is per device, not per workspace.** It is held in memory (`loop_guard.dart:166-180`; `kAutoBudgetItems = 1000` per 10 min, `:68-69`), so N members give N× the budget.

**Modules and consent safety. [V]** Consent is pinned to `codeHash` (`firestore.rules:129-130`; status check through `moduleStatusOf`). If an editor rewrites module code, every other member drops back to `needsConsent`, so this is safe by construction. Saving modules or automations from an assistant plan requires `actor.kind == user`, and "the consent and `autoBy` belong to the approving member" (`plan_committer.dart:846-858`).

## 2. Ask Morkva assistant (`lib/api/assistant`, `lib/api/ai`, `lib/features/assistant`)

- **[V] Threads are per member** at `workspaces/{wid}/members/{uid}/assistantThreads/{tid}/messages` (`firestore_thread_repository.dart:19-24`, spec D10). They are private to the member. **[I]** A thread keeps result tables or charts from data the member could see then. Revoking access does not scrub old threads.
- **[V] Consent is per workspace and any member can set it.** `grantConsent` merge-writes `workspaces/{wid}/config/assistant {consentedBy, consentedAt}` (`assistant_config_repository.dart:53-60`). The rule is `read, write: isWorkspaceOwner` (`firestore.rules:134-136`), so under membership any member could consent for the whole team. Free-tier data use is in play: `AvailabilityNeedsConsent(freeTier: …)` (`assistant_bloc.dart:300-303`). **Rule: only the owner/admin writes `config/assistant`. Other members get a read-only notice.**
- **[V] Who pays.** `FirebaseAI.googleAI().generativeModel` (`gemini_llm_client.dart:155-156`) uses the Gemini Developer API, so quota is per **Firebase project**, shared by every user of every workspace. App Check is optional (`main.dart:16-90`). `dailyTurnsSoft` is parsed (`assistant_config.dart:43,72,108`) but **not enforced anywhere** (grep shows no other use). Quota is handled only reactively (`_quotaUntil`, `assistant_bloc.dart:306-308`). The Epic 8 spec defers "a per-member daily counter doc" (`epic-08 spec:1596-1597`). **Impact:** any member, or an outsider if outsiders get the assistant, can exhaust everyone's quota. Without Functions, a counter at `members/{uid}/usage/{yyyy-mm-dd}` with an increment-only rule is advisory but rule-shaped.
- **[V] Enable flag is per user, not per workspace.** `featureFlags/{uid}.assistant` overrides global `enabled` (`assistant_config.dart:59-62`). The owner's flag does not carry over to members.
- **[V] Agent grants vs role.** The agent loop uses `Grants(kAssistantCaps)`, which is all capabilities except `hostCommit` (`assistant_session.dart:53`, `capability.dart:54-56`). Plans commit with `Grants.all()` as `Actor.user` (`assistant_bloc.dart:1691`). There is no role input. The infrastructure exists, though: `Grants(caps, collections:)` (`capability.dart:113-150`), plus digest redaction `redacted:true` for calculated fields that read ungranted collections (`workspace_digest.dart:302-370`, `readsUngranted` at `query_engine.dart:910-930`). The Epic 8 spec already prescribes "viewer = `*:read` + `ui:navigate`, editor = everything except `schema:delete`, owner = all; Firestore rules stay the real boundary" (`epic-08 spec:292-300`).
- **[I] What a viewer's assistant can reach:** the session cache, which equals what the rules let the client read. If schemas are readable but data is gated, `workspace.describe` lists hidden collections. Pass `collections:` in the role grants so they read as `unknown_collection`. Without role grants, a viewer's plans fail at commit with permission-denied, partly applied per item.
- **Outsider via link:** no assistant. That avoids cost, consent and data-reach problems.

## 3. Calculated fields, references, lookups, sublists, files

**[V] How they compute:**
- Calculated values are "computed on read by `Derivation` and never stored" (`calculated_field.dart:13-20`). So **no leak through card docs**, but a reader must be able to read every source collection.
- Lookup chain: `lookupTargetOf` needs the **target schema** (`lookups.dart:13-28`). Without it the field resolves to null and shows as a broken field.
- `Derivation`: "Objects of a collection missing from [objects] count as still loading: aggregates over them are blank, not 0" (`derivation.dart:25-27`). A permission-denied source shows as a **permanent blank or loading state**, not an error.
- Reference values store only target ids (`reference_field.dart:18-23`). The chip label needs the target card.
- The editor watches the targets, the sublist collections and `Derivation.sourcesOf(...)` (`object_editor_cubit.dart:150-170`). On error it falls back to empty choices: "A failed target shows no choices instead of loading forever" (`:166-167`).

**Concrete cases.** Assume a member can see **Deals** but not **Invoices** or **Companies**:

- **Breaks:**
  - `Deals.Total invoiced` (an aggregate `linkedFrom` Invoices) stays blank forever.
  - `Deals.Industry` (a lookup through `Company` into Companies) is blank if the schema is readable, or a broken field if the schema is hidden.
  - The `Company` chip shows no title and the picker is empty.
  - The Invoices sublist in the deal form is empty or missing.
  - A formula that reads `{Total invoiced}` is also blank (transitive).
  - A required reference into Companies makes **creating a deal impossible**.
- **Leaks:**
  - (a) If schemas are readable to all members, hidden collections' names, field names and select options are visible. Data is not.
  - (b) Run logs and assistant threads written by a member with wider access.
  - (c) An automation, or an editor, copying a hidden value into a plain field of a visible collection. This is intentional, but invisible to the admin.
  - (d) Shared-view "hidden columns": the whole card doc is readable (§0).

**Suggestions:**
- Schemas are readable to all members.
- The UI marks a calculated field "Restricted" when `readsUngranted(owner, field, roleGrants, allSchemas)` is true. This is existing code, and it is transitive.
- Show restricted reference chips as "Restricted card".
- Block, or warn on, a role scope that excludes a collection required by a visible one. Compute this with `Derivation.sourcesOf`.

**Outsider link view.** Rules cannot pass a share token to an objects read unless the token sits in the doc path. The Spark-compatible option is a **published projection**: `shares/{token}` plus `shares/{token}/rows/{id}`, holding only the view's fields. The sharer's client writes it with **calculated values materialized**, which deliberately reveals the aggregate but not its source. **[I]** Limitations of that option:
- It is stale until a member with access is online to refresh it.
- Writes are doubled.
- Doc limit is 1 MB per row doc.
- Without anonymous Auth enabled, outsiders also need a Google sign-in (Auth is Google-only).

**Files.** The storage path has no collection (§0). Per-collection file rules need `files/{collectionId}/…` plus a cross-service `firestore.get()` in `storage.rules`. This is a one-line path change now (no clients). Storage is deferred.

## 4. Templates, schema management, import

- **[V] Templates.** `importTemplate` writes collection docs, then objects with `WriteKind.template`. Auto-numbers bump the workspace `counters` (`collections_list_cubit.dart:82-105`). This is a schema write, so admin or a "manage collections" role.
- **[V] Schema edits.** `updateCollection` re-reads the server copy in a transaction, so concurrent schema edits by two admins merge field-wise (`data_repository.dart:129-132`). `deleteCollection` deletes only the schema doc (`firestore_data_repository.dart:272-274`). Bulk object deletes go through the plan committer as `WriteKind.collectionDelete` (`plan_committer.dart:1318`). **[I]** An editor-level rule for object delete would let the bulk delete partly fail, so this is owner/admin only.
- **[V] Module import.** `import_sheet.dart:11-12` takes a `.morkva.json` module and runs the consent flow. This is `modules:write`.
- **[V] Trello import.** It exists only on `feat/trello-import` (spec `docs/superpowers/specs/2026-11-13-trello-import-design.md`). It creates collections plus `saveObjectsBatch` with `WriteKind.template` (`trello_import_cubit.dart:250, 462, 493`), so no triggers fire. Trello members map to a `multi_select` of full names (spec line 106), **not** to workspace members. A "member" or person field type is a natural follow-up for an assignee. Comments go to a child collection until the planned comments feed.

## 5. Feature flags / admin

- **[V]** `featureFlags/{uid}` is read only for `assistant` (`assistant_config_repository.dart:43`; it is the only reader in `lib`).
- Flags follow the **user**, not the workspace. A paid or plan-gated team feature would need workspace-scoped flags, for example a `workspaceFlags/{wid}` doc that is console-written and readable by members. **[I]**
- Member invite and role management cannot be console-only. They need client-written `members/{uid}` docs (role, collections) under owner-only rules. That is out of my area but blocks every row below.

## 6. Table

| Feature | Current assumption (file:line) | Multi-user impact | Suggested permission rule |
|---|---|---|---|
| Card-event triggers | Local writes only fire (`data_repository.dart:126-128`, `trigger_evaluator.dart:88-91`); writer's consent (`automation_runner.dart:692`) | Runs on the writing member's device only, never twice; members without consent get `needsConsent` skips, so behaviour is inconsistent; viewers never fire | Automation create/edit/delete: admin (or editor with "automations"). Consent: each member for themselves (existing rule `:122-131`). UI: show "runs for N of M members" |
| Auto-apply | `autoBy == uid` (`automation_runner.dart:1150-1156`, `apply_policy.dart:53-55`, `firestore.rules:81-83`) | Other members' runs of an Auto automation go to review on their own device | Keep per member; offer "Use auto for me too" (member's own `autoApply` plus a per-member auto marker); no team delegation without a server |
| Automation pause | Whole-doc save from any device (`automation_runner.dart:1264-1269`) | **Rejected by rules for non-authors of Auto automations; error swallowed** | Members may update only the pause keys (`affectedKeys().hasOnly([...pause keys])`) |
| Run log | Shared `runs`, newest 200, prune and 8 h expiry by any device (`automation_runner.dart:1251-1261, 1380-1405`; `stores.dart:54`) | Logs leak hidden data; one member prunes others' history; "Review not available here" copy is wrong | Read: admin, or `by == 'user:'+uid` (non-admins query `where by ==`); create/update: own `by`, plus the existing lifecycle transitions; delete/prune: admin only (or own runs) |
| Auto budget | In-memory per device (`loop_guard.dart:166-180`) | Effectively N×1000 items per 10 min | Accept with a comment, or keep a shared counter doc (advisory) |
| Modules | Code-hash-pinned consent (`firestore.rules:57-72, 129-130`) | An edit by one member re-asks consent of all others (safe) | Install/edit/delete: admin; read: members; outsiders: none |
| Ask Morkva availability | Consent per workspace, any member may write (`assistant_config_repository.dart:53-60`, `firestore.rules:134-136`); flag per user (`assistant_config.dart:59-62`) | One member can opt the whole team into free-tier data use | `config/assistant` write: owner only; members read; per-user flag stays |
| Ask Morkva cost | Project-wide Gemini quota; `dailyTurnsSoft` unenforced (`assistant_config.dart:43,72`; `gemini_llm_client.dart:155`) | Any member can exhaust everyone's quota | Viewer: allowed but read-only; outsider: none; per-member daily counter doc (advisory, rule-checked increment) |
| Ask Morkva reach | Agent `Grants(kAssistantCaps)`, commit `Grants.all()` (`assistant_session.dart:53`, `assistant_bloc.dart:1691`) | No role input; viewer plans fail at commit | Map role to `Grants(caps, collections:)` in one place: viewer = `schema:read, data:read, ui:navigate`, scoped to the member's collections; editor = all but `schema:delete`, module and automation writes |
| Threads | `members/{uid}/assistantThreads` (`firestore.rules:115-119`) | Private already; old threads keep data after access is revoked | Own uid only (`isMember && uid == auth.uid`); admin cannot read |
| Templates | Schema write plus `counters` (`collections_list_cubit.dart:82-105`) | Creates collections for everyone | Admin, or a "manage collections" role |
| Schema edits / delete | Transactional update; bulk delete through `collectionDelete` (`plan_committer.dart:1318`) | Concurrent admins are fine; an editor delete would partly fail | Schema write: admin; collection delete: owner/admin |
| Views (filters, sort, collapse, order) | Embedded in collection doc (`collection.dart:46-51`, `collection_views_cubit.dart:685-709`) | Viewers cannot interact; personal tweaks become global | Shared view definition: admin; personal overrides at `members/{uid}/viewPrefs/{cid}` |
| Pins | Workspace doc `pinnedCollections` (`firestore_data_repository.dart:211-213`) | Shared pins | Move to `members/{uid}` |
| Card create/edit | `rev` LWW plus field-conflict banner (`firestore_data_repository.dart:448-481`, `object_editor_cubit.dart:370-410`); no author key | Conflicts more frequent; no attribution; auto-number needs a workspace-doc write | Editor: create/update with `collectionId in member.collections`, `updatedBy == auth.uid`, monotonic `rev`; workspace doc update `hasOnly(['counters'])`; viewer: read; `readOnlyFieldIds` (`object_editor_state.dart:69`) can drive a fully read-only form |
| Calculated / lookup / reference / sublist | Computed on read; a missing source counts as loading and stays blank (`derivation.dart:25-27`, `lookups.dart:13-28`, `object_editor_cubit.dart:150-170`) | Hidden sources give blank aggregates and lookups, untitled chips, empty pickers and sublists; required refs block create; schemas leak names if readable | Schemas readable by all members; data gated per collection; UI "Restricted" through `readsUngranted` (`query_engine.dart:910`); warn when a scope excludes a dependency (`Derivation.sourcesOf`) |
| File fields | Path without collection (`firebase_attachment_store.dart:9-10`, `storage.rules:8-13`) | Cannot gate files per collection | Path `files/{collectionId}/…` plus `firestore.get()` membership in `storage.rules` |
| Import (module / Trello) | Module: consent flow; Trello: `WriteKind.template` writes (branch) | Creates schema for everyone; Trello people do not become workspace members | Admin only; later map Trello members to a member field |
| Feature flags / admin | `featureFlags/{uid}`, console-only (`firestore.rules:146-149`) | Per user, not per team; no in-app admin | Keep per-user flags; add a console-written `workspaceFlags/{wid}`; roles live in client-written `members/{uid}` with owner-only rules |
| Outsider by link or email | Google-only Auth; no share concept | Card docs are readable whole, so field and filter privacy is impossible | Published projection `shares/{token}/rows` written by the sharer's client (materialized calculated values, only the view's fields); no assistant, automations or run log |

Not checked: the Trello branch only at spec and grep level; journal and undo across members (`host_ops.dart:410` compares the journal actor, so undo is per member, **[I]**); presence; and the exact contents of `triggerEval`/`why` strings in run logs.

Main risk: the `_pause` rule rejection is a real bug that appears the moment membership rules land.
