# Epic 3 — Collection Management

## Goal
A user can create collections and configure their field schema entirely in-app — adding,
ordering, editing, and removing fields of any type — without writing code.

## Why
This is how every domain gets built. The user turns "I track orders" into a real collection by
defining fields. No domain is hardcoded; the user authors it here.

## In scope
- **Browse collections**: a home surface listing the user's collections, with create/rename/
  delete.
- **Create a collection**: name, description, and an initial field schema.
- **Field schema editor**: add fields, choose a field type (the full Epic 1 set), set per-type
  config (e.g. select options + their colors, number unit/precision, reference target
  collection, auto-number settings), reorder fields, rename, and remove.
- **Schema changes degrade gracefully** for existing objects (e.g. removing a field hides its
  data without corrupting the file; changing a type follows a defined, safe rule or is
  disallowed with a clear message).
- Persist all of this through the Epic 2 storage layer.

## Out of scope
- Rendering objects in table/board form (Epic 4) and editing individual objects' values
  (Epic 5). This epic configures *structure*, not data entry.
- Computing calculated/aggregation values (Epic 6) — but the schema editor must let the user
  *declare* a calculated or reference or auto-number field (its config UI can land here or be
  stubbed and completed in Epic 6; coordinate so the schema can express it).

## Key concepts
- **Schema authoring is the product's core creative act.** It should feel approachable: clear
  field-type choices with helpful descriptions, sensible defaults, and immediate feedback.
- **Reference and select config** are the load-bearing ones (they power boards in Epic 4 and
  aggregation in Epic 6) — make picking a target collection and defining option sets smooth.

## Deliverables
- Collection list/home screen with create/rename/delete.
- A collection editor screen with the full field-schema editor.
- Blocs managing collection and schema state, persisting via the storage repository.
- Graceful handling of schema edits against existing objects.
- Tests covering create/edit/delete of collections and of fields, including schema-change
  degradation.

## Acceptance criteria
- A user can create a collection from scratch and define a schema using every field type.
- Select/tag fields support a user-defined option set with colors; reference fields let the
  user choose a target collection.
- Editing the schema (add/reorder/rename/remove a field) never corrupts existing objects'
  stored data.
- All changes persist to Drive and survive a reload.

## Dependencies & design notes
- Depends on Epic 1 (the model) and Epic 2 (persistence).
- **Use `/design`** for the collection list, the create flow, and especially the field-schema
  editor — this is dense, interaction-heavy UI that must stay clear and inviting, not a raw
  form dump.
