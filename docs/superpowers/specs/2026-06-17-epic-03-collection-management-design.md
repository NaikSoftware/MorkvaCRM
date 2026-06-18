# Epic 03 — Collection Management — Design

**Date:** 2026-06-17
**Epic:** [`docs/plan/epic-03-collection-management.md`](../../plan/epic-03-collection-management.md)
**Depends on:** Epic 1 (domain model), Epic 2 (Firestore `DataRepository`)
**Status:** approved-to-build (decisions made by lead; open to correction)

---

## 1. Goal

A user can create collections and author their full field schema entirely in-app —
add / reorder / rename / remove / configure fields of every Epic 1 type — without writing
code, with a polished, modern Material UX. Everything persists through the Epic 2
`DataRepository` (Firestore) and survives reload. This epic configures **structure**, not
object data entry (Epic 5) or value computation (Epic 6).

This is the product's core creative act: turning "I track orders" into a real, typed
collection. It must feel approachable and inviting, not like a raw form dump.

---

## 2. Decisions (the four load-bearing forks)

1. **Editor architecture → field-editor registry.** A UI-side `FieldEditorRegistry` parallels
   the domain `FieldTypeRegistry`. Each field type contributes one `FieldEditor` describing how
   to *present* and *configure* it. Adding a field type stays one registration line — no edits
   to the editor screen. No `switch (type)` in widgets.
2. **IA → dedicated route per collection.** Home is the collections surface
   (browse + create + rename + delete). Tapping a collection opens `/collections/:id`, a full
   editor whose primary content is the field-schema editor. Create = a lightweight name dialog
   that creates the collection then lands the user in its editor.
3. **Config depth → full now, generation/eval deferred.** Full config UI for every concrete
   type. `auto_number` (prefix, padding) and `calculated` (declaredOutputType, expression) are
   **declared** — their settings persist — but generation and evaluation remain Epic 6.
4. **Type-change rule → type is locked after first save.** Once a field has been persisted, its
   `type` is immutable. Name, description, required, per-type config, order, and removal all
   stay editable. To change type, remove and re-add. This is the simplest provably
   non-corrupting rule. (Unsaved, never-persisted draft fields may still change type freely.)

---

## 3. Architecture & layers

New feature package: **`lib/features/collections/`**. It consumes the existing
`DataRepository` (Epic 2) and `lib/core/domain/` (Epic 1) and the `lib/design/` system
(Epic 0). No new persistence APIs are required — `watchCollections` / `getCollection` /
`saveCollection` / `deleteCollection` already cover everything.

```
lib/features/collections/
  collections.dart                      # barrel
  list/
    collections_list_cubit.dart         # watches DataRepository.watchCollections()
    collections_list_state.dart
    collections_list_view.dart          # the Home body (grid/list of collections)
    collection_card.dart                # one collection tile (name, field count, actions)
    create_collection_dialog.dart       # name + optional description -> creates, navigates
  editor/
    collection_editor_cubit.dart        # working draft of one Collection; dirty tracking; save
    collection_editor_state.dart
    collection_editor_page.dart         # /collections/:id host (header, save/dirty, layout)
    field_list.dart                     # reorderable list of fields
    field_row.dart                      # one field: icon, name, type badge, config summary
    field_config_panel.dart             # hosts the active field's FieldEditor.configEditor
    add_field_sheet.dart                # type picker (grid of FieldEditor descriptors)
    card_preview.dart                   # live preview of an empty card for this schema
  field_editors/
    field_editor.dart                   # abstract FieldEditor + FieldEditorRegistry
    built_in_field_editors.dart         # registers one editor per built-in type
    text_field_editor.dart
    number_field_editor.dart
    boolean_field_editor.dart
    date_field_editor.dart
    single_select_field_editor.dart     # shared option-set editor (see below)
    multi_select_field_editor.dart
    reference_field_editor.dart         # target-collection picker
    file_field_editor.dart
    auto_number_field_editor.dart       # declare-only (prefix, padding)
    calculated_field_editor.dart        # declare-only (output type, expression)
    widgets/
      option_set_editor.dart            # shared by single/multi select: add/reorder/recolor
      color_swatch_picker.dart          # Warm-Carrot palette swatches for option colors
```

### 3.1 The field-editor registry (the open-for-extension seam)

```dart
abstract class FieldEditor {
  String get typeId;                       // matches FieldDefinition.type
  String get displayLabel;                 // "Single select"
  String get description;                  // one line for the type picker
  IconData get icon;                       // for picker + field row
  bool get isComputed;                     // auto_number/calculated -> "declared, computed later"

  /// A fresh definition of this type with sensible defaults and the given id/name.
  FieldDefinition createDefault({required String id, required String name});

  /// The config editor for [definition]; calls [onChanged] with an updated definition.
  /// [collections] is the live collection list (reference picker needs target choices).
  Widget buildConfigEditor(
    BuildContext context,
    FieldDefinition definition,
    ValueChanged<FieldDefinition> onChanged, {
    required List<Collection> collections,
    required String editingCollectionId,
  });

  /// Short human summary for the field row, e.g. "3 options" / "→ Orders".
  String summarize(FieldDefinition definition);
}

class FieldEditorRegistry {
  void register(FieldEditor editor);
  FieldEditor? forType(String typeId);
  List<FieldEditor> get all;               // type-picker order
}
```

`built_in_field_editors.dart` registers one editor per type — the mirror of
`built_in_field_types.dart`. The editor screen and field rows dispatch through the registry;
they never name a concrete type. Each `FieldEditor` casts the `FieldDefinition` to its concrete
subclass internally, and produces a new immutable instance on every change (domain types are
immutable, so config editors emit replacements, not mutations).

---

## 4. State management (BLoC)

Two cubits, both fed by `DataRepository`. Widgets are dumb.

### 4.1 `CollectionsListCubit`
- Subscribes to `DataRepository.watchCollections()`; emits `CollectionsListState`
  (`loading` / `ready(List<Collection>)` / `error`). The stream replays on subscribe
  (rxdart `BehaviorSubject` from Epic 2) and tolerates the empty initial list.
- Actions: `createCollection(name, description?)` → builds a `Collection` with a generated id
  and empty fields, `saveCollection`, returns the new id (caller navigates to the editor);
  `renameCollection(id, name, description?)`; `deleteCollection(id)`.
- Id generation: a small `IdGenerator` (`c_` + time-ordered random suffix). No `Math.random`/
  `DateTime.now` constraints here (that limitation is workflow-script-only).

### 4.2 `CollectionEditorCubit`
- Loads one collection (from the list stream or `getCollection`) into a **working draft** held
  in state, plus the `savedRevision` it was loaded from, plus a `dirty` flag.
- Events (all mutate the in-memory draft, never persist until save):
  `addField(typeId)` (appends a default of that type, enters config), `updateField(definition)`,
  `removeField(fieldId)`, `reorderFields(oldIndex, newIndex)`, `renameCollection`,
  `selectField(fieldId?)` (drives the config panel).
- `save()` → `DataRepository.saveCollection(draft)`; on success clears `dirty`. Surfaces the
  Epic 2 conflict warning if a concurrent write bumped `rev` (last-write-wins + visible banner —
  reuse the existing sync/conflict surface, do not reinvent).
- **Validation before save:** non-empty collection name; unique non-empty field names; select
  fields with zero options and reference fields with no target are flagged inline (warn, allow
  save as a draft-incomplete state — they are still valid documents) — *blocking* errors are
  only empty names / duplicate field ids.
- **Dirty-leave guard:** navigating away with `dirty == true` prompts save / discard / cancel.

State is plain immutable classes (Equatable), consistent with Epic 1/2.

---

## 5. Routing & IA

- `lib/app/router`: add `/collections/:id` → `CollectionEditorPage`. Home (`/`) renders
  `CollectionsListView` (replacing the placeholder `EmptyState` in `home_page.dart`).
- The router already gates on session readiness (Epic 2 `/loading`), so blocs mount only after
  `DataRepository.initialize()`.
- Deep-linking `/collections/:id` for a missing/deleted id shows a friendly "collection not
  found" state with a back-to-home action.

---

## 6. Screens & UX (driven by `/design`)

The visual layer is designed via the `ui-ux-designer` / `/design` agent against the existing
**Warm Carrot** system (`lib/design/`). Targets, responsive for web and mobile:

**A. Collections surface (Home).**
- Empty state (reuses `EmptyState`) → primary "New collection" CTA.
- Populated: a responsive grid (wide) / list (narrow) of `CollectionCard`s — name, description,
  field count, last-updated; overflow menu for rename/delete (delete = confirm dialog, no
  destructive accidents). Create via `create_collection_dialog`.

**B. Collection editor (`/collections/:id`).**
- In-content page header (matches Epic 0 shell): editable collection name + description, a
  **Save** affordance that is prominent only when `dirty`, and a discard option.
- Two-region layout, responsive:
  - **Field list** — a `ReorderableListView` of `field_row`s. Each row: type icon, field name,
    type badge, config summary (`FieldEditor.summarize`), required indicator, drag handle,
    remove. Tap selects → opens config.
  - **Config region** — on wide screens a side panel; on narrow screens a bottom sheet / pushed
    sub-page. Hosts the selected field's `FieldEditor.buildConfigEditor`. Shows the
    type-locked note for persisted fields.
- **Add field** — `add_field_sheet`: a grid of type cards (icon + label + one-line description,
  `isComputed` ones tagged "computed in a later update"). Picking one appends a default field
  and selects it.
- **Live card preview** (`card_preview`) — a compact, read-only rendering of an empty object for
  the current schema, so the author sees the shape they are building. Uses field labels + type
  affordances; no data entry (that is Epic 5).

**C. Per-type config editors.** Each maps 1:1 to `docs/domain-json-schema.md`:
- text: multiline toggle, max length. number: decimal places, unit label, min/max. boolean: —.
- date: include-time toggle, min/max. single/multi-select: the shared `option_set_editor`
  (add / rename / reorder / recolor options via Warm-Carrot swatches; ids generated, stable).
- reference: target-collection picker (dropdown of live collections, self-target allowed) +
  multiple toggle. file: multiple toggle + allowed extensions. auto_number:
  prefix + padding (declare-only banner). calculated: declared output type + expression text
  (declare-only banner; no evaluation).
- Every editor also exposes the common envelope: name, description, required.

---

## 7. Schema-change degradation (correctness contract)

Object data is never touched by this epic; safety rests on the Epic 1 read contract
(`docs/domain-json-schema.md`): **on read, values for fields no longer in the schema are
dropped, and missing values become the field's empty value.** Therefore:
- **Remove field** → safe; orphaned values are dropped on next object read. No object rewrite.
- **Add field** → safe; existing objects read the new field as its empty value.
- **Reorder / rename** → safe; ids are stable, values key off id not name/order.
- **Change required** → safe structurally; only affects future validation, not stored data.
- **Change type** → *disallowed* after first save (decision 4). This removes the only operation
  that could reinterpret stored bytes, so no value-coercion logic is needed in this epic.

A unit test asserts that loading objects after each schema edit yields no corruption / no throw.

---

## 8. Data flow

```
DataRepository.watchCollections()  ──►  CollectionsListCubit  ──►  CollectionsListView
                                                                      │ create/rename/delete
                                                                      ▼
                                          DataRepository.saveCollection / deleteCollection
                                                                      │
        /collections/:id  ──►  CollectionEditorCubit (working draft) ─┘
              edits ──► in-memory draft ──► Save ──► DataRepository.saveCollection(draft)
```

The list stream is the single source of truth; the editor edits a detached draft and commits
atomically, so partial schema states never reach Firestore.

---

## 9. Error handling
- Save failures (network/permission) → non-destructive snackbar/banner; draft retained, stays
  `dirty` so the user can retry. Reuse Epic 2 sync-status/conflict surface for rev conflicts.
- Delete is confirm-gated; failures restore the row.
- Missing collection id (deep link) → friendly not-found state.
- All cubits guard against the empty initial list and late `initialize()`.

---

## 10. Testing (proportional, per `/test`)
- `CollectionsListCubit`: create/rename/delete; stream → state mapping; id uniqueness.
- `CollectionEditorCubit`: add/reorder/rename/remove field; dirty tracking; save commits the
  whole draft; validation (empty name, duplicate field names) blocks; type-lock enforced on
  persisted fields but free on draft fields.
- `FieldEditorRegistry`: every built-in domain type has a registered editor; `createDefault`
  round-trips through `toJson`/`FieldTypeRegistry`.
- Each per-type config editor: editing config produces a valid, JSON-round-trippable definition.
- **Degradation test:** apply add/remove/reorder/rename to a schema with existing objects and
  assert objects still decode with no throw and no corruption.
- Widget tests for the list, the reorderable field list, and the add-field flow (golden/smoke as
  the design lands).
- Gate: `flutter analyze` clean, all tests green, web build OK.

---

## 11. Out of scope (explicit)
- Rendering objects as table/board (Epic 4) and editing object values (Epic 5).
- Auto-number generation, calculated evaluation, reference target-existence integrity (Epic 6).
- File blob upload (later epic) — the file field is configured here, not uploaded to.
- JS-module / marketplace extension of field types (future) — the registry is built so this
  drops in later without redesign.

---

## 12. Build sequence
1. `field_editors/` registry + abstract `FieldEditor` + the two simplest editors (text, boolean)
   and `FieldEditorRegistry` tests. (Establishes the seam every screen depends on.)
2. `CollectionsListCubit` + state + tests; wire Home to the list; create/rename/delete +
   `create_collection_dialog`; route `/collections/:id` stub.
3. `CollectionEditorCubit` + state + tests (draft, dirty, save, validation, type-lock,
   degradation test).
4. Remaining `FieldEditor`s + shared `option_set_editor` / `color_swatch_picker` /
   reference picker.
5. Editor UI (`/design`): field list (reorder), config region, add-field sheet, card preview,
   page header + save/dirty + leave-guard.
6. Polish pass with `/design` (responsive web+mobile, empty/loading/error states), `/check`,
   then PR to main.

Parallelizable in agent-team mode: registry+editors (one owner), list feature (one owner),
editor cubit+page (one owner), design pass (designer). Disjoint files; shared contract is
`FieldEditor` + the cubit state classes, authored first by the lead.
