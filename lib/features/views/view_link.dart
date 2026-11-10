import 'dart:convert';

import '../../core/domain/domain.dart';
import '../../core/harness/harness.dart';
import '../../core/harness/input/filter_compiler.dart';
import '../../core/harness/input/ref_resolver.dart';

/// The deep link to a collection's Work surface:
/// `/collections/:id?view=<viewId>&card=<objectId>&filter=<filter param>`.
///
/// Every query parameter is optional. [view] selects that view, [filter] puts
/// transient ("From assistant") filters over it and [card] opens that card's
/// editor. The assistant's object chips and "Open as filtered view" build it
/// with this function.
String collectionLink(
  String collectionId, {
  String? view,
  String? card,
  List<Object?>? where,
}) {
  final query = {
    'view': ?view,
    'card': ?card,
    if (where != null && where.isNotEmpty) 'filter': encodeLinkFilter(where),
  };
  return Uri(
    path: '/collections/$collectionId',
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

/// The most a link's `filter` parameter may hold once decoded, in bytes.
const int maxLinkFilterBytes = 4096;

/// The `filter` parameter of a [collectionLink]: unpadded base64url of the
/// UTF-8 JSON list of friendly filters, the same shape as a tool's `where`
/// (`[{field, op, value?, relative?, n?}]`; fields, options and cards by name
/// or id).
String encodeLinkFilter(List<Object?> where) =>
    base64Url.encode(utf8.encode(jsonEncode(where))).replaceAll('=', '');

/// The filters a link's `filter` [param] stands for, compiled against
/// [collection] with the harness's strict input rules, or null when the
/// parameter is not valid. The parameter is untrusted: it is size-capped,
/// and a filter `applyView` could not evaluate (a missing operand, an
/// operator the field does not take, a card timestamp) fails the whole link,
/// so a bad link never shows more cards than it meant.
///
/// [workspace] must have its lookups resolved and hold the cards that
/// reference values may name; [today] expands relative dates.
List<ViewFilter>? parseLinkFilter(
  String param, {
  required Collection collection,
  required WorkspaceReader workspace,
  required DateTime today,
}) {
  // Each 3 bytes are 4 characters: reject an oversized one before decoding.
  if (param.isEmpty || param.length > (maxLinkFilterBytes + 2) ~/ 3 * 4) {
    return null;
  }
  final Object? where;
  try {
    final bytes = base64Url.decode(base64Url.normalize(param));
    if (bytes.length > maxLinkFilterBytes) return null;
    where = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    return null;
  }
  if (where is! List || where.isEmpty) return null;
  final List<ViewFilter> filters;
  try {
    filters = FilterCompiler(
      RefResolver(
        workspace,
        HarnessContext(
          workspaceId: '',
          actor: const Actor.user(''),
          grants: Grants.all(),
          now: today,
          today: today,
        ),
      ),
    ).compile(collection, where);
  } on HarnessException {
    return null;
  }
  for (final filter in filters) {
    final field = collection.fieldById(filter.fieldId);
    // Timestamps (`@createdAt`) have no field `applyView` could read.
    if (field == null || filterProblem(field, filter) != null) return null;
  }
  return filters;
}
