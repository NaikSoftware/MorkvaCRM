import 'table_mode.dart';
import 'view_mode.dart';

/// The modes shipped with the app, in picker order. Table comes first: it is
/// the fallback for unknown mode ids. Add a mode with one line here.
ViewModeRegistry defaultViewModeRegistry() =>
    ViewModeRegistry(const [TableMode()]);
