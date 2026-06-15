# Appendix — Example Setups (reference only)

These are the two real-world setups used to pressure-test the engine. They are **examples**,
not product features. Nothing here is hardcoded; the goal is that a user can rebuild all of it
using only generic collections, fields, views, and calculated fields (see
[`epic-07-example-templates.md`](epic-07-example-templates.md)). Field/option names are
illustrative.

---

## Example A — Apparel production & inventory (from a spreadsheet)

A small hoodie business tracks raw-material purchases, production, and per-unit cost. Source
workbook had four sheets:

- **Dashboard** — a read-only roll-up. Per color: total material added (kg), total purchase
  cost, units produced, and **material cost per unit = cost ÷ units**. A summary block adds
  derived material cost + manual constants (sewing fee, delivery) to get the true unit cost, and
  compares it to a target price. All values are `SUMIF`-style aggregations grouped by color.
- **Sewing journal** — manual log: one row per production batch (date, color, quantity, sizes).
- **Material inventory** (two materials: main fabric and ribbing) — purchase log (date, color,
  kg, cost, write-off) plus a derived per-color balance: remaining kg = purchased − (units
  produced × kg-per-unit), and how many more units the remaining material yields.

**What it exercises in the engine:** a reference/option list (colors) used as a join key;
aggregation (sum/count) grouped by a reference; per-object derived values (cost ÷ units,
remaining balance); a roll-up combining derived aggregates with manual constants.

**Maps to:** collections for *Colors*, *Material purchases*, *Inventory/production*; aggregation
and roll-up calculated fields (Epic 6); a roll-up/dashboard surface.

> Note for whoever ports this: the original balance formula has a latent bug — the
> kg-per-unit multiplier cell was left empty, so the consumption term evaluates to zero and the
> "remaining" figure shows raw purchased kg. A calculated-field model should make this explicit
> and correct rather than silently zero.

---

## Example B — Orders pipeline & inventory boards (from Trello)

The same business runs its day-to-day on a Trello workspace built from two board archetypes,
joined by card-to-card links.

- **Orders board** — one card per customer order. The **list/column is the status**, and the
  pipeline runs: ordered → to-clarify → in-queue → in-progress → made → shipped → received, with
  a side bucket for "not picked up." Cards carry: customer handle, an **auto-incremented order
  number** (they maintain a separate counter card + automation to generate it), recipient,
  phone, city, shipping point, deadline (date), prepayment and cash-on-delivery amounts, an
  order-items checklist, design-image attachments, and **links to the inventory cards** the
  order contains. Color-coded **labels**: gift, needs-design, cash-on-delivery, prepaid,
  not-urgent, has-deadline.
- **Inventory boards** (hoodies, light hoodies, t-shirts) — one card per color×size SKU. The
  **column is the size**; each card has numeric fields: **quantity in stock**, **used**
  (cumulative), and **reserve** (allocated to open orders). "Available" = quantity; "mark as
  used/sold" = the used/reserve numbers change as a linked order progresses — there is no
  separate "sold" column.
- **Certificates board** — gift-code lifecycle: created → issued → used. Card title = code.
  Same "move to a column = change status" pattern as orders.

**What it exercises in the engine:**
- **Board = group-by an attribute**, and the attribute differs per board: orders group by
  *status*, inventory by *size*, certificates by *status*. The view system must group by **any**
  select/reference field — identical machinery, different field (Epic 4).
- **References with reverse lookups** tying orders to inventory SKUs (Epic 6).
- **Calculated aggregates**: an SKU's reserved/used derived from the orders linking it — fixing
  the data drift (negative reserves) the manual Trello setup shows.
- **Auto-number** per collection (replacing the counter-card hack), **tag/multi-select** for
  labels, **status transitions** (the side-effect automation is a *future* epic; deriving counts
  is Epic 6).

**Maps to:** collections for *Orders*, *Inventory*, *Certificates*; board views grouped by the
relevant field; reference fields; calculated aggregation and auto-number (Epic 6); tags as
multi-select.

---

## The throughline

Both examples reduce to the same primitives: **collections of objects, typed fields (incl.
references, selects, tags, auto-number), views that group by an attribute, and calculated/
aggregation fields.** No "orders" feature, no "inventory" feature — just the engine, configured.
That is the test the plan is designed to pass.
