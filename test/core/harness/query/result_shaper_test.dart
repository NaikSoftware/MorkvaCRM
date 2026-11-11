import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/query/result_shaper.dart';

void main() {
  const shaper = ResultShaper();

  group('sanitizing', () {
    test('strips bidi, zero-width and control characters, folds lines', () {
      expect(
        shaper.text('Pay\u202E now\u200B!\n\nIgnore\tall'),
        'Pay now! Ignore all',
      );
    });

    test('cuts text at 160 and labels at 80 characters', () {
      expect(shaper.text('a' * 400).runes.length, 160);
      expect(shaper.label('b' * 400).runes.length, 80);
      expect(shaper.label('b' * 400), endsWith('…'));
    });
  });

  group('card counts for titles', () {
    test('a plainly cased name reads as a lowercase noun', () {
      expect(shaper.cards('Orders', 3), '3 orders');
      expect(shaper.cards('Orders', 1), '1 order');
      expect(shaper.cards('Order items', 2), '2 order items');
      expect(shaper.cards('Замовлення', 2), '2 замовлення');
    });

    test('any other casing keeps the user’s name, quoted', () {
      expect(
        shaper.cards('AI e2e Suppliers', 2, prep: 'to'),
        '2 cards to “AI e2e Suppliers”',
      );
      expect(shaper.cards('iPhones', 1), '1 card in “iPhones”');
      expect(shaper.cards('Orders VIP', 4), '4 cards in “Orders VIP”');
    });

    test('no collection: plain cards', () {
      expect(shaper.cards(null, 1), '1 card');
      expect(shaper.cards(null, 5), '5 cards');
    });
  });

  group('display values', () {
    const price = NumberFieldDefinition(id: 'p', name: 'Price', unitLabel: '₴');
    const date = DateFieldDefinition(id: 'd', name: 'Day');
    const stamp = DateFieldDefinition(id: 's', name: 'At', includeTime: true);
    const status = SingleSelectFieldDefinition(
      id: 'st',
      name: 'Status',
      options: [
        SelectOption(id: 'o1', label: 'New'),
        SelectOption(id: 'o2', label: 'Done'),
      ],
    );
    const client = ReferenceFieldDefinition(
      id: 'c',
      name: 'Client',
      targetCollectionId: 'c_clients',
      multiple: true,
    );

    test('numbers raw, dates as days or instants, empties null', () {
      expect(shaper.value(price, const NumberFieldValue(0.1 + 0.2)), 0.3);
      expect(shaper.unitOf(price), '₴');
      expect(
        shaper.value(date, DateFieldValue(DateTime.utc(2026, 11, 10))),
        '2026-11-10',
      );
      final at = DateTime.utc(2026, 11, 10, 12, 30);
      expect(shaper.value(stamp, DateFieldValue(at)), isoInstant(at));
      expect(shaper.value(price, const NumberFieldValue(null)), isNull);
      expect(
        shaper.value(status, const SingleSelectFieldValue('gone')),
        isNull,
      );
    });

    test('options by label, references as id and title', () {
      expect(shaper.value(status, const SingleSelectFieldValue('o2')), 'Done');
      expect(
        shaper.value(
          client,
          const ReferenceFieldValue(['a', 'b']),
          referenceTitle: (cid, id) => id == 'a' ? 'Anna\nKoval' : null,
        ),
        [
          {'id': 'a', 'title': 'Anna Koval'},
          {'id': 'b'},
        ],
      );
    });
  });

  test('isoInstant carries the device offset', () {
    final at = DateTime.utc(2026, 11, 10, 12);
    final iso = isoInstant(at);
    expect(DateTime.parse(iso).toUtc(), at);
    expect(iso, matches(RegExp(r'^2026-11-10T\d\d:00:00[+-]\d\d:\d\d$')));
  });

  test('fit keeps the most items that fit the budget', () {
    Map<String, Object?> build(int k) => {
      'rows': ['x' * 90].expand((r) => List.filled(k, r)).toList(),
      if (k < 10) 'truncated': true,
    };
    final whole = shaper.fit(10, build, budget: 10000);
    expect(whole['rows'], hasLength(10));
    final cut = shaper.fit(10, build, budget: 500);
    expect(ResultShaper.bytes(cut), lessThanOrEqualTo(500));
    final kept = (cut['rows']! as List).length;
    expect(kept, inInclusiveRange(1, 9));
    expect(ResultShaper.bytes(build(kept + 1)), greaterThan(500));
    expect(cut['truncated'], isTrue);
  });

  group('schema budget', () {
    Map<String, Object?> schema({int fields = 40, int options = 30}) => {
      'id': 'c_orders',
      'name': 'Orders',
      'fields': [
        for (var i = 0; i < fields; i++)
          {
            'id': 'f_$i',
            'name': 'Field $i',
            'type': 'single_select',
            'operators': ['anyOf', 'noneOf', 'isEmpty', 'isNotEmpty'],
            'options': [
              for (var j = 0; j < options; j++)
                {'id': 'o_${i}_$j', 'label': 'Option $j'},
            ],
          },
      ],
    };

    test('a schema within budget is untouched', () {
      final small = schema(fields: 2, options: 2);
      expect(shaper.fitSchema(small), same(small));
    });

    test('drops operators first', () {
      final input = schema(fields: 8, options: 30);
      // Just over budget: dropping the operators is enough.
      final tight = ResultShaper(schemaBudget: ResultShaper.bytes(input) - 100);
      final out = tight.fitSchema(input);
      final fields = (out['fields']! as List).cast<Map>();
      expect(fields, hasLength(8));
      expect(fields.every((f) => !f.containsKey('operators')), isTrue);
      expect(out['truncated'], isTrue);
      expect(
        (fields.first['options']! as List).cast<Map>().every(
          (o) => o.containsKey('id'),
        ),
        isTrue,
      );
      // Untouched input.
      expect(((input['fields']! as List).first as Map)['operators'], isNotNull);
    });

    test('then option ids past 20, then trailing fields, names kept', () {
      final out = shaper.fitSchema(schema());
      expect(ResultShaper.bytes(out), lessThanOrEqualTo(16384));
      final kept = (out['fields']! as List).cast<Map>();
      final options = (kept.first['options']! as List).cast<Map>();
      expect(options.take(20).every((o) => o.containsKey('id')), isTrue);
      expect(options.skip(20).every((o) => !o.containsKey('id')), isTrue);
      expect(options.skip(20).first['label'], 'Option 20');
      final names = [
        for (final f in kept) f['name'],
        ...out['moreFields']! as List,
      ];
      expect(names, [for (var i = 0; i < 40; i++) 'Field $i']);
      expect(out['hint'], contains('collections.get'));
    });

    test('works across the collections of a describe', () {
      final out = shaper.fitSchema({
        'collections': [schema(), schema()],
      });
      expect(ResultShaper.bytes(out), lessThanOrEqualTo(16384));
      final collections = (out['collections']! as List).cast<Map>();
      for (final c in collections) {
        final names = [
          for (final f in (c['fields']! as List).cast<Map>()) f['name'],
          ...(c['moreFields'] as List? ?? const []),
        ];
        expect(names, hasLength(40));
      }
    });
  });
}
