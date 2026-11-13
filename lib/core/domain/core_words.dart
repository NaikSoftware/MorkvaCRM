/// The few words core writes into display text itself: fallbacks, default
/// names and value formats. English by default; the app swaps in the user's
/// language through [current] (like `Intl.defaultLocale` for dates), so core
/// stays free of Flutter and of `AppLocalizations`.
class CoreWords {
  const CoreWords({
    this.untitled = 'Untitled',
    this.yes = 'Yes',
    this.no = 'No',
    this.linkedCount = _linkedCount,
    this.noValueGroup = _noValueGroup,
    this.weekOf = _weekOf,
    this.defaultViewName = 'All',
  });

  /// The words core formats with; set by the app when its locale resolves.
  static CoreWords current = const CoreWords();

  /// A card with a blank title.
  final String untitled;

  /// A Yes / No value.
  final String yes;
  final String no;

  /// A reference value whose cards aren't loaded: "2 linked".
  final String Function(int count) linkedCount;

  /// The group of cards with an empty [field]: "No Status".
  final String Function(String field) noValueGroup;

  /// A week group, from its Monday's formatted [day]: "Week of Nov 9, 2026".
  final String Function(String day) weekOf;

  /// The name of a collection's default view.
  final String defaultViewName;
}

String _linkedCount(int count) => '$count linked';
String _noValueGroup(String field) => 'No $field';
String _weekOf(String day) => 'Week of $day';
