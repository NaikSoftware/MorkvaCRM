import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// English, for contexts with no localizations delegate (bare test harnesses).
final _english = lookupAppLocalizations(const Locale('en'));

extension L10nContext on BuildContext {
  /// The app's strings in the current locale.
  AppLocalizations get l10n => AppLocalizations.of(this) ?? _english;
}
