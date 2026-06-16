# MorkvaCRM — Implementation Plan

This folder is the build roadmap for MorkvaCRM, split into **epics**. Each epic is a
self-contained unit of work that can be handed to an AI agent (or a small team) and
delivered independently, in order. Read this file first, then the epic you're assigned.

For the product vision, see [`../PRD.md`](../PRD.md).

---

## The one idea everything rests on

> **Everything is collections and objects. There are no business-specific features.**

A **collection** is a set of **objects** (cards). Every object is a bag of **typed fields**.
That single model expresses every example we care about — a list of clothes, a pipeline of
orders, a gift-certificate tracker, a fabric-inventory sheet. The product never knows what a
"hoodie" or an "order" is. The user builds those by creating collections and fields.

Two consequences that shape the whole plan:

1. **Views are not features — they are render modes over the same objects.**
   A *table* renders objects as rows. A *board* ("kanban") renders objects as columns
   **grouped by an attribute**. They are not separate subsystems and must not be built as
   such. There is one View system; "board" is "table" grouped by a field. Adding a calendar
   or gallery later is adding a mode, not a feature.

2. **Nothing about clothing, orders, or any domain is hardcoded.**
   The hoodie spreadsheet and the morkvawear Trello (see [`appendix-examples.md`](appendix-examples.md))
   are *illustrations* used to pressure-test the engine. They ship — if at all — as
   importable **example templates** (plain data), never as product code.

If an epic ever tempts you to write `if (collection.isOrders)` or to special-case a field
named `status`, stop: the requirement belongs in the generic engine as a configurable
capability.

---

## Scope of this plan

**In scope:** the generic engine, Firebase Storage (cloud JSON) from day one, the view system
(table + board), object editing, and calculated/aggregation fields — enough that a user can
*rebuild* both example setups themselves, with no hardcoding.

**Deferred (noted, not built here):** automation/triggers, Firebase admin/feature-flags,
shared-workspace collaboration, the JS-module marketplace, and extra view modes. See
[`future-epics.md`](future-epics.md). (Firebase Auth ships in Epic 2, since it backs storage access.)

---

## Epic map and sequence

Build top to bottom. Arrows show hard dependencies.

| # | Epic | Delivers | Depends on |
|---|------|----------|------------|
| 0 | [Foundation & design system](epic-00-foundation.md) | Runnable Flutter app, BLoC scaffold, theme, routing, quality gates | — |
| 1 | [Core domain model](epic-01-domain-model.md) | Collections, objects, typed fields, JSON schema, validation | 0 |
| 2 | [Firebase Storage & sync](epic-02-storage-sync.md) | Firebase Auth sign-in, cloud JSON read/write, sync, offline cache | 1 |
| 3 | [Collection management](epic-03-collection-management.md) | Create/configure collections and their field schema in-app | 1, 2 |
| 4 | [Views & view modes](epic-04-views.md) | One view system: table mode + board (group-by) mode, filter/sort/fields | 3 |
| 5 | [Object detail & field editors](epic-05-object-editing.md) | Open an object, edit every field type, validation UX | 1, 4 |
| 6 | [Calculated & aggregation fields](epic-06-calculated-fields.md) | References + reverse lookups, formulas, cross-collection aggregation, auto-number, roll-up | 1, 5 |
| 7 | [Example templates](epic-07-example-templates.md) | Importable hoodie + orders templates; end-to-end acceptance | 4, 6 |
| 8 | [Global AI assistant](epic-08-ai-assistant.md) *(planned)* | "Ask Morkva" chat: ask / analyze / act on data via repository-bound tools | 2 (4, 6 soft) |
| — | [Future epics](future-epics.md) | Automation, Firebase, marketplace, more modes | — |

A reasonable first milestone ("the engine is real") is **Epics 0–4**: a user can sign in,
create a collection, add objects, and look at them as a table or a board. Epics 5–6 make it
powerful; Epic 7 proves it.

---

## Conventions every epic follows

- **State management: BLoC.** Widgets are dumb; all logic lives in blocs/cubits.
- **UI: Material, polished, distinctive.** Any screen, component, or visual decision goes
  through the `/design` skill — do not hand-roll generic tables and buttons.
- **Platform-agnostic core.** Shared code is shared; web-only / mobile-only bits are isolated.
- **Null-safe, idiomatic Dart**, small composable widgets.
- **Done means verified:** `flutter analyze` clean and tests green before an epic is called
  complete. Write tests proportional to complexity (see the project `/test` skill).
- **Definition of done per epic:** every item in that epic's *Acceptance criteria* is
  demonstrably true in the running app, not just in code.

## How to read an epic file

Each epic file has the same shape so an agent can pick it up cold:

- **Goal** — one sentence.
- **Why** — the context and the example it unblocks.
- **In scope / Out of scope** — the boundary.
- **Key concepts** — the nouns and how they relate.
- **Deliverables** — what to produce.
- **Acceptance criteria** — how we know it's done.
- **Dependencies & design notes** — what must exist first, and where `/design` is required.

## Glossary

- **Collection** — a named set of objects sharing a field schema (e.g. "Clothes", "Orders").
- **Object** — one item in a collection (the PRD calls it a *card*). A map of field → value.
- **Field** — a typed, named slot in a collection's schema (text, number, date, boolean,
  single-select, multi-select/tags, reference, file, auto-number, calculated).
- **Reference field** — a field whose value points to object(s) in another collection.
- **View** — a saved way to render a collection: a mode + group-by + filters + sort + visible
  fields. **Board/kanban = a view in board mode grouped by an attribute.**
- **Calculated field** — a field whose value is derived (per-object formula or cross-object
  aggregation), never entered by hand.
