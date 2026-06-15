# Domain JSON Schema (Epic 1)

The on-disk shape produced by the core domain model (`lib/core/domain/`). This is
exactly what Epic 2 reads from and writes to Google Drive. The format is designed for
**forward compatibility**: readers tolerate unknown keys, and a `schemaVersion` is
stamped on every collection.

## Collection

```json
{
  "schemaVersion": 1,
  "id": "c_orders",
  "name": "Orders",
  "description": "optional, omitted when null",
  "fields": [ /* ordered list of Field definitions */ ]
}
```

Field order is significant (UI render order). Unknown top-level keys are ignored on read.

## Field definition

Every field shares a common envelope and adds its own config keys:

```json
{
  "id": "f_title",
  "name": "Title",
  "description": "optional, omitted when null",
  "type": "text",
  "required": false
  /* ...per-type config keys merged in here... */
}
```

`type` is the discriminator that selects the field type via `FieldTypeRegistry`. Per-type config:

| `type`          | Config keys                                                        | Stored value shape |
|-----------------|--------------------------------------------------------------------|--------------------|
| `text`          | `multiline` (bool), `maxLength` (int?)                             | `string` \| null |
| `number`        | `decimalPlaces` (int?), `unitLabel` (string?), `min`/`max` (num?)  | `number` \| null (int/double preserved) |
| `boolean`       | —                                                                  | `bool` \| null |
| `date`          | `includeTime` (bool), `min`/`max` (ISO-8601 string?)              | ISO-8601 UTC string \| null |
| `single_select` | `options`: `[{id, label, color?}]`                                | option `id` string \| null |
| `multi_select`  | `options`: `[{id, label, color?}]`                                | `[id, ...]` |
| `reference`     | `targetCollectionId` (string), `multiple` (bool)                  | `[objectId, ...]` (single ref = list ≤ 1) |
| `file`          | `multiple` (bool), `allowedExtensions` ([string]?)               | `[{id, name, mimeType?, sizeBytes?}, ...]` |
| `auto_number`   | `prefix` (string?), `padding` (int?)                              | `int` \| null (generation in Epic 6) |
| `calculated`    | `declaredOutputType` (string), `expression` (string?)            | cached value, any JSON (computation in Epic 6) |

Optional config keys are omitted when null. `select_option.color` is an optional `#RRGGBB` hint.

## Object

```json
{
  "id": "o_123",
  "collectionId": "c_orders",
  "createdAt": "2026-06-16T09:00:00.000042Z",
  "updatedAt": "2026-06-16T09:00:00.000042Z",
  "values": { "f_title": "Hello", "f_qty": 3, "f_tags": ["a", "b"] }
}
```

- Timestamps are ISO-8601 **UTC** (microsecond precision, lossless round-trip).
- `values` maps field-id → the field's stored value shape (see table). It is **normalized**
  against the collection schema: one entry per field, empty fields serialized as `null`
  (or `[]` for list-valued types).
- On read, values for fields no longer in the schema are dropped (graceful schema evolution),
  and missing values become the field's empty value.

## Guarantees

- **Round-trip identity:** a collection or object serialized and read back through the matching
  schema is `==` to the original (proven by `test/core/domain/all_field_types_integration_test.dart`).
- **Never throws on parse:** malformed-but-plausible values (e.g. a JSON `42.0` for an int, a
  wrong-typed scalar) degrade to the empty value rather than crashing.
- **Extensible:** adding a field type is a new `FieldDefinition`/`FieldValue` pair plus one
  registration line; no existing type's serialization or validation changes.
