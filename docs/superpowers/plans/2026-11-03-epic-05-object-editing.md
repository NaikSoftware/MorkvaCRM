# Epic 5 — Object Editing — Implementation Plan

Spec: `docs/superpowers/specs/2026-11-03-epic-05-object-editing-design.md`
Mockups (Claude Design): https://claude.ai/artifact/NAZbLcgX6XmXAGXiUH8wSZ — copies in `docs/superpowers/mockups/epic-05/`; the
artboards: `Main` (desktop centered dialog, edit), `Invalid` (save blocked + conflict banner),
`RefPicker` (desktop multi picker), `PhoneNew` (phone create page), `PhonePicker` (phone single
picker sheet).
Branch: `worktree-epic-05-object-editing` (worktree `.claude/worktrees/epic-05`).

Tasks run strictly in order; each ends with `flutter analyze` clean, its tests green, a commit.

## Task 0 — Epic 4 leftovers (from the design audit)
- Setup card sheet: intro line "Choose which fields show on each card in “⟨view⟩” and drag to set
  their order." and footnote "Empty fields are skipped on the card." (`fields_editor_sheet.dart`).
- Phone (superseded 2026-11-08: a round "+" FAB floating over the body, "New ⟨item⟩" as its
  tooltip, no bottom padding): the main add button becomes an extended FAB "+ New ⟨item⟩" (collapses to icon while
  scrolling down is NOT needed — keep it simple: always extended).
- Calendar month grid on a collection with no objects: a centered hint "Click a day to add a
  ⟨item⟩" (phone agenda keeps "Nothing scheduled yet").
- Loading skeleton: add the toolbar row (filter chip + sort/columns stubs) above the table-shaped
  block. (Mode-shaped skeletons need the view before the collection loads — deferred.)
- Reproduce the "Add your first ⟨item⟩" nudge showing while objects exist ("0 of 9"); fix only if
  reproduced (likely first objects emission is empty). Add a regression test if fixed.

## Task 1 — Value-editor seam + simple editors
- `lib/core/domain/view/object_labels.dart`: `Map<String,String> objectLabels(Collection target,
  List<MorkvaObject> objects)` (target's first view order, unfiltered; first text field or
  "Untitled"); `CollectionViewsCubit._labelsFor` uses it. Unit test.
- `lib/features/objects/value_editors/`: `FieldValueEditor`, `ValueEditorContext`,
  `FieldValueEditorRegistry`, `defaultValueEditorRegistry()`, fallback for unknown types.
- Editors: text (single/multi-line, maxLength counter), number (parse, unitLabel suffix,
  decimalPlaces formatting on blur, input error "Enter a number"), boolean (switch row), date
  (picker, includeTime → time picker, clear, min/max), auto_number + calculated (read-only).
- Widget tests: each round-trips its value; number parse error reported; read-only editors inert.

## Task 2 — Choice + reference editors
- single_select (pill button → menu of option pills + Clear), multi_select (chips with remove +
  "Add" checklist menu), reference (chips + "Link ⟨item⟩" → `ReferencePicker`: dialog ≥ 840 px,
  bottom sheet below; search, single tap-to-link with check on current, multi with checkboxes +
  Done, empty + no-match states, Unlink in single mode).
- `ReferenceChoices` in the context: `labelsFor(field)` (null while loading) + secondary line.
- Widget tests: select round-trips; picker search filters; single links and closes; multi Done.

## Task 3 — ObjectEditorCubit
- State: collection, original (null in create), draft (changed keys), input errors, validation
  shown (touched set / all after Save), status (editing/saving/saveFailed/saved/deleted),
  remote conflict fields, remoteDeleted, reference labels per target, uploading count.
- Commands: `change(fieldId, value)`, `setInputError`, `touch(fieldId)`, `save()` (only changed
  keys; create = full object incl. prefill; remoteDeleted → write full object), `delete()`
  (status deleted; caller does the actual delete with Undo), `hasUnsavedChanges`.
- Watches the collection's objects (find by id) for live sync and reference targets for labels.
- bloc_test coverage per spec "Testing".

## Task 4 — Form, hosts, wiring
- `ObjectEditor` widget: header, banners (errors count, conflict, deleted, save failed), layout
  sections (collapsible) / rows / spans with narrow stacking, field chrome (label, required `*`,
  changed dot, description, error line), footer / phone app bar; scroll to first error.
- Hosts: `showObjectEditor(context, …)` → centered dialog ≥ 840 px (≤ 720 px, sized to the form, dark scrim) — was a side panel until 2026-11-04
  or full-screen dialog page; PopScope discard guard ("Discard changes?").
- Wire into `collection_views_page.dart`: open object → editor (edit); main "+ New" / FAB →
  editor (create); QuickAddDialog gets "Add details" → editor with title + prefill. Delete →
  existing `cubit.deleteObject` + Undo snackbar. Remove `ObjectDetailSheet` and its tests.
- Widget/flow tests: edit → save → table shows value; create → appears; invalid save blocked;
  discard guard; dialog vs page by width.

## Task 5 — File attachments
- Deps: `firebase_storage`, `file_picker`. `lib/api/files/attachment_store.dart` interface +
  `firebase_attachment_store.dart` (`workspaces/{uid}/files/{id}/{name}`, progress stream,
  download URL); provided like `DataRepository`. `storage.rules` + `firebase.json` entry.
- File editor: tiles (type badge / image thumbnail, name, size, open in new tab, remove), upload
  with progress, allowed extensions on the picker, single vs multiple, inline upload errors; cubit
  blocks Save while uploads run.
- Tests with a fake store: upload adds attachment, failure shows error, remove, single replaces.

## Task 6 — Verify
- `flutter analyze`, full `flutter test`.
- E2E on web (run-for-web): edit every type on a seeded collection, reference link, validation
  block, create from board column via "Add details", phone width page; screenshots.
- design-reviewer pass on the rendered editor vs the mockups; code review of the branch diff;
  fix findings; update `docs/plan/epic-05-object-editing.md` status.
