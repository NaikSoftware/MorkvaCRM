# Inbox — design

Owner ask (2026-11-14): "Create design and spec for an Inbox feature. Grill the idea: analyze
competitors. Notifications for me or assigned to a teammate; type notification/task (maybe an icon
is enough); a simple calendar to move between days; link any card of any collection; don't make the
design complex — we already have many functions, maybe turn buttons into icons or a ⋯ menu, or
reorganize; plan local notifications and show them; reminders (15 min before, at time, …); nice,
minimalistic, informative — some will use it as sticky notes, some as task delivery. Then think with
a critic, consolidate into AC and implement. Open a PR. Web now; Android/iOS later." Later: "also
can see how it works in xtiles.app".

Built autonomously (owner preference): every decision marked *my call* was made without an approval
round-trip. Process: competitor research → draft → adversarial critic round (product/UX + technical,
verdicts folded in below) → Claude Design mockups + design critic → build.

## 1. Intent & why

The competitor study (`docs/research/2026-11-13-market-competitors.md` §5) names two strong pains we
don't answer: **#3 "DIY Notion/Airtable CRMs decay — no reminders"** and **#6 "Who needs a follow-up
today?"**; §6 lists reminders as the first real gap. The Inbox is the daily-use surface that brings
people back: one list of things to do or remember, by day, optionally tied to a card ("call this
client", "order #1042 ships Friday"), with a reminder that actually pops up.

Two usage styles must both feel native:
- **Sticky notes** — capture a line fast, no date, no ceremony ("door code 4512", "Iryna prefers
  Viber"). They stay visible every day until deleted.
- **Task delivery** — a dated task with a reminder, linked to a card, (with Epic 10) assigned to a
  teammate.

### Goals
- G1. Capture in one line from the Inbox page (Enter adds); details are optional.
- G2. See any day's items at a glance; move between days with a week strip; overdue tasks never
  disappear silently.
- G3. Link an item to any card of any collection; open the card from the item; add an item from a
  card and see a card's open items from the card.
- G4. Reminders (at start, 15 min, 30 min before, or a custom date/time; morning-of for all-day items) that
  show as a browser notification when Morkva is open but not focused, and as an in-app toast when it
  is focused.
- G5. Team-ready data: items live at workspace level with an assignee and an author, so Epic 10
  (team workspaces) turns on assignment to a teammate with a rules change and a picker, no reshaping.
- G6. One entry per navigation surface; exactly one new header button (the card editor's Inbox
  icon, below); everything else in the Inbox page itself.

### Non-goals (v1)
- **Assigning to a teammate in the UI** — no members exist until Epic 10 (designed, not built).
  The data carries `assigneeUid`; the assignee chip, the picker and a "Mine · Assigned by me" filter
  are drawn in the mockups (team state) and ship with Epic 10.
- Natural-language quick add ("tomorrow 10am"); recurring items; sub-tasks; priorities; labels;
  comments; snooze.
- Push notifications with the tab closed (FCM + Cloud Functions, Blaze) — §8.
- Mobile local notifications (planned in §8, built with the mobile release).
- Reminders generated from card date fields — follow-up that writes Inbox items (§10).
- A month view of items (the month label opens the standard date picker to jump).

### Anti-goals
- An inbox that nags: no permission prompt on page load or without a click; no badge for notes or
  for tasks due after today.
- A second task app bolted on: items stay one line until opened; no fields beyond those below.
- Lost reminders presented as delivered: if a reminder can't fire (no tab open, permission blocked),
  the UI says so instead of implying it will.
- Sticky notes vanishing because a day passed.

## 2. Competitor patterns (grilled)

Full digest with sources: [`2026-11-14-inbox-research.md`](2026-11-14-inbox-research.md) (CRMs:
Pipedrive, HubSpot, Attio, folk, KeyCRM; personal: Todoist, Things, Keep; team: Linear, ClickUp,
Trello; the owner's reference xTiles). What we take, what we leave:

| Pattern | Seen in | Inbox v1 |
|---|---|---|
| Overdue folded into Today, with "Reschedule all" | folk, HubSpot, Todoist, xTiles | ✅ Overdue group on Today + "Move all to today" (undoable) |
| Undated items always visible | Todoist Inbox, xTiles Task List "Inbox" | ✅ the **No date** shelf (xTiles using "Inbox" for two things is the trap) |
| Week strip, dot = has items, month label → picker, back-to-today | Todoist Upcoming, xTiles Planner | ✅ |
| Relative reminder presets incl. minutes, default once a time is set | Trello, HubSpot, Todoist | ✅ xTiles' day-only presets are too coarse for a 14:00 call |
| Date-only items remind in the morning | Pipedrive 09:00, folk 08:00 | ✅ 09:00 |
| Few date presets | Attio, folk, KeyCRM | ✅ Today · Tomorrow · Next Monday · Pick… |
| Create from a record → pre-linked; record shows its tasks | Attio, folk, KeyCRM | ✅ card editor Inbox icon with count |
| Badge = my overdue + due today | Pipedrive | ✅ notes never count |
| Overdue in red with lateness | Attio, xTiles | ✅ "2 d late" |
| Reminder state visible (permission, blocked) | complaint: HubSpot "reminders silently not firing" | ✅ in-context permission ask + honest copy |
| "While you were away" summary | Linear inbox, morning digests | ✅ catch-up toast (≤ 24 h) |
| Accept/decline on assignment | xTiles | ❌ extra state; Epic 10 decides |
| Natural-language quick add | Todoist, TickTick | ❌ follow-up |
| Priorities, labels, projects, recurrence | everyone | ❌ anti-goal |
| Notification centre with tabs | xTiles, Linear | ❌ the Inbox *is* the list |

## 3. Concepts

| Term | Meaning |
|---|---|
| **Item** | One Inbox entry, a **task** or a **note**. |
| **Task** | Round checkbox; can be done; can be overdue. Default date: the selected day. |
| **Note** | The owner's "notification": no checkbox, never overdue, ends with Delete. Default: **No date** (a sticky note); with a date + time + reminder it is a timed notification. |
| **Kind toggle** | The leading icon of the composer/editor; tooltip "Task — switch to note" / "Note — switch to task" (owner: "maybe icon is enough"). Toggling flips the date default unless the user touched the date. |
| **Due** | Optional: a date (all-day) or a date + time. |
| **Reminder** | Up to 3 per item (owner, 2026-11-14). Timed items: "At start", "15 min before", "30 min before". All-day items: "Morning of" (09:00). Any item with a date: "Pick date & time…" sets a custom reminder (date picker, then time picker). Presets follow the due moment when it moves; a custom reminder keeps the date/time picked. Setting a time adds "At start" by default (removable); switching timed ↔ all-day drops the other kind's presets. |
| **Link** | Optional reference to one card: `{collectionId, cardId, label}` (card ids are unique only within their collection; `label` is a snapshot for display). |
| **Assignee** | `assigneeUid`, defaults to me. Not editable until Epic 10. |

### Day rules (all local time)
- **Day of an item:** all-day → the UTC date parts of `dueAt` (stored as UTC midnight of the
  calendar date; never `toLocal`); timed → the `toLocal()` date.
- **Overdue:** open **tasks** whose day is before today. A timed task earlier today stays in today's
  section with its time in the error colour.
- **Lateness:** "N d late" = calendar days between its day and today.
- **No date:** undated items (tasks and notes) — shown under every day.
- **Completed (on day D):** done tasks whose `doneAt.toLocal()` date is D (covers undated and
  overdue tasks finished that day).
- **"Next Monday" on a Monday** = +7 days.
- **Badge** = my open tasks that are overdue or due today.

## 4. UX

### Navigation
- **Wide sidebar:** "Inbox" row **above** "All collections"; trailing count pill = badge (hidden at
  0).
- **Rail (840–1240):** Inbox rail button with the badge.
- **Phone bottom bar:** `Inbox · pin1 · pin2 · pin3 · All` (5 destinations, the M3 maximum), badge on
  Inbox. The bar now also shows with zero pins (`Inbox · All`) and on `/inbox`, alongside the
  existing All/pinned-tab cases. Long pin labels truncate at 360 px.
- Route `/inbox` (`?day=yyyy-MM-dd`, `?item=<id>` opens that item's editor).

### Inbox page
Wide: the Automations frame (page draws its own `headlineSmall` title), content column max 760.

```
Inbox
November 2026 ▾                                    ‹   Today   ›
 Mon 9  Tue 10  Wed 11  Thu 12  Fri 13  [Sat 14]  Sun 15
   ·              ··                       ●
┌─────────────────────────────────────────────────────────────────┐
│ ○  Add a task for today…                                         │
│    [📅 Sat 14 ×] [🕘] [🔔] [🔗]                          (on focus)│
└─────────────────────────────────────────────────────────────────┘
OVERDUE · 2                                         Move all to today
 ○  Call Iryna about the fabric        2 d late    ▣ Orders · #1042
TODAY · 3
 ○  09:30  Pay the Textile Co invoice   🔔 15 min   ▣ Suppliers · Textile Co
 ◧  11:00  Courier comes at 11          🔔 at time
 ○         Prepare samples
NO DATE · 4
 ◧  Door code 4512
 ○  Ask Max for the new price list
Completed · 2 ▸
```

- **Week strip:** Mon–Sun; the selected day filled carrot, today ringed; up to 3 dots under days with
  open items. `‹ ›` move a week; "Today" jumps back (disabled when the selected day is today).
  "November 2026 ▾" opens Material `showDatePicker` in `MondayFirst` (as `calendar_agenda.dart`).
  Phone: swipe moves a week. Reuse `calendar_common.dart` helpers and the `_StripDay` look.
- **Composer:** one input; the leading icon toggles task/note. Placeholder names what will be made
  ("Add a task for today…", "Add a task for Fri 13…" on another day, "Add a note…"). Enter adds and keeps focus. On focus a row of
  **icon-only** chips appears: date (task: the selected day; note: empty = No date), time, reminder,
  link; a chip shows its value once set ("Sat 14", "10:00", "15 min", "Orders · #1042"); × clears.
  *my call:* icons, not labelled buttons (owner: "transform button to icon").
- **Sections:** Overdue (only when the selected day is today) · the day ("Today" / "Sat 14";
  timed by time, then all-day by creation) · No date (newest first; collapsible) · Completed
  (collapsed; count in the header).
- **Row anatomy (≤ 2 lines):** leading control (task: round checkbox; note: tinted note glyph) ·
  time (tabular; timed only; error colour when past and open) · title (1 line, ellipsis) · meta:
  "2 d late" (overdue), bell + first reminder ("15 min", "+1" if more), link chip (collection icon +
  "Collection · label"; tap opens the card). Tap elsewhere opens the editor. No row ⋯ menu
  (*critic*: the editor already has date presets and Delete).
- **Done:** the checkbox animates, the row moves to Completed, snackbar "Done · Undo". Unchecking in
  Completed reopens it.
- **Move all to today:** sets every overdue task's day to today (keeping times); snackbar
  "Moved N tasks to today · Undo".
- **Empty states:** day empty → a quiet line "Nothing for Sat 14" in the day section; no items at all
  → `EmptyState` "Jot down notes, plan tasks and get reminded. Link anything to a card."
- **Loading / error:** spinner; load failure → error line + Retry (every listener has `onError`).

### Item editor
Dialog (480 wide, card-editor dialog look: paper fill, radius 28, level3 shadow) on wide;
full-height bottom sheet on phone (root navigator).

```
[○|◧]  Title…………………………………………                              ×
Details (optional)
📅  Sat 14 Nov · 10:00     [Today] [Tomorrow] [Next Mon] [Pick…]   [🕘 time ×]
🔔  At start × · 15 min ×   [+]      ← Turn on notifications · first time only
🔗  Orders · #1042 ×       or  "Link a card"
🗑 Delete                                                      [Save]
```
- Rows are quiet (icon + value); an empty row's muted placeholder is its button.
- Reminder row disabled with "Set a date to add reminders" for undated items. Under it one quiet
  line, whose text depends on the browser permission:
  - `default` → "Reminders pop up while Morkva is open. **Turn on notifications** to see them in
    other tabs too." (the link calls `Notification.requestPermission()` — the only place we ask);
  - `granted` → "Reminders pop up while Morkva is open in a tab.";
  - `denied` → "Notifications are blocked for this site — reminders show only inside Morkva.";
  - unsupported → nothing.
- Save writes only the fields that changed (`update`), so a `done` set from a toast or another
  device survives an open editor. Delete → closes, snackbar "Deleted · Undo".
- Escape / × with unsaved changes → the existing "Discard changes?" confirm.

### Link a card
Two steps, *critic* (no cross-collection index exists; scanning every collection costs reads):
a collection list (icon + name, search field) → that collection's `ReferencePicker`-style card
list with search. Choosing stores `{collectionId, cardId, label}`. The chip opens the card
(`collectionLink(cid, card: id)`); a deleted collection shows the chip as "Collection deleted";
a card that no longer exists is detected on tap ("Card deleted" snackbar, the chip turns muted).

### From a card
The card editor header gets **one** `IconActionButton` (Inbox glyph) before Close, hidden while
creating a card; a small count badge = open items linked to this card (from the app-wide stream).
- 0 items → opens the item editor pre-linked (task, no date).
- ≥ 1 → a menu: the items (kind icon, title, day) → opens that item's editor; divider; "Add to
  Inbox…".
- *my call / critic:* not a ⋯ menu — the header already has `CardActions`' own "More" overflow,
  and Delete stays where it is (moving it churns tests for no user gain).

### Reminders: delivery on web
- **ReminderScheduler** (pure Dart over an injected clock, attention source and key-value store)
  runs while signed in. It ticks every 20 s and immediately on `visibilitychange`, `focus` and any
  inbox change (background tabs throttle timers; sleep delays them).
- **High-water mark:** `localStorage['morkva.reminders.lastTickAt']`, shared by all tabs. A tick
  fires every reminder whose fire time is in `(lastTickAt, now]` (window capped at 24 h), then writes
  `now`. First run in a browser (no mark) sets the mark and fires nothing. Reminders of done tasks
  never fire; a time edited into the past doesn't fire. *shortcut:* no Web Lock around
  read-window-write; two tabs ticking at once may fire twice — the system notification `tag` and the
  pending-toast key make that invisible; add `navigator.locks` if duplicates show up.
- **On fire:**
  - window focused (`document.hasFocus()`) → add a **pending toast**;
  - not focused → a browser `Notification` (title; body "10:00 · Orders · #1042"; `tag` =
    `itemId@fireMillis`) if permission is `granted` — then **no** toast; without permission → a
    pending toast (seen when the user comes back).
- **Pending toasts** live in `localStorage['morkva.reminders.pending']` (keys `itemId@fireMillis`);
  every tab renders the same list and listens to `storage` events, so closing a toast in one tab
  closes it everywhere. A toast renders from the **live item** (title/time update; it disappears when
  the item is done, deleted or its due time changes).
- **Catch-up:** a window longer than 2 min (the app was closed or the machine slept) puts its
  reminders into one grouped toast "3 reminders while you were away" listing them (tap → item); no
  system notifications for those.
- **Toast UI:** top-right on wide, top on phone, max 3 stacked + "+N more": kind icon, title,
  time, link chip; actions **Done** (tasks) · **Open** · ×.
- **Notification click:** `window.focus()`, navigate to `/inbox?item=<id>`, `close()`.
- **Web notifier failures** (`new Notification` throws on Chrome Android, unsupported browser) →
  fall back to a pending toast.

### Decisions after design critic round 1
Mockups: Claude Design canvas https://claude.ai/artifact/5CRWtUY879wwWW71a4RK6x, local copies
`docs/superpowers/mockups/inbox/` (11 artboards). Critic verdict: accept with fixes.
- **Toasts anchor bottom-right on wide** (*my call*): a stack top-right covered the strip's ‹ Today ›
  and "Move all to today"; snackbars stay bottom-centre. Phone: top. Toast leading tile = kind glyph
  (a hollow circle read as a second checkbox).
- **Selected day is the target** (owner, 2026-11-14, replacing "a past day defaults to today"):
  the composer's task date is the selected day, past days included; placeholder "Add a task for
  today…" when that day is today, else "Add a task for Tue 10…".
- **Phone composer chips wrap** to a second line.
- **Editor date row** shows the date only ("Sat 14 Nov"); the time lives in its own chip.
- **Collapse chevrons** sit left of the section caption for both No date and Completed.
- **Badges** are carrot (primary / onPrimary) everywhere, never error red (red means lateness).
- **Week strip** is a new widget (cells 48×56, phone 44×56, radius 12; selected = primary fill;
  today = 2 px inset primary ring; ≤ 3 dots of 4 px), not `_StripDay`.

### Build & verification notes (2026-11-14)
- Independent code review (9 findings) fixed: `?item` leaves the URL when its editor closes (a second
  notification click reopens), the reminder mark only advances on server snapshots (not cache), fire
  times earlier than the item's last edit never fire, deep link waits for the server list, picker
  load error + Retry, `dueAt` rewritten only when date/time changed (DST), `?day` clamped to ±10 years,
  link label capped at 200, localStorage write failure falls back to memory.
- Owner-reported focus bug ("clicked outside input, it starts input"): a composer that lost focus
  without its own unfocus stayed its scope's last focus, so disposing a tapped toast button handed
  focus back; pickers also re-requested focus. Fixed and re-verified on a release build.
- Design critic round 2 (app vs mockups): pass with fixes, all applied (field padding, card menu
  style, picker hugs content, title styles, 44 px clear targets, empty-day fill, sheet peek, empty
  state width, toast button alignment). Mockup updates owed (app is the agreed design): doodle
  background behind the page, catch-up rows show "Today · 03:44", Ukrainian presets wrap to two rows
  on phone, toasts dim under a dialog scrim.
- Web e2e (release build, Firestore emulator with this branch's rules, notification permission
  granted over CDP, `Notification` replaced by a recorder): composer task/note, badge + dots, unfocused
  reminder → one notification (tag `itemId@fireMillis`, body "03:44 · Olena") and no toast, focused →
  toast, Done completes, catch-up toast, editor save writes only changed fields, two-step link picker,
  card editor Inbox button + menu, Move all to today + Undo, phone 390 en/uk.
- Known: phone bar pin labels wrap to two lines with 5 destinations (long collection names); the
  Hanken weights render a step lighter than mockup CSS app-wide (font files check — not Inbox-specific).

## 5. Data model

`workspaces/{wid}/inbox/{itemId}` — *critic over my first draft* (`members/{uid}/inbox`): Epic 10's
rules keep `members/{uid}/*` strictly private (allow-listed by name and depth), the assigner must be
able to track and reassign, and an admin must still see a removed member's tasks. Needs one rules
deploy (owner action); e2e runs on the Firestore emulator with this branch's rules.

| Field | Type | Notes |
|---|---|---|
| `kind` | `'task' \| 'note'` | |
| `title` | string 1..500 | trimmed |
| `details` | string ≤ 5000 | optional |
| `dueAt` | Timestamp? | timed: the instant; all-day: UTC midnight of the calendar date |
| `allDay` | bool | |
| `reminders` | int[] ≤ 3 | wall-clock minutes before the due moment (all-day: before local midnight; negative = after). Presets: timed 0, 15, 30; all-day `-540` (09:00 that day). Any other value is a custom date/time. |
| `link` | `{collectionId, cardId, label}`? | label ≤ 200 |
| `assigneeUid` | string | = `createdBy` in v1 |
| `createdBy` | string | |
| `done` / `doneAt` | bool / Timestamp? | tasks only |
| `createdAt` / `updatedAt` | Timestamp | client time |

- Query: `where('assigneeUid', isEqualTo: me)` (single-field, no composite index). Epic 10 adds a
  `createdBy == me` listener for "Assigned by me". *shortcut:* the whole inbox is streamed; add a
  `doneAt` window when it grows past a few thousand items.
- Writes fire without awaiting the server ack (offline must just work) but every write has a
  `catchError` that shows a snackbar ("Couldn't save — …") — a rejected write is otherwise silently
  rolled back.
- Edits are field `update`s; create is `set`.
- Rule (shape-checked):
  ```
  match /inbox/{itemId} {
    allow read: if isWorkspaceOwner(workspaceId)
        && (resource.data.assigneeUid == request.auth.uid || resource.data.createdBy == request.auth.uid);
    allow create: if isWorkspaceOwner(workspaceId) && inboxShapeOk(request.resource.data)
        && request.resource.data.createdBy == request.auth.uid;
    allow update: if isWorkspaceOwner(workspaceId) && inboxShapeOk(request.resource.data)
        && request.resource.data.createdBy == resource.data.createdBy;
    allow delete: if isWorkspaceOwner(workspaceId);
  }
  ```
  `inboxShapeOk`: kind in [task, note]; title string 1..500; details absent or string ≤ 5000;
  reminders list size ≤ 3; assigneeUid/createdBy strings. Epic 10 replaces `isWorkspaceOwner` with
  its member check — add `inbox` to that spec's rule list.

## 6. Architecture

- `lib/core/domain/inbox/` — `InboxItem` (+ codec, validation), pure helpers: `dayOf`, `fireTimes`,
  `InboxSections.of(items, day, now)`, `badgeCount`, date presets, reminder presets.
- `lib/api/inbox/` — `InboxRepository` (`initialize(workspaceId, uid)`, `watch()`, `create`,
  `update(id, fields)`, `delete`) + `FirestoreInboxRepository`; wired in `app.dart` like the
  automation stores (injectable for tests).
- `lib/features/inbox/` — `InboxCubit` (app-level: items, load/error, badge, linked counts),
  `InboxPage` + `InboxPageCubit` (selected day, composer draft), `InboxItemEditor`,
  `CardLinkPicker`, `WeekStrip`, `ReminderToastHost`, `CardInboxButton`.
- `lib/features/inbox/reminders/` — `ReminderScheduler` (pure; injected `now`, `Attention`
  {focused, visible + change stream}, `ReminderStore` {get/set/remove + change stream}, and a
  `SystemNotifier`); web impls over `package:web` (`Notification`, `document.hasFocus`,
  `visibilitychange`, `localStorage` + `storage` events); stubs elsewhere (conditional import like
  `session_key.dart`).
- Router `/inbox`; `ShellPlace.inbox`; sidebar row, rail button, phone bar destination.

## 7. Limitations (stated in UI where they matter)
- Web reminders fire only while a Morkva tab is open (background is fine; Chrome may delay a hidden
  tab's tick by up to ~1 min).
- Each device fires its own reminders.
- Assigning to a teammate arrives with Epic 10.
- Production needs the owner to deploy `firestore.rules` before the Inbox loads (else
  permission-denied → the page's error state).

## 8. Plan for mobile & closed-tab delivery
- **Android/iOS:** `flutter_local_notifications` + `timezone`; a mobile `SystemNotifier` schedules
  the nearest 50 reminders (iOS caps pending at 64) with `zonedSchedule` and re-syncs on every inbox
  change (the scheduler hands it future fire times instead of firing on ticks); Android 13+
  `POST_NOTIFICATIONS` is asked from the same in-context link; exact alarms via
  `SCHEDULE_EXACT_ALARM` with an inexact fallback; tap payload `/inbox?item=` deep link.
- **Closed tab / other devices:** FCM web push + a scheduled Cloud Function (Blaze) — later.

## 9. Acceptance criteria

**Navigation**
- AC1. Wide sidebar shows "Inbox" above "All collections" with a count pill = my open tasks overdue
  or due today; 0 → no pill. Rail shows the same as a badge.
- AC2. Phone bottom bar is `Inbox · ≤3 pins · All`, shows with zero pins and on `/inbox`, Inbox
  badge as AC1.
- AC3. `/inbox?day=2026-11-20` selects that day; `/inbox?item=<id>` opens its editor; unknown id →
  page without editor.

**Page**
- AC4. Week strip Mon–Sun with selected/today states and ≤ 3 dots for days with open items; ‹ › move
  a week; Today returns; the month label opens the date picker and selects the picked day.
- AC5. Sections follow §3 Day rules: Overdue only on today, with "N d late" and "Move all to today"
  (undoable); the day section sorted timed → all-day; No date on every day; Completed by `doneAt`
  day, collapsed.
- AC6. Composer: Enter creates an item and keeps focus; a task defaults to the selected day; a note
  defaults to No date; toggling kind flips the default unless the date chip was touched; chips set
  date/time/reminder/link; blank title does nothing.
- AC7. Checking a task moves it to Completed with "Done · Undo"; unchecking restores it.
- AC8. A note created on Today is still listed under No date on the next day.
- AC9. Empty day / first-run / loading / load-error (Retry) states render.

**Editor & links**
- AC10. Editor edits title, details, kind, date (presets Today/Tomorrow/Next Monday/Pick), time,
  reminders (valid presets per §3; ≤ 3; time set → "At start" added), link; Save sends only changed
  fields; Delete with Undo; dirty close asks to discard.
- AC11. Reminder row shows the permission line per state; "Turn on notifications" is the only call to
  `requestPermission`.
- AC12. Link picker: collection → card, stores label; chip opens the card; deleted collection/card
  shows the muted state.
- AC13. Card editor (existing card) shows the Inbox icon with a count of open linked items; 0 →
  pre-linked editor; ≥ 1 → menu of items + "Add to Inbox…"; hidden when creating.

**Reminders**
- AC14. Scheduler fires exactly the reminders in `(lastTickAt, now]`; none on first run; none for
  done tasks; none for times edited into the past; a > 2 min window becomes one "while you were
  away" toast.
- AC15. Focused → toast only; unfocused + granted → one `Notification` with tag `itemId@fireMillis`
  and no toast; unfocused + not granted → toast when back; `Notification` throwing → toast.
- AC16. Toasts are shared across tabs (closing in one closes in all), render the live item, vanish
  when the item is done/deleted/rescheduled; Done/Open act on the item.
- AC17. Clicking a system notification focuses the tab and opens the item.

**Data & quality**
- AC18. Items stored at `workspaces/{wid}/inbox/{id}` with the §5 shape; rules allow the owner's own
  items and reject bad shapes / foreign `createdBy` (emulator check); writes don't await the server
  and surface failures as a snackbar.
- AC19. Unit tests: codec, day rules and sections (run under `TZ=America/New_York` too), presets,
  reminder fire times (DST), scheduler (fake clock/attention/store), cubits; widget tests: page
  sections, composer, editor, card button; `flutter analyze` clean.
- AC20. Web e2e on the emulator: create task/note via composer, link a card, set a reminder 1 min
  ahead → toast while focused; with notification permission granted over CDP and `window.Notification`
  replaced by a recorder and focus emulated off → one recorded notification; badge counts; phone width
  390 layout; design critic compares screenshots with the mockups.

## 10. Follow-ups
- Epic 10: assignee picker + avatar, "Mine · Assigned by me" filter, rule member check, "new" dot.
- Natural-language quick add; recurring items; snooze; reminders from card date fields; push
  delivery; mobile notifier (§8); Web Lock if duplicate fires show up.
