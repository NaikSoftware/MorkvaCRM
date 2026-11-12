# Import from Trello — design

Owner ask (2026-11-13): "implement migrations from other services. First — from Trello. Place it in
settings. Create design using Claude Design. It should ask what to import — which collections and
automations if possible." Built autonomously; every decision below marked *my call* was made without
an approval round-trip (owner preference).

## What Trello can give us (researched 2026-11-13)

- **Board JSON export** (board menu → Print, export, and share → Export as JSON) works on every plan,
  one file per board. It has lists, cards, labels, members, checklists, custom fields, attachments
  (as URLs) and the **1000 most recent actions** (so older comments are cut off). Archived lists and
  cards are included with `closed: true`.
- **REST API** (key + token, CORS open) gives the same data plus all comments, but needs a Trello API
  key with every app origin registered — an owner action. *My call:* ship file import now; "Connect
  Trello account" is a follow-up.
- **Automations (Butler rules, card/board buttons, scheduled commands) are in neither the export nor
  any public API** (Jira TRELLO-1429 open). They cannot be imported. The flow still shows an
  Automations section so the user knows why it is empty, and links to Morkva Automations.
- Uploaded attachment bytes need an OAuth header and Storage is deferred: attachments import as
  links (text), never as files.

## Flow

> Where this section and "UI decisions after design critic round 1" below disagree (copy, the
> automations row, Close while writing, "stalled" wording), the UI decisions and the mockups win.

Settings gets an **Import** section with a "Trello" row ("Boards, lists, cards and checklists").
It opens a sheet with two steps, then an Importing → Done phase with no step counter (`showAutomationSheet`: 560 dialog on wide, full-height bottom sheet on
phone; *my call:* a sheet, not a `/settings/import` route, so the phone back button is not routed to
Home):

1. **Add boards** — "Export each board from Trello as JSON (board menu → Print, export, and share →
   Export as JSON), then add the files here." File / Paste segmented control (as the module import
   sheet). Several files at once; each parsed board shows as a row (board name, lists · cards) with a
   remove button; unreadable files show an inline error row. Continue enabled with ≥ 1 board.
2. **Choose what to import** — per board, a group of **collections** with checkboxes:
   - the board itself → collection "<board name>" (cards count; field chips preview),
   - "<board> · Checklist items" (only when the board has checklists; item count),
   - "<board> · Comments" (only when it has comment actions; count; note that Trello exports keep only
     the newest 1000 actions).
   Child collections need their board ticked. Options: "Include archived cards and lists" (off).
   **Automations** section: an unavailable row "Butler rules and buttons — Trello doesn't include
   them in exports" + "Set up automations" link after import. Footer: "Import N collections".
   Disabled while offline ("You're offline — connect to import").
3. **Importing → Done** — linear progress "Writing cards 450 of 1,200"; done shows one row per
   created collection with "Open"; errors keep the sheet open with Retry (already-written
   collections are listed so a retry is not a silent duplicate — retry re-imports only the failed
   remainder of cards; collections are not re-created).
   - **Stalled:** each slice has a 30 s watchdog (the assistant's precedent). A slice that does not
     ack → "Import stalled — check your connection" with Retry. A timed-out slice may still land, and
     a second create of an existing id becomes an update that the monotonic-rev rule can reject for the
     whole batch, so Retry first reads `getServerObjects` for each collection and skips ids that exist.
   - The sheet is **not dismissible** by scrim tap or drag (`showAutomationSheet(dismissible: false)`);
     its own Close is disabled while writing, so the cubit can't be disposed mid-write.

### UI decisions after design critic round 1 (mockups: Claude Design canvas
https://claude.ai/artifact/VtcEYDWkDHVfygGtoAtwEL, local copies `docs/superpowers/mockups/trello-import/`)

- Settings: a 720 max-width column, section labels "Workspace" (Automations) and "Import from other
  apps" (Trello: "Boards become collections — lists, cards, labels, checklists and comments"); the
  EmptyState placeholder goes. Phone Settings is the same column at full width.
- Sheet: `showAutomationSheet(dismissible: false)` → dialog `barrierDismissible: false`; phone
  `isDismissible: false, enableDrag: false, showDragHandle: false`; body in `PopScope(canPop: !writing)`.
  `SheetHeader` gains an optional `onClose` (Close X); there is no footer Cancel. Default carrot tile.
- Step 1: copy covers Trello opening the JSON in a tab ("save the page as a .json file (Ctrl+S), or
  copy all of it and use Paste"). Files/Paste `SegmentedButton` 44 px tall. Files: multi-file picker.
  Paste: mono field + "Add board" — parses, appends a row, clears the field. Empty list: "No boards
  yet" box; footer hint "Add at least one board", Continue disabled. Parse error: inline error row
  (`Semantics(liveRegion)`), dismissible. The same board again: "Already added" (see Round 2 additions), not a
  second row.
- Step 2 order: neutral automations note first ("Automations can't come along. …"), then the
  archived switch, then Collections. Each board is a bordered group: the board row is the head
  (checkbox, name max 2 lines, "N cards · N lists", field chips = the real mapped fields), children
  indented and titled just "Checklist items" / "Comments". Unticking a board disables its children
  ("· needs the board"). Footer: `PrimaryButton('Import N collections')`; the hint slot is only for
  reasons: "Choose at least one collection", "You're offline — connect to import". Counts follow the
  archived toggle.
- Importing: rows "x of N" per collection; pending = `Icons.schedule`; running = spinner; done = check.
  Stalled/error (desktop mirrors PhoneStalled inside the dialog): warning banner + Close + Retry.
- Round 2 additions: "Already added" shows as a problem-style row in the boards list (Files) and as
  an inline note under the Paste field (Paste). Field chips: compact width (< 840) shows the first 6
  chips + plain text "+N more fields"; wide shows all. Phone uses the desktop strings and the same
  44 px `SheetHeader`. While writing there is no Close; footer hint "Writing — keep this open" next
  to a disabled Done; "Imported cards don't start automations." sits under the progress bar.
  Paused (stall or refused write): warning `AutomationBanner` "Import paused. Morkva couldn't reach
  the server for 30 seconds. Check your connection, then retry — cards already written won't be added
  twice. Closing keeps what's already imported." (a refused write says "Morkva couldn't save some
  cards." instead of the 30-second sentence); paused row marker = warning-container circle with a
  pause glyph; footer Close + Retry. Frame metrics follow `AutomationSheetFrame` (Spacing.md footer,
  outlineVariant divider, Radii.md tile).
- Done: one row per collection with `CollectionGlyph(tintSeed: id)` (icons `cards`/`task`/`note`), Open;
  a note row linking to Automations; Done button.

## Mapping (pure Dart, `lib/core/import/trello/`)

Board collection fields — a field is created only when at least one imported card has a value for it
(*my call*, keeps boards without dates/members clean), except Name and List:

| Trello | Morkva field | type |
|---|---|---|
| card name | Name | text (title) |
| desc | Description | text, multiline (Markdown kept as text) |
| list | List | single_select, options in list `pos` order (archived lists only with the option) |
| labels | Labels | multi_select, colours mapped from Trello colour names; unnamed label → colour name |
| members | Members | multi_select of full names |
| start | Start | date |
| due | Due | date with time |
| dueComplete | Due done | boolean |
| custom fields text/number/date/checkbox/list | same name | text / number / date / boolean / single_select |
| attachments | Attachments | text, multiline, one "name — url" per line |
| shortUrl | Trello link | text |
| closed (only with archived on) | Archived | boolean |

Edge cases (*my call*):
- A card in an archived list counts as archived (with the option off it is skipped; step 2 counts
  follow the toggle).
- A board with no imported lists still gets a List field with one option "No list", so strict
  validation passes and the Board view works.
- Option labels: an unnamed label takes its colour name ("Green"), a colourless unnamed one "Label";
  duplicate labels within a field get " (2)", " (3)"…; blank list names become "Untitled list".
- Checklist items and comments whose card is not imported are dropped.
- Custom-field values parse tolerantly (`"true"`/`true`, numeric strings, a missing item = empty).
- The same board added twice (same id) is kept once.
- Check: the mapper's output passes `validateCollectionSchema(strict: true)` with sibling ids and
  every card passes `validateAgainst`; every reference and `manualOrder` id exists.

Field names are de-duplicated case-insensitively (a custom field "Due" becomes "Due (Trello field)").
Card `createdAt` comes from the Trello id's ObjectId timestamp; `updatedAt` from `dateLastActivity`.

Views: **Board** (board mode, grouped by List, first/default view, `manualOrder` = cards by list pos
then card pos, archived filtered out when imported) and **All** (table).

Checklist items: Item (text), Done (boolean), Checklist (text, the checklist name), Due (date, when
any), Card (reference → board). Shows as a sublist on the board card. Order by card, checklist pos,
item pos. Comments: Comment (multiline text), Author (text), Date (date with time), Card
(reference). Ordered newest first (`sort: @createdAt` descending; createdAt = comment date).

## Writing

`TrelloImportCubit` (features/settings/import): mints all ids up front (`IdGenerator`), then
`saveCollection` for each collection, then `saveObjectsBatch` in slices of 450 with
`WriteOrigin(kind: WriteKind.template)` (no automation triggers, keeps Trello dates) and reports
progress per slice. Start is disabled while `SyncStatusCubit` is offline (a batch queues offline and
would never resolve). No Firestore rule change is needed.

## Out of scope (follow-ups)

Connect Trello account (API key + allowed origins, owner action) for all comments and a board
picker; workspace ZIP export; attachment bytes; re-import de-duplication; other sources (Asana,
Notion, CSV).
