# Inbox — design

Owner ask (2026-11-14): "Create design and spec for an Inbox feature. Grill the idea: analyze
competitors. Notifications for me or assigned to a teammate; type notification/task (maybe an icon
is enough); a simple calendar to move between days; link any card of any collection; don't make the
design complex — we already have many functions, maybe turn buttons into icons or a ⋯ menu, or
reorganize; plan local notifications and show them; reminders (15 min before, at time, …); nice,
minimalistic, informative — some will use it as sticky notes, some as task delivery. Then think with
a critic, consolidate into AC and implement. Open a PR. Web now; Android/iOS later."

Built autonomously (owner preference): every decision marked *my call* was made without an approval
round-trip.

## 1. Intent & why

The competitor study (`docs/research/2026-11-13-market-competitors.md` §5) names two strong pains we
don't answer: **#3 "DIY Notion/Airtable CRMs decay — no reminders"** and **#6 "Who needs a follow-up
today?"**; §6 lists reminders as the first real gap. The Inbox is the daily-use surface that brings
people back: one list of things to do or remember, by day, optionally tied to a card ("call this
client", "order #1042 ships Friday"), with a reminder that actually pops up.

Two usage styles must both feel native:
- **Sticky notes** — capture a line fast, no date, no ceremony ("door code 4512", "Iryna prefers
  Viber").
- **Task delivery** — a dated task with a reminder, linked to a card, assigned to a teammate.

### Goals
- G1. Capture in one line from the Inbox page (Enter adds); details are optional.
- G2. See any day's items in one glance; move between days with a week strip; overdue tasks never
  disappear silently.
- G3. Link an item to any card of any collection; open the card from the item; add an item from a
  card.
- G4. Reminders (at time, 15 min, 1 h, 1 day before) that show as a browser notification when
  Morkva is open in a background tab and as an in-app toast when it is in front.
- G5. Team-ready data: every item has an assignee and an author, so Epic 10 (team workspaces) turns
  on assignment to a teammate without a data migration.
- G6. Adds at most **one** entry to each navigation surface; no new buttons in page headers.

### Non-goals (v1)
- Natural-language quick add ("tomorrow 10am") — later, behind the same input.
- Recurring items; sub-tasks; priorities; labels/projects; comments (see comments-feed plan).
- Push notifications with the tab closed (needs FCM + Cloud Functions, Blaze) — §8.
- Mobile local notifications (planned in §8, built with the mobile release).
- Date reminders generated from card date fields ("3 days before Due") — a follow-up that writes
  Inbox items (§10).
- Month/week calendar *views* of items (the strip + month popover only navigate).

### Anti-goals
- An inbox that nags: no permission prompt on page load, no badge for notes, no badge for tasks
  that aren't due yet.
- A second task app bolted on: items stay one line until opened; no fields beyond those below.
- Lost reminders presented as delivered: if a reminder can't fire (tab closed, permission blocked),
  the UI says so instead of implying it will.

## 2. Competitor patterns (grilled)

Full digest with sources: [`2026-11-14-inbox-research.md`](2026-11-14-inbox-research.md) (CRMs:
Pipedrive, HubSpot, Attio, folk, KeyCRM; personal: Todoist, Things, Keep; team: Linear, ClickUp,
Trello; the owner's reference xTiles). What we take, what we leave:

| Pattern | Seen in | Inbox v1 |
|---|---|---|
| Overdue folded into Today, with "Reschedule all" | folk, HubSpot, Todoist, xTiles | ✅ Overdue group on Today + "Move all to today" |
| Undated items always visible ("No date" shelf) | Todoist Inbox, xTiles Task List "Inbox" | ✅ the sticky-note shelf; named **No date** (xTiles' two meanings of "Inbox" is the trap) |
| Week strip, dot = has items, month label → picker, back-to-today | Todoist Upcoming, xTiles Planner | ✅ |
| Relative reminder presets incl. minutes | Trello, HubSpot, Todoist (auto when a time is set) | ✅ at time (default once a time is set), 15 min, 1 h, 1 day; xTiles' day-only presets are too coarse |
| Date-only items remind in the morning | Pipedrive 09:00, folk 08:00 | ✅ 09:00 |
| Few date presets | Attio, folk, KeyCRM | ✅ Today · Tomorrow · Next Monday · Pick… |
| Create from a record → pre-linked | Attio, folk, KeyCRM | ✅ "Add to Inbox" on the card |
| Badge = my overdue + due today | Pipedrive | ✅ notes never count |
| Overdue in red with lateness | Attio, xTiles | ✅ "2 d late" in error colour |
| Notes dismissed, tasks checked | Keep, Linear inbox | ✅ notes: "Dismiss" in ⋯ |
| Reminder state visible (permission, blocked) | complaint: HubSpot "reminders silently not firing" | ✅ banner + honest copy |
| "While you were away" summary | Linear inbox, morning digests | ✅ grouped toast on return |
| Accept/decline on assignment | xTiles | ❌ extra state; Epic 10 decides |
| Natural-language quick add | Todoist, TickTick | ❌ follow-up |
| Priorities, labels, projects, recurrence | everyone | ❌ (anti-goal: second task app) |
| Notification centre with tabs | xTiles, Linear | ❌ the Inbox *is* the list; no second bell |

## 3. Concepts

| Term | Meaning |
|---|---|
| **Item** | One Inbox entry: a **task** (checkbox, can be done, can be overdue) or a **note** (no checkbox; informs; never overdue). Kind is shown by the leading icon only and toggled by tapping that icon in the composer/editor (owner: "maybe icon is enough"). |
| **Due** | Optional: a date (all-day) or a date + time. Undated items live on the **No date** shelf. |
| **Reminder** | Up to 3 offsets before the due moment: at time, 15 min, 1 h, 1 day. Setting a time adds "At time" by default (removable). All-day items remind relative to **09:00 local** on the due day ("1 day before" = 09:00 the day before). |
| **Link** | Optional reference to one card: `{collectionId, cardId}` (card ids are unique only within their collection). |
| **Assignee** | The workspace member who should act. Defaults to me. Until Epic 10 ships members the only person is me, so the assignee control and the Mine/Everyone filter are hidden (*my call*; the field is written anyway). |
| **Author** | `createdBy` uid. |

## 4. UX

### Navigation (G6)
- **Wide sidebar:** a new "Inbox" row **above** "All collections". Trailing: a count pill of my open
  tasks that are overdue or due today (hidden at 0). Notes never count.
- **Rail (840–1240):** an Inbox rail button with the same count as a small badge.
- **Phone bottom bar:** Inbox becomes the first destination: `Inbox · pin1 · pin2 · pin3 · All`
  (5 destinations, the M3 maximum) with a badge. *my call:* the bar is the only phone navigation and
  a reminder needs a one-tap way back.
- Route `/inbox` (`?day=yyyy-MM-dd` selects a day, `?item=<id>` opens an item's editor).

### Inbox page
Wide: the Automations frame (page draws its own `headlineSmall` title), content column max 760.

```
Inbox                                                   [Mine ▾]  (team only)
November 2026 ▾                                    ‹   Today   ›
 Mon 9  Tue 10  Wed 11  Thu 12  Fri 13  [Sat 14]  Sun 15
   ·              ··                       ●
┌─────────────────────────────────────────────────────────────────┐
│ ○  Add a task for Sat 14…                                        │
│    [📅 Sat 14 ×] [🕘] [🔔] [🔗] [👤]                     (on focus)│
└─────────────────────────────────────────────────────────────────┘
OVERDUE · 2                                     (only when viewing today)
 ○  Call Iryna about the fabric       Thu 12 · 10:00   ▣ Order #1042
SAT 14 · 3
 ○  09:30  Pay the Textile Co invoice   🔔 15 min   ▣ Suppliers · Textile Co
 ◧  11:00  Courier comes at 11
 ○         Prepare samples                                     (TM)
NO DATE · 4
 ◧  Door code 4512
 ○  Ask Max for the new price list
Completed · 2 ▸
```

- **Week strip:** Mon–Sun, the selected day filled carrot, today ringed; dots under days with open
  items (≤ 3). `‹ ›` move a week; "Today" jumps back (disabled on today). "November 2026 ▾" opens a
  month grid popover (dialog on phone) with the same dots. Phone: swipe moves a week. Reuse
  `calendar_common.dart` helpers and the `_StripDay` look from `CalendarAgenda`.
- **Quick add:** one input; its leading icon toggles task/note. Placeholder names the day ("Add a
  task for Sat 14…"). Enter adds and keeps focus (rapid capture). On focus a row of **icon-only**
  chips appears: date (prefilled with the selected day; × clears → No date), time, reminder, link,
  assignee (team only); a chip shows its value once set ("10:00", "15 min", "Order #1042").
  *my call:* icons, not labelled buttons (owner: "transform button to icon").
- **Sections:** Overdue (open tasks due before today; only when viewing today) · the selected day
  (timed by time, then all-day) · No date (undated; on every day, collapsible — the sticky-note shelf) · Completed (done
  tasks of that day; collapsed).
- **Row anatomy:** leading control (task: round checkbox; note: tinted note glyph) · time (tabular,
  timed only) · title (≤ 2 lines) + first line of details (muted) · meta: bell + first reminder,
  link chip ("Collection · Card" with the collection icon), assignee avatar (team only). Wide: hover
  shows a ⋯ menu; phone: trailing ⋯. Tap opens the editor.
- **Overdue header** carries a text action "Move all to today"; overdue rows show "2 d late" in the
  error colour instead of the date.
- **Row ⋯ menu:** Move to tomorrow · Remove date / Set a date · Open card (when linked) · Dismiss
  (notes) · Delete.
  Completing a task: the checkbox animates, the row moves to Completed, snackbar "Done · Undo".
- **Empty states:** day empty → quiet "Nothing for Sat 14"; no items at all → EmptyState "Jot down
  notes, plan tasks and get reminded. Link anything to a card."

### Item editor
Dialog (480 wide, the card-editor dialog look) on wide; full-height bottom sheet on phone (root
navigator).

```
[○|◧]  Title…………………………………………                         ⋯   ×
Details (optional)
📅  Sat 14 Nov · 10:00       [Today] [Tomorrow] [Next Mon] [Pick…]   time on/off
🔔  At time × · 15 min ×     [+]      (presets: At time, 15 min, 1 h, 1 day before)
🔗  Order #1042 · Orders ×   or  "Link a card"
👤  You                       (team only)
                                                              [Save]
```
- Rows are quiet (icon + value); an empty row's muted placeholder is its button.
- Reminder row disabled with "Set a date to add reminders" for undated items; under it a quiet line
  "Reminders pop up while Morkva is open in a tab."
- ⋯ holds Delete (and Open card when linked).

### Link a card
Picker dialog/sheet: one search field over every collection's cards (labels via `objectLabels`,
search via `LabelIndex`), results grouped by collection with its icon; an empty query lists
collections → tap one to browse its cards.

### From a card
The card editor header gets a **⋯ menu** (wide and phone) with "Add to Inbox…" (item editor,
prelinked, kind task, no date) and **Delete card** (moved from the footer/bottom of the form —
*my call*, owner invited moving buttons into ⋯). When the card has open linked items the header shows
a small bell + count; tapping lists them with "Open in Inbox".

### Reminders: delivery on web
- A **ReminderScheduler** runs while signed in. It watches my open items and checks a wall-clock
  **tick every 20 s**, plus immediately on `visibilitychange`/`focus` and on any inbox change
  (background tabs throttle timers and sleep delays them, so one long `Timer` is not trusted).
- A reminder is due when its fire time ≤ now and it is not in the fired set. On fire:
  - window **focused** (`document.hasFocus()`) → in-app **reminder toast** only (top-right on wide,
    top on phone): kind icon, title, time, link chip; actions **Done** (tasks) · **Open** · close;
    stays until dismissed (max 3 stacked, "+N more").
  - **not focused** (other tab, other window, minimised, or visible beside another focused window)
    → a browser `Notification` (title; body "10:00 · Orders · #1042"; `tag` = item+fire time so
    tabs don't duplicate) if permission is `granted`, **and** the toast is queued for when the user
    comes back. Click on the notification focuses the tab and opens the item.
- Fired reminders are remembered in `localStorage` (`itemId@fireMillis`, pruned after 7 days) so a
  reload doesn't re-fire.
- **Missed while away:** reminders whose fire time passed while no Morkva tab was running (not in
  the fired set, within the last 7 days, item still open) are not dropped: on start one grouped toast
  says "3 reminders while you were away" and lists them (tap → item). No system notification for
  those.
- **Notification banner** (Inbox page, under the strip, dismissible): permission `default` and a
  reminder exists → "Get reminders even when Morkva is in another tab · [Turn on]"; `denied` →
  "Notifications are blocked for this site — reminders show only inside Morkva".
  `requestPermission` is only ever called from that button.

## 5. Data model

`workspaces/{wid}/members/{uid}/inbox/{itemId}` — the member's own inbox. *my call:* the existing
`members/{uid}/{sub}/**` rule already allows it, so the feature works in production without a rules
deploy. Epic 10 delivery to a teammate = writing the item into **their** inbox
(`members/{assignee}/inbox`, `createdBy` = me) behind a rule added with team membership; the
assignee field already exists, so nothing else changes (no clients → no migration concerns).

| Field | Type | Notes |
|---|---|---|
| `kind` | `'task' \| 'note'` | |
| `title` | string 1..500 | trimmed |
| `details` | string ≤ 5000 | optional |
| `dueAt` | Timestamp? | timed: the instant; all-day: UTC midnight of the calendar date |
| `allDay` | bool | |
| `reminders` | int[] ≤ 3 | minutes before (0, 15, 60, 1440) |
| `link` | `{collectionId, cardId}`? | |
| `assigneeUid` | string | defaults to the author |
| `createdBy` | string | |
| `done` / `doneAt` | bool / Timestamp? | tasks only |
| `createdAt` / `updatedAt` | Timestamp | client time |

- One listener on the member's inbox. *shortcut:* the whole inbox is streamed; add a `doneAt`
  window when it grows past a few thousand items.
- Writes are fired, not awaited (Firestore resolves only on server ack; offline must just work).
- Rules: none added (existing member rule). Shape is validated client-side in the codec.
- Deleted linked card → the chip shows "Card deleted" muted; the item stays.
- Last-write-wins on the whole doc, no `rev` (*my call*: an item has one editor in practice).

## 6. Architecture

- `lib/core/domain/inbox/` — `InboxItem` + codec + pure helpers: day membership, fire times,
  section grouping, badge count.
- `lib/api/inbox/` — `InboxRepository` interface + Firestore impl (`initialize(workspaceId, uid)`,
  `watch()`, `save`, `delete`), wired in `app.dart` like the automation stores.
- `lib/features/inbox/` — `InboxCubit` (app-level items, load/error, counts), `InboxPage` +
  `InboxPageCubit` (selected day, composer), `InboxItemEditor`, `CardPicker`, `WeekStrip`,
  `MonthPicker`, `ReminderToastHost`.
- `lib/features/inbox/reminders/` — `ReminderScheduler` (pure timing over an injectable clock,
  `fake_async` tests), `LocalNotifier` interface: web impl over `package:web` (`Notification`,
  `document.visibilityState`, `localStorage`), no-op stub elsewhere (conditional import like
  `session_key.dart`).
- Router `/inbox`; `ShellPlace.inbox`; sidebar row, rail button, phone bar destination.
- Card editor: ⋯ menu + linked-items bell.

## 7. Limitations (stated in UI where they matter)
- Web reminders fire only while a Morkva tab is open (background is fine).
- Each open device fires its own reminders; `tag` merges duplicates within one browser only.
- Assigning to a teammate arrives with Epic 10.
- Chrome on Android (mobile web) throws on `new Notification()` without a service worker: the web
  notifier catches it and falls back to the toast. Phones get real notifications from the native app
  (§8).

## 8. Plan for mobile & closed-tab delivery
- **Android/iOS:** `flutter_local_notifications` + `timezone`; a mobile `LocalNotifier` schedules
  the nearest 50 reminders (iOS caps at 64) with `zonedSchedule` and re-syncs on every inbox change;
  Android 13+ `POST_NOTIFICATIONS` is asked from the same in-context banner; exact alarms via
  `SCHEDULE_EXACT_ALARM` with an inexact fallback; tap payload `/inbox?item=` deep link. The
  scheduler hands the notifier a list of future fire times instead of arming its own timer.
- **Closed tab / other devices:** FCM web push + a scheduled Cloud Function (Blaze) — a later epic.

## 9. Acceptance criteria

> Consolidated after the critic round — pending.

## 10. Follow-ups
- Natural-language quick add; recurring items; reminders from card date fields; team assignment UI
  (Epic 10); push delivery; mobile notifier.
