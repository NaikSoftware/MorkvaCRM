import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/collections/list/collection_card.dart';
import 'package:morkva_crm/features/collections/list/collections_list_cubit.dart';
import 'package:morkva_crm/features/collections/list/collections_list_view.dart';

import 'fake_data_repository.dart';

void main() {
  // A minimal router so the view's navigation resolves without the real Work
  // and editor pages. The list view itself is the unit under test.
  GoRouter router() => GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: CollectionsListView()),
          ),
          GoRoute(
            path: '/collections/:id',
            builder: (_, state) =>
                Scaffold(body: Text('work:${state.pathParameters['id']}')),
          ),
          GoRoute(
            path: '/collections/:id/edit',
            builder: (_, state) =>
                Scaffold(body: Text('editor:${state.pathParameters['id']}')),
          ),
        ],
      );

  Future<void> pumpView(
    WidgetTester tester,
    FakeDataRepository repository,
  ) async {
    final cubit = CollectionsListCubit(repository)..initialize();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('CollectionsListView', () {
    testWidgets('shows the empty state with a create CTA when there are no '
        'collections', (tester) async {
      await pumpView(tester, FakeDataRepository());

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No collections yet'), findsOneWidget);
      expect(find.text('New collection'), findsOneWidget);
      expect(find.byType(CollectionCard), findsNothing);
    });

    testWidgets('renders a card per collection when populated', (tester) async {
      final repository = FakeDataRepository([
        const Collection(id: 'c_orders', name: 'Orders'),
        const Collection(
          id: 'c_clients',
          name: 'Clients',
          description: 'People we work with',
          fields: [TextFieldDefinition(id: 'f_name', name: 'Name')],
        ),
      ]);

      await pumpView(tester, repository);

      expect(find.byType(EmptyState), findsNothing);
      expect(find.byType(CollectionCard), findsNWidgets(2));
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Clients'), findsOneWidget);
      // Field-count footer reflects the schema.
      expect(find.text('No fields yet'), findsOneWidget);
      expect(find.text('1 field'), findsOneWidget);
      // Header count.
      expect(find.text('2 collections'), findsOneWidget);
    });

    testWidgets('tapping a card opens its Work page', (tester) async {
      final repository = FakeDataRepository([
        const Collection(id: 'c_orders', name: 'Orders'),
      ]);

      await pumpView(tester, repository);

      await tester.tap(find.byType(CollectionCard));
      await tester.pumpAndSettle();

      expect(find.text('work:c_orders'), findsOneWidget);
    });

    testWidgets('a new collection opens in its editor', (tester) async {
      final repository = FakeDataRepository();

      await pumpView(tester, repository);

      await tester.tap(find.text('New collection'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Deals');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      final id = (await repository.getCollections()).single.id;
      expect(find.text('editor:$id'), findsOneWidget);
    });
  });
}
