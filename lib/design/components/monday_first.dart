import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Makes the date pickers below [child] start weeks on Monday, like the
/// calendar month grid, so every calendar in the app agrees.
// shortcut: Monday is fixed and the strings are the default English ones;
// follow MaterialLocalizations.firstDayOfWeekIndex once the app has locales.
class MondayFirst extends StatelessWidget {
  const MondayFirst({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Localizations.override(
    context: context,
    delegates: const [_MondayFirstDelegate()],
    child: child,
  );
}

class _MondayFirstLocalizations extends DefaultMaterialLocalizations {
  const _MondayFirstLocalizations();

  @override
  int get firstDayOfWeekIndex => 1;
}

class _MondayFirstDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _MondayFirstDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture(const _MondayFirstLocalizations());

  @override
  bool shouldReload(_MondayFirstDelegate old) => false;
}
