import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/plan/plan.dart';
import 'package:morkva_crm/features/assistant/bloc/chat_item.dart';

import 'plan_fixture.dart';

void main() {
  late PlanHarness h;

  setUp(() => h = PlanHarness());
  tearDown(() => h.dispose());

  group('collections.create', () {
    test('lists every field with its type; ids are minted, refs never '
        'stored', () async {
      await h.ok('collections.create', {
        'collections': [
          {
            'ref': '@sup',
            'name': 'Suppliers',
            'icon': 'truck',
            'fields': [
              {'name': 'Name', 'type': 'text'},
              {'name': 'Phone', 'type': 'text'},
              {
                'name': 'City',
                'type': 'single_select',
                'options': ['Kyiv', 'Lviv', 'Odesa'],
              },
              {
                'name': 'Fabrics sold',
                'type': 'reference',
                'target': 'Fabrics',
                'multiple': true,
              },
            ],
          },
        ],
        'cards': [
          {
            'collection': '@sup',
            'ref': '@s1',
            'values': {
              'Name': '@sup',
              'City': 'lviv',
              'Fabrics sold': ['Linen Black'],
            },
          },
        ],
      });
      final plan = await h.sealPlan();
      final view = PlanView.fromJson(plan.toJson());
      expect(plan.title, 'Create “Suppliers” · 4 fields · 1 card');
      final create = plan.items.first as CreateCollectionItem;
      expect(create.collection.id, startsWith('c_'));
      expect(create.ref, '@sup');
      expect(create.collection.views.single.id, ViewDefinition.defaultId);
      final fields = plan.items.whereType<AddFieldItem>().toList();
      expect(
        [for (final f in fields) (f.label, f.detail)],
        [
          ('Name', 'Text · title'),
          ('Phone', 'Text'),
          ('City', 'Select · Kyiv, Lviv, Odesa'),
          ('Fabrics sold', 'Link → Fabrics, many'),
        ],
      );
      expect(fields.every((f) => f.newCollection), isTrue);
      expect(fields.every((f) => f.dependsOn.single == create.itemId), isTrue);
      expect(
        fields.map((f) => f.field.id).every((id) => id.startsWith('f_')),
        isTrue,
      );
      final city = fields[2].field as SingleSelectFieldDefinition;
      expect(city.options.every((o) => o.id.startsWith('o_')), isTrue);
      final card = plan.items.last as CreateCardItem;
      expect(card.collectionId, create.collection.id);
      expect(card.dependsOn, [create.itemId]);
      expect(card.object.id, startsWith('b_'));
      // A user's text that looks like a ref stays text.
      expect((card.object[fields[0].field.id]! as TextFieldValue).text, '@sup');
      expect(jsonEncode(create.collection.toJson()), isNot(contains('@sup')));
      expect(view.groups.map((g) => g.kind), [
        'createCollection',
        'addField',
        'createCard',
      ]);
      expect(h.repo.saveCount + h.repo.batchCalls, 0);
      // The full plan is plain JSON (the harness asserts it).
      final full = await h.call(
        'plans.get',
        {'planId': plan.planId},
        actor: const Actor.user('u1'),
        noTurn: true,
      );
      final items = (full as HarnessOk).result['items']! as List;
      expect((items.first as Map)['collection'], isA<Map<String, Object?>>());
    });

    test(
      'links, lookups, formulas and aggregates across new collections',
      () async {
        await h.ok('collections.create', {
          'collections': [
            {
              'ref': '@b',
              'name': 'Brands',
              'fields': [
                {'name': 'Title', 'type': 'text'},
                {
                  'name': 'Country',
                  'type': 'single_select',
                  'options': ['UA', 'PL'],
                },
                {
                  'name': 'Products count',
                  'type': 'calculated',
                  'aggregate': {
                    'source': 'linkedFrom',
                    'collection': '@p',
                    'referenceField': 'Brand',
                    'op': 'count',
                  },
                },
              ],
            },
            {
              'ref': '@p',
              'name': 'Products',
              'fields': [
                {'name': 'Price', 'type': 'number'},
                {'name': 'Qty', 'type': 'number'},
                {'name': 'Brand', 'type': 'reference', 'target': '@b'},
                {
                  'name': 'Sum',
                  'type': 'calculated',
                  'formula': '{Price} * {Qty}',
                },
                {
                  'name': 'Brand country',
                  'type': 'calculated',
                  'lookup': {'via': 'Brand', 'field': 'Country'},
                },
              ],
            },
          ],
        });
        final plan = await h.sealPlan();
        final creates = plan.items.whereType<CreateCollectionItem>().toList();
        final brands = creates[0].collection;
        final products = creates[1].collection;
        // No text field in Products: a Name field leads.
        expect(products.fields.first.name, 'Name');
        final count = brands.fields.last as CalculatedFieldDefinition;
        expect(count.aggregate!.collectionId, products.id);
        expect(
          count.aggregate!.referenceFieldId,
          products.fields.firstWhere((f) => f.name == 'Brand').id,
        );
        final sum =
            products.fields.firstWhere((f) => f.name == 'Sum')
                as CalculatedFieldDefinition;
        expect(sum.expression, contains('{f_'));
        expect(sum.declaredOutputType, kNumberFieldType);
        final lookup =
            products.fields.firstWhere((f) => f.name == 'Brand country')
                as CalculatedFieldDefinition;
        expect(lookup.declaredOutputType, kSingleSelectFieldType);
        expect(plan.title, 'Create 2 collections');
      },
    );

    test(
      'formula errors carry their offset; loops are formula_cycle',
      () async {
        final bad = await h.error('collections.create', {
          'collections': [
            {
              'name': 'X',
              'fields': [
                {'name': 'A', 'type': 'number'},
                {'name': 'B', 'type': 'calculated', 'formula': '{A} +'},
              ],
            },
          ],
        });
        expect(bad.code, ErrorCode.formulaError);
        expect(bad.path, 'collections[0].fields[1].formula');

        h.newTurn();
        final loop = await h.error('collections.create', {
          'collections': [
            {
              'name': 'Y',
              'fields': [
                {'name': 'A', 'type': 'calculated', 'formula': '{B} + 1'},
                {'name': 'B', 'type': 'calculated', 'formula': '{A} + 1'},
              ],
            },
          ],
        });
        expect(loop.code, ErrorCode.formulaCycle);
      },
    );

    test(
      'a link without a target and an empty option list are refused',
      () async {
        final link = await h.error('collections.create', {
          'collections': [
            {
              'name': 'X',
              'fields': [
                {'name': 'Link', 'type': 'reference'},
                {
                  'name': 'Kind',
                  'type': 'single_select',
                  'options': ['A', 'a'],
                },
              ],
            },
          ],
        });
        expect(link.details!.map((d) => d.path), [
          'collections[0].fields[0].target',
          'collections[0].fields[1].options[1]',
        ]);
        h.newTurn();
        final empty = await h.error('collections.create', {
          'collections': [
            {
              'name': 'Y',
              'fields': [
                {'name': 'Kind', 'type': 'single_select', 'options': []},
              ],
            },
          ],
        });
        expect(empty.code, ErrorCode.invalidArgs);
        expect(empty.path, 'collections[0].fields[0].options');
      },
    );
  });

  group('fields.add', () {
    test('a new field filled by setFrom in the same turn: one plan with '
        'per-card diffs; unconvertible cards are skipped with notes', () async {
      await h.ok('fields.add', {
        'collection': 'Orders',
        'fields': [
          {'name': 'Old price', 'type': 'number', 'unitLabel': '₴'},
        ],
        'after': 'Price',
      });
      final legacy = [
        for (final o in h.seed.orderCards)
          if ((o[OrderFields.legacyPrice] as TextFieldValue?)?.text
              case final t? when t.isNotEmpty)
            (o.id, t),
      ];
      await h.ok('cards.update', {
        'collection': 'Orders',
        'target': {
          'where': [
            {'field': 'Legacy price', 'op': 'isNotEmpty'},
          ],
        },
        'setFrom': [
          {'field': 'Old price', 'from': 'Legacy price'},
        ],
        if (legacy.length > 20) 'expectedCount': legacy.length,
      });
      final plan = await h.sealPlan();
      final add = plan.items.first as AddFieldItem;
      expect(
        add.index,
        h
                .collection(SeedIds.orders)
                .fields
                .indexWhere((f) => f.id == OrderFields.price) +
            1,
      );
      expect(add.views.length, h.collection(SeedIds.orders).views.length);
      expect(add.views.first.after!.fieldIds.last, add.field.id);
      final updates = updatesOf(plan);
      for (final (id, text) in legacy) {
        final n = num.tryParse(text);
        if (n == null) {
          expect(updates.containsKey(id), isFalse);
        } else {
          final item = updates[id]!;
          expect(item.afterValues, {add.field.id: n});
          expect(item.dependsOn, [add.itemId]);
        }
      }
      expect(plan.notes.where((n) => n.contains('Skipped')), isNotEmpty);
      expect(
        plan.title,
        startsWith('Add field “Old price” to Orders + 1 more'),
      );
    });

    test('required fields warn about the cards left empty', () async {
      await h.ok('fields.add', {
        'collection': 'Clients',
        'fields': [
          {'name': 'Email', 'type': 'text', 'required': true},
        ],
      });
      final plan = await h.sealPlan();
      expect(plan.warnings.single.code, 'required_empty');
      expect(plan.warnings.single.message, startsWith('8 clients'));
    });

    test('a duplicate name is refused', () async {
      final e = await h.error('fields.add', {
        'collection': 'Orders',
        'fields': [
          {'name': 'price', 'type': 'number'},
        ],
      });
      expect(e.code, ErrorCode.invalidArgs);
      expect(e.message, contains('Duplicate'));
    });
  });

  group('fields.update', () {
    test('rename and option edits keep every option id', () async {
      await h.ok('fields.update', {
        'collection': 'Orders',
        'field': 'Status',
        'patch': {
          'name': 'Stage',
          'renameOptions': [
            {'option': 'Packing', 'label': 'Packed'},
          ],
          'addOptions': [
            {'label': 'Returned'},
          ],
        },
      });
      final plan = await h.sealPlan();
      final item = plan.items.single as UpdateFieldItem;
      final after = item.after as SingleSelectFieldDefinition;
      expect(after.name, 'Stage');
      expect(after.options.take(4).map((o) => o.id), [
        SeedOptions.statusNew,
        SeedOptions.packing,
        SeedOptions.shipped,
        SeedOptions.done,
      ]);
      expect(after.options[1].label, 'Packed');
      expect(after.options.last.id, startsWith('o_'));
      expect(item.risk, Risk.medium);
      expect(item.changes.map((c) => (c.field, c.beforeText, c.afterText)), [
        ('Name', 'Status', 'Stage'),
        ('Options', 'Packing', 'Packed'),
        ('Options', null, 'Returned'),
      ]);
      expect(plan.title, 'Change field “Status” in Orders');
    });

    test(
      'type, target, options, multiple and includeTime are locked',
      () async {
        Future<HarnessError> patch(String field, Map<String, Object?> p) {
          h.newTurn();
          return h.error('fields.update', {
            'collection': 'Orders',
            'field': field,
            'patch': p,
          });
        }

        expect(
          (await patch('Status', {
            'options': ['A', 'B'],
          })).code,
          ErrorCode.typeLocked,
        );
        expect(
          (await patch('Client', {'target': 'Fabrics'})).code,
          ErrorCode.typeLocked,
        );
        final multiple = await patch('Fabrics', {'multiple': false});
        expect(multiple.code, ErrorCode.typeLocked);
        expect(multiple.message, contains('setFrom'));
        expect(
          (await patch('Created', {'includeTime': true})).code,
          ErrorCode.typeLocked,
        );
        expect(
          (await patch('Price', {'multiline': true})).code,
          ErrorCode.invalidArgs,
        );
      },
    );

    test(
      'removeOptions clears the option on cards and in view filters',
      () async {
        final vip = [
          for (final c in h.seed.clientCards)
            if ((c[ClientFields.tags] as MultiSelectFieldValue?)?.optionIds
                    .contains(SeedOptions.vip) ??
                false)
              c,
        ];
        expect(vip, isNotEmpty);
        await h.ok('fields.update', {
          'collection': 'Clients',
          'field': 'Tags',
          'patch': {
            'removeOptions': ['VIP'],
          },
        });
        final plan = await h.sealPlan();
        final field = plan.items.first as UpdateFieldItem;
        final vipView = field.views.single;
        expect(vipView.viewId, 'v_cl_vip');
        expect(vipView.before!.filters, hasLength(1));
        expect(vipView.after!.filters, isEmpty, reason: 'no operand left');
        final cards = plan.items.whereType<UpdateCardItem>().toList();
        expect(cards.map((c) => c.cardId).toSet(), {for (final c in vip) c.id});
        for (final c in cards) {
          expect(c.dependsOn, [field.itemId]);
          expect(
            c.afterValues[ClientFields.tags],
            isNot(contains(SeedOptions.vip)),
          );
        }
        expect(plan.warnings.map((w) => w.code), ['options_in_use']);
      },
    );
  });

  group('fields.delete', () {
    test('records every view it changes and warns about readers', () async {
      await h.ok('fields.delete', {
        'collection': 'Orders',
        'fields': ['Status', 'Price'],
      });
      final plan = await h.sealPlan();
      final status = plan.items[0] as DeleteFieldItem;
      final price = plan.items[1] as DeleteFieldItem;
      expect(status.risk, Risk.high);
      final board = status.views.firstWhere((v) => v.viewId == 'v_or_unpaid');
      expect(board.before!.layoutFieldId, OrderFields.status);
      expect(board.after!.layoutFieldId, isNull);
      expect(status.layoutAfter!.fieldIds, isNot(contains(OrderFields.status)));
      expect(price.views, isEmpty, reason: 'no view shows Price');
      final codes = plan.warnings.map((w) => w.code).toSet();
      expect(codes, {'breaks_views', 'breaks_calculations'});
      expect(
        plan.warnings.map((w) => w.message),
        contains(allOf(contains('Total'), contains('“Price”'))),
      );
      expect(plan.title, 'Delete 2 fields from Orders');
    });
  });

  group('collections.update / delete', () {
    test('rename records the key before and after', () async {
      await h.ok('collections.update', {
        'collection': 'Fabrics',
        'name': 'Materials',
        'icon': 'tag',
      });
      final plan = await h.sealPlan();
      final item = plan.items.single as UpdateCollectionItem;
      expect(item.keys['name'], (before: 'Fabrics', after: 'Materials'));
      expect(item.keys['icon'], (before: 'box', after: 'tag'));
      expect(plan.title, 'Rename “Fabrics” to “Materials”');
    });

    test('an unknown icon is refused by the schema', () async {
      final e = await h.error('collections.update', {
        'collection': 'Fabrics',
        'icon': 'rocket',
      });
      expect(e.code, ErrorCode.invalidArgs);
      expect(e.candidates, contains('truck'));
    });

    test('delete counts the cards and warns about links into it', () async {
      await h.ok('collections.delete', {'collection': 'Clients'});
      final plan = await h.sealPlan();
      final item = plan.items.single as DeleteCollectionItem;
      expect(item.cardCount, h.seed.clientCards.length);
      expect(item.risk, Risk.high);
      expect(plan.warnings.map((w) => w.code), contains('breaks_references'));
      expect(plan.undo, UndoSupport.full);
      expect(PlanView.fromJson(plan.toCompactJson()).destructive, isTrue);
    });

    test('nothing may follow a collection delete in its turn', () async {
      await h.ok('collections.delete', {'collection': 'Fabrics'});
      final e = await h.error('fields.add', {
        'collection': 'Orders',
        'fields': [
          {'name': 'X', 'type': 'text'},
        ],
      });
      expect(e.message, contains('on its own'));
    });
  });
}
