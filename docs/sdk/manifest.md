# The module manifest

Every module has a manifest: its name, the permissions it asks for, and its
actions. Morkva checks it strictly. An unknown key at any level, an unknown
capability or a value out of range is refused, and the import lists every
problem at once (`actions[0].input.properties.days.default: Doesn't match the
input's type.`). The manifest is checked again before every run, so a module
whose stored manifest no longer passes is shown as broken and does not run.

## Example

```json
{
  "id": "low-stock-flag",
  "name": "Flag low stock",
  "version": "1.0.0",
  "description": "Ticks a checkbox on every product whose stock is below a threshold.",
  "author": "SDK example",
  "apiVersion": 2,
  "timeoutMs": 20000,
  "permissions": {
    "capabilities": ["schema:read", "data:read", "data:write"]
  },
  "actions": [
    {
      "id": "flagLow",
      "label": "Flag low stock",
      "scope": "collection",
      "icon": "flag",
      "input": {
        "type": "object",
        "required": ["stockField", "flagField", "below"],
        "properties": {
          "stockField": { "type": "string", "title": "Stock field", "format": "field" },
          "flagField": { "type": "string", "title": "Checkbox to tick", "format": "field" },
          "below": { "type": "number", "title": "Below", "minimum": 0, "default": 20 }
        }
      }
    }
  ]
}
```

## Keys

| Key | Required | Rules |
|---|---|---|
| `id` | yes | 3–40 characters: lowercase letters, digits and dashes, starting with a letter. Identifies the module in the workspace: importing a file with the same `id` offers to replace it. |
| `name` | yes | 1–60 characters. Shown everywhere the module is. |
| `version` | yes | `major.minor.patch`, each part 1–4 digits (`1.0.0`). |
| `description` | | Up to 500 characters. |
| `author` | | Up to 80 characters. |
| `apiVersion` | yes | Must be `2`. |
| `timeoutMs` | | How long one run may take: 1000–60000, default 20000. The run is stopped (`timed_out`) when it is over. |
| `permissions.capabilities` | yes | At least one capability from the table below, each once. |
| `actions` | yes | 1–20 actions. |

**Reserved names.** `name` and `author` may not contain "morkva" or
"assistant" in any case: a module must never read as the app or as Ask
Morkva.

### Actions

| Key | Required | Rules |
|---|---|---|
| `id` | yes | Up to 40 letters, digits or underscores, starting with a letter; unique in the module. The id your code passes to `morkva.action`. |
| `label` | yes | 1–40 characters: the button text. |
| `description` | | Up to 300 characters. |
| `scope` | yes | `card`: card buttons and card events. `collection`: collection buttons only. `any`: both. |
| `icon` | | A collection icon id: `cards`, `grid`, `box`, `truck`, `cart`, `bag`, `tag`, `people`, `person`, `business`, `store`, `money`, `receipt`, `calendar`, `task`, `folder`, `note`, `star`, `flag`, `home`, `car`, `build`, `pets`, `restaurant`. |
| `input` | | The action's settings, filled in per automation (below). |

### Action input

`input` is a JSON Schema object with up to 12 properties. The automation
editor renders it as a form, validates the values when the automation is
saved and again when it runs, and passes them as the action's `input` with the
defaults filled in.

| Key | Rules |
|---|---|
| `type` | `"object"`; may be left out. An empty `input: {}` means no settings. |
| `required` | Names of properties the user must fill in. |
| `properties.<name>.type` | `string`, `number`, `integer` or `boolean`. |
| `properties.<name>.title` | Up to 40 characters: the form label. |
| `properties.<name>.description` | Up to 200 characters: the help text. |
| `properties.<name>.enum` | String inputs only: 1–30 allowed values (a dropdown). |
| `properties.<name>.minimum` / `maximum` | Number and integer inputs only. |
| `properties.<name>.default` | Must match the type, the `enum` and the bounds. |
| `properties.<name>.format` | String inputs only. `field`: a picker of the trigger collection's fields, stores the field id. `collection`: a picker of the collections the module is allowed in, stores the collection id. |

## Capabilities

What a module may do is the intersection of what its manifest asks for and
what the user allowed. The consent sheet shows each capability in these words:

| Capability | Shown as | Meaning |
|---|---|---|
| `schema:read` | See your collections and fields | Reads collection and field names and types. |
| `data:read` | Read cards | Reads card values in the allowed collections. |
| `data:write` | Create and change cards | Proposes new cards and edits. |
| `data:delete` | Delete cards | Proposes deleting cards. Never applied automatically. |
| `schema:write` | Change collections and fields | Proposes new fields or field changes. Never applied automatically. |
| `schema:delete` | Delete fields and collections | Proposes deleting fields or collections. Never applied automatically. |
| `views:write` | Change views | Proposes view changes — filters, sort, columns. Never applied automatically. |
| `ui:navigate` | Link to cards | Shows links that open a card or view when you tap them. |

- `data:write` and `data:delete` need `data:read`; `schema:write`,
  `schema:delete` and `views:write` need `schema:read`. A module cannot plan
  blind; a missing prerequisite is an error, not added for you.
- `*`, `host:commit`, `modules:read`, `modules:write` and `automations:write`
  are refused (`not_grantable`): a module can never apply its own changes,
  install or change modules, or bind automations. There is no network
  permission.
- Each op in [api.md](api.md#operations) names the capability it needs.

## Permission model

```
effective grants of a run =
  capabilities: manifest ∩ what a module may hold ∩ the consent
  collections:  the consent's collections ∩ the automation's collections
```

- **Consent is per person and per bundle.** It records the exact manifest and
  code it was given for (the bundle hash below), the capabilities, the
  collections ("All collections" or a list), and whether changes may apply
  automatically. A different bundle has no consent until the user allows it
  again; until then its automations show "Needs consent" and their runs are
  skipped.
- **Collections.** A module sees and plans changes only in its collections.
  Outside them every op answers the same `not_permitted` "Collection not
  available to this module", whether the collection exists or not. Links into
  other collections show no titles. Calculated values that read other
  collections are left out of `ctx.card`. The trigger collection of an
  automation must be one of the module's collections.
- **Change access / revoke.** The module page can change the collections or
  revoke the consent. Revoking skips queued runs and rejects pending reviews.
- **Uninstall** removes the module, its automations and its consent. Run
  history stays.
- Modules made by Ask Morkva follow the same rules: the assistant's install is
  a plan the user approves, and it never turns on automatic apply.

## Apply policy

A module only plans. When the action returns, the runtime seals its plan and
decides:

- **Button runs and Run again** open the review now, unless the automation
  applies automatically.
- **Event runs** wait in **Needs review** (the indicator in the sidebar).
- The editor offers **Apply automatically** only when the module's
  auto-apply switch is on and its manifest asks for none of `data:delete`,
  `schema:write`, `schema:delete`, `views:write`.
- **Automatic apply** happens only when all of these hold; otherwise the plan
  goes to review and the run log says which check failed:
  - the automation is set to **Apply automatically** by the signed-in person;
  - that person turned on auto-apply for the module (the module page's switch,
    the only place that can), and the consent still matches this exact
    bundle;
  - the plan has at most 20 items, every one a low-risk card create or update
    that clears no value, inside the effective grants (deletes, schema and
    view changes always wait for review);
  - the workspace has applied fewer than 1,000 items automatically in the last
    10 minutes.
- **Approving a review** re-checks the live consent and the code: if either
  changed since the run, nothing is applied ("This module's permissions
  changed — run it again").
- Reviews are kept in the open app: they expire after a reload (or 8 hours)
  and offer **Run again**, which re-runs the action on the current card.
- Applying needs a connection. Undo works for 10 minutes in the same session.

## The `.morkva.json` file

Import and export use one JSON file:

```json
{ "morkva": 1, "manifest": { … }, "code": "morkva.action('stamp', …);" }
```

- `morkva` is the file format version, `1`. No other top-level keys.
- `code` is the whole module source as one string, loaded as a classic
  script (bundle it as an IIFE, see the [README](README.md#3-bundle-it-only-for-more-than-one-file)).
- Limits: code up to 256 KB (UTF-8), the manifest up to 16 KB, the file up to
  300 KB.
- The README has a ten-line Node script that writes this file from
  `manifest.json` and `module.js`.

**The bundle hash** pins a consent to one bundle:

```
sha256:<hex of sha256(utf8(canonicalJson(manifest) + "\n" + code))>
```

`canonicalJson` writes object keys sorted at every level, with no whitespace
and whole numbers without a decimal point. The hash covers the manifest too:
a new name, action, scope or timeout asks for consent again, just like new
code.

## Versioning and re-consent

- Bump `version` with every change you ship. Importing a module whose `id` is
  installed replaces it after a new consent: the sheet shows "Code changed:
  v1.0.0 → v1.1.0" and what changed in the permissions.
- A replaced bundle keeps its automations; they run again once the new bundle
  is allowed. Auto-apply turns off for the new version until it is turned on
  again on the module page. Reviews still pending from the old code are
  rejected (`code_changed`).
- An automation whose action, setting or field no longer exists is shown as
  broken until it is edited.
