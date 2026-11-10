import '../api/capability.dart';
import '../api/envelope.dart';
import '../api/harness_context.dart';
import '../api/operation.dart';
import '../query/query_engine.dart';
import '../schema/arg_shapes.dart';
import '../schema/json_schema.dart';
import 'registry.dart';

/// Registers the UI op: `ui.open`.
///
/// `ui.open` validates what to show (collection, view, card, filters) and
/// returns a chip: `{shown, collectionId, viewId?, cardId?, where?, label,
/// summary}`. It never navigates: the host renders the chip and calls its
/// `UiPort` (`ui_port.dart`) with those keys when the user taps it, so the
/// model never yanks the screen.
void registerUiOps(OperationRegistry ops, {required QueryEngine queries}) =>
    ops.register(_UiOpen(queries));

typedef _Json = Map<String, Object?>;

final class _UiOpen extends Operation<_Json> {
  _UiOpen(this._queries);

  final QueryEngine _queries;

  @override
  OperationDescriptor get descriptor => _descriptor;

  @override
  _Json decode(_Json args, HarnessContext ctx) => args;

  @override
  Future<OpResult> run(_Json args, HarnessContext ctx, HarnessRequest r) async {
    final result = await _queries.withScope(args, ctx, (scope) async {
      final collection = scope.collection;
      final shaper = _queries.shaper;
      final view = switch (args['view']) {
        final String ref => scope.refs.view(collection, ref),
        _ => null,
      };
      final cardId = switch (args['card']) {
        final String ref => scope.refs.card(collection, ref),
        _ => null,
      };
      final where = args['where'] as List?;
      // Validated now so a bad filter fails here, not on the user's tap.
      if (where != null) scope.compiler.compile(collection, where);

      final name = shaper.name(collection.name);
      final card = cardId == null
          ? null
          : _queries.cache.current(collection.id)?[cardId];
      final label = card != null
          ? shaper.title(collection, card)
          : [
              name,
              if (view != null) ' › ${shaper.name(view.name)}',
              if (where != null) ' (filtered)',
            ].join();
      return {
        'shown': true,
        'collectionId': collection.id,
        if (view != null) 'viewId': view.id,
        'cardId': ?cardId,
        'where': ?where,
        'label': label,
        'summary': 'Linked $label',
      };
    });
    return OpResult(result);
  }
}

final OperationDescriptor _descriptor = OperationDescriptor(
  id: 'ui.open',
  kind: OpKind.ui,
  capability: Capability.uiNavigate,
  summary:
      'Posts a chip that opens a collection, a view, a card or a filtered '
      'list when the user taps it. "@card" is the open card.',
  argsSchema: JsonSchema.object({
    'collection': refSchema(description: 'A collection id or name.'),
    'from': JsonSchema.enumOf(const [
      '@screen',
    ], description: 'The collection on screen, instead of "collection".'),
    'view': refSchema(description: 'A view id or name.'),
    'card': refSchema(description: 'A card id or title, or "@card".'),
    'where': whereSchema(),
  }),
  resultSchema: JsonSchema.object(
    {
      'shown': JsonSchema.boolean(),
      'collectionId': JsonSchema.string(),
      'viewId': JsonSchema.string(),
      'cardId': JsonSchema.string(),
      'where': whereSchema(),
      'label': JsonSchema.string(),
      'summary': JsonSchema.string(),
    },
    required: ['shown', 'collectionId', 'label', 'summary'],
  ),
);
