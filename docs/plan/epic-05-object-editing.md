# Epic 5 — Object Detail & Field Editors

## Goal
Open an object and edit every field type with a fit-for-purpose editor, with validation shown
inline. This turns viewing into real data entry.

## Why
Views (Epic 4) show objects; users also need to create and edit them in full. Each field type
deserves a proper editor (a date picker, a reference picker, a select chooser) — not raw text
boxes.

## In scope
- **Object detail screen**: shows all of an object's fields, grouped/ordered per the schema,
  with create and edit flows (reached from a view or quick-add).
- **Per-type editors**:
  - Text — single/multi-line input.
  - Number — numeric input honoring precision/unit.
  - Date / date-time — picker.
  - Boolean — toggle/checkbox.
  - Single-select — option chooser showing option colors.
  - Multi-select / tags — multi chooser with colored chips.
  - Reference — a **picker that searches the target collection** and links object(s); shows the
    linked object's title; supports single or multi.
  - File / attachment — upload/preview/remove (stored via the Epic 2 layer).
  - Auto-number / Calculated — shown **read-only** (their values come from Epic 6).
- **Validation UX**: surface the Epic 1 validation results inline (required, range, invalid
  reference, etc.) and block saving invalid objects with clear messaging.
- **Save / discard**, persisting through the storage layer; deleting an object.

## Out of scope
- Computing calculated/auto-number values (Epic 6) — here they render read-only.
- View rendering (Epic 4).

## Key concepts
- **One editor per field type, selected by type** — a registry mapping field type → editor
  widget, so adding a field type later means adding an editor, not editing a giant switch.
- **The reference picker is pivotal** — it's how a user links an order to the clothes it
  contains (in the examples), and it must feel fast and searchable.

## Deliverables
- An object detail/edit screen driven by the collection schema.
- A field-editor widget per type, wired through a type→editor registry.
- A searchable reference picker and a file attachment editor.
- Inline validation display and save/discard/delete, persisted via storage.
- Tests for editor value round-trips and validation gating on save.

## Acceptance criteria
- A user can create and edit an object touching every field type, with the right editor for
  each.
- Reference fields let the user search and link objects from the target collection, with the
  link persisted and visible.
- Invalid input is flagged inline and prevents save; valid edits persist to Drive.
- Calculated and auto-number fields appear read-only.
- Adding a new field-type editor doesn't require modifying existing editors.

## Dependencies & design notes
- Depends on Epic 1 (types/validation) and Epic 4 (views open the editor).
- **Use `/design`** for the detail screen and each editor — the object screen is where users
  spend real time; it should be clean, well-spaced, and consistent with the design system.
