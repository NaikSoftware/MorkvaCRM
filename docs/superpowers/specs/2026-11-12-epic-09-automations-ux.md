# Epic 9 — Automations: UX spec (screens, states, copy)

Companion to `2026-11-12-epic-09-automations-design.md` (architecture; vocabulary and decisions
D1–D19 live there; every critique item and its resolution is in its **Critique log**, items `U1`–`U40`
are this spec's). This spec wins on any UI detail. Mockups: Claude Design canvas, local copies in
`docs/superpowers/mockups/epic-09/` (artboards at the end). Visual language: **"Warm Carrot"**
(`lib/design/DESIGN.md`) — warm-paper canvas, carrot for primary actions only, amber `warning`
(never carrot) for "needs attention", Bricolage Grotesque headings, Hanken Grotesk body, radii
sm 8 / md 12 / lg 16 / full 28, spacing 4/8/12/16/24/32/48, motion 120/200/320 ms emphasized, every
pressable with `PressableScale` and a 44 px hit area, sentence case everywhere. Colours are named by
**token only** (no hex in this spec).

House components to reuse: `PrimaryButton`, `SecondaryButton`, `TextActionButton`,
`IconActionButton`, `MorkvaTextField`, `SearchField`, `SurfaceCard`, `ListTileCard`,
`MorkvaConfirmDialog`, `EmptyState`, `CollectionGlyph`, `OptionPill`, `ToolbarButton`, the
`SyncStatusIndicator` pill shape (28 px, `foreground @ 12%` wash, `Radii.full`,
`sync_status_indicator.dart:119-129`), the views tab style (`lib/features/views/widgets/view_tabs.dart`),
the views `FilterBuilder` popover (`lib/features/views/widgets/filter_builder.dart:15`), the assistant
`PlanCard` and `AppliedCard` (via `PlanCardScope`, design H15), and the `_notify` snackbar pattern
(`collection_views_page.dart:315-333`: `persist: false`, 5 s, floating, width 480 on wide). Monospace
text uses `MorkvaTypography.mono` (new: `fontFamily: 'monospace'`, fallback `['Roboto Mono', 'Courier
New']`, the pattern of `calculation_config.dart:480`) — no font download.

## Breakpoints

From the code: phone **< 840** (`app_shell.dart:81`), rail **840–1239** with the **76 px** rail
(`shell_sidebar.dart:74`), full sidebar **≥ 1240** at **272 px** (`shell_sidebar.dart:71`,
`app_shell.dart:84`). Mockups use these widths, not epic-08's 248/80 drift.

| Surface | Sidebar ≥ 1240 | Rail 840–1239 | Phone < 840 |
|---|---|---|---|
| Automations entry | `_NavRow` "Automations" (bolt) right under "All collections", live pill trailing | `_RailButton` bolt under the All tile, badge | Settings page row "Automations"; collection More menu "Automations…"; the header indicator while not idle |
| Automations page | shell page, max content width 1040, tabs | same | full-screen shell page, tabs scroll |
| Module details / run detail | shell page with back to the tab (run detail is always its own page, never master-detail) | same | pushed page |
| Consent, import, review, test run | centered dialog 560 wide (`Radii.lg`, level3) | same | bottom sheet, full height, drag handle |
| Automation editor | right side sheet 480 (scrim) | same | full-screen route with Close + Save |
| Code viewer | dialog 900 × 80% height | dialog | full-screen route |

## 1. Automations page

Route `/automations` (`?tab=modules|automations|runs`, default `modules`; `&collection=<id>`
filters the Automations tab; `&card=<id>` and `&filter=review|failed` filter the Runs tab). The page
reacts to query changes while mounted (`didUpdateWidget`), so the indicator can switch tabs. New
`ShellPlace.automations` (`shell_sidebar.dart:15`), highlighted in the sidebar/rail. Header (wide):
title **Automations** (headlineSmall), subtitle "Modules add actions. Automations put them on
buttons or run them when cards change." Right side: the tab's primary action.

Tabs (the views tab style, `view_tabs.dart`, labelLarge): **Modules** `3` · **Automations** `5` ·
**Runs** with an amber count pill when runs need review ("Runs · 2").

### 1a. Modules tab

Header action: `SecondaryButton` (upload icon) **Import module**. Secondary text button
**Ask Morkva to write one** (opens the assistant with the prefill "Write a module that …"; hidden
when Ask Morkva is flagged off, `app_shell_scaffold.dart:337`).

List of `SurfaceCard` rows (two columns of cards ≥ 1240, one column below):

```
[glyph]  Stamp shipped date   v1.0.0                           [Installed ✓] / [Needs consent ⚠]
         Sets a date field to today when an order ships.
         Reads cards · Changes cards · In Orders                 Made by Ask Morkva · 2 automations
```

- Glyph: `CollectionGlyph` with the first action's icon, tinted by module id.
- Version: `OptionPill` neutral.
- Status chip: **Installed** (the leaf `CollectionTints` pair), **Needs consent**
  (`warningContainer` / `onWarningContainer`) or **Broken** (`errorContainer`; the manifest no longer
  parses).
- Permission summary: the plain-language capability titles (section 2) joined with " · ", then
  "In <collections>" or "In all collections".
- Source: "Made by Ask Morkva" (`source: assistant`) or "Imported".
- Tap → module details.

Empty state (`EmptyState`, doodle background): title **No modules yet**; body "Modules add actions
to Morkva — like stamping a date or flagging low stock. Ask Morkva to write one, or import a
.morkva.json file."; actions `PrimaryButton` **Ask Morkva** (sparkle; hidden when flagged off) and
`SecondaryButton` **Import module**.

### 1b. Automations tab

Header action: `PrimaryButton` (plus) **New automation**; disabled with the visible line "Install a
module first" when there are none.

Grouped by collection (`CollectionGlyph` + collection name as a caption row; a `collection`
query param shows one group and a chip "Orders ✕"). Each row (`ListTileCard`, 64 px):

```
[tile] Stamp when shipped                                   [Ask first]  [status]  (●── switch)
       When a card is updated · Status starts matching "is Shipped"
       Do: Stamp shipped date › Stamp
```

- Tile: the button's icon on its tint (buttons) or a bolt on `surfaceContainerHigh` (events).
- "When" line: "Button on a card", "Button on Orders", "When a card is created",
  "When a card is updated · <condition summary>", "When a card is deleted". Condition summary =
  the filter chips' text joined with " and "; `fields` → "· when Status or Qty changes".
- Apply chip shows the **effective** mode: **Ask first** (neutral), **Auto** (leaf `CollectionTints`
  pair), or **Auto · off for this module** (amber; tap → module details) when the automation is
  stored as Auto but the module's auto-apply is off (after a code update or by the user).
- Status chip (only when not active): **Needs consent** (amber, tap → module consent),
  **Broken** (error tone, tap → editor with the problem banner), **Stopped after a crash** (amber,
  tap → **Resume**), **Loop suspected** (amber, tap → "Resume"), **Paused** (neutral; = switch off).
- Switch toggles `enabled` immediately (no save button).
- Tap → editor.

Empty: title **No automations yet**; body "Put a module's action on a button, or run it when cards
are created, changed or deleted."; action **New automation** (or **Import module** when no
modules).

### 1c. Runs tab

Filter chips row: **All** · **Needs review `2`** (amber count) · **Failed** · an automation picker
(`ToolbarButton` "Any automation ▾") · a card chip "#1042 ✕" when opened with `card=`. The tab shows
the latest 200 runs. A "Running now" section appears at the top while runs are queued or running
(spinner rows, live), each with **Stop** and, for queued rows, "3 ahead".

Run row (56 px):

```
[status]  Stamp when shipped · Stamp                    #1042        2 min ago   412 ms
          Stamped #1042                                                         [Review] / [Run again on #1042]
```

- Status icon: spinner (`info`) running · clock (muted) queued · amber dot **needs review** ·
  check (`success`) succeeded · ↶ (muted) undone · red ✕ failed / timed out · grey ⊘ skipped ·
  hourglass-off (muted) expired · ✕ muted rejected · amber "?" outcome unknown / interrupted.
- Second line: the summary, or the reason in plain words (table in section 9). A run triggered by
  an offline change that synced later reads "Changed offline 11:40 · ran 12:04".
- Skipped rows are muted (`onSurfaceVariant`); coalesced rows read "Skipped 14 times · Needs
  consent"; more than 3 consecutive rows sharing a reason collapse into "12 skipped — show".
- A review this tab doesn't hold: "Review not available here — it was opened in another window, or
  before Morkva restarted" (muted), trailing **Run again**.
- Trailing action: **Review** (awaiting review in this tab); **Run again on #1042** on every failed,
  timed-out, skipped or expired run whose automation is runnable — not for `card.deleted` runs, not
  when changes may be unconfirmed or the outcome is unknown, replaced by **Review permissions** /
  **Edit automation** when the module needs consent / the automation is broken, disabled offline
  with "Needs a connection". Tap row → run detail.

Empty: title **No runs yet**; body "When an automation runs, its log shows up here — what
triggered it, what it read, what it changed."

## 2. Module details

Route `/automations/modules/:id`. Back arrow "Automations".

Header: `CollectionGlyph` 44, **Stamp shipped date** (headlineSmall), `v1.0.0` pill, status chip;
meta line "Made by Ask Morkva · 12 Nov · 2.1 KB" or "Imported · Author: Jane Doe (from the file) ·
12 Nov · 2.1 KB" (the manifest `author` is free text, so it is always labelled as the file's).
Overflow `IconActionButton` (⋯): **Export**, **Uninstall**.

Banners (top, `Radii.md`, live region):
- needs consent, never consented: amber — "**Allow this module to run.** Review what it can do
  before its actions can run." `PrimaryButton` **Review permissions**.
- needs consent after a change: amber — "**This module changed (v1.0.0 → v1.1.0).** Its
  automations are paused until you allow the new version." **Review changes** (versions from the
  old consent's `version`).
- broken: error tone — "**This module's file is no longer valid.** Import it again." (with the
  parser problems).
- engine unavailable (device-wide): `warning` — "Automations can't run on this device right now.
  Runs are skipped and logged."

Sections (`SurfaceCard` each, section gap 24):

1. **About** — the description (plain text); "Author: … (from the file)"; source.
2. **What it can do** — one row per capability: icon, title, one-line explanation, then the
   collections line "In Orders, Clients" or "In all collections" (from the consent; before consent
   from the manifest: "Will ask for: …"). Plain language — `kCapabilityCopy`, the same strings in the
   consent sheet, the assistant preview and SDK `manifest.md`:

   | Capability | Title | Explanation |
   |---|---|---|
   | `schema:read` | See your collections and fields | Reads collection and field names and types. |
   | `data:read` | Read cards | Reads card values in the allowed collections. |
   | `data:write` | Create and change cards | Proposes new cards and edits. |
   | `data:delete` | Delete cards | Proposes deleting cards. Never applied automatically. |
   | `schema:write` | Change collections and fields | Proposes new fields or field changes. Never applied automatically. |
   | `schema:delete` | Delete fields and collections | Proposes deleting fields or collections. Never applied automatically. |
   | `views:write` | Change views | Proposes view changes — filters, sort, columns. Never applied automatically. |
   | `ui:navigate` | Link to cards | Shows links that open a card or view when you tap them. |

   Section actions: `SecondaryButton` **Change access** (consent sheet in edit mode: collections)
   and `TextActionButton` **Revoke** (error tone; `MorkvaConfirmDialog` "Revoke access for "Stamp
   shipped date"?" — "Its automations stop running and pending reviews are dropped until you allow
   it again." → the module becomes Needs consent).
   Footer (muted, shield icon): "Modules can't reach the internet, your account or other apps.
   Every change goes through a preview unless you turn on auto-apply below."
3. **Auto-apply** — `Switch` **Apply changes automatically**. Help: "Small card creates and edits
   from this module — up to 20 cards, nothing cleared — are applied without asking. Bigger changes,
   deletes and structure changes always wait for you. You can undo an applied run until you reload
   Morkva." Shown only when the module asks for `data:write` and none of `data:delete`,
   `schema:write`, `schema:delete`, `views:write`; otherwise a muted line: "This module can delete or
   change structure, so its changes always wait for your review." Turning it on asks once:
   `MorkvaConfirmDialog` "Apply this module's changes automatically?" / confirm **Turn on**. Turning
   it off while automations use Auto confirms "2 automations will ask first." / **Turn off**.
   Disabled while the module needs consent.
4. **Actions** — per action: icon, **label**, scope tag ("On a card" / "On a collection" /
   "Card or collection"), description, its inputs ("Date field — a field picker"), buttons
   `TextActionButton` **Test run** and **Add to a button**; before consent **Test run** is disabled
   with the visible line "Allow this module first".
5. **Automations using it** — compact rows (as 1b) + **New automation**.
6. **Code** — "module.js · 2.1 KB · sha256:3fa2…c91" (tabular), `SecondaryButton` **View code**.
7. **Recent runs** — last 5 rows (as 1c) + **All runs** link (Runs tab filtered by module).

### Consent sheet

Title: **Allow "Stamp shipped date"?** Subtitle: "v1.0.0 · Imported · 2.1 KB".
Body:
- "It can:" + the capability rows (icon, title, explanation).
- "Actions:" the action labels with their scope tags; `TextActionButton` **View code** (the code
  viewer over the in-memory bundle — nothing is installed yet).
- **Where** — radio: **All collections** / **Only these** + a checklist of collections (glyph +
  name). Preselected: for an import, **nothing** ("Only these" with the collection the user came
  from checked, if any); for an assistant install, the collections it chose. **Allow and install**
  stays disabled until a scope is chosen.
- Muted footer: "Modules can't reach the internet, your account or other apps. You can change or
  revoke this later in module details."
- Re-consent: rows carry a tag — **New** (amber outline) for added capabilities, struck-through
  muted rows for removed ones, plain for kept; a line "Code changed: v1.0.0 → v1.1.0 · 2.1 KB →
  2.4 KB" (from the old consent's `version` and `codeBytes`); when auto-apply was on: "Auto-apply
  turns off for the new version. Turn it on again in module details."
- Edit mode (Change access): title **Change access for "Stamp shipped date"**, only the Where
  section is editable; button **Save**.
Buttons: **Cancel** · `PrimaryButton` **Allow and install** (import) / **Allow** (re-consent).
Auto-apply is never in this sheet (separate, explicit step in section 3).

### Import sheet

Title **Import module**. Segmented control **File** | **Paste**.
- File: dashed drop zone (web) "Drop a .morkva.json file here" + `SecondaryButton` **Choose file**
  (file_picker); phone shows only the button.
- Paste: `MorkvaTypography.mono` `MorkvaTextField`, 8 lines, hint "Paste the module file (JSON)".
- Errors (error tone list under the input, each "path — message"): "This isn't a Morkva module
  file.", "The code is 312 KB; the limit is 256 KB.", "permissions.capabilities[2]: "*" can't be
  granted to a module.", "actions[0].scope must be card, collection or any.", "name: modules can't
  be named after Morkva or the assistant."
- Replace notice (amber): "A module with this id is installed (v1.0.0). Allowing replaces it with
  v1.1.0 for its 2 automations."
Buttons: **Cancel** · `PrimaryButton` **Continue** → consent sheet.

### Export

Overflow → **Export**: the system save dialog on every platform (`FilePicker.platform.saveFile`;
on web it downloads `<id>.morkva.json`). Snackbar "Exported stamp-shipped-date.morkva.json".

### Uninstall

`MorkvaConfirmDialog`: **Uninstall "Stamp shipped date"?** — "Its 2 automations and their buttons
are deleted, its pending reviews are dropped and its permissions are removed. The run history
stays." Confirm **Uninstall** (error tone). Snackbar "Uninstalled Stamp shipped date".

### Code viewer

Header: "module.js" · "2.1 KB · sha256:3fa2…c91" · `IconActionButton` **Copy** · Close. Body:
read-only, `MorkvaTypography.mono` 13/20, line numbers in a muted gutter, soft
`surfaceContainerHigh` background, lazy lines, horizontal scroll for long lines. No editing, no
syntax colors in v1. Opened from module details, the consent sheet and an assistant preview row
(**View code**).

### Test run sheet

Title **Test "Stamp"**. Copy under the title: "Test runs never change data — you'll see what
would change." Inputs, in order: **Collection** (dropdown limited to the module's allowed
collections; preset for card-scoped automations), then **Card** (search field over that
collection's cards, shows "#1042 · Acme") for card actions, **Test as** (segmented: **Button** /
**Card updated** — sets `ctx.trigger.as`), the action's params form; `PrimaryButton` **Run test**
(spinner while running; disabled with "Allow the module to test it" before consent). Result block:
status line ("Would change 1 card · 38 ms" / "No changes" / "Failed: TypeError: …"), plan rows
read-only (PlanCard row style, no checkboxes), then collapsible **Calls (3)** and **Console (2)**
lists in mono.

## 3. Automation editor

Side sheet (wide) / full-screen (phone). Title **New automation** / **Edit automation**.

1. **Name** — `MorkvaTextField`, prefilled "<action label> on <collection>" until edited.
2. **When** — five radio cards in a 2-column grid (1 column on phone), each icon + title + hint:
   - **Button on a card** — "Shows in the card's header."
   - **Button on a collection** — "Shows in the collection's Actions menu."
   - **When a card is created**
   - **When a card is updated**
   - **When a card is deleted**
3. **In** — collection dropdown (glyph + name). Collections the module isn't allowed in are listed
   disabled with "Not allowed for this module · Change access" (link to module details).
4. **If** (events only) — the filter chips of the views toolbar + dashed **+ Condition** opening
   the `FilterBuilder` popover for this collection. Chips read "Status is Shipped", "Qty < 5".
   Relative conditions written by Ask Morkva show as read-only chips ("Due · today") with ✕ only.
   A condition reading a collection the module isn't allowed in is refused inline: "This condition
   reads Clients, which the module isn't allowed in."
   For **updated** two more controls:
   - **Only when these fields change** — optional multi-select chips of the collection's fields;
     hint "Leave empty to react to any change."
   - **Run** — radio **Once, when the card starts matching** (default; hint "Won't run again
     while it keeps matching.") / **Every time it's updated and matches**.
   Help line (muted): "Runs on the device where the change is made, while Morkva is open there.
   Offline changes run when they sync. Calculated values don't trigger on their own."
   **Last checked** line (existing automations, muted): "#1042 · 12:04 · 'Status is Shipped' was
   false after the change → didn't run" (the latest of the in-memory last checks).
5. **Do** — **Module** dropdown → **Action** dropdown (only actions whose scope fits the "When":
   card buttons and events need `card`/`any`, collection buttons `collection`/`any`; others listed
   disabled with "Runs on a collection"). Then the action's inputs: `format: field` → field
   dropdown of the chosen collection; `format: collection` → collection dropdown; enum → dropdown;
   boolean → switch; number/integer → number field; string → text field. Required inputs marked.
6. **Button** (button kinds) — **Label** (default = the action label cut to 24 chars with "…";
   ≤ 24), **Icon** (grid of the collection icons, 6 per row), **Color** (the 8 collection tints as
   28 px swatches, each with a 44 px hit area), a live preview of the button as it will look in the
   card header.
7. **Apply** — radio:
   - **Ask first** (default) — "You review each change in a preview."
     For events: "Each card waits in Needs review."
   - **Apply automatically** — "Small card creates and edits apply without asking. Bigger changes,
     deletes and structure changes still wait." Disabled with a visible reason line + link when not
     allowed: "Turn on auto-apply for this module first" (→ module details) or "This module can
     delete or change structure, so it always asks."
8. **Enabled** — switch, default on.
9. **Advanced** (collapsed disclosure) — **Collections it may touch**: "Same as the module's access"
   (default) or a checklist limited to the module's allowed collections (the automation's
   narrowing scope).

Footer: **Delete** (existing; `MorkvaConfirmDialog` "Delete "Stamp when shipped"?" — "Its button
disappears. Run history stays.") · **Cancel** · `PrimaryButton` **Save**.

Validation (inline, error tone, on Save): "Give it a name", "Pick an action", "This action runs on
a collection — use a collection button", "Fill in Date field", "The module isn't allowed in
Orders", "Add at least one condition or pick fields to watch" (updated with neither — prevents
firing on every edit; a checkbox "Run on any change" overrides it).

Broken banner (top of the editor when `pausedReason == broken`): error tone — "**This automation
is paused.** The condition uses "Status", which was deleted." Fixing and saving clears it.
Loop banner: amber — "**Paused: it ran 31 times in a minute**, which looks like a loop (it may be
changing the cards it watches)." `SecondaryButton` **Resume**. Crash banner: amber — "**Paused:
Morkva stopped while this ran** (probably out of memory)." **Resume**.

## 4. Action buttons

### Card editor, wide (`object_editor.dart:456` `_Header`)

On the **title row**, between the title block and Close, in the automation's order. The buttons
take at most **45%** of the header width; labels ellipsize at 16 chars (full label in the tooltip);
whatever doesn't fit goes into **More ▾** (menu with the rest); below 560 px header width buttons
are icon-only with tooltips. Button: 36 px visual / 44 px hit, `Radii.md`, tint background
(collection tint pair), icon 18 + label (labelLarge). Tooltip: the action description.

States:
- **Idle**.
- **Unsaved form / new card** — normal look with a small dot; a press opens a menu anchored to the
  button: **Save and run** (`PrimaryButton` style row; saves without closing the editor, then runs
  on the saved card) · **Cancel**. Copy under the first row: "The action works on the saved card."
  If the save fails, the editor shows its usual save error and nothing runs.
- **Needs consent** — amber dot on the icon; tap opens the consent sheet.
- **Queued** — clock icon, label "Queued · 3 ahead"; long-press (or the More ▾ row's ⋯) →
  **Stop**.
- **Running** — 14 px spinner replaces the icon, label "Running…"; progress `n/N` when the module
  reports progress or the commit emits progress events; long-press / ⋯ → **Stop**.
- **Waiting for review** — amber dot, label unchanged; tap reopens the review sheet.
- **Last run failed** — error dot; tap opens the run detail (until the next run).
- A press while a run of the same (automation, card) is queued, running or awaiting review does not
  start a second run; it focuses that run (reopens the review sheet, or shows the running state).
- On finish (Ask): the review sheet opens **above** the card editor (section 6) — only if this
  editor is still the top route; otherwise the Needs-review indicator and the snackbar
  "Mark shipped needs your review · Review" take over.
- On finish (Auto / no changes / failure / timed out / stopped): an **in-editor banner** (the
  editor's `_Banners` slot, `object_editor.dart:604-674`) — never a shell snackbar while the editor
  is open (it would sit under the editor's scrim):
  - "Mark shipped · 1 order updated" + **Undo** + **View run**
  - "Mark shipped · No changes" + **View run**
  - "Mark shipped failed — TypeError in module" + **View run**
  - "Mark shipped was stopped. Nothing was changed."
  - when the run produced exactly one link: + **Open #1042**.

### Card editor, phone (`object_editor.dart:389-418` AppBar)

`IconActionButton` ⚡ left of **Save** (only when the card's collection has card buttons). While
any run for this card is queued, running or applying, the ⚡ shows a spinner ring with `n/N` and a
2 px `LinearProgressIndicator` runs under the AppBar. Tap → bottom sheet **Actions**: rows (icon on
tint, label, module name muted); with an unsaved form a row shows "Save and run" as its subtitle and
saves first; a running row shows a spinner and **Stop**. Selecting a row closes the sheet and runs;
results use the in-editor banner.

### Collection header Actions menu

Wide (`collection_views_page.dart:687` `_WideHeader`): `SecondaryButton` (bolt) **Actions ▾** left
of **Customize**; icon-only with tooltip **Actions** when `narrow` (< 720 content,
`collection_views_page.dart:54`). Menu:
- one item per collection button: label + muted "Runs on 23 shown cards" (the current view's
  count; "Runs on all 23 cards" without filters);
- divider; **Automations for Orders…** (→ `/automations?tab=automations&collection=<id>`);
  **New automation…** (editor prefilled with this collection).
Phone (`_PhoneFrame` More menu, `collection_views_page.dart:817`): **Run action…** (sheet like
the card ⚡ sheet) and **Automations…**, above "Customize collection".
A run from the menu shows its spinner on a header pill "Running Flag low stock…" until finished.

## 5. Run indicator

One `RunIndicator` widget family, fed by `AutomationRunsCubit`. Primary state priority:
**running** > **needs review** > **attention** (failed or didn't run) > idle. While running, a
needs-review count shows as a **second amber badge** next to the running pill, so reviews are never
hidden by a steady trickle of runs.

| State | Sidebar row "Automations" (≥ 1240) | Rail button (840–1239) | Phone indicator (< 840, icon-only 44 px) |
|---|---|---|---|
| idle | no pill | bolt, no badge | hidden |
| running N (incl. queued) | pill `info` spinner 12 px + "Running · 2" (+ amber "2" badge when reviews wait) | spinner ring around the bolt; tooltip "Automations · 2 running" | bolt with spinner ring |
| needs review N | amber pill "2 need review" (`warningContainer` / `onWarningContainer`) | count badge `warningContainer` / `onWarningContainer` | bolt with amber count badge |
| attention (unseen failed or didn't-run runs) | `warning` dot + pill "1 automation didn't run" / "1 failed" (`errorContainer` for failed) | dot | bolt with dot |
| reviews expired (once, after a reload) | pill "2 reviews expired · View" (muted) | dot | bolt with dot |
| engine unavailable (only when ≥ 1 automation is enabled) | `warning` dot; tooltip "Automations can't run on this device" | `warning` dot | bolt with `warning` dot |

- "Didn't run" covers the actionable skips: `not_settled`, `needs_consent`, `broken`, `crashed`,
  `fan_out`, `queue_full`, `depth_limit`, `review_backlog`, `not_permitted`. Attention is "unseen"
  until the Runs tab is opened.
- Tap anywhere on it → `/automations?tab=runs` (needs review → `&filter=review`; attention →
  `&filter=failed`).
- Where the shell header is off, the phone indicator also mounts:
  - in the collection `_PhoneFrame` AppBar (`collection_views_page.dart:805-834`) — it **takes the
    sync pill's slot while not idle**, and the sync state moves into its tooltip (the AppBar already
    holds Ask, the sync pill, tune and More);
  - in the `/assistant` AppBar (`app_router.dart:164-166`).
  The phone card editor uses the ⚡ ring instead (section 4).
- Live region announcements (polite, once per change): "2 automations running", "Stamp when
  shipped needs your review", "Stamp shipped date failed", "1 automation didn't run".
- Auto budget hit: the pill adds "Auto-apply paused for 10 min" (amber) and a snackbar explains
  "Too many automatic changes — the next ones wait for your review."

### Finish snackbar (`persist: false`, 5 s, the `_notify` pattern; never while the card editor is open)

Event-run snackbars **never replace** a visible snackbar that has an action (the view's own
"Moved to Shipped · Undo"): they wait in the `ScaffoldMessenger` queue until it closes. The view's
Undo reverts only the user's own change; the automation's change has its own Undo below.

| Situation | Text | Action |
|---|---|---|
| Button run applied (Auto) or approved | "Mark shipped · 1 order updated" (button label; or the module's summary: "Mark shipped · Stamped #1042") — tapping the text opens the run | **Undo** |
| Event runs applied | coalesced within 2 s: "Stamp when shipped ran on 3 cards" (automation name) | **Undo** (all of them) |
| No changes | "Mark shipped · No changes" | **View run** |
| Needs review (event) | "Stamp when shipped needs your review" | **Review** |
| Review dismissed | "Saved for review" | **Review** |
| Failed | "Mark shipped failed — TypeError in module" | **View run** |
| Timed out | "Mark shipped timed out after 20 s" | **View run** |
| Stopped | "Mark shipped was stopped. Nothing was changed." | — |
| Offline at apply | "Couldn't apply — you're offline" | **Run again** |
| Engine unavailable | "Automations can't run on this device" | **View run** |
| Loop breaker | "Stamp when shipped was paused — it looks like a loop" | **Open** |
| Broken by a schema change | "Stamp when shipped was paused — "Status" was deleted" | **Edit** |
| One link produced | "… · Open #1042" | **Open #1042** |
| Undo | "Reverted 1 order" | — |

## 6. Review sheet

Dialog (wide) / bottom sheet (phone). Over the card editor it uses a **transparent barrier** (the
editor's scrim already darkens the page). Contains:
- Header line (labelMedium, muted): **Module · Stamp shipped date (stamp-shipped-date) · Stamp when
  shipped** (module name and id · automation name; test runs never get here). The PlanCard keeps
  its own "Proposed changes" heading; the header line does not repeat "Proposed".
- Context line: "Button pressed on #1042 · 12:04" or "Because Status changed to Shipped on #1042".
- The assistant `PlanCard` unchanged (selection, diff rows, Approve N / Reject, destructive
  variant for deletes, progress bar "Updating 120 of 200…" while applying).
- **Dismiss** (scrim, back, swipe down) = decide later: the run stays in Needs review; snackbar
  "Saved for review · Review".
- After approve: the sheet closes on success and the finish snackbar (or in-editor banner) shows
  with **Undo**; on partial failure the `AppliedCard` "Updated 190, 10 failed · Retry failed" stays
  in the sheet.
- Approve refused because the module's access or code changed since the preview: "This module's
  permissions changed — run it again." **Run again**.
- Stale / nothing applied: "The card changed since this preview — Run again." **Run again** (the
  PlanCard's Rebuild maps here).
- Held by another tab: "This review was replaced in another window." (approve refused).
- Expired (opened after a reload): the PlanCard area is replaced by a muted card — "**This review
  expired.** Previews are kept only while Morkva is open. Run it again to get a fresh preview on
  the current data." `PrimaryButton` **Run again**.
- Several waiting: after approve or reject the sheet offers **Next review (49 left)** (oldest
  first) instead of closing.

## 7. Run detail

Route `/automations/runs/:id` (a separate page at every width; keyed per id). Header: status badge +
**Stamp when shipped** (headlineSmall); subtitle "Stamp shipped date v1.0.0 › Stamp · Ask first · on
web · 12 Nov 12:04 · 412 ms". Actions row: **Undo** (when available), **Run again on #1042**,
**Stop** (running), **Open card**, **Edit automation**, overflow **Copy log** (JSON).

Timeline (vertical rule with dots, each step a `SurfaceCard` section, collapsible):
1. **Trigger** — "Status changed Packed → Shipped on #1042 · by you" / "Button pressed on #1042" /
   "Button pressed on Orders · 23 cards" / "Changed offline 11:40 · ran 12:04". Chain breadcrumb
   when depth > 1: "You edited #1042 → Stamp when shipped → **Notify team** (this run)"; each
   earlier step links to its run. Below: the evaluation line in muted mono "matched: before=false
   after=true · changed: Status".
2. **Inputs** — params as label: value rows.
3. **Calls (3)** — rows "cards.get · #1042 · 4 ms ✓", "cards.update · planned 1 change · 6 ms ✓";
   refused calls in error tone with the code ("not_permitted — Collection not available to this
   module"); `no_change` calls muted: "cards.update · Already up to date".
4. **Console (2)** — mono lines (plain text), level color (warn amber, error red), "+12 lines
   dropped".
5. **Plan** — read-only rows as in the PlanCard ("#1042 · Shipped on: — → 12 Nov"); a muted line
   when it went to review instead of Auto: "Asked first: 23 cards is more than auto-apply allows."
6. **Links** — "Open #1042" chips from `ui.open` (navigate only on tap).
7. **Outcome** — "Applied 1 change" + `SecondaryButton` **Undo · 9 min left** (countdown) →
   "Undo expired" (muted) → after undo "Reverted · 12:09"; after a reload "Undo isn't available
   after a reload" (muted). Partial: "Updated 190, 10 failed" + **Retry failed**. Failure: error
   card with code, message and stack (mono, **Copy**). Skipped: the reason sentence and what to do
   (section 9). Outcome unknown: "Interrupted — may be partly applied, check #1042" (no Run again).

## 8. Test run, empty and error states (summary)

- Test run: section 2 "Test run sheet".
- Empty states: Modules, Automations, Runs (section 1); module with no automations: "No automations
  use it yet." + **New automation**; card with no card buttons: no ⚡, nothing shown.
- **Engine unavailable** (web probe failed or QuickJS lib missing): `warning` banner on the
  Automations page and module details (section 2); buttons stay enabled, a press ends in the
  snackbar + a skipped run.
- **Timed out**: run row reason "Timed out after 20 s"; detail outcome "The action took longer
  than 20 s and was stopped. Nothing was changed."
- **Offline**: Auto/approve at apply → "Couldn't apply — you're offline" + **Run again**; import
  and editor saves work offline (Firestore queues them), no special state.
- **Module error**: "The module failed: TypeError: Cannot read properties of undefined (reading
  'values') · at morkva-module/stamp-shipped-date.js:12:7".

## 9. Status and reason codes (plain words)

| Code | Row text | Detail sentence | What to do |
|---|---|---|---|
| `needs_consent` | Needs consent | The module changed or isn't allowed yet. | **Review permissions** |
| `broken` | Automation broken | Its condition, action or collection no longer fits. | **Edit automation** |
| `crashed` | Stopped after a crash | Morkva stopped while this ran, probably out of memory. | **Resume** on the automation |
| `paused` / `loop_suspected` | Paused | It was paused (by you, or because it looked like a loop). | **Resume** |
| `engine_unavailable` | Can't run here | The secure sandbox can't start on this device. | Run it from another device or browser |
| `not_settled` | Card didn't update in time | The change hadn't reached Morkva within 5 s, so it wasn't checked. | **Run again** |
| `not_permitted` | Not allowed | A change touched a collection this module isn't allowed in. | **Change access** |
| `loop` | Would loop | This automation already ran in this chain. | Change its conditions |
| `depth_limit` | Chain too long | Automations triggered each other 3 levels deep; Morkva stopped here. | Change the automations' conditions |
| `fan_out` | Too many cards at once | Only the first 100 cards of one change are processed. | Split the change into smaller batches |
| `queue_full` | Too busy | Too many runs were waiting. | **Run again** later |
| `review_backlog` | Too many waiting reviews | 50 reviews are already waiting. | Review or reject the waiting ones |
| `card_gone` | Card was deleted | The card no longer exists. | — |
| `cancelled` | Stopped | Stopped by you. Nothing was changed. | **Run again** |
| `load_error` / `boot_error` / `load_timeout` | Module didn't start | The module's code has an error or took too long to load. | Ask Morkva to fix it, or import a fixed file |
| `module_error` | Module failed | (message + stack) | Ask Morkva to fix it |
| `plan_refused` | Change refused | A change the module asked for wasn't allowed — see Calls. | Check Calls; **Change access** if needed |
| `limit_exceeded` | Too much work | The module asked for more than one run may do (calls, data or time). | Run it on fewer cards |
| `timed_out` | Timed out after N s | The action took too long and was stopped. Nothing was changed. | **Run again** |
| `abuse` | Stopped | The module sent too many or too large messages. | Ask Morkva to fix it |
| `offline` | Offline | Couldn't apply without a connection. | **Run again** when online |
| `not_applied` | Nothing applied | None of the changes could be applied — see the plan. | **Run again** |
| `interrupted` | Outcome unknown | Morkva was closed while applying — it may be partly applied. | Check the card |
| `rejected` | Rejected | You rejected the preview (or the module was removed or changed). | — |
| `expired` | Expired | The preview was kept only while Morkva was open. | **Run again** |
| `internal` | Something went wrong | Morkva hit an unexpected error. | **Run again**; copy the log if it repeats |

Tone: failure codes use the error tone; skip codes are muted; `no_change` is never shown as an
error ("Already up to date", muted).

## 10. Assistant preview (module install)

In the chat, an assistant `modules.save` plan renders the PlanCard **shield variant** (H14):
header icon shield on `primaryContainer`, title **Install "Stamp shipped date"** (or **Update
"Stamp shipped date"**), subtitle "Approving installs this module and lets it use these
permissions. Auto-apply stays off." (on an update whose module had auto-apply on: "Auto-apply turns
off for the new version. Turn it on again in module details."); rows = permission `DiffLine`s with
the `kCapabilityCopy` titles ("Create and change cards → Orders"), "Actions → Stamp (on a card)",
"Code → 2.1 KB" with a **View code** link; an `automations.save` row in the same plan shows "When a
card is updated in Orders · Status starts matching Shipped → Stamp", plus "Applies changes without
asking" when it uses Auto. Approve label **Install module** / **Update module** (single module item)
/ **Approve N changes**.

A `modules.testRun` result renders a read-only **Test run** card in the thread: the Test-run
sheet's result block (status line, plan rows, **Calls**, **Console**) — the user sees the same dry
run the assistant reads.

## 11. Dark mode

Espresso surfaces (canvas and raised surface tokens), cream ink; the tab underline and primary
buttons use `carrotBright`; status chips use the dark semantic containers; the code viewer uses the
sunk surface token with `onSurfaceVariant` line numbers; the review PlanCard keeps its 2 px
`primary` border (destructive: `error`). No shadows for depth — surface steps only.

## 12. Accessibility

- Every interactive target ≥ 44 × 44 (colour swatches included); tab order follows reading order;
  the editor's radio cards are a `RadioGroup` with arrow-key movement.
- The run indicator and button states are announced politely once per change (never per
  progress tick).
- Status is never color-only: chips carry text, the rail badge has a tooltip and semantics label
  ("Automations, 2 need review").
- Disabled controls show their reason as **visible text** (tooltips don't show on touch) and as a
  semantics hint ("Allow this module first", "Needs a connection").
- Monospace blocks are selectable; Copy buttons have labels.

## Artboards (Claude Design)

| # | Name | Size | Shows |
|---|---|---|---|
| 1 | Modules | 1440 × 900 | Sidebar 272 with "Automations" selected and an idle row; Modules tab: 3 module cards (Installed, Needs consent, Made by Ask Morkva), Import module |
| 2 | ModuleDetails | 1440 × 900 | Module details: header with "Author: … (from the file)", "What it can do" rows with collections + Change access / Revoke, Auto-apply switch with help, Actions with Test run, Code section, recent runs |
| 3 | Consent | 1440 × 900 | Consent sheet over module details for an import: Actions + View code, Where with nothing preselected and Allow disabled |
| 4 | Reconsent | 1440 × 900 | "This module changed" banner + consent sheet with **New** permission tag, struck removed one, "v1.0.0 → v1.1.0 · 2.1 KB → 2.4 KB" and the auto-apply-off line |
| 5 | Editor | 1440 × 900 | Automations tab behind; editor side sheet for "When a card is updated": conditions chips, fields-watch chips, Once/Every radio, Last checked line, Do with a field-picker input, Apply with "Apply automatically" disabled + reason, collapsed Advanced |
| 6 | CardButtons | 1440 × 900 | Wide card editor with 2 action buttons on the title row (one running with n/N, one showing the open **Save and run** menu); an in-editor result banner "Mark shipped · 1 order updated · Undo · View run"; a second state: the review sheet above the editor (transparent barrier) with the "Module · … (id) · …" header and PlanCard |
| 7 | ActionsMenu | 1440 × 900 | Collection page with the **Actions ▾** menu open (2 collection buttons with counts, Automations…, New automation…) and the finish snackbar "Flag low stock · Flagged 4 products · Undo" |
| 8 | RunDetail | 1440 × 900 | Run detail page (full width, no list beside it): chain breadcrumb, calls incl. a muted no_change row, console, plan, Undo countdown |
| 9 | Tablet | 1024 × 768 | Rail 76 with the bolt and an amber "2" badge; Runs tab filtered to Needs review with Review buttons and one "Review not available here" row |
| 10 | Phone | 390 × 844 | Phone card editor with ⚡ in the AppBar and the Actions bottom sheet (one row with "Save and run" subtitle) |
| 11 | PhoneRuns | 390 × 844 | Phone Automations page, Runs tab with the icon-only bolt indicator (spinner ring), a "Running now" row with Stop, and an expired row with Run again |
| 12 | Dark | 1440 × 900 | Dark theme: failed run detail with error stack and the module details code viewer dialog |
| 13 | PhoneRunning | 390 × 844 | Phone card editor while a run is going: ⚡ with spinner ring and "1/3", linear progress under the AppBar, then the in-editor result banner |
