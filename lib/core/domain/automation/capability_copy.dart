/// The plain words for every capability a module may ask for: the one source
/// of permission copy for the consent sheet, module details, the assistant
/// preview and `docs/sdk/manifest.md` (UX spec §2).
///
/// The keys are exactly the wires a manifest may list (`kModuleGrantable` in
/// the harness), in display order; the manifest parser uses them as its
/// capability allowlist.
const Map<String, ({String title, String explanation})> kCapabilityCopy = {
  'schema:read': (
    title: 'See your collections and fields',
    explanation: 'Reads collection and field names and types.',
  ),
  'data:read': (
    title: 'Read cards',
    explanation: 'Reads card values in the allowed collections.',
  ),
  'data:write': (
    title: 'Create and change cards',
    explanation: 'Proposes new cards and edits.',
  ),
  'data:delete': (
    title: 'Delete cards',
    explanation: 'Proposes deleting cards. Never applied automatically.',
  ),
  'schema:write': (
    title: 'Change collections and fields',
    explanation:
        'Proposes new fields or field changes. Never applied automatically.',
  ),
  'schema:delete': (
    title: 'Delete fields and collections',
    explanation:
        'Proposes deleting fields or collections. Never applied automatically.',
  ),
  'views:write': (
    title: 'Change views',
    explanation:
        'Proposes view changes — filters, sort, columns. Never applied '
        'automatically.',
  ),
  'ui:navigate': (
    title: 'Link to cards',
    explanation: 'Shows links that open a card or view when you tap them.',
  ),
};

/// The capabilities that keep a module's changes out of auto-apply: a
/// manifest asking for any of them always waits for review (Apply policy).
const Set<String> kReviewOnlyCapabilities = {
  'data:delete',
  'schema:write',
  'schema:delete',
  'views:write',
};
