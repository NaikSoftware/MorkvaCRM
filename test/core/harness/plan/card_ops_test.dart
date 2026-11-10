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

  List<MorkvaObject> orders() => h.seed.orderCards;
  String? statusOf(MorkvaObject o) =>
      (o[OrderFields.status] as SingleSelectFieldValue?)?.optionId;

  group('cards.update', () {
    test('a where target becomes one plan with a shared diff and writes '
        'nothing', () async {
      final packing = [
        for (final o in orders())
          if (statusOf(o) == SeedOptions.packing) o.id,
      ];
      expect(packing, isNotEmpty);
      final r = await h.ok('cards.update', {
        'collection': 'orders',
        'target': {
          'where': [
            {'field': 'Status', 'op': 'equals', 'value': 'packing'},
          ],
        },
        'set': {'Status': 'Shipped'},
        if (packing.length > 20) 'expectedCount': packing.length,
      });
      expect(r['status'], 'planned');
      expect(r['itemCount'], packing.length);
      final compact = await h.seal();
      expect(compact['planId'], r['planId']);
      expect(compact['risk'], 'low');
      expect(
        compact['title'],
        'Set Status to Shipped · ${packing.length} '
        '${packing.length == 1 ? 'order' : 'orders'}',
      );
      expect(compact['sharedChange'], {
        'fieldId': OrderFields.status,
        'field': 'Status',
        'beforeText': 'Packing',
        'afterText': 'Shipped',
      });
      final plan = h.store.get(r['planId']! as String)!;
      final items = updatesOf(plan);
      expect(items.keys.toSet(), packing.toSet());
      final first = items[packing.first]!;
      expect(first.beforeValues, {OrderFields.status: SeedOptions.packing});
      expect(first.afterValues, {OrderFields.status: SeedOptions.shipped});
      expect(first.label, startsWith('#'));
      expect(plan.createdBy.actor, Actor.assistant);
      expect(plan.expiresAt, now.add(const Duration(minutes: 15)));
      // Planning never writes.
      expect(h.repo.saveCount, 0);
      expect(h.repo.batchCalls, 0);
    });

    test('more than 20 matched cards need expectedCount, and a wrong one '
        'is a count_mismatch', () async {
      final n = orders().length;
      final args = {
        'collection': 'Orders',
        'target': {
          'where': [
            {'field': 'Item', 'op': 'isNotEmpty'},
          ],
        },
        'set': {'Legacy price': 'n/a'},
      };
      final missing = await h.error('cards.update', args);
      expect(missing.code, ErrorCode.invalidArgs);
      expect(missing.path, 'expectedCount');
      final wrong = await h.error('cards.update', {
        ...args,
        'expectedCount': 3,
      });
      expect(wrong.code, ErrorCode.countMismatch);
      expect((wrong.expected, wrong.actual), (3, n));

      h.newTurn();
      await h.ok('cards.update', {...args, 'expectedCount': n});
      final plan = await h.sealPlan();
      expect(plan.risk, Risk.medium, reason: 'more than 20 cards');
      expect(plan.items.every((i) => i.risk == Risk.medium), isTrue);
    });

    test('{"screen": true} means the cards on screen, frozen to ids', () async {
      final unpaid = [
        for (final o in orders())
          if ((o[OrderFields.paid] as BooleanFieldValue?)?.value != true) o.id,
      ];
      final focus = ScreenContext(
        page: ScreenPage.collection,
        collectionId: SeedIds.orders,
        filters: const [
          ViewFilter(fieldId: OrderFields.paid, op: FilterOp.isFalse),
        ],
      );
      await h.ok('cards.update', {
        'collection': 'Orders',
        'target': {'screen': true},
        'set': {'Paid': true},
        if (unpaid.length > 20) 'expectedCount': unpaid.length,
      }, focus: focus);
      final plan = await h.sealPlan();
      expect(updatesOf(plan).keys.toSet(), unpaid.toSet());

      h.newTurn();
      final none = await h.error('cards.update', {
        'collection': 'Orders',
        'target': {'screen': true},
        'set': {'Paid': true},
      });
      expect(none.code, ErrorCode.invalidArgs);
      expect(none.message, contains('Nothing is on screen'));
    });

    test('@card names the open card', () async {
      final card = h.seed.card(SeedIds.orders, SeedCards.order(1003));
      final item = (card[OrderFields.item]! as TextFieldValue).text;
      await h.ok(
        'cards.update',
        {
          'collection': 'Orders',
          'target': {
            'ids': ['@card'],
          },
          'set': {'Item': 'Linen coat'},
        },
        focus: ScreenContext(
          page: ScreenPage.card,
          collectionId: SeedIds.orders,
          openCardId: SeedCards.order(1003),
        ),
      );
      final plan = await h.sealPlan();
      final only = plan.items.single as UpdateCardItem;
      expect(only.label, '#1003 · $item');
      expect(only.changes.single.afterText, 'Linen coat');
    });

    test(
      'setFrom with a formula computes per card; blanks are no-ops',
      () async {
        await h.ok('cards.update', {
          'collection': 'Orders',
          'target': {
            'where': [
              {'field': 'Item', 'op': 'isNotEmpty'},
            ],
          },
          'setFrom': [
            {'field': 'Price', 'formula': '{Price} * 1.1'},
          ],
          'expectedCount': orders().length,
        });
        final plan = await h.sealPlan();
        final items = updatesOf(plan);
        for (final o in orders()) {
          final price = (o[OrderFields.price] as NumberFieldValue?)?.value;
          if (price == null) {
            expect(items.containsKey(o.id), isFalse);
          } else {
            expect(
              items[o.id]!.afterValues[OrderFields.price] as num,
              closeTo(price * 1.1, 1e-9),
            );
          }
        }
        expect(plan.notes, isNotEmpty, reason: 'blank prices are no-ops');
      },
    );

    test('a formula that does not compile fails with its offset', () async {
      final e = await h.error('cards.update', {
        'collection': 'Orders',
        'target': {
          'ids': [SeedCards.order(1001)],
        },
        'setFrom': [
          {'field': 'Price', 'formula': '{Price} * '},
        ],
      });
      expect(e.code, ErrorCode.formulaError);
      expect(e.offset, isNotNull);
    });

    test('a source that can never fill the field fails up front', () async {
      final e = await h.error('cards.update', {
        'collection': 'Orders',
        'target': {
          'ids': [SeedCards.order(1001)],
        },
        'setFrom': [
          {'field': 'Paid', 'from': 'Price'},
        ],
      });
      expect(e.code, ErrorCode.wrongType);
    });

    test(
      'add and remove edit one multi-select list; single selects refuse',
      () async {
        final ids = [SeedCards.order(1001), SeedCards.order(1002)];
        await h.ok('cards.update', {
          'collection': 'Orders',
          'target': {'ids': ids},
          'add': {'Tags': 'Urgent'},
        });
        final plan = await h.sealPlan();
        for (final id in ids) {
          final before =
              (h.seed.card(SeedIds.orders, id)[OrderFields.tags]
                      as MultiSelectFieldValue?)
                  ?.optionIds ??
              const <String>[];
          final item = updatesOf(plan)[id];
          if (before.contains(SeedOptions.urgent)) {
            expect(item, isNull);
          } else {
            expect(item!.afterValues[OrderFields.tags], [
              ...before,
              SeedOptions.urgent,
            ]);
          }
        }

        h.newTurn();
        final e = await h.error('cards.update', {
          'collection': 'Orders',
          'target': {'ids': ids},
          'add': {'Status': 'Done'},
        });
        expect(e.code, ErrorCode.invalidArgs);
        expect(e.message, contains('use set'));
      },
    );

    test('an update where every card already has the value fails with the '
        'skip notes', () async {
      final card = h.seed.card(SeedIds.orders, SeedCards.order(1001));
      final item = (card[OrderFields.item]! as TextFieldValue).text!;
      final e = await h.error('cards.update', {
        'collection': 'Orders',
        'target': {
          'ids': [card.id],
        },
        'set': {'Item': item},
      });
      expect(e.code, ErrorCode.invalidArgs);
      expect(e.message, startsWith('Nothing would change.'));
      expect(e.message, contains('already'));
      expect(e.message, contains('— skipped'));
    });

    test('a setFrom no card converts fails with every card listed', () async {
      final ids = [
        for (final o in orders())
          if ((o[OrderFields.item] as TextFieldValue?)?.text case final t?
              when t.isNotEmpty && num.tryParse(t) == null)
            o.id,
      ].take(3).toList();
      expect(ids, hasLength(3));
      final e = await h.error('cards.update', {
        'collection': 'Orders',
        'target': {'ids': ids},
        'setFrom': [
          {'field': 'Price', 'from': 'Item'},
        ],
      });
      expect(e.code, ErrorCode.wrongType);
      expect(e.details, hasLength(3));
      expect(e.details!.every((d) => d.code == ErrorCode.wrongType), isTrue);
    });

    test('a target above 500 cards is limit_exceeded', () async {
      final big = PlanHarness(SeedWorkspace(orders: 501));
      addTearDown(big.dispose);
      final target = {
        'where': [
          {'field': 'Status', 'op': 'isNotEmpty'},
        ],
      };
      final update = await big.error('cards.update', {
        'collection': 'Orders',
        'target': target,
        'set': {'Item': 'x'},
        'expectedCount': 501,
      });
      expect(update.code, ErrorCode.limitExceeded);
      final delete = await big.error('cards.delete', {
        'collection': 'Orders',
        'target': target,
        'expectedCount': 501,
      });
      expect(delete.code, ErrorCode.limitExceeded);
    });

    test('a card both in the target and patched is refused', () async {
      final e = await h.error('cards.update', {
        'collection': 'Orders',
        'target': {
          'ids': [SeedCards.order(1001)],
        },
        'set': {'Paid': true},
        'patches': [
          {
            'id': SeedCards.order(1001),
            'set': {'Item': 'x'},
          },
        ],
      });
      expect(e.code, ErrorCode.invalidArgs);
      expect(e.path, 'patches[0].id');
    });

    test('every bad patch comes back in one error', () async {
      final e = await h.error('cards.update', {
        'collection': 'Orders',
        'patches': [
          for (final (i, v) in ['12', '12 USD', 'abc', 7, 'x'].indexed)
            {
              'id': SeedCards.order(1001 + i),
              'set': {'Price': v},
            },
        ],
      });
      expect(e.code, ErrorCode.wrongType);
      expect(e.details!.map((d) => d.path), [
        'patches[1].set.Price',
        'patches[2].set.Price',
        'patches[4].set.Price',
      ]);
      expect(e.details![0].message, contains("the unit is 'USD'"));
    });
  });

  group('cards.create', () {
    test('cards get ids, @refs link them, and the items depend on their '
        'links', () async {
      await h.ok('cards.create', {
        'collection': 'Clients',
        'cards': [
          {
            'ref': '@nova',
            'values': {'Name': 'Nova Atelier', 'City': 'Lviv'},
          },
        ],
      });
      await h.ok('cards.create', {
        'collection': 'Orders',
        'cards': [
          {
            'values': {'Item': 'Coat', 'Client': '@nova', 'Price': 1200},
          },
        ],
      });
      final plan = await h.sealPlan();
      final client = plan.items[0] as CreateCardItem;
      final order = plan.items[1] as CreateCardItem;
      expect(client.object.id, startsWith('b_'));
      expect(client.ref, '@nova');
      expect(
        (order.object[OrderFields.client]! as ReferenceFieldValue).objectIds,
        [client.object.id],
      );
      expect(order.dependsOn, [client.itemId]);
      expect(order.detail, 'Number assigned on save');
      expect(
        order.changes.firstWhere((c) => c.field == 'Client').afterText,
        'Nova Atelier',
      );
      expect(plan.title, 'Add 1 client + 1 more change');
      expect(h.repo.saveCount + h.repo.batchCalls, 0);
    });

    test('a card created in this turn cannot also be updated', () async {
      await h.ok('cards.create', {
        'collection': 'Clients',
        'cards': [
          {
            'ref': '@c1',
            'values': {'Name': 'Nova'},
          },
        ],
      });
      final e = await h.error('cards.update', {
        'collection': 'Clients',
        'target': {
          'ids': ['@c1'],
        },
        'set': {'Phone': '123'},
      });
      expect(e.code, ErrorCode.invalidArgs);
    });

    test('required fields are checked; auto-numbers are not', () async {
      final e = await h.error('cards.create', {
        'collection': 'Orders',
        'cards': [
          {
            'values': {'Price': 10},
          },
        ],
      });
      expect(e.code, ErrorCode.requiredValue);
      expect(e.path, 'cards[0].values.Item');
    });
  });

  group('cards.delete', () {
    test('ids need no count; links into the cards are warned about', () async {
      await h.ok('cards.delete', {
        'collection': 'Clients',
        'target': {
          'ids': [SeedCards.olena],
        },
      });
      final plan = await h.sealPlan();
      final item = plan.items.single as DeleteCardItem;
      expect(item.before.id, SeedCards.olena);
      expect(item.risk, Risk.medium);
      expect(item.detail, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(plan.warnings.map((w) => w.code), contains('breaks_references'));
      expect(plan.title, 'Delete 1 client');
    });

    test('a where target needs expectedCount', () async {
      final e = await h.error('cards.delete', {
        'collection': 'Orders',
        'target': {
          'where': [
            {'field': 'Paid', 'op': 'isTrue'},
          ],
        },
      });
      expect(e.code, ErrorCode.invalidArgs);
      expect(e.path, 'expectedCount');
    });
  });

  group('turn merge', () {
    test('a failed call means no plan: seal returns its error', () async {
      await h.ok('cards.update', {
        'collection': 'Orders',
        'target': {
          'ids': [SeedCards.order(1001)],
        },
        'set': {'Item': 'Coat'},
      });
      await h.error('cards.update', {
        'collection': 'Orders',
        'target': {
          'ids': [SeedCards.order(1002)],
        },
        'set': {'Totl': 1},
      });
      final sealed = await h.seal();
      expect(sealed['planId'], isNull);
      final errors = sealed['errors']! as List;
      expect(errors, hasLength(1));
      expect((errors.single as Map)['callId'], 'r1.2');
      // The turn's overlay is gone: a new call starts a fresh plan.
      final again = await h.ok('cards.update', {
        'collection': 'Orders',
        'target': {
          'ids': [SeedCards.order(1001)],
        },
        'set': {'Item': 'Coat'},
      });
      expect(again['planId'], isNot(sealed['planId']));
    });

    test('collections.delete is refused next to another change', () async {
      await h.ok('cards.update', {
        'collection': 'Orders',
        'target': {
          'ids': [SeedCards.order(1001)],
        },
        'set': {'Item': 'Coat'},
      });
      final e = await h.error('collections.delete', {'collection': 'Fabrics'});
      expect(e.code, ErrorCode.invalidArgs);
      expect(e.message, contains('on its own'));
      expect((await h.seal())['errors'], hasLength(1));
    });

    test('a plan over 500 items fails at plans.seal', () async {
      final big = PlanHarness(SeedWorkspace(orders: 300));
      addTearDown(big.dispose);
      for (final field in ['Legacy price', 'Item']) {
        await big.ok('cards.update', {
          'collection': 'Orders',
          'target': {
            'where': [
              {'field': 'Status', 'op': 'isNotEmpty'},
            ],
          },
          'set': {field: 'zz-$field'},
          'expectedCount': 300,
        });
      }
      final r = await big.call('plans.seal', {'turnId': big.turn});
      expect((r as HarnessFailure).error.code, ErrorCode.limitExceeded);
    });

    test('the same card key twice in one turn is refused', () async {
      final args = {
        'collection': 'Orders',
        'target': {
          'ids': [SeedCards.order(1001)],
        },
        'set': {'Item': 'Coat'},
      };
      await h.ok('cards.update', args);
      final e = await h.error('cards.update', {
        ...args,
        'set': {'Item': 'Dress'},
      });
      expect(e.code, ErrorCode.invalidArgs);
      expect(e.message, contains('another call'));
    });
  });

  group('turns and access', () {
    test('plan ops need a turn the caller owns', () async {
      final noTurn = await h.call('cards.update', {
        'collection': 'Orders',
        'target': {
          'ids': [SeedCards.order(1001)],
        },
        'set': {'Item': 'Coat'},
      }, noTurn: true);
      expect((noTurn as HarnessFailure).error.code, ErrorCode.notPermitted);

      final plugin = await h.call('cards.update', {
        'collection': 'Orders',
        'target': {
          'ids': [SeedCards.order(1001)],
        },
        'set': {'Item': 'Coat'},
      }, actor: const Actor.plugin('m1'));
      expect((plugin as HarnessFailure).error.code, ErrorCode.notPermitted);

      final other = h.harness.openTurn(Actor.assistant);
      final seal = await h.call('plans.seal', {'turnId': other});
      expect((seal as HarnessFailure).error.code, ErrorCode.notPermitted);
    });

    test('plans.get serves the creator and the user, until expiry', () async {
      await h.ok('cards.update', {
        'collection': 'Orders',
        'target': {
          'ids': [SeedCards.order(1001)],
        },
        'set': {'Item': 'Coat'},
      });
      final planId = (await h.seal())['planId']! as String;
      Future<HarnessResponse> get(Actor actor, {DateTime? at}) => h.call(
        'plans.get',
        {'planId': planId},
        actor: actor,
        noTurn: true,
        at: at,
      );
      final own = await get(Actor.assistant);
      expect((own as HarnessOk).result['items'], hasLength(1));
      expect(await get(const Actor.user('u1')), isA<HarnessOk>());
      final plugin = await get(const Actor.plugin('m1'));
      expect((plugin as HarnessFailure).error.code, ErrorCode.notPermitted);
      final late = await get(
        Actor.assistant,
        at: now.add(const Duration(minutes: 16)),
      );
      expect((late as HarnessFailure).error.code, ErrorCode.planExpired);
    });

    test('a collection outside the grants is unknown', () async {
      final e = await h.error('cards.update', {
        'collection': 'Fabrics',
        'target': {
          'ids': [SeedCards.linenBlack],
        },
        'set': {'Name': 'x'},
      }, grants: Grants(Capability.values, collections: [SeedIds.orders]));
      expect(e.code, ErrorCode.unknownCollection);
    });
  });

  group('plan JSON contract', () {
    test('the compact and full plans parse as PlanView; mixed plans start '
        'with risky groups unticked', () async {
      await h.ok('cards.update', {
        'collection': 'Orders',
        'target': {
          'ids': [SeedCards.order(1001), SeedCards.order(1002)],
        },
        'set': {'Item': 'Coat'},
      });
      await h.ok('cards.delete', {
        'collection': 'Orders',
        'target': {
          'ids': [SeedCards.order(1005)],
        },
      });
      final compact = await h.seal();
      final view = PlanView.fromJson(compact);
      expect(view.itemCount, 3);
      expect(view.risk, PlanRisk.medium);
      expect(view.groups.map((g) => g.kind), ['updateCard', 'deleteCard']);
      expect(view.rows.first.risk, PlanRisk.low);
      expect(view.defaultSelection, {'i1', 'i2'});

      final full = await h.call(
        'plans.get',
        {'planId': view.planId},
        actor: const Actor.user('u1'),
        noTurn: true,
      );
      final fullView = PlanView.fromJson((full as HarnessOk).result);
      expect(fullView.rows.map((r) => r.itemId), ['i1', 'i2', 'i3']);
      expect(fullView.rows.last.targetId, SeedCards.order(1005));
      final items = full.result['items']! as List;
      expect((items.last as Map)['before'], isA<Map<String, Object?>>());
    });

    test('compact plans list at most 5 items', () async {
      final ids = [for (var n = 1001; n <= 1010; n++) SeedCards.order(n)];
      await h.ok('cards.update', {
        'collection': 'Orders',
        'target': {'ids': ids},
        'set': {'Legacy price': 'zz'},
      });
      final compact = await h.seal();
      expect(compact['items'], hasLength(kCompactPlanItems));
      expect(compact['itemCount'], 10);
      expect(compact['moreItems'], 5);
      expect(PlanView.fromJson(compact).isComplete, isFalse);
    });
  });
}
