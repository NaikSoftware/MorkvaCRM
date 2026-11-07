# Lookup fields & in-card sublists — Design

**Date:** 2026-11-07 · **Status:** built; decided autonomously ("my call" marks my decisions)
**Why:** the Epic 7 gap analysis. Order line items (garment, size, colour, what to embroider,
done/not done) have to be real objects so stock math works on them. A SKU's reserved stock is
"sum of item quantities where the item's order is still open". That needs a filter on a field of
a *linked* object, which the engine couldn't express.
**Mockups:** Claude Design canvas https://claude.ai/artifact/2vnJ4H4n17vK9C6pVXU3mW (copies in
`docs/superpowers/mockups/epic-07/`: `Main` = order form with its items, `Lookup` = config panel).

## Lookup (a third calculated mode)

- Config `{"lookup": {"referenceFieldId": "order", "fieldId": "status"}}` on the existing
  `calculated` type, next to formula / aggregate. Values are derived on read and never stored, like
  every calculated value.
- **Keeps the shown field's type (my call).** A lookup of a select yields the option *id*. Once
  `resolveLookups` has attached the shown field (`lookupTarget`, in memory only), it formats,
  filters (`anyOf` by option), sorts and gets summed as that field. Totals filtered on a lookup
  survive option renames. Formulas read the label.
- Single references only in the UI. The engine reads the first link (shortcut in `derivation.dart`).
- Resolution happens where collections are loaded: `CollectionViewsCubit._onCollections`, and the
  object editor's `getCollections`. Unresolved, the field falls back to plain text.
- `Derivation.sourcesOf` follows lookups, so views watch the collection being looked up.

## Sublists (backlinks inside the form)

- **My call: no new field type.** The form lists every collection that has a reference pointing at
  this collection (`Sublist` = collection + reference), below the card layout. Nothing to
  configure. Upgrade path: a placeable "sublist" field if the owner wants to choose which ones show
  and where.
- **Row** (`SublistRow`): follows the item's card-layout order. The first filled text, select or
  number value is the title, so a picked garment titles the row and nothing has to be typed (owner
  feedback). Other select values become pills, the first other text is a note line, and the first
  number sits on the right with its field name. The first yes/no field becomes a checkbox
  (done/not done) that writes only that key. Links, files, the back-reference and lookups through
  it are left out.
- Tap a row to open the item's form (nested). **Add** opens a new item already linked here.
  Deleting from the item form deletes the item.
- Items and the item form are derived (lookups and formulas preview live), including against this
  object's unsaved edits.
- **New object (my call):** items can be added before the object is saved. They point at its
  pre-minted id. If the object is discarded, those items are deleted again, and Discard asks first.
- Out of scope: deleting an object leaves its items (no cascade); no reordering of items.

## Done/not done

Pure data: a yes/no field on the item collection. "Done items" is an aggregate count (filter
`isTrue`) and "all done" is a formula. No engine code is involved.

## Verification

Unit tests:
- `lookup_test.dart`: reserved via a lookup filter, rename-safe.
- Sublist cubit and widget tests.
- Lookup config panel test.

E2E on web against real Firestore: an order with 3 items (rows titled by the garment, ticking
writes through), SKU reserved = 1 with the sent order excluded, and the Lookup panel compared with
the mockup.
