import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';
export 'core_labels.dart';

/// English, for contexts with no localizations delegate (bare test harnesses).
final _english = lookupAppLocalizations(const Locale('en'));

extension L10nContext on BuildContext {
  /// The app's strings in the current locale.
  AppLocalizations get l10n => AppLocalizations.of(this) ?? _english;
}

/// The app's strings in the language it resolved last (`Intl.defaultLocale`,
/// set by the app), for text written outside a widget; English when unset
/// or unsupported.
AppLocalizations currentAppStrings() {
  final code = Intl.shortLocale(Intl.getCurrentLocale());
  final known = AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == code,
  );
  return lookupAppLocalizations(Locale(known ? code : 'en'));
}
