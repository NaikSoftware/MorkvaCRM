import 'package:flutter/material.dart';

/// A thin "Warm Carrot" wrapper over the themed [AppBar].
///
/// All visual styling (background, foreground, elevation, title font) comes
/// from `AppTheme`'s [AppBarTheme] — this widget only assembles the slots so
/// screens get a consistent bar without re-specifying theme values. The [title]
/// string is rendered with [TextTheme.titleLarge] (the brand grotesque).
class MorkvaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MorkvaAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    this.bottom,
    this.centerTitle = false,
  });

  /// Bar title, rendered with [TextTheme.titleLarge].
  final String title;

  /// Optional leading widget (e.g. back button or menu); defaults to the
  /// platform/Scaffold-provided leading when null.
  final Widget? leading;

  /// Trailing actions, laid out at the end of the bar.
  final List<Widget> actions;

  /// Optional bottom widget (e.g. a [TabBar]); its height is added to
  /// [preferredSize].
  final PreferredSizeWidget? bottom;

  /// Whether to center the title. Defaults to false (start-aligned).
  final bool centerTitle;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppBar(
      leading: leading,
      title: Text(title, style: textTheme.titleLarge),
      centerTitle: centerTitle,
      actions: actions.isEmpty ? null : actions,
      bottom: bottom,
    );
  }
}
