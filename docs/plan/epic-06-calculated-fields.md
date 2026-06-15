# Epic 6 — Calculated & Aggregation Fields

## Goal
Fields whose values are *derived*, not entered: per-object formulas, cross-collection
aggregations over references, per-collection auto-numbers, and roll-up/dashboard objects.
This is what lets the engine replace a spreadsheet.

## Why
The hoodie spreadsheet runs on `SUMIF` aggregations (cost and kg per color, units sewn,
remaining fabric) and a cost roll-up; the Trello inventory derives "reserved" and "used" from
linked orders, and order numbers come from an auto-increment counter. All of these are the same
generic capability the PRD calls "calculated fields derived from other fields or from another
card by id." Build it once, generically, and both examples — and anything else — work.

## In scope
- **References + reverse lookups (the foundation):** given a reference field, an object can be
  asked "which objects in collection X reference me?" Reverse lookup is what makes aggregation
  across linked objects possible.
- **Per-object formulas:** a derived field computed from other fields of the *same* object
  (e.g. `total = price × quantity`).
- **Cross-collection aggregation:** a derived field that aggregates over a set of related
  objects — **sum / count / average / min / max**, optionally filtered — equivalent to the
  spreadsheet's `SUMIF`. Examples it must express (as configuration, not code): total cost and
  total kg grouped by a reference; units reserved/used for an inventory object computed from the
  orders that link it.
- **Roll-up / dashboard:** a way to show aggregate totals across a whole collection (the
  spreadsheet's Дашборд) — e.g. a single summary object or a dedicated roll-up view fed by
  aggregation fields. Combine derived aggregates with manual constants (like a fixed sewing fee)
  the way the dashboard does.
- **Auto-number:** a per-collection monotonic sequence assigned on object creation (replacing
  the Trello "counter board" hack). Configurable start/format.
- **Recomputation:** derived values update when their inputs change (an edited object, a new/
  removed reference) without the user refreshing.
- **Extensible expression model:** structure the formula/aggregation definitions so richer
  operations (conditionals, more functions, multi-step expressions) can be added later without
  reworking storage or the field system. Start with the operations above; leave the door open.

## Out of scope
- A full general-purpose formula language / scripting (future epic — the deferred "full formula
  engine"). Ship the concrete operation set above, designed to extend.
- Automation/triggers that perform *side effects* on status change (future epic). Here, derived
  values are *read* from current data; we don't yet write side effects on transitions.

## Key concepts
- **Derive, don't duplicate.** Reserved/used/available counts should be *computed* from linked
  orders, not stored and hand-maintained — this is exactly the drift (negative reserves) the
  Trello setup suffers. Calculated fields fix that by construction.
- **Dependency awareness:** a calculated field depends on specific fields/relationships;
  changing those triggers recompute. Keep the dependency model simple but correct, and guard
  against reference cycles.

## Deliverables
- Reverse-lookup capability on reference fields.
- A calculated-field engine supporting per-object formulas and cross-collection aggregation
  (sum/count/avg/min/max with optional filter), with a defined, extensible definition format.
- Auto-number sequence generation per collection.
- A roll-up/dashboard mechanism combining aggregates and constants.
- Recomputation on input change, with cycle protection.
- Tests reproducing the spreadsheet's core math (e.g. cost-per-unit and remaining-quantity
  style calculations) and the orders→inventory reserved/used derivation — built purely as
  configuration over generic collections.

## Acceptance criteria
- A user can define a per-object formula field and see it compute (e.g. price × quantity).
- A user can define an aggregation field that sums/counts values from objects linking via a
  reference, with an optional filter, and it matches a hand-computed `SUMIF` result.
- An inventory-style object's "reserved/used" can be derived from linked order objects and
  updates automatically as orders are added/changed.
- A new object in a collection with an auto-number field receives the next sequence value.
- A roll-up surface shows correct collection-wide totals combining derived values and manual
  constants.
- All of the above is configured through the generic field system — no domain-specific code.

## Dependencies & design notes
- Depends on Epic 1 (field types, incl. reference/calculated/auto-number placeholders) and
  Epic 5 (where derived values render read-only).
- **Use `/design`** for the roll-up/dashboard presentation — it should read like a clear
  summary, not a raw number dump.
