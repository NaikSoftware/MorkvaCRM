import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';

void main() {
  final full = ScreenContext(
    page: ScreenPage.collection,
    collectionId: 'c_orders',
    viewId: 'v_unpaid',
    viewName: 'Unpaid',
    mode: 'board',
    filters: const [
      ViewFilter(fieldId: 'f_paid', op: FilterOp.isFalse),
      ViewFilter(fieldId: 'f_status', op: FilterOp.anyOf, operand: ['o_new']),
    ],
    search: 'melnyk',
    sort: const ViewSort(fieldId: 'f_total', ascending: false),
    groupByFieldId: 'f_status',
    visibleFieldIds: const ['f_no', 'f_total'],
    shownCount: 23,
    shownIds: const ['b_1', 'b_2'],
    openCardId: 'b_1',
    selectedIds: const ['b_2'],
  );

  test('round-trips through JSON text', () {
    final json = jsonDecode(jsonEncode(full.toJson())) as Map<String, Object?>;
    expect(ScreenContext.fromJson(json), full);
  });

  test('an empty snapshot writes only its page', () {
    final home = ScreenContext(page: ScreenPage.home);
    expect(home.toJson(), {'page': 'home'});
    expect(ScreenContext.fromJson(home.toJson()), home);
  });

  test('keeps only the first 50 shown ids', () {
    final ids = [for (var i = 0; i < 80; i++) 'b_$i'];
    final screen = ScreenContext(page: ScreenPage.collection, shownIds: ids);
    expect(screen.shownIds, ids.take(ScreenContext.maxShownIds));
    expect(
      ScreenContext.fromJson({'page': 'collection', 'shownIds': ids}).shownIds,
      hasLength(50),
    );
  });

  test('an unknown page reads as other; wrong types throw', () {
    expect(ScreenContext.fromJson({'page': 'reports'}).page, ScreenPage.other);
    expect(
      () => ScreenContext.fromJson({'page': 'home', 'shownCount': 'many'}),
      throwsFormatException,
    );
    expect(
      () => ScreenContext.fromJson({
        'page': 'home',
        'filters': [
          {'fieldId': 'f', 'op': 'between'},
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => ScreenContext.fromJson({
        'page': 'home',
        'selectedIds': [1],
      }),
      throwsFormatException,
    );
  });

  test('HarnessContext carries the snapshot as its focus across turns', () {
    final ctx = HarnessContext(
      workspaceId: 'w1',
      actor: Actor.assistant,
      grants: Grants.all(),
      now: DateTime(2026, 11, 10, 14),
      today: DateTime(2026, 11, 10),
      focus: full,
    );
    final HarnessFocus? focus = ctx.withTurn('t_1').focus;
    expect(focus, same(full));
  });
}
