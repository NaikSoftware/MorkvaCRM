# Epic 5 — Object Detail & Field Editors — Design

**Date:** 2026-11-03 · **Status:** decided autonomously (owner asked for no approval stops; "my call" marks my decisions)
**Epic:** `docs/plan/epic-05-object-editing.md` · **Mockups:** Claude Design canvas "MorkvaCRM Object editor" (link in the plan)

## Goal

Open any object and edit every field type with a proper editor, with validation shown inline;
create new objects with the same form. Replaces Epic 4's read-only `ObjectDetailSheet`.

## Where it lives

- New feature folder `lib/features/objects/`:
  - `object_editor_cubit.dart` / `object_editor_state.dart` — draft, validation, save/delete, live sync.
  - `object_editor.dart` — the form surface (header, sections, footer); hosted two ways (below).
  - `value_editors/` — one `FieldValueEditor` per field type + `FieldValueEditorRegistry` +
    `built_in_value_editors.dart` (one registration line per type).
  - `widgets/reference_picker.dart`, `widgets/attachment_tile.dart`, small shared bits.
- `lib/api/files/` — `AttachmentStore` interface + `FirebaseAttachmentStore` (Firebase Storage).
- Shared label logic moves to `lib/core/domain/view/object_labels.dart` (used by the views cubit
  and the editor; today it is private in `CollectionViewsCubit._labelsFor`).

## Surface (my call)

One widget, `ObjectEditor`, hosted by width:
- **≥ 840 px (expanded):** a **centered dialog** (owner's call, 2026-11-04 — replaced the first
  560 px side panel), up to 720 px wide, 28 px corners, sized to the form and scrolling inside up
  to the viewport; fade + slight scale in; the same dark scrim as other dialogs (`Colors.black54`
  — a theme color such as `onSurface` turns into a light wash in dark mode).
- **< 840 px:** a **full-screen page** (dialog route) with a top app bar (close ✕, title, Save).

Opened from: tapping an object in any mode (edit); the main "+ New ⟨item⟩" button / phone FAB
(create, empty); board column "+", list section "+", calendar day "+" keep the fast
`QuickAddDialog`, which gains an **"Add details"** action that opens the editor in create mode
pre-filled with the typed title and the group/day value.

No deep-link route (YAGNI; views own navigation today).

## Form layout

- Header: collection glyph, the object's title (live from the draft's title field; "New ⟨item⟩"
  in create mode), and "Created · Updated" timestamps (edit mode, muted).
- Body: rendered from `Collection.layout` (Epic 3 card layout): **sections** (titled,
  collapsible, honoring `collapsed` as the initial state), **rows**, and **12-column spans**. On
  the phone page and in a narrow dialog every cell stacks full width when the row would give a
  cell < 240 px (same rule as the card preview: narrow = stacked).
- Each field: label (name, `*` when required), the type's editor, description as helper text,
  and the inline error line.
- Footer (dialog) / app bar (phone): **Delete** (edit mode; danger text button, left),
  **Cancel**, **Save** (primary). Save shows a spinner while writing.

## Edit model

- `ObjectEditorCubit(repository, collection, {object?, prefill, attachmentStore, ids, clock})`.
- Draft = map of changed field values only (`dirty`). Displayed value = draft ?? stored value.
- **Save** writes **only the changed keys** (`saveObject` merges values) so concurrent edits of
  other fields survive; `updatedAt = now`. Create mode writes the full normalized object.
- **Validation**: `field.validate(value)` per field (Epic 1) plus editor **input errors** (text
  that does not parse, e.g. "12,3a" in a number). Errors appear for a field after it was edited
  and blurred, and for **all** fields after the first Save attempt. Save with errors: nothing is
  written, the form scrolls to the first invalid field, and a banner says "Fix N fields to save".
- **Discard guard**: closing with unsaved changes asks "Discard changes?" (Keep editing / Discard).
- **Live sync**: the cubit watches the object. Non-dirty fields update in place from the stream.
  If a *dirty* field changes elsewhere, a banner warns "⟨Field⟩ was changed elsewhere — saving
  will overwrite it" (Epic 2's last-write-wins + visible warning). If the object is deleted
  elsewhere: banner "This ⟨item⟩ was deleted", Save becomes "Save as new" (restores it).
- **Delete** (edit mode): asks first ("Delete ⟨item⟩?" — owner's call, 2026-11-04), then closes
  the editor and returns `deleted`; the views page runs `cubit.deleteObject` with the Undo
  snackbar (which expires after 5 s).
- After a successful save the editor closes and the views page shows "Saved" only when the saved
  object is hidden by the active filters ("Saved — hidden by the filters"), like quick add.

### As built (Tasks 3–4)

- Banners (errors, conflict, deleted, save failed) sit fixed between the header and the scrolling
  body, so they stay visible wherever the form is scrolled.
- Phone page, edit mode: Delete is a red text button at the end of the body; the app bar keeps
  ✕ / title / Save.
- Pickers (date, select, reference, boolean) count as touched on change; text/number on blur.
- `showObjectEditor(...)` returns `ObjectEditorSaved(object)` / `ObjectEditorDeleted()` / null;
  "Saved — hidden by the filters" is decided by `applyView` on the saved object.
- `QuickAddDialog` returns `({String title, bool details})`; "Add details" opens the editor with
  the title and group/day prefill; the prefill note shows under the prefilled field(s).

## Value editors (registry seam)

```dart
abstract class FieldValueEditor {
  String get typeId;
  bool get isReadOnly => false;            // auto_number, calculated
  Widget build(BuildContext context, ValueEditorContext ctx);
}
class ValueEditorContext {               // everything an editor may need, nothing type-specific
  FieldDefinition field; FieldValue value; String? error; bool enabled;
  ValueChanged<FieldValue> onChanged;
  void Function(String? message) onInputError;   // parse errors that block save
  ReferenceChoices references;                   // labels + search for reference targets
  AttachmentActions attachments;                 // upload/remove/open for file fields
}
```
`FieldValueEditorRegistry` mirrors `FieldEditorRegistry`; the form never names a field type.
Unknown types render a read-only "Can't edit ⟨type⟩ here" line. Adding a type = one new editor
class + one registration line.

Per type (all Material 3, consistent with the design system):

| Type | Editor |
|---|---|
| text | `MorkvaTextField`; `multiline` → 3–8 lines growing; counter when `maxLength` |
| number | text field with numeric keyboard, `unitLabel` as suffix, decimals per `decimalPlaces`; local parse error; min/max errors from validation |
| date | read-only field + calendar icon → `showDatePicker` (Monday-first), `includeTime` → then `showTimePicker`; clear (✕) button; min/max bound the picker |
| boolean | `Switch` row (label left, switch right) |
| single_select | a pill button showing the colored option → menu of option pills (+ "Clear") |
| multi_select | wrap of colored chips (✕ to remove) + "Add" → checklist menu of options |
| reference | linked objects as chips (title, ✕) + "Link ⟨target item⟩" → **reference picker** |
| file | attachment tiles (icon/thumbnail, name, size, open, remove) + "Upload" (multi per config) |
| auto_number, calculated | read-only value with a lock/function glyph and "Set automatically" / "Calculated" helper; value comes from Epic 6 |

### Reference picker

Dialog (≥ 840 px) / bottom sheet (phone) with a search field (autofocus), the target
collection's objects as rows (title + up to two secondary values from the target's first view),
filtered as you type (case-insensitive substring on the label). Single: tap links and closes.
Multiple: checkboxes + "Done (n)". Shows "No ⟨items⟩ match" and, when the target is empty,
"⟨Target⟩ has no items yet". Labels come from `objectLabels()` (first text field, else
"Untitled"), shared with the views. Target objects are loaded via `watchObjects(target)` when the
editor opens (all reference fields of the schema), so linked chips show titles at once.

### File attachments (my call — infra is new)

- `AttachmentStore` (api): `upload(workspace path, PlatformFile) → FileAttachment` with progress,
  `downloadUrl(FileAttachment)`. Firebase Storage path:
  `workspaces/{uid}/files/{attachmentId}/{fileName}`; `FileAttachment.id` = attachmentId.
- Picking: `file_picker` package (web + mobile). Uploads start on pick; the tile shows progress;
  Save stays disabled while an upload runs. Allowed extensions filter the picker and validate.
- `storage.rules`: owner-only read/write under `workspaces/{uid}/**`, ≤ 25 MB per file.
- If Storage is unavailable (bucket not provisioned), the upload fails with an inline error
  "Couldn't upload ⟨name⟩" and the form keeps working.
- shortcut: removing an attachment or discarding a draft leaves the blob in Storage; a cleanup
  job belongs to the Storage epic.

## States

- Loading targets: reference chips show a shimmer stub until labels arrive.
- Save failure: banner "Couldn't save — check your connection" + Save enabled again; draft kept.
- Read-only fields never show errors and are skipped by the dirty/discard logic.

## Testing

- Unit (cubit): edit → dirty → save writes only changed keys; create writes full object with
  prefill; validation gating (required, number parse error, maxLength, range) blocks save and
  marks all fields; discard guard flag; live sync updates non-dirty fields and flags conflicts;
  remote delete → "Save as new"; delete returns `deleted`.
- Widget: each value editor round-trips its value (text, number incl. parse error, date clear,
  boolean, single/multi select, reference picker search + link, file tile remove); read-only
  editors; registry fallback for an unknown type; the form renders layout sections/rows and
  stacks on narrow widths.
- Flow: tap a row → edit → save → the table shows the new value; "+ New" → fill → save →
  appears; invalid save blocked. E2E on the web app at the end (desktop dialog + phone width).

## Out of scope

Computing auto-number/calculated values (Epic 6), referential-integrity checks (Epic 6), blob
cleanup, deep links to objects, comments/history.
