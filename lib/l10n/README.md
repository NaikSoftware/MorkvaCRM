# Localization

English (`app_en.arb`, the template) and Ukrainian (`app_uk.arb`). The app follows the device
language; anything other than Ukrainian gets English. Generated with `flutter gen-l10n`
(`l10n.yaml`); `flutter run`/`build` regenerate it, the generated files are committed for
`flutter analyze`.

## Using strings

- `context.l10n.someKey` (`lib/l10n/l10n.dart`). It falls back to English when no delegate is in
  the tree, so bare `MaterialApp` test harnesses keep working.
- Keys are lowerCamel with an area prefix (`collections…`, `views…`, `automation…`). Shared
  wording lives in `common…` keys (`commonCancel`, `commonCardCount`, …): reuse them.
- One message per whole sentence, with placeholders. Never glue translated fragments together and
  never pluralize with `'s'`: use ICU `plural` (Ukrainian needs `one`, `few`, `many`, `other`).
- `lib/core` is pure Dart and can't read `AppLocalizations`: it returns structured values (enums,
  records) that the feature layer words, or takes the strings as parameters. Dates in core use
  `DateFormat` from `package:intl`; the app sets `Intl.defaultLocale`.

**Translate** what a user sees or hears: text, labels, hints, tooltips, semantic labels,
snackbars, dialogs, empty states, errors we write, and default names created for the user.
**Keep in English**: anything the model reads (`lib/core/harness`, prompts, tool declarations),
messages for module developers (manifest/protocol errors), logs, `toString`, Firestore keys, route
paths, strings compared in code, brand names (Google, Trello, Morkva CRM) and raw Firebase/network
error text (shown as is).

## Ukrainian style

- Address the user with lowercase «ви». Buttons and menu items are infinitives: «Зберегти»,
  «Додати поле». Sentence case only — never Title Case.
- Apostrophe `’` (U+2019, never ASCII `'`), quotes «», ellipsis `…`, dash ` — ` with spaces.
- Ukrainian runs 20–30 % longer: keep buttons, chips and tabs short.
- Inserted user text stays in the nominative: «Колекцію «{name}» видалено», «Поле: {name}». Avoid
  agreement with a placeholder of unknown gender — rephrase instead.
- No calques: «наразі» (not «на даний момент»), «збігатися» (not «співпадати»), «правильний»
  (not «вірний»), «наступний» (not «слідуючий»), «за замовчуванням», «протягом» (not «на
  протязі»), «скасувати» (not «відмінити»), «є» (not «являється»), «брати участь».

## Glossary

| English | Українська |
|---|---|
| collection | колекція |
| card | картка |
| field | поле |
| view (of a collection) | подання |
| table / board / calendar / list | таблиця / дошка / календар / список |
| group, group by | група, групувати за |
| filter / sort | фільтр / сортування |
| workspace | робочий простір |
| template | шаблон |
| pin / unpin / pinned | закріпити / відкріпити / закріплені |
| calculated field / formula | обчислюване поле / формула |
| reference (field type) / link, linked cards | посилання / пов’язати, пов’язані картки |
| backlinks | зворотні посилання |
| single select / multi-select / option | вибір / множинний вибір / варіант |
| tag / label (Trello) | тег / мітка |
| checkbox (field type) | прапорець |
| auto number | автонумерація |
| file / attachment | файл / вкладення |
| required | обов’язкове |
| automation / module / trigger | автоматизація / модуль / тригер |
| run (noun) / run (verb) | запуск / запустити |
| button (automation) | кнопка |
| permission / grant access | дозвіл / надати доступ |
| Ask Morkva / Morkva (assistant) | Запитати Моркву / Морква (declined: Моркви, Моркву) |
| Morkva CRM (app name) | Morkva CRM; «Morkva» meaning the app → «застосунок» |
| thread (chat) / message | розмова / повідомлення |
| sync / offline / conflict | синхронізація / офлайн / конфлікт |
| sign in / sign out | увійти / вийти |
| import / export | імпорт / експорт |
| delete / remove / archive / restore | видалити / прибрати / архівувати / відновити |
| cancel / undo | скасувати / скасувати (on one surface: undo = «Повернути») |
| untitled | без назви |
