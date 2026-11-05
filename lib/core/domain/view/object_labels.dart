import '../collection.dart';
import '../morkva_object.dart';
import '../types/text_field.dart';
import 'view_definition.dart';
import 'view_query.dart';

/// Human labels for [objects] of [target], keyed by object id, in the order of
/// [target]'s first view (or [ViewDefinition.defaultFor]) with its filters
/// cleared, so every object gets a label.
///
/// A label is the object's first text field, trimmed; blank or missing →
/// `'Untitled'`. Shared by the views (reference cells, groups, filters) and the
/// object editor (reference chips and picker).
Map<String, String> objectLabels(
  Collection target,
  List<MorkvaObject> objects,
) {
  final view =
      (target.views.firstOrNull ?? ViewDefinition.defaultFor(target.fields))
          .copyWith(filters: const []);
  final titleField = target.fields.whereType<TextFieldDefinition>().firstOrNull;
  return {
    for (final o in applyView(target, view, objects))
      o.id: switch (o[titleField?.id ?? '']) {
        TextFieldValue(:final text?) when text.trim().isNotEmpty => text.trim(),
        _ => 'Untitled',
      },
  };
}
