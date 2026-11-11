import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/query/query_engine.dart';
import 'package:morkva_crm/features/assistant/host/router_ui_port.dart';

void main() {
  late GoRouter router;
  late RouterUiPort port;

  Future<void> pumpApp(WidgetTester tester) async {
    final rootKey = GlobalKey<NavigatorState>();
    router = GoRouter(
      navigatorKey: rootKey,
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(body: child),
          routes: [
            GoRoute(path: '/', builder: (_, _) => const Text('home')),
            GoRoute(
              path: '/collections/:id',
              builder: (_, state) =>
                  Text('collection ${state.pathParameters['id']}'),
            ),
          ],
        ),
        GoRoute(
          path: '/assistant',
          parentNavigatorKey: rootKey,
          builder: (_, _) => const Text('chat'),
          routes: [
            GoRoute(
              path: 'history',
              parentNavigatorKey: rootKey,
              builder: (_, _) => const Text('history'),
            ),
          ],
        ),
      ],
    );
    port = RouterUiPort(() => router);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  }

  Uri location() => router.routerDelegate.currentConfiguration.uri;

  List<Object?> filterOf(Uri uri) =>
      jsonDecode(
            utf8.decode(
              base64Url.decode(
                base64Url.normalize(uri.queryParameters['filter']!),
              ),
            ),
          )
          as List;

  testWidgets('a chip opens the deep link to the collection, view and card', (
    tester,
  ) async {
    await pumpApp(tester);
    port.open(collectionId: 'c_orders', viewId: 'v_all', cardId: 'b_or_1042');
    await tester.pumpAndSettle();
    expect(location().path, '/collections/c_orders');
    expect(location().queryParameters, {'view': 'v_all', 'card': 'b_or_1042'});
    expect(find.text('collection c_orders'), findsOneWidget);
  });

  testWidgets('on phone the chat route is popped first', (tester) async {
    await pumpApp(tester);
    router.push('/assistant');
    await tester.pumpAndSettle();
    router.push('/assistant/history');
    await tester.pumpAndSettle();
    expect(find.text('history'), findsOneWidget);

    port.open(
      collectionId: 'c_orders',
      where: [
        {
          'field': 'Status',
          'op': 'anyOf',
          'value': ['Packing'],
        },
      ],
    );
    await tester.pumpAndSettle();
    expect(location().path, '/collections/c_orders');
    expect(filterOf(location()), [
      {
        'field': 'Status',
        'op': 'anyOf',
        'value': ['Packing'],
      },
    ]);
    expect(find.text('chat'), findsNothing);
    expect(find.text('history'), findsNothing);
    expect(find.text('collection c_orders'), findsOneWidget);
  });

  testWidgets('"Open as filtered view" turns a stored query into filters', (
    tester,
  ) async {
    await pumpApp(tester);
    const spec = QuerySpec(
      collectionId: 'c_orders',
      orderViewId: 'v_all',
      filters: [
        ViewFilter(fieldId: 'f_status', op: FilterOp.anyOf, operand: ['o_p']),
        ViewFilter(fieldId: 'f_paid', op: FilterOp.isFalse),
      ],
    );
    expect(port.openQuery(spec.toJson()), isTrue);
    await tester.pumpAndSettle();
    expect(location().queryParameters['view'], 'v_all');
    expect(filterOf(location()), [
      {
        'field': 'f_status',
        'op': 'anyOf',
        'value': ['o_p'],
      },
      {'field': 'f_paid', 'op': 'isFalse'},
    ]);

    expect(port.openQuery({'kind': 'aggregate'}), isFalse);
  });

  testWidgets('a query with a search or a created/updated-date filter has no '
      'filtered view: it is not opened with more cards than it showed', (
    tester,
  ) async {
    await pumpApp(tester);
    final before = location();
    const searched = QuerySpec(collectionId: 'c_orders', search: 'Acme');
    final created = QuerySpec(
      collectionId: 'c_orders',
      filters: [
        ViewFilter(
          fieldId: kCreatedAtRef,
          op: FilterOp.after,
          operand: '2026-11-01',
        ),
      ],
    );

    for (final spec in [searched, created]) {
      expect(RouterUiPort.viewQuery(spec.toJson()), isNull);
      expect(port.openQuery(spec.toJson()), isFalse);
    }
    await tester.pumpAndSettle();
    expect(location(), before);
    expect(
      RouterUiPort.viewQuery(const QuerySpec(collectionId: 'c').toJson()),
      isNotNull,
    );
  });
}
