import '../../../domain/domain.dart';
import '../../api/envelope.dart';
import '../plan.dart';
import 'plan_call.dart';

/// The view modes a plan may create, in the app's order.
const List<String> kViewModes = [
  ViewModeIds.table,
  ViewModeIds.board,
  ViewModeIds.list,
  ViewModeIds.calendar,
  ViewModeIds.summary,
];

/// Whether [mode] must have a layout field (board, calendar).
bool modeNeedsLayoutField(String mode) =>
    mode == ViewModeIds.board || mode == ViewModeIds.calendar;

/// Whether [mode] can be laid out by [field]: board and list by a groupable
/// field (single select or single link), calendar by a date field; table
/// and summary by none. Mirrors each `ViewMode.acceptsLayoutField`.
bool modeAcceptsLayoutField(String mode, FieldDefinition field) =>
    switch (mode) {
      ViewModeIds.board || ViewModeIds.list => isGroupable(field),
      ViewModeIds.calendar => field is DateFieldDefinition,
      _ => false,
    };

/// `invalid_args` (with the eligible fields as candidates) when [field]
/// does not suit [mode], or [mode] needs one and got none.
void checkLayoutField(
  Collection collection,
  String mode,
  FieldDefinition? field, {
  String path = 'layoutField',
}) {
  final eligible = [
    for (final f in collection.fields)
      if (modeAcceptsLayoutField(mode, f)) f.name,
  ];
  if (field == null) {
    if (!modeNeedsLayoutField(mode)) return;
    throw HarnessException.of(
      ErrorCode.invalidArgs,
      eligible.isEmpty
          ? 'A $mode view needs a ${_kind(mode)} field, and '
                '${collection.name} has none.'
          : 'A $mode view needs a layoutField: a ${_kind(mode)} field.',
      path: path,
      candidates: eligible,
      hint: eligible.isEmpty ? 'Add one with fields.add first.' : null,
    );
  }
  if (modeAcceptsLayoutField(mode, field)) return;
  throw HarnessException.of(
    ErrorCode.invalidArgs,
    eligible.isEmpty || !_usesLayout(mode)
        ? 'A $mode view takes no layoutField.'
        : '"${field.name}" cannot lay out a $mode view; it needs a '
              '${_kind(mode)} field.',
    path: path,
    candidates: eligible.isEmpty ? null : eligible,
  );
}

bool _usesLayout(String mode) =>
    mode == ViewModeIds.board ||
    mode == ViewModeIds.list ||
    mode == ViewModeIds.calendar;

String _kind(String mode) =>
    mode == ViewModeIds.calendar ? 'date' : 'single-select or single-link';

/// `Board · by Status`, `Table`: a view's mode tag for plan rows.
String modeTag(PlanCall call, Collection collection, ViewDefinition view) {
  final name = view.mode[0].toUpperCase() + view.mode.substring(1);
  final by = view.layoutFieldId == null
      ? null
      : collection.fieldById(view.layoutFieldId!)?.name;
  return by == null ? name : '$name · by ${call.name(by)}';
}

/// The parts of a `views.create` / `views.update` call, resolved against
/// [collection]: filters, sort, shown fields and the layout field.
({
  List<ViewFilter>? filters,
  ViewSort? sort,
  List<String>? fieldIds,
  FieldDefinition? layout,
})
_viewArgs(Map<String, Object?> args, Collection collection, PlanCall call) {
  final refs = call.resolver();
  final compiler = call.compiler();
  final where = args['where'];
  final sort = args['sort'];
  final fields = args['fields'];
  final layout = args['layoutField'];
  return (
    filters: where == null
        ? null
        : compiler.compile(collection, listArg<Object?>(where, 'where')),
    sort: sort == null
        ? null
        : compiler.compileSort(collection, mapArg(sort, 'sort')),
    fieldIds: fields == null
        ? null
        : <String>{
            for (final (i, ref) in listArg<String>(fields, 'fields').indexed)
              refs.field(collection, ref, path: 'fields[$i]').id,
          }.toList(),
    layout: layout is String
        ? refs.field(collection, layout, path: 'layoutField')
        : null,
  );
}

/// `views.create {collection, name, mode, where?, sort?, fields?,
/// layoutField?}`: one `createView` appended to the views.
Future<void> planViewsCreate(Map<String, Object?> args, PlanCall call) async {
  final collection = call.collection(args['collection']! as String);
  await call.leased([collection.id], () async {
    final schema = call.schemaOf(collection.id);
    final name = (args['name']! as String).trim();
    if (name.isEmpty) throw invalidArgs('A view needs a name.', path: 'name');
    final mode = args['mode']! as String;
    final parts = _viewArgs(args, schema, call);
    checkLayoutField(schema, mode, parts.layout);
    final view = ViewDefinition(
      id: call.ids.viewId(),
      name: name,
      mode: mode,
      layoutFieldId: parts.layout?.id,
      fieldIds:
          parts.fieldIds ?? ViewDefinition.defaultFor(schema.fields).fieldIds,
      filters: parts.filters ?? const [],
      sort: parts.sort,
    );
    call.changes.putDraft(schema.copyWith(views: [...schema.views, view]));
    call.add(
      CreateViewItem(
        itemId: call.nextItemId(),
        callId: call.callId,
        collectionId: schema.id,
        label: call.name(name),
        risk: Risk.low,
        view: view,
        index: schema.views.length,
        detail: modeTag(call, schema, view),
        dependsOn: call.dependencies(schema.id, fieldIds: _fieldsOf(view)),
      ),
    );
    call.title('Create view ${call.quoted(name)} in ${call.name(schema.name)}');
  });
}

/// `views.update {collection, view, name?, mode?, where?, sort?, fields?,
/// layoutField?}`: one `updateView`. `where` replaces the view's filters;
/// a mode change re-checks the layout field (dropped when the new mode
/// takes none, required when it needs one).
Future<void> planViewsUpdate(Map<String, Object?> args, PlanCall call) async {
  final collection = call.collection(args['collection']! as String);
  await call.leased([collection.id], () async {
    final schema = call.schemaOf(collection.id);
    final before = call.resolver().view(
      schema,
      args['view']! as String,
      path: 'view',
    );
    final mode = args['mode'] as String? ?? before.mode;
    final parts = _viewArgs(args, schema, call);
    var layout = parts.layout;
    if (layout == null && args['layoutField'] == null) {
      final current = before.layoutFieldId == null
          ? null
          : schema.fieldById(before.layoutFieldId!);
      if (current != null && modeAcceptsLayoutField(mode, current)) {
        layout = current;
      }
    }
    checkLayoutField(schema, mode, layout);
    String? name;
    if (args['name'] case final String raw) {
      name = raw.trim();
      if (name.isEmpty) throw invalidArgs('A view needs a name.', path: 'name');
    }
    final after = before.copyWith(
      name: name,
      mode: mode,
      layoutFieldId: layout?.id,
      filters: parts.filters,
      sort: parts.sort ?? before.sort,
      fieldIds: parts.fieldIds,
    );
    if (after == before) return;
    call.changes.putDraft(
      schema.copyWith(
        views: [for (final v in schema.views) v.id == before.id ? after : v],
      ),
    );
    call.add(
      UpdateViewItem(
        itemId: call.nextItemId(),
        callId: call.callId,
        collectionId: schema.id,
        label: call.name(before.name),
        risk: Risk.medium,
        before: before,
        after: after,
        index: schema.views.indexOf(before),
        detail: modeTag(call, schema, after),
        changes: _viewChanges(call, schema, before, after),
        dependsOn: call.dependencies(schema.id, fieldIds: _fieldsOf(after)),
      ),
    );
    call.title(
      'Change view ${call.quoted(before.name)} in ${call.name(schema.name)}',
    );
  });
}

/// `views.delete {collection, view}`: one `deleteView`; the last view of a
/// collection cannot go (`last_view`).
Future<void> planViewsDelete(Map<String, Object?> args, PlanCall call) async {
  final collection = call.collection(args['collection']! as String);
  final schema = call.schemaOf(collection.id);
  final view = call.resolver().view(
    schema,
    args['view']! as String,
    path: 'view',
  );
  if (schema.views.length <= 1) {
    throw HarnessException.of(
      ErrorCode.lastView,
      '${call.quoted(view.name)} is the only view of ${schema.name}; a '
      'collection keeps at least one.',
      path: 'view',
      hint: 'Create another view first, or change this one with views.update.',
    );
  }
  call.changes.putDraft(
    schema.copyWith(
      views: [
        for (final v in schema.views)
          if (v != view) v,
      ],
    ),
  );
  call.add(
    DeleteViewItem(
      itemId: call.nextItemId(),
      callId: call.callId,
      collectionId: schema.id,
      label: call.name(view.name),
      risk: Risk.medium,
      before: view,
      index: schema.views.indexOf(view),
      detail: modeTag(call, schema, view),
      dependsOn: call.dependencies(schema.id),
    ),
  );
  call.title(
    'Delete view ${call.quoted(view.name)} from ${call.name(schema.name)}',
  );
}

Iterable<String> _fieldsOf(ViewDefinition v) => {
  ...v.fieldIds,
  ?v.layoutFieldId,
  for (final f in v.filters) f.fieldId,
  if (v.sort case final s? when !s.isPseudo) s.fieldId,
};

List<FieldChange> _viewChanges(
  PlanCall call,
  Collection schema,
  ViewDefinition before,
  ViewDefinition after,
) {
  String? field(String? id) =>
      id == null ? null : call.name(schema.fieldById(id)?.name ?? id);
  String? sort(ViewSort? s) => s == null
      ? null
      : '${s.isPseudo ? s.fieldId : field(s.fieldId)} '
            '${s.ascending ? 'ascending' : 'descending'}';
  String filters(List<ViewFilter> fs) => fs.isEmpty
      ? 'none'
      : [for (final f in fs) '${field(f.fieldId)} ${f.op.name}'].join(', ');
  String fields(List<String> ids) => ids.map(field).join(', ');
  return [
    if (before.name != after.name)
      FieldChange(
        field: 'Name',
        before: before.name,
        after: after.name,
        beforeText: call.name(before.name),
        afterText: call.name(after.name),
      ),
    if (before.mode != after.mode)
      FieldChange(
        field: 'Mode',
        before: before.mode,
        after: after.mode,
        beforeText: before.mode,
        afterText: after.mode,
      ),
    if (before.layoutFieldId != after.layoutFieldId)
      FieldChange(
        field: 'Laid out by',
        before: before.layoutFieldId,
        after: after.layoutFieldId,
        beforeText: field(before.layoutFieldId),
        afterText: field(after.layoutFieldId),
      ),
    if (!jsonEquals(
      [for (final f in before.filters) f.toJson()],
      [for (final f in after.filters) f.toJson()],
    ))
      FieldChange(
        field: 'Filters',
        before: [for (final f in before.filters) f.toJson()],
        after: [for (final f in after.filters) f.toJson()],
        beforeText: call.name(filters(before.filters)),
        afterText: call.name(filters(after.filters)),
      ),
    if (before.sort != after.sort)
      FieldChange(
        field: 'Sort',
        before: before.sort?.toJson(),
        after: after.sort?.toJson(),
        beforeText: sort(before.sort),
        afterText: sort(after.sort),
      ),
    if (!jsonEquals(before.fieldIds, after.fieldIds))
      FieldChange(
        field: 'Fields',
        before: before.fieldIds,
        after: after.fieldIds,
        beforeText: call.name(fields(before.fieldIds)),
        afterText: call.name(fields(after.fieldIds)),
      ),
  ];
}
