# Epic 6 — Calculated & Aggregation Fields — Design

**Date:** 2026-11-07 · **Status:** decided autonomously (owner asked for no approval stops; "my call" marks my decisions)
**Epic:** `docs/plan/epic-06-calculated-fields.md`

## Goal

Fields whose values are derived, not typed in: formulas over an object's own fields, totals over
linked (or all) objects of another collection, auto-numbers, and a dashboard surface that reads
like a summary.

## Core decision: derive on read, never store (my call)

Calculated values are computed in memory every time objects are shown and are **never written to
Firestore**. `applyView` already filters/sorts whole collections in memory, a write-back cache
would trip the `rev` conflict detector and drift offline, and the epic's own rule is "derive, don't
duplicate". The repository skips calculated fields when encoding values.

- `lib/core/domain/calc/` — pure Dart:
  - `formula.dart` — tokenizer, parser (AST), type check, evaluator.
  - `calculation.dart` — the config model (`FormulaCalculation` / `AggregateCalculation`).
  - `derivation.dart` — `Derivation`: given collections and their raw objects, fills every
    calculated value. Memoized per (object, field); a cycle evaluates to empty; incoming
    references are indexed once per (source collection, reference field).
  - `sequences.dart` — auto-number allocation (shared by the Firestore and fake repositories).
- `CollectionViewsCubit` derives between the stream and `applyView`, so every mode, filter, sort
  and label sees the values. It also watches each collection a calculation needs (transitively).
- `ObjectEditorCubit` gets a `derive` callback from the views cubit: calculated fields preview live
  from the draft as the user types.

Only exports/AI tools reading Firestore directly would miss the values; neither exists yet.

## Field config (backward compatible)

The type stays `calculated` (fields may already exist in the owner's workspace). Config:

```json
{ "declaredOutputType": "number", "decimalPlaces": 2, "unitLabel": "₴",
  "expression": "{fld_price} * {fld_qty}" }                 // formula
{ "declaredOutputType": "number",
  "aggregate": { "source": "linkedFrom", "collectionId": "c_orders",
                 "referenceFieldId": "fld_item", "op": "sum", "fieldId": "fld_qty",
                 "filters": [ /* ViewFilter json */ ] } }     // aggregation
```

- No `aggregate` key → formula (the Epic 1 shape). `declaredOutputType` is set by the editor from
  the inferred type (formula) or the op (aggregation); it drives formatting, filters and sorting.
- `CalculatedFieldDefinition.outputField` is a synthetic definition of the output type (number
  with decimals/unit, text, yes/no, date-only) and `outputValue(...)` converts the value, so
  `formatFieldValue`, `operatorsFor`, `matchesFilter`, sort keys and numeric/metric checks delegate
  instead of growing calculated cases.

### Formulas (my call: small, typed, extensible)

- Field refs `{Field name}` in the editor, stored as `{fieldId}` (renames don't break them). A
  token that isn't an id is resolved by name (case-insensitive), so Epic 1 free-text survives.
- Literals: numbers, `"text"`, `TRUE`/`FALSE`. Operators: `+ - * /`, unary `-`, `&` (join text),
  `= != < <= > >=`. Date ± number → date; date − date → days.
- Functions: `IF AND OR NOT ROUND FLOOR CEIL ABS MIN MAX CONCAT LEN UPPER LOWER TODAY YEAR MONTH DAY
  ISBLANK`. A function table, so more can be added without touching storage.
- Field types usable: number, auto-number, text, single/multi select (labels), yes/no, date,
  other calculated fields. Reference/file fields are rejected with "Use an Aggregate field to
  summarize linked items".
- Blanks act like a spreadsheet: 0 in arithmetic, "" in text, false in logic — but when every
  field the formula reads is blank, the result is blank (a new object shows nothing, not 0).
- Division by zero and runtime type errors → blank.
- The type check runs in the editor (live: "Result: Number" or the error) and at derive time
  (an invalid formula → blank). A broken formula or a loop does not block saving the collection
  (my call): it is shown inline and computes blank, so a half-written formula is never lost.
- The formula input is syntax-highlighted (owner's ask): field refs as tinted chips, functions,
  text, numbers and operators colored, unknown fields/names with a wavy error underline.

### Aggregations

- Sources: **linkedFrom** (objects of X whose reference field points at this object — the reverse
  lookup), **linked** (objects this object's reference field points at), **all** (every object of
  X — for dashboards). Optional filters (AND, the view filter model and `FilterBuilder` UI).
- Ops: count, sum, average, min, max. Count needs no field; sum/average need a numeric field
  (number, auto-number, numeric calculated); min/max a numeric or date field.
- Empty set: count → 0, sum → 0, average/min/max → blank.

### Dependencies, cycles & performance

Derivation is lazy recursion with an in-progress set: a field reading itself (directly, through
another formula, or through another collection's aggregate) is empty instead of looping. The
config panel names a formula loop inside one collection ("Circular: Total → Tax → Total").
Measured: 3,000 orders + 300 items with an aggregate, a filter and two formulas derive in ~40 ms
(VM); the views cubit reuses the last result while none of its inputs changed (identity check).

## Auto-number (my call)

- Assigned inside the existing `saveObject` transaction when the object is **new** (no stored doc)
  and has no number: `next = max(counter, start − 1) + 1`; the counter lives on the workspace doc,
  `workspaces/{uid}.counters.{collectionId}.{fieldId}` (rules already allow it; no deploy, and
  `saveCollection`'s full overwrite can't wipe it). Deleting the newest object never reuses its
  number; restoring it (Undo) keeps its number.
- Config gains `start` (default 1) next to `prefix` and `padding`; the Build panel previews the
  next value ("ORD-0042").
- The number appears once the write commits (the stream echo); until then the form says
  "Assigned on save". Transactions already need a connection — not new.
- shortcut: objects that existed before the field was added stay blank (no backfill).

## UI

Mockups in Claude Design first (owner's rule), then Flutter to match.

- **Build → Calculated field panel:** a segmented "Formula | Aggregate" switch.
  - Formula: a multi-line monospace input; "Insert field" chips (tap inserts `{Name}` at the
    cursor), a functions menu, and a live status line (green "Number" / red error).
  - Aggregate: "Summarize" source picker (each linking reference: "⟨X⟩ linking via ⟨Field⟩";
    each own reference: "Linked ⟨X⟩ (⟨Field⟩)"; each collection: "All ⟨X⟩"), the op as chips,
    "of" field picker, "Only where" filter chips + "Add condition" (FilterBuilder popover), and a
    plain-language sentence ("Sum of Quantity of Orders linking here via Item, where Status is
    Paid").
  - Number output: decimals and unit.
- **Build → Auto-number panel:** start, prefix, padding, live "Next: ORD-0042".
- Remove the "computed later" banners and pill.
- **Object form:** calculated values read-only, live; helper line explains the calculation
  ("Price × Quantity", "Sum of Quantity · Orders linking here").
- **New view mode "Summary"** (my call): each object as a panel of big stat tiles (its shown
  fields; numbers large and tabular, other values small). A one-object "Dashboard" collection with
  **all**-source aggregates + manual constants + formulas is the spreadsheet's dashboard; a
  collection of colors with linkedFrom aggregates gives a summary per color. Tapping a panel opens
  the form (edit constants there).
- Tables: numeric calculated columns right-aligned like numbers.

## Out of scope (named cuts)

- A general scripting language; table totals footer; backlinks list in the form; auto-number
  backfill; any server-side computation; date-with-time outputs (dates are date-only).

## Acceptance mapping

| Criterion | How |
|---|---|
| Formula field computes | `{Price} * {Quantity}` → table/card/form |
| SUMIF-style aggregation | linkedFrom / all + filters; test vs hand-computed sums |
| Reserved/used derived from orders | inventory linkedFrom sum with status filter; live on change |
| Auto-number | transaction allocation; test in fake + Firestore unit |
| Roll-up | Summary mode over a Dashboard object; test totals |
| Generic | all configuration, no domain code |
