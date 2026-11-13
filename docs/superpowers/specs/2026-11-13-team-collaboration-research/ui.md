# UI surfaces for sharing: digest

Repo: `the repo` @ 3e754b8. All paths below are relative to it. **[V]** means I verified it in code. **[I]** means I inferred it and did not run it.

## 1. Navigation map and deep links

**Routes** (`lib/app/router/app_router.dart`, go_router ^14.6.2) [V]
- One ShellRoute (98-230) wraps `AppShellScaffold`. Its routes:
  - `/` is HomePage, which shows All collections.
  - `/settings` (115)
  - `/automations?tab=&collection=&card=&filter=&module=` (125), plus `/automations/modules/:moduleId` (144) and `/automations/runs/:runId` (166)
  - `/collections/:id` (184), page key `ValueKey('/collections/$id')` (192)
  - `/collections/:id/edit?field=` (208) is the full-screen schema editor on the root navigator.
- Outside the shell:
  - `/assistant` and `/assistant/history` (233-245): phone only, Ask Morkva full screen.
  - `/sign-in` (246) and `/loading` (250).
- **No route carries a workspace segment.** Every path resolves against the signed-in user's own workspace.

**Auth gate** (redirect 62-94) [V]
- `AuthInitial` goes to `/loading`.
- `AuthLoading` goes to `/sign-in`.
- `AuthAuthenticated`: goes to `/loading` until `sessionReady`; after that, if it is on `/sign-in` or `/loading`, it returns `'/'` (88).
- Unauthenticated or error goes to `/sign-in`.
- No `from`/`returnTo` parameter is kept. A grep for `from=|redirectTo|returnTo` over lib and web found nothing.

**Consequence for shared links** [I, strong; not run]
- A link opened in a fresh tab or on a cold start passes through `/loading` and lands on `/`. The target is lost even for the owner.
- A signed-out recipient goes `/sign-in` → `/`.
- The only "cold link" test bypasses the auth gate: `test/features/views/collection_views_page_link_test.dart:85` uses `pumpWorkPage(location:)`. `test/app/router/app_router_test.dart` has no deep-link-through-auth test.
- Sharing needs a preserved-intent redirect, e.g. `/sign-in?next=` plus a workspace-scoped route.

**`view_link.dart`** [V]
- `collectionLink(id, {view, card, where})` (`lib/features/views/view_link.dart:15`) builds `/collections/:id?view=<viewId>&card=<objectId>&filter=<b64url JSON>`.
- `filter` is unpadded base64url of the "friendly where" list: `[{field, op, value?, relative?, n?}]`, with fields, options and cards given by name or id (39-40).
- It is capped at `maxLinkFilterBytes = 4096` (33). `parseLinkFilter` (51) treats the param as untrusted: it compiles through `FilterCompiler` with `Grants.all()` and `workspaceId: ''`, and any bad filter fails the whole link.
- Today it is used by the assistant's object chips, "Open as filtered view" and automations `openCard` (`lib/app/shell/app_shell_scaffold.dart:447`).
- **On the page** (`lib/features/views/collection_views_page.dart:41-44, 110-180`):
  - `view` selects the view.
  - `filter` becomes transient filters, shown as the "From assistant · …" chip (1021) with a "Save as view" action (958).
  - `card` opens the card editor.
  - Handled params are removed in place with `_dropParams` (`Router.neglect`).
  - An unknown or deleted collection shows `_NotFound` (1118): "This collection may have been deleted, or the link is wrong." with a "Back to collections" button.
- A view is not a document of its own. It is a `ViewDefinition` (id, name, mode, layoutFieldId, fieldIds, filters, sort, manualOrder, collapsedGroups; `lib/core/domain/view/view_definition.dart:116-171`) inside `Collection.views` (`lib/core/domain/collection.dart:51`).

**Web URL scheme** [I from absence]
- There is no `usePathUrlStrategy`/`setUrlStrategy` anywhere, so the hash strategy applies: `https://<host>/#/collections/<id>?view=…`.
- `web/index.html` is stock: `<base href="$FLUTTER_BASE_HREF">`, title "Morkva CRM", manifest, no meta/OG tags.
- **No hosting config in the repo.** `firebase.json` has firestore, storage and flutter blocks, but no `hosting`. No `web.app`/deploy references in README, docs/*.md or .github. The public origin is unknown, so a share link needs a decided origin.

**Mobile deep links** [V]
- Android `android/app/src/main/AndroidManifest.xml:23-26`: only the MAIN/LAUNCHER intent filter. No scheme/host, no `autoVerify`, `launchMode="singleTop"`.
- iOS `ios/Runner/Info.plist`: no `CFBundleURLTypes`, no `FlutterDeepLinkingEnabled`, no entitlements file / associated domains.
- pubspec has no app_links, uni_links or share_plus. It has `url_launcher ^6.3.3`.
- `Clipboard.setData` is already used: `lib/features/automation/view/code_viewer.dart:91`, `lib/features/automation/view/run_detail_page.dart:329`, `lib/features/assistant/view/widgets/result_table_card.dart:88`.
- So "Copy link" works today. A native share sheet or app links would be new.

## 2. Natural share entry points (existing surfaces)

**A. Wide collection header** `_WideHeader` (`lib/features/views/collection_views_page.dart:697-762`) — the prime spot [V]
- Padding is 24/24/24/8. One Row, left to right:
  1. `CollectionGlyph` 44px tile (icon 24, tinted by `CollectionTints.of(id)`)
  2. 12px gap
  3. Name in `headlineMedium` (Bricolage 24/600)
  4. `CollectionRunPill`
  5. `CollectionActionsMenu`: OutlinedButton.icon `bolt` "Actions ▾" with a MenuAnchor (`lib/features/automation/widgets/collection_actions_menu.dart:142-199`); icon-only `IconButton.outlined` when narrow
  6. OutlinedButton.icon `tune` "Customize"; icon-only when content < 720 (`_narrowContent`, line 56)
  7. `PrimaryButton` "+ New <item>"
- A "Share" OutlinedButton (icon `ios_share`/`person_add`) fits between Customize and "+ New", and collapses to an icon when narrow. Pattern to follow: Notion- or Airtable-style "Share" left of the primary CTA.
- Member avatars (a facepile) could sit before it.

**B. Phone collection AppBar** `_PhoneFrame` (`lib/features/views/collection_views_page.dart:764-871`) [V]
- Back button (hidden when it is a bottom-bar tab), then 32px glyph and name (`titleLarge`).
- Actions: AskMorkvaAction, `RunIndicatorButton(idle: SyncStatusIndicator())`, `tune` "View settings", and a `more_vert` PopupMenu holding `collectionPhoneMenuItems` (`lib/features/automation/widgets/collection_actions_menu.dart:351`; rows are Icon 20 + 12 gap + Text) plus "Customize collection".
- The FAB is "+".
- Share fits as a PopupMenu item ("Share…") or a dedicated icon before `more_vert`.

**C. View tabs** `ViewTabs` (`lib/features/views/widgets/view_tabs.dart`) [V]
- A scrollable TabBar. Each tab is 48px tall: mode icon 18 + 8 gap + name.
- Indicator: 3px carrot underline, top radius 3. Labels in `labelLarge`, w600 when active.
- The active tab has a 32px `more_horiz` "View options" button (250-269). That opens the **only per-view menu**: Rename / Duplicate / Delete (123-139). Delete is disabled for the last view. The menu also opens on long-press and right-click.
- The "+" New view button is 36×36.
- "Share view…" / "Copy link to view" belongs in this menu.

**D. View toolbar** `ViewToolbar` (`lib/features/views/widgets/view_toolbar.dart:9-12`) [V]
- Left: filter chips plus a dashed "+ Filter".
- Right (wide): an outline cluster (1px outline @60%, Radii.md, 1×20 outlineVariant separators; 203-215) holding `ToolbarButton`s: 36px tall in a 44 hit area, radius sm, padding h12, icon 18 onSurfaceVariant, label `labelLarge` onSurface (152-171). The cluster holds the mode chip, Sort and Columns.
- A "Share" chip could join this cluster, but the header (A) is the better spot.

**E. All collections**
- Wide header (`lib/features/collections/list/collections_list_view.dart:194-256`):
  - Left: "All collections" `headlineMedium` with the count in bodyMedium onSurfaceVariant under it.
  - Right: SearchField (260 wide), SecondaryButton "From template", PrimaryButton "New collection".
  - Narrow: filter, `IconButton.outlined`, `IconButton.filled`.
- Each collection card has a `more_vert` PopupMenu (`lib/features/collections/list/collection_card.dart:146-178`): Customize / Rename / Delete (error tint). A ListTile row per item.
- A "Share…" item fits there. A "Shared with me" section or filter could live here too.

**F. Sidebar** `ShellSidebar` (`lib/app/shell/shell_sidebar.dart`) [V]
- Full width 272, rail 76. Background `surfaceContainer`. Padding 12/16/12/12.
- Full sidebar, top to bottom:
  - `BrandWordmark` "Morkva CRM", which collapses the sidebar
  - `_JumpField`: 40 tall, surface fill, outlineVariant border, Radii.md, "Ctrl K" kbd chip
  - `_AskButton`: 44 tall, sparkle icon
  - `_NavRow` "All collections" (28px carrot `_AllTile`)
  - `_NavRow` "Automations" (bolt tile + RunIndicatorPill)
  - "PINNED" cap label: labelSmall w700, tracking 0.9
  - Reorderable pinned `_NavRow`s
  - Divider
  - `_ProfileRow` (746-799): UserAvatar 34, name (labelLarge) with `SyncStatusIndicator(dense)` under it, `tune` Settings IconButton
- `_NavRow` (545-655): 44 tall, radius 14, padding L8/R6, leading tile 28 + 12 gap. Label `labelLarge`, w700 when selected, else w500. Selected state is a `surfaceContainerLowest` pill with `MorkvaElevation.level1`. Hover is surfaceContainerLowest @55%. A drag handle shows on hover. Right-click opens Unpin.
- Rail (216-317): 52px buttons in 56px slots, radius 16. Selected is a raised white pill. Open collection gets a 4×20 carrot edge marker plus a 2px carrot ring around the glyph. Settings (`tune`) and UserAvatar with a sync dot sit at the bottom.
- Natural team spots:
  - A workspace switcher replacing or under the wordmark. No workspace-name concept exists.
  - A "SHARED WITH ME" section like PINNED.
  - A member facepile or "Invite" in the profile row.

**G. Settings** `SettingsPage` (`lib/features/settings/settings_page.dart:12-50`) — a placeholder [V]
- Padding 24. Contents:
  - One `ListTileCard` "Automations" / "Modules, buttons and runs" (bolt leading, RunIndicatorPill + chevron trailing)
  - EmptyState `tune_outlined` "Settings" / "Workspace and account settings will live here."
  - A centered SecondaryButton "Sign out" (`logout_rounded`)
- `ListTileCard` = SurfaceCard (white, Radii.lg 16, level1 shadow, level2 on hover), min height 44, titleMedium title, bodySmall onSurfaceVariant subtitle.
- **"Team / Members" goes here** as a ListTileCard entry or a section (a members list with roles, pending invites, an Invite button).
- Phone page header: shell `_PageHeader` with BackButton + "Settings" `headlineSmall` (`lib/app/shell/app_shell.dart:206-234`; `lib/app/shell/app_shell_scaffold.dart:349-367`).
- Phone header trailing: run indicator, Ask, and an avatar → `/settings` ("Account and settings", 292-306). The avatar is hidden in Settings and Automations.
- **Phone bottom bar** `_PinsBar` (`lib/app/shell/app_shell_scaffold.dart:764-800`): M3 NavigationBar with the first 3 pins plus "All".

## 3. Design language digest (match exactly)

**Source**
- `lib/design/DESIGN.md` ("Warm Carrot").
- Tokens in `lib/design/tokens/*.dart`; theme in `lib/design/theme/app_theme.dart`.
- Take shell values from code, not from the epic-08 mockups. Per a Memroot note, they drift: sidebar is 272 not 248, page titles use headlineSmall not 30px, buttons use 24px padding.
- Existing mockups: `docs/superpowers/mockups/{sidebar,epic-05..09}/*.dc.html`, e.g. `sidebar/Main.dc.html`, `sidebar/Mobile.dc.html`, `sidebar/Rail.dc.html`, `epic-09/ActionsMenu.dc.html`, `epic-09/Consent.dc.html`.

**Fonts** (`lib/design/tokens/typography.dart`)
- Bricolage Grotesque:
  - display 48/700/-1.0, 36/700/-0.8, 30/600/-0.6
  - headlineLarge 28/600/-0.5, headlineMedium 24/600/-0.4, headlineSmall 20/600/-0.3
  - titleLarge 18/600/-0.2
- Hanken Grotesk:
  - titleMedium 16/600, titleSmall 14/600
  - bodyLarge 16/400 lh1.5, bodyMedium 14/400 lh1.45, bodySmall 12/400 (onSurfaceVariant)
  - labelLarge 14/600 +0.1, labelMedium 12/600 +0.2, labelSmall 11/600 +0.4 (onSurfaceVariant)
- Roboto Mono for code. Tabular figures for numbers. Sentence case.

**Colors, light** (`lib/design/tokens/colors.dart:10-83`)

| Role | Hex |
|---|---|
| primary | #E8821E |
| onPrimary | #3A1E00 |
| primaryContainer | #FFE0C2 |
| onPrimaryContainer | #4E2A00 |
| primaryText (carrot text/links) | #8A4708 |
| secondary (leaf; avatar disc) | #4C7A34 |
| onSecondary | #FFFFFF |
| surface (canvas) | #FBF7F2 |
| surfaceContainerLowest (cards, sheets) | #FFFFFF |
| surfaceContainerLow | #FAF4EC |
| surfaceContainer (sidebar) | #F4EDE3 |
| surfaceContainerHigh | #EEE5D8 |
| surfaceContainerHighest | #E8DECD |
| onSurface | #2B2018 |
| onSurfaceVariant | #6B5E52 |
| outline | #B6A593 |
| outlineVariant | #E0D5C7 |
| error | #C0392B |
| success | #2E8B57 |
| warning | #D4A017 (never carrot) |
| warningContainer | #FBF3DC |
| onWarningContainer | #5A4410 |
| info | #3A7CA5 |
| doodle | #6B5E52 @10% |

**Colors, dark**

| Role | Hex |
|---|---|
| primary | #F59B3C |
| onPrimary | #3A1E00 |
| primaryText | #F59B3C |
| secondary | #8FCB6B |
| onSecondary | #12300A |
| surface | #1A1410 |
| surfaceContainerLowest | #141009 |
| surfaceContainerLow | #1F1813 |
| surfaceContainer | #241D17 |
| surfaceContainerHigh | #2E2620 |
| surfaceContainerHighest | #39302A |
| onSurface | #F3EBE0 |
| onSurfaceVariant | #C3B6A6 |
| outline | #4A4036 |
| outlineVariant | #332A22 |
| error | #E6786B |
| success | #5BB585 |
| warning | #E6BE54 |
| warningContainer | #3A2F12 |
| info | #6FA8C9 |

- Dark depth comes from surface steps, not shadows.
- Collection tints: 8 pairs each for light and dark (carrot, leaf, sky, plum, sand, rose, slate, teal), hashed from the id (`colors.dart:116-148`). Light carrot is #FFE0C2/#8A4708; leaf #E3EEDB/#3B6128; sky #DCEAF3/#2F5F80. These are a ready palette for member avatars.

**Radii** (`radii.dart`): sm 8 (chips), md 12 (buttons, inputs, menus/popover), lg 16 (cards, sheets, dialogs), full 28 (pills). Nav row radius is 14; rail button radius is 16.

**Spacing**: 4/8/12/16/24/32/48 (xxs…xxl). Content padding is 16, section gaps 24.

**Elevation** (`elevation.dart`)
- level1: `0 1 2 #00000014` + `0 3 6 #4A35200F` (cards, selected nav)
- level2: `0 2 4 #0000001A` + `0 8 14 #523A2214` (hover)
- level3: `0 4 10 #00000024` + `0 16 28 #523A221A` (menus, popovers, dialogs)

**Motion**: fast 120, base 200, slow 320 ms. Curve `cubic-bezier(0.16,1,0.3,1)`. Press scale 0.96 (PressableScale). No ink splash (`NoSplash`). No bounce.

**Buttons** (all 44 tall, Radii.md, h-padding 24, label `labelLarge`)
- PrimaryButton: carrot fill, #3A1E00 text.
- SecondaryButton: surfaceContainerHighest fill + 1px outlineVariant border (`lib/design/components/buttons/secondary_button.dart:41-50`).
- OutlinedButton (theme): outline border, onSurface text, used for header Actions/Customize.
- TextActionButton: primaryText color, h-padding 12.
- IconActionButton: 44 circle.

**Inputs**: white fill, 1px outline border, focus 2px primary, Radii.md, padding 16/12.

**Sheets, the responsive pattern to copy**
- `showAutomationSheet` (`lib/features/automation/view/consent_sheet.dart:22-55`):
  - Wide (≥840, `automationsExpanded` = `AppShell.expandedBreakpoint`): a centered Dialog, max width 560, max height 90%, Radii.lg, inset 24, fill `sheetSurface` (white in light, `surfaceContainer` #241D17 in dark, not the M3 default; lines 15-17).
  - Phone: `showModalBottomSheet`, scroll-controlled, safe area, drag handle.
- Frame `AutomationSheetFrame`: header padding 24/24/24/12; scroll body 24/8/24/24; divider; footer padding 16.
- `SheetFooter`: hint left, buttons right, stacked under 480.
- **Anchored popover** `showViewPopover` (`lib/features/views/widgets/view_popover.dart`):
  - Wide: 360 wide, hangs from an anchor rect, Radii.md, level3, white with outlineVariant border, transparent barrier, Esc/outside to dismiss.
  - Phone: a white bottom sheet (top radius 16, max 80%).
  - This is the best fit for a Notion-style Share popover under a header button.
- Dialogs: `MorkvaConfirmDialog` (TextActionButton cancel + PrimaryButton confirm, destructive tint, optional type-to-confirm). Jump-to dialog is max 480×460.

**Snackbars**
- Theme: floating, `inverseSurface`, Radii.md (`lib/design/theme/app_theme.dart:180-187`).
- Usage (`lib/features/views/collection_views_page.dart:324-343`): 480 wide on desktop, 5 s, **`persist:false`** (a snackbar with an action never times out on web otherwise).
- A "Link copied" toast should follow this.

**Chips and pills**
- `OptionPill`: 24 tall, full radius, 8px dot, labelMedium, tint @16% on white.
- InputChip "From assistant": secondaryContainer, Radii.sm, auto_awesome avatar.
- Filter chip: Radii.sm, onPrimaryContainer.
- Kbd chip: radius 6, 1px outlineVariant, labelSmall.
- Role badges like "Editor"/"Viewer" should reuse the OptionPill shape.

**Layout**
- Breakpoints: 840 (compact vs. expanded), 1240 (rail vs. full sidebar), 1280 (side panel pushes vs. overlays) (`lib/app/shell/app_shell.dart:81-94`).
- Doodle background only in the main panel. Never in dialogs or sheets.
- Touch targets ≥ 44.

## 4. Sign-in flow and account UI

**Sign-in** (`lib/features/auth/sign_in_page.dart`) [V]
- On the canvas. Wide: a centered SurfaceCard, max 400, padding 32. Compact: no card.
- Content:
  - `BrandWordmark(extended)`
  - "Welcome to your workspace" (headlineSmall)
  - Value line: "One tidy home for your collections and cards — synced securely across every device you sign in on."
  - Full-width carrot "Continue with Google" with a G glyph
  - "Cancel" TextActionButton while loading
  - Footnote: "We only use your Google account to sign you in. Your data stays yours."
  - Inline error box
- Google only (`AuthCubit.signInWithGoogle`, `lib/api/auth/auth_cubit.dart:86`).
- No invite or "you were invited to X" variant exists. An invite landing needs a new state on this page plus a preserved `next` (see §1).

**User model** `AuthUser` (`lib/api/auth/auth_user.dart`): uid ("doubles as the workspace id today", line 18), email, displayName?, photoUrl?. photoUrl is mapped in `lib/api/auth/firestore_auth_repository.dart:87-92`.

**Avatar** `UserAvatar` (`lib/app/shell/shell_sidebar.dart:802-890`) [V]
- **Initials only** on a leaf (`secondary`) disc, default 34px, labelLarge w700 onSecondary.
- `initialsOf`: the first letters of 2 name parts, else the email's first letter, else "?".
- **photoUrl is never rendered.**
- Optional 11px sync dot with a 2px ring: success / info / outline / warning / error.
- Shown in:
  - sidebar profile row (name or email + sync status)
  - rail bottom
  - phone header (tap → `/settings`)
- A members list could reuse it. Other users would need a tint per uid; the leaf disc is the "me" color today.

**Sign-out**: only via Settings → SecondaryButton "Sign out" (`lib/features/settings/settings_page.dart:40-46`). No account menu or popover exists. The profile row's only control is the `tune` Settings button.

**Workspace concept** [V]
- `WorkspaceResolver` interface, default `UidWorkspaceResolver` → `uid` (`lib/api/workspace/workspace_resolver.dart:14-20`).
- Injected into `lib/app/app.dart:102,143`. Resolved on each auth change (248-270), which binds DataRepository, attachments, automations, assistant and runner to that `workspaceId`.
- **There is no workspace name, title or switcher UI anywhere.** A grep for workspaceName/Title found nothing. The brand wordmark is static "Morkva CRM".
- The resolver is the existing seam for "open a workspace I was invited to". Switching workspaces today means re-initializing the whole session, because `_initializedWorkspaceId` gates it.

---
Not checked: `firestore.rules`, the domain layer, and `view_settings_sheet.dart` internals. The deep-link loss through `/loading` is read from code, not run. Not run: no app or emulator check, no `flutter analyze`.
Risk: a shared link opened in a new tab lands on Home today, and there is no hosting origin in the repo, so link sharing needs router and hosting decisions first.