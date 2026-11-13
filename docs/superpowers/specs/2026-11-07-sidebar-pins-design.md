# Sidebar with pinned collections & All collections — Design

**Date:** 2026-11-07 · **Status:** built; decided autonomously ("my call" marks my decisions)
**Why:** the old shell had two fixed destinations (Home, Settings) and every collection was two
taps away. The owner asked for the collections they use often to sit in the sidebar, with the
full list one step away.
**Mockups:** Claude Design canvas https://claude.ai/artifact/1SPRQ1VJbzfmUZJYW2dtjq (copies in
`docs/superpowers/mockups/sidebar/`: `Main` = wide sidebar + All collections, `Rail` = medium
width, `Mobile` = phone).

**Supersedes:** the Home / Settings `NavigationRail` + `NavigationCubit` shell from Epic 0
(`2026-06-16-epic-00-design-system-design.md`) and the "home screen" wording of Epic 3. Where
those documents disagree with this one, this one wins.

## Navigation model

- **Routes are the navigation state.** No `NavigationCubit`: `AppShellScaffold` gets the place
  from the router (`/` = All collections, `/collections/:id` = a collection, `/settings`).
- `/settings` is a route under `/` in the `ShellRoute` (no transition wide, a push on phone).
  Settings is no longer a destination: it is the icon next to the profile (wide) or the avatar
  in the phone header.
- An open collection that is not pinned highlights **All collections** (it lives there).

## Layout (breakpoints unchanged: 840 / 1240)

- **≥ 1240 — sidebar (272 px, `surfaceContainer`):** brand block (carrot logomark + "Morkva" /
  "CRM"; tapping it collapses the sidebar to the rail), "Jump to…" with its shortcut (Ctrl K; ⌘ K on macOS;
  hidden on Android/iOS), All collections, `PINNED` list, profile row (initials,
  name, dense sync status, settings button).
- **840–1240 — rail (76 px):** logomark (tap expands to the full sidebar), Jump to, All collections, pinned tiles (name in the
  tooltip, open one gets a carrot ring + edge marker), settings, avatar with a sync dot.
- **< 840 — phone:** header = logomark, "Collections", avatar (→ settings, sync dot). On `/` the
  bottom bar holds the first 3 pins + All; with no pins there is no bottom bar (a
  `NavigationBar` needs two destinations). Those 3 pins are tabs: opening one keeps the bar,
  with no back button and no push transition (owner, 2026-11-08). Any other collection opens
  full-screen with back.

## Pins

- Stored on the workspace doc as `pinnedCollections: [collectionId…]` (merge-set; the existing
  owner rule covers it, no rules change). My call: workspace-level for now —
  `shortcut:` comment in `FirestoreDataRepository` says to move pins to a per-member doc when
  shared workspaces land.
- `DataRepository.watchPinnedCollectionIds()` / `savePinnedCollectionIds()`;
  `PinnedCollectionsCubit` (optimistic emit, then save). Ids of deleted collections are skipped
  on display (`pinnedCollections()`), and dropped on the next reorder — never eagerly cleaned.
- Pin / unpin: the pin button on every card in All collections; unpin also by right-click on a
  sidebar or rail pin. Reorder: drag the handle shown on hover in the full sidebar.
- `AppShellScaffold` owns the shell-wide `CollectionsListCubit` and `PinnedCollectionsCubit`;
  `HomePage` reuses them.

## All collections page

- Wide header: "All collections", "N collections · M pinned to the sidebar", From template,
  New collection (icon buttons below 760 px). Phone: "N collections · M pinned" and the icon
  buttons. No filter: finding a collection is Jump to (sidebar field, rail icon, Ctrl+K; on phone
  a search icon in the All collections header), owner 2026-11-14.
- Sections `PINNED` then `EVERYTHING ELSE` (just `COLLECTIONS` when nothing is pinned); card grid
  (max 320 px wide; 2 columns on phone), 176 px cards: tinted glyph, pin toggle, overflow menu
  (Customize / Rename / Delete), name, 2-line description, field count.

## Collection colours

- `CollectionTints` (tokens, light + dark pairs): 8 soft tints picked by a stable hash of the
  collection id (`String.hashCode` differs on web vs VM, so a hand-rolled hash). My call: no
  stored colour field yet. `CollectionGlyph(tintSeed: collection.id)` everywhere a collection
  shows (sidebar, cards, views header, object editor, schema editor); a `null` seed keeps the
  carrot tile (new-collection dialog, templates).

## Cut from the first mockup (owner informed)

- Card counts and "updated 2 min ago": no count API (Firestore `count()` doesn't work offline)
  and collections have no `updatedAt`. Cards show the field count instead.
- Workspace name under the logo: workspaces have no name; the block reads "Morkva / CRM".
- Rail "library flyout": the rail's grid button opens the All collections page instead.
- A separate collapse button: the logo toggles sidebar ↔ rail instead (owner, 2026-11-08); the
  choice lasts for the session (`SidebarExtendedCubit`), otherwise width decides.
- Jump to searches collections only (cards search would be a separate epic).
