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

Settings gets an **Import** section with a "Trello" row ("Boards, lists, cards and checklists").
It opens a three-step sheet (`showAutomationSheet`: 560 dialog on wide, full-height bottom sheet on
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
