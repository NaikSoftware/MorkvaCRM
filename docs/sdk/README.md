# Morkva module SDK

A **module** is a small JavaScript program that adds actions to Morkva: a
button on a card, a button on a collection, or something that happens when a
card is created, updated or deleted. An **automation** binds one module action
to one of those triggers, with its own settings.

A module never writes data itself. It reads cards through `morkva.call`, plans
changes the same way, and returns. Morkva then shows the changes for review
or, when the user allowed it, applies them. Every run is logged.

- [manifest.md](manifest.md): the manifest, permissions, the file format, and
  when changes are applied without asking.
- [api.md](api.md): `morkva`, the action context, every op you can call, error
  codes and limits (generated from the app).
- [morkva.d.ts](morkva.d.ts): TypeScript declarations for editors and type
  checking.
- [examples/](examples): three complete modules.

## Quick start

This walks through [examples/stamp-shipped-date](examples/stamp-shipped-date),
which fills an order's "Shipped on" date with today's date.

### 1. Write the code

`module.js`:

```js
morkva.action('stamp', async (input, ctx) => {
  const card = ctx.card;
  // A CardRef (no values) means the run lacks data:read.
  if (!card || !('values' in card)) return 'No card to stamp';
  const field = input.dateField;
  const name = card.fields[field] || field;
  if (card.values[field] !== undefined) {
    return `${name} is already set on ${card.title}`;
  }
  await morkva.call('cards.update', {
    collection: card.collectionId,
    target: { ids: [card.id] },
    set: { [field]: ctx.today },
  });
  return `Set ${name} to ${ctx.today} on ${card.title}`;
});
```

- `morkva.action(id, handler)` registers an action. Call it at the top level
  of the script, never later.
- `input` holds the automation's settings (here, which date field to fill).
- `ctx.card` is the card the button was pressed on, or the card the event is
  about. `values` maps field ids to display values; an empty field has no key.
- `cards.update` does not change the card yet: it **plans** the change. The
  runtime collects everything the action planned into one plan.
- The returned string is the run's summary, shown when the run finishes.

### 2. Write the manifest

`manifest.json` names the module, the permissions it needs and its actions:

```json
{
  "id": "stamp-shipped-date",
  "name": "Stamp shipped date",
  "version": "1.0.0",
  "apiVersion": 2,
  "permissions": { "capabilities": ["schema:read", "data:read", "data:write"] },
  "actions": [
    {
      "id": "stamp",
      "label": "Stamp today",
      "scope": "card",
      "input": {
        "type": "object",
        "required": ["dateField"],
        "properties": {
          "dateField": { "type": "string", "title": "Date field", "format": "field" }
        }
      }
    }
  ]
}
```

`"format": "field"` makes the automation editor show a field picker for that
setting. Everything else is in [manifest.md](manifest.md).

### 3. Bundle it (only for more than one file)

A module is loaded as **one classic script**: no `import` / `export`, no
top-level `await`. A single file like the one above needs no bundling. If you
split your code or use npm packages, bundle it into one IIFE:

```sh
npx esbuild src/index.js --bundle --format=iife --target=es2020 --outfile=module.js
```

### 4. Wrap it as a `.morkva.json` file

The app imports one file that holds the manifest and the code. This Node
script (`bundle.mjs`) writes it:

```js
// node bundle.mjs <module dir>  →  <dir>/<id>.morkva.json
import { readFileSync, writeFileSync } from 'node:fs';

const dir = process.argv[2];
const manifest = JSON.parse(readFileSync(`${dir}/manifest.json`, 'utf8'));
const code = readFileSync(`${dir}/module.js`, 'utf8');
writeFileSync(
  `${dir}/${manifest.id}.morkva.json`,
  JSON.stringify({ morkva: 1, manifest, code }, null, 2),
);
```

Every example folder already has its `.morkva.json`, built exactly this way.

### 5. Import and allow it

In Morkva open **Automations**, then **Import module**, and choose the file
(or paste its text). The consent sheet lists what the module asks for in plain
words and asks **where** it may work: all collections, or only the ones you
tick. Nothing is preselected. **Allow and install** saves the module.

The consent covers this exact code and manifest. If either changes, the module
asks again before it runs.

### 6. Bind an action

From the module's page (or Automations, **New automation**), pick the action,
then the trigger:

- **Button on a card** or **button on a collection**: the button appears on
  the card editor or in the collection's Actions menu.
- **When a card is created / updated / deleted**: with conditions such as
  "Status is Shipped". "Updated" fires when the card starts matching the
  conditions, or on every matching change if you choose so.

Then fill the action's settings (the `input` of the manifest) and choose
**Ask first** (the default) or **Apply automatically** (see
[manifest.md](manifest.md#apply-policy)).

**Test run** on the module page runs an action against a card without saving
anything, and shows the plan and the log.

### 7. Run it and read the log

Press the button. When the action returns, you review the plan (or it is
applied, for Auto). **Automations → Runs** lists every run; a run shows its
trigger, every `morkva.call` with its result, the console lines, the plan and
the outcome. Undo works on applied runs for 10 minutes in the same session.

## Rules of the runtime

**Guaranteed globals.** Only these exist on every device:

- the ES2020 built-ins (`Object`, `Array`, `Map`, `Set`, `Promise`, `JSON`,
  `Math`, `Date`, `RegExp`, …). `Intl` is **not** guaranteed: Android and iOS
  lack it;
- `morkva` (frozen; see [api.md](api.md));
- `console.log` / `info` / `warn` / `error` / `debug`, written to the run log;
- `setTimeout` / `clearTimeout`: at most 100 pending, they fire only while the
  run lives. There is no `setInterval`.

Anything else an engine happens to have may be missing on the next one.

**No network, no eval.** `fetch`, `XMLHttpRequest`, `WebSocket`,
`importScripts`, `import()`, `eval`, `new Function` and WebAssembly do not
work. A module reaches data only through `morkva.call`, inside its consent.

**Keep the JS responsive.** A stretch of synchronous code between two `await`s
may take up to 1 s. On Android and iOS a longer one is stopped and the run
fails `limit_exceeded`, and `try` / `catch` cannot catch it. Split long loops
with `await`. A run has 20 s by default (`timeoutMs`, up to 60 s).

**Nothing survives a run.** Every run gets a fresh sandbox, which is thrown
away when the action returns. Keep state in cards.

**One plan per run.** All plan calls of a run become one plan, applied
together after the action returns. A failed plan call fails the whole run
(even if you catch it) and nothing is applied, except `no_change`, which only
says the change was already there. Check before you plan.

**Trigger time vs execution time.** `ctx.card` and the trigger's `before` /
`after` are the card as it was when the trigger fired. Your reads see the data
when the action runs, which can be later when runs queue up. A plan built on a
stale assumption fails its stale check instead of overwriting a newer change.

**Plain text.** Summaries, progress labels and log lines are shown as plain
text, never as links or markdown, and cut to their limits. To link to cards,
use `ui.open` (needs `ui:navigate`).

## Known gaps

- Only changes made in Morkva on the same device fire events. Changes from
  another device, a teammate or the Firebase console fire nothing.
- An offline delete, or a change whose save is confirmed only after the app
  restarts, fires nothing. One confirmed later in the same session fires late.
- A calculated value that changes because *another* card changed is not an
  event.
- Deleting a collection fires no `card.deleted` for its cards.
- A save that fails fires nothing, and undo fires nothing.
- Runs pending review live in the open app: after a reload they expire and
  offer **Run again**.

## Type checking

`morkva.d.ts` declares the globals above, the action context and one
`morkva.call` overload per op, so a wrong op name or argument is a type error.
Use it from JavaScript with a `jsconfig.json`, or from TypeScript:

```json
{
  "compilerOptions": {
    "lib": ["es2020"],
    "types": [],
    "checkJs": true,
    "strict": true,
    "noEmit": true
  },
  "files": ["morkva.d.ts", "module.js"]
}
```

Leave out the DOM library: those globals do not exist in a module, and its
`console` and timers clash with the declarations.

## Examples

| Example | Shows |
|---|---|
| [stamp-shipped-date](examples/stamp-shipped-date) | A card action that fills a date field (a `format: field` setting). Bind it to a card button, or to "card updated" when Status enters Shipped. |
| [copy-order-total](examples/copy-order-total) | Reading a link and a calculated total, then planning an update in **another** collection, picked by a `format: collection` setting (link values hold card ids only) and which the consent must include. Catching `no_change`. |
| [low-stock-flag](examples/low-stock-flag) | A collection action: one `cards.query` (paged with `cards.page`), the button's visible cards from `ctx.trigger.cardIds`, progress, and one bulk `cards.update`. |

The app's tests run each example through the real sandbox on the web and on
QuickJS (Android and iOS) against a sample workspace.
