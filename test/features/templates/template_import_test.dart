import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/collections/list/collections_list_cubit.dart';
import 'package:morkva_crm/features/templates/template_picker.dart';

import '../collections/fake_data_repository.dart';

WorkspaceTemplate _load(String name) => WorkspaceTemplate.fromJson(
  jsonDecode(File('assets/templates/$name.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  test('importing writes every collection and sample card, linked', () async {
    final repo = FakeDataRepository();
    final cubit = CollectionsListCubit(repo)..initialize();
    final template = _load('orders_pipeline');
    final first = await cubit.importTemplate(template);

    final collections = await repo.getCollections();
    expect([for (final c in collections) c.name], template.collectionNames);
    expect(first, collections.first.id);
    final orders = repo.objectsOf(first);
    expect(orders, hasLength(3));
    // Auto-numbers are allocated on save, like any new order.
    expect(
      [for (final o in orders) (o['no']! as AutoNumberFieldValue).sequence]
        ..sort(),
      [1, 2, 3],
    );
    final items = repo.objectsOf(collections[1].id);
    final linked = {
      for (final i in items) ...(i['order']! as ReferenceFieldValue).objectIds,
    };
    expect(linked.difference({for (final o in orders) o.id}), isEmpty);

    // Twice is fine: fresh ids, nothing overwritten.
    await cubit.importTemplate(template);
    expect(await repo.getCollections(), hasLength(8));
    await cubit.close();
  });

  testWidgets('the picker adds a template and closes', (tester) async {
    final templates = [_load('orders_pipeline'), _load('production_materials')];
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    WorkspaceTemplate? added;
    Object? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showTemplatePicker(
              context,
              load: () async => templates,
              onAdd: (t) async => added = t,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Orders pipeline'), findsOneWidget);
    expect(find.text('Production & materials'), findsOneWidget);
    expect(find.text('4 collections · 13 sample cards'), findsOneWidget);
    await tester.tap(find.text('Add to workspace').last);
    await tester.pumpAndSettle();
    expect(added?.id, 'production_materials');
    expect(result, added);
    expect(find.text('Start from a template'), findsNothing);
  });

  testWidgets('a failed add says so and keeps the picker open', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTemplatePicker(
              context,
              load: () async => [_load('orders_pipeline')],
              onAdd: (_) async => throw Exception('offline'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to workspace'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't add Orders pipeline"), findsOneWidget);
    expect(find.text('Start from a template'), findsOneWidget);
  });
}
