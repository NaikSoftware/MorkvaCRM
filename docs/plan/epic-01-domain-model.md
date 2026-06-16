# Epic 1 — Core Domain Model

## Goal
The universal data model — collections, objects, and typed fields — with JSON serialization
and validation. This is the heart of the product; everything else renders or stores it.

## Why
The entire product is "collections of objects with typed fields." Get this model right and
expressive, and every example (clothes, orders, inventory, certificates) is just data. Get it
wrong and we end up hardcoding domains later.

## In scope
- **Collection**: id, name, description, and an ordered **field schema** (the list of field
  definitions). Objects in the collection conform to this schema.
- **Object**: id, the collection it belongs to, a map of field-id → value, and timestamps.
- **Field definitions** for these types (each with its own config):
  - **Text** (single/multi-line)
  - **Number** (optional precision/unit label)
  - **Date** (and date-time)
  - **Boolean**
  - **Single-select** (fixed option set, each option may carry a color)
  - **Multi-select / tags** (same, multiple values — covers the "labels" pattern)
  - **Reference** (points to object(s) in another collection; single or multi; see Epic 6 for
    reverse lookups and aggregation)
  - **File / attachment**
  - **Auto-number** (a per-collection sequence; generation logic lands in Epic 6, but the
    field type and config are defined here)
  - **Calculated** (value is derived, not entered; computation lands in Epic 6, but the type,
    its declared output type, and its placeholder in the schema are defined here)
- **Typed value handling**: a polymorphic value model so each field type stores and reports a
  correctly-typed value, with safe defaults and missing-value handling.
- **Validation**: per-type rules (required, number range, valid select option, valid
  reference target) producing structured validation results the UI can show.
- **JSON serialization**: stable, human-readable JSON for a collection and its objects — this
  is exactly what Epic 2 writes to Firebase Storage. Design the schema for **forward
  compatibility** (unknown fields tolerated, versioned where needed) so the model can grow.

## Out of scope
- Persistence/sync (Epic 2), any UI (Epics 3–5), and the *computation* of calculated /
  aggregation / auto-number values (Epic 6) — only their type definitions live here.

## Key concepts
- **Schema vs. data**: a collection's field schema is separate from its objects' values.
  Editing a schema (Epic 3) must degrade gracefully for existing objects.
- **Extensibility first**: adding a new field type later should mean adding a type, not
  touching every consumer. Design the field-type system to be open for extension.

## Deliverables
- The Collection, Object, and Field-definition models with the full field-type set above.
- Polymorphic typed-value model with serialization to/from the JSON schema.
- Validation logic returning structured results.
- A documented description of the on-disk JSON shape (used by Epic 2).
- Unit tests covering serialization round-trips and validation for each field type.

## Acceptance criteria
- A collection with every field type can be created in code, populated with objects,
  serialized to JSON, and read back **identically** (round-trip).
- Validation correctly accepts valid values and rejects invalid ones for each type.
- Adding a hypothetical new field type requires no changes to serialization/validation of
  existing types (demonstrated by the type-system structure).
- No domain-specific names or logic exist anywhere in the model.

## Dependencies & design notes
- Depends on Epic 0.
- No UI — no `/design` needed. This epic is pure engine; favor clarity and extensibility over
  cleverness, since every later epic builds on these types.
