# Epic 8 — Ask Morkva: UX spec (states, layout, interaction)

Companion to `2026-11-10-epic-08-ai-assistant-design.md` (architecture). Mockups:
`docs/superpowers/mockups/epic-08/` (Claude Design canvas "Ask Morkva — AI assistant").
An independent design critic reviewed round 1 (ACCEPT WITH CHANGES); its findings are
folded in below and in the revised artboards.

## Surfaces and entry points

| Breakpoint | Entry | Panel |
|---|---|---|
Breakpoints follow `AppShell` (`lib/app/shell/app_shell.dart`): phone < 840 (bottom
NavigationBar), rail 840–1239, sidebar ≥ 1240.

| Breakpoint | Entry | Panel |
|---|---|---|
| Sidebar (≥ 1240 px) | Sidebar button "Ask Morkva" under "Jump to…", shortcut `Ctrl J`. A toggle (`aria-pressed`), carrot-tint (`primaryContainer`) when open — never styled as the current page. | 440 px side panel. Window ≥ 1280: it **pushes** the page (Main artboard); below that: overlay sheet. |
| Rail (840–1239 px) | Rail icon button with tooltip "Ask Morkva · Ctrl J". | 440 px **modal side sheet over the page** with a scrim (Tablet artboard). |
| Phone (< 840 px) | Tinted sparkle action in the page header of every shell page (PhoneEntry artboard; bottom NavigationBar unchanged). | Full-screen route with back arrow (Phone artboard). |

`Ctrl J` toggles the panel everywhere; `Esc` closes it; focus moves into the composer on open
and returns to the opener on close.

## Message anatomy (structured parts — no free-form markdown renderer)

The model's answers are rendered from **structured parts**, not raw markdown (my call: trust
cards and tables must not depend on model formatting; avoids a markdown dependency).

- **User bubble** — soft, low-contrast bubble: `surfaceContainerHigh` (#EEE5D8 light,
  #3A3028-ish dark) with `onSurface` text, right-aligned, 16/16/4/16 radius. Owner found the
  dark ink bubble too contrasty (2026-11-10).
- **Assistant text** — plain paragraphs with **bold** spans (we support `**bold**` and line
  breaks only), selectable.
- **Tool steps** — collapsed chip summarising the run ("Looked at Orders · filtered 148 → 5 ·
  summed Total"), expandable to one line per step. Running step shows a spinner and the step in
  bold; a failed step shows an error icon and a short reason.
- **Result table** — first column = object chip (deep link), at most 6 columns; wider tables
  scroll horizontally inside the card; long cell text ellipsized; footer row for totals.
  Actions: "Open as filtered view", "Copy table".
- **Chart** — bar chart from Rows/Containers (no chart dependency), value labels for the peak,
  partial periods drawn dashed, bars ≥ 3:1 against the card; "Show as table" is the accessible
  fallback.
- **Object chip** — `#1042` style chip that navigates to the card. On phone: the chat route is
  popped, the card opens, back returns to the chat (conversation state is kept in the bloc).
- **Change preview card** (awaiting approval) — 2 px `primary` border; title states the change
  and the count ("Set Status to Shipped · 3 orders"); subtitle "Nothing changes until you
  approve. You can undo afterwards."; when every item gets the same old→new value the diff is
  shown once in the header and rows list only the items; otherwise each row shows its own
  diff. Tri-state select-all; at most 5 rows, then "Show N more" expanding a lazy list (max
  height ~320 px). Approve label follows the selection ("Approve 2 changes"); disabled at 0.
  Schema changes (create collection / add field) list the fields with their types and options.
- **Destructive preview** — 2 px `error` border, trash tile, items listed inline with
  checkboxes, confirm button names count and noun ("Delete 7 orders"), copy states the undo window.
- **Applied card** — collapsed summary ("Set Status to Done · 12 orders", "You approved 12 of
  14 · undo available for 9 min") with a persistent **Undo** button for the whole undo window;
  then "Undo expired". After undo: "Reverted 12 orders". Plus a transient snackbar "12 orders
  updated · Undo" inside the panel (nested ScaffoldMessenger).
- **Rejected card** — collapsed: "Rejected — nothing changed".
- **Error row** — dashed card, says whether anything was written ("Nothing was changed."),
  "Try again" re-runs the last turn.

## Required states (implementation must cover; not all are drawn)

1. **Empty / first open** — greeting with the user's first name, "I can read all N of your
   collections…", suggestions grouped Ask / Analyze / Act; suggestions are generic templates
   filled with real collection names when possible.
2. **Thinking** — before first token / first step: "Thinking…" shimmer row.
3. **Streaming** — text appears incrementally with a caret; send button becomes **Stop**; after
   the stream ends, Stop turns back into Send.
4. **Tool running / failed** — see tool steps.
5. **Awaiting approval** — only **one** pending preview at a time. The composer shows "Approve or
   reject the changes above — or send a new message to skip them"; sending a new message marks
   the pending card "Skipped — nothing changed" and tells the model the user declined.
6. **Partial approval** — unchecked items are excluded; the applied card reports "N of M".
7. **Applying** — progress for large batches ("Updating 120 of 200…"); partial failure:
   "Updated 190, 10 failed · Retry failed".
8. **Conflict** — if an object changed since the preview (rev moved), that item fails with
   "Changed elsewhere since the preview" and is listed in the failure summary; nothing is
   overwritten silently.
9. **Undo** — done / expired / failed (e.g. the object was edited after the change: skip it and
   report).
10. **Rate limited (transient 429)** — warning banner "Gemini is busy. Retrying in N s." with a
    live countdown and "Retry now".
11. **Quota exhausted (daily)** — banner without auto-retry: "Today's free AI limit is used up.
    It resets at HH:MM." Composer disabled.
12. **Assistant disabled** — feature flag off: entry points hidden; deep link shows "Ask Morkva
    isn't enabled for your account."
13. **Offline** — composer disabled with "You're offline — Ask Morkva needs a connection"; the
    conversation stays readable.
14. **Long content** — auto-scroll while at bottom; when the user scrolls up, a "Jump to latest"
    button appears.
15. **History** — header button opens the conversation list (search, grouped by day, delete a
    conversation with confirm, empty state "No conversations yet"). On phone it's a full-screen
    list.
16. **Context chip** — "Looking at: Orders" (current collection) or "Looking at: #1042" (open
    card); removable; sent with the next turn as a hint, not as data.
17. **Dark theme** — Dark artboard: soft raised bubble, `primary` (carrotBright) preview border,
    `error` destructive border, warning container banner.

## Accessibility

- All interactive targets ≥ 44×44 (visual 36 inside a 44 hit area is fine — use the house
  buttons, which already set `minimumSize: Size(0, 44)`).
- Streaming answers and step updates are announced through a polite live region, once per
  message/step — never token by token.
- Approve / Reject reachable by Tab; Enter sends, Shift+Enter inserts a newline.
- Contrast: small grey text uses `onSurfaceVariant` (5.4–6.3:1 on our surfaces); non-text
  indicators (bars, borders that carry meaning) ≥ 3:1; composer focus ring uses
  `primaryText` (#8A4708) not raw carrot.
- Colors come from `ColorScheme` / `MorkvaSemanticColors`; add a `warningContainer` /
  `onWarningContainer` pair to the semantic extension instead of hardcoding the banner hexes.
