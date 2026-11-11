import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/input/input_errors.dart';
import 'package:morkva_crm/core/harness/input/value_codec.dart';

import '../fixtures/seed_workspace.dart';
import 'input_fixture.dart';

void main() {
  late ValueCodec codec;

  setUp(() => codec = ValueCodec(resolver()));

  FieldValue decode(String field, Object? value, {ValueCodec? using}) {
    final c = (using ?? codec);
    return c.decode(
      orders,
      c.refs.field(orders, field),
      value,
      path: 'set.$field',
    );
  }

  group('text', () {
    test('takes strings and stringifies numbers', () {
      expect(
        decode('Item', 'Linen dress'),
        const TextFieldValue('Linen dress'),
      );
      expect(decode('Legacy price', 1500), const TextFieldValue('1500'));
      expect(decode('Legacy price', 12.5), const TextFieldValue('12.5'));
      expect(decode('Legacy price', 12.0), const TextFieldValue('12'));
    });

    test('refuses bools and lists', () {
      expect(
        () => decode('Item', true),
        throwsHarness(ErrorCode.wrongType, path: 'set.Item'),
      );
      expect(() => decode('Item', ['a']), throwsHarness(ErrorCode.wrongType));
    });
  });

  group('number', () {
    test('takes numbers and numeric-only strings', () {
      expect(decode('Price', 1200), const NumberFieldValue(1200));
      expect(decode('Price', ' 12 '), const NumberFieldValue(12));
      expect((decode('Price', '12') as NumberFieldValue).value, isA<int>());
      expect(decode('Metres', '-2.5'), const NumberFieldValue(-2.5));
    });

    test('"12 USD" is wrong_type with the unit named', () {
      final error = errorOf(() => decode('Price', '12 USD'));
      expect(error.code, ErrorCode.wrongType);
      expect(error.message, contains("the unit is 'USD'"));
      expect(error.message, contains('Send 12 only'));
    });

    test('refuses words, bools and infinity', () {
      expect(() => decode('Price', 'abc'), throwsHarness(ErrorCode.wrongType));
      expect(() => decode('Price', true), throwsHarness(ErrorCode.wrongType));
      expect(
        () => decode('Price', double.infinity),
        throwsHarness(ErrorCode.wrongType),
      );
    });
  });

  test('booleans take yes/no/true/false in any case', () {
    expect(decode('Paid', true), const BooleanFieldValue(true));
    expect(decode('Paid', 'Yes'), const BooleanFieldValue(true));
    expect(decode('Paid', 'NO'), const BooleanFieldValue(false));
    expect(decode('Paid', 'false'), const BooleanFieldValue(false));
    expect(() => decode('Paid', 'maybe'), throwsHarness(ErrorCode.wrongType));
    expect(() => decode('Paid', 1), throwsHarness(ErrorCode.wrongType));
  });

  group('date-only', () {
    test('takes YYYY-MM-DD as that calendar day', () {
      expect(
        decode('Created', '2026-11-01'),
        DateFieldValue(DateTime.utc(2026, 11, 1)),
      );
    });

    test('relative words and offsets count from the injected today', () {
      expect(
        decode('Created', 'today'),
        DateFieldValue(DateTime.utc(2026, 11, 10)),
      );
      expect(
        decode('Created', 'tomorrow'),
        DateFieldValue(DateTime.utc(2026, 11, 11)),
      );
      expect(
        decode('Created', '+3d'),
        DateFieldValue(DateTime.utc(2026, 11, 13)),
      );
      expect(
        decode('Created', '-1w'),
        DateFieldValue(DateTime.utc(2026, 11, 3)),
      );
      final newYear = ValueCodec(resolver(on: DateTime(2026, 12, 31)));
      expect(
        decode('Created', 'tomorrow', using: newYear),
        DateFieldValue(DateTime.utc(2027, 1, 1)),
      );
    });

    test('refuses impossible days, instants and other words', () {
      expect(
        () => decode('Created', '2026-02-30'),
        throwsHarness(ErrorCode.wrongType, message: 'YYYY-MM-DD'),
      );
      expect(
        () => decode('Created', '2026-11-10T10:00:00Z'),
        throwsHarness(ErrorCode.wrongType),
      );
      expect(
        () => decode('Created', 'soon'),
        throwsHarness(ErrorCode.wrongType),
      );
    });
  });

  group('date with time', () {
    test('an explicit zone is that instant', () {
      expect(
        decode('Delivery slot', '2026-11-10T14:30:00Z'),
        DateFieldValue(DateTime.utc(2026, 11, 10, 14, 30)),
      );
      expect(
        decode('Delivery slot', '2026-11-10T14:30:00+02:00'),
        DateFieldValue(DateTime.utc(2026, 11, 10, 12, 30)),
      );
    });

    test('a zone-less value is device-local time', () {
      expect(
        decode('Delivery slot', '2026-11-10T14:30'),
        DateFieldValue(DateTime(2026, 11, 10, 14, 30).toUtc()),
      );
      expect(
        decode('Delivery slot', '2026-11-10'),
        DateFieldValue(DateTime(2026, 11, 10).toUtc()),
      );
    });

    test('refuses garbage and rolled-over days', () {
      expect(
        () => decode('Delivery slot', '10/11/2026 14:30'),
        throwsHarness(ErrorCode.wrongType, message: 'ISO date-time'),
      );
      expect(
        () => decode('Delivery slot', '2026-02-30T10:00:00Z'),
        throwsHarness(ErrorCode.wrongType),
      );
    });
  });

  group('selects', () {
    test('single select takes a label or id', () {
      expect(
        decode('Status', 'packing'),
        const SingleSelectFieldValue(SeedOptions.packing),
      );
      expect(
        decode('Status', SeedOptions.done),
        const SingleSelectFieldValue(SeedOptions.done),
      );
    });

    test('an unknown label lists every label', () {
      final error = errorOf(() => decode('Status', 'Lost'));
      expect(error.code, ErrorCode.unknownOption);
      expect(error.candidates, ['New', 'Packing', 'Shipped', 'Done']);
      expect(error.path, 'set.Status');
    });

    test('multi select takes a list or one label, without repeats', () {
      expect(
        decode('Tags', ['Gift', 'URGENT', 'gift']),
        const MultiSelectFieldValue([SeedOptions.gift, SeedOptions.urgent]),
      );
      expect(
        decode('Tags', 'repeat'),
        const MultiSelectFieldValue([SeedOptions.repeat]),
      );
      final error = errorOf(() => decode('Tags', ['Gift', 'Sale']));
      expect(error.code, ErrorCode.unknownOption);
      expect(error.path, 'set.Tags[1]');
    });
  });

  group('references', () {
    test('take titles and ids of the target collection', () {
      expect(
        decode('Client', 'Olena Bondar'),
        const ReferenceFieldValue([SeedCards.olena]),
      );
      expect(
        decode('Fabrics', ['Silk Olive', SeedCards.linenBlack]),
        const ReferenceFieldValue([SeedCards.silkOlive, SeedCards.linenBlack]),
      );
    });

    test('a title two cards share is ambiguous_reference with both', () {
      final error = errorOf(() => decode('Client', 'Anna Koval'));
      expect(error.code, ErrorCode.ambiguousReference);
      expect(error.candidates, hasLength(2));
    });

    test('no match is invalid_reference with the nearest titles', () {
      final error = errorOf(() => decode('Client', 'Olena Bondr'));
      expect(error.code, ErrorCode.invalidReference);
      expect(
        error.candidates,
        contains(equals({'id': SeedCards.olena, 'title': 'Olena Bondar'})),
      );
    });

    test('@card links the card open on screen', () {
      final onClient = ValueCodec(
        resolver(
          focus: ScreenContext(
            page: ScreenPage.card,
            collectionId: SeedIds.clients,
            openCardId: SeedCards.taras,
          ),
        ),
      );
      expect(
        decode('Client', '@card', using: onClient),
        const ReferenceFieldValue([SeedCards.taras]),
      );
    });

    test('a target outside the grants is not_permitted', () {
      final pinned = ValueCodec(
        resolver(
          grants: Grants(Capability.values, collections: [SeedIds.orders]),
        ),
      );
      expect(
        () => decode('Client', 'Olena Bondar', using: pinned),
        throwsHarness(ErrorCode.notPermitted),
      );
    });
  });

  test(
    'calculated and auto-number fields are read-only; files unsupported',
    () {
      expect(
        () => decode('Total', 100),
        throwsHarness(ErrorCode.readOnlyField, message: 'calculated'),
      );
      expect(
        () => decode('No', 5),
        throwsHarness(ErrorCode.readOnlyField, message: 'automatically'),
      );
      expect(() => decode('Photos', []), throwsHarness(ErrorCode.unsupported));
    },
  );

  test('null, "" and [] clear a writable field', () {
    expect(decode('Price', null), const NumberFieldValue(null));
    expect(decode('Item', ''), const TextFieldValue(null));
    expect(decode('Tags', []), const MultiSelectFieldValue());
  });

  group('decodeValues', () {
    test('keys by field id and collects every problem with its path', () {
      final errors = InputErrors();
      final values = codec.decodeValues(
        orders,
        {'Item': 'Shirt', 'Price': '12 USD', 'Sttus': 'New', 'Paid': 'yes'},
        path: 'cards[2].values',
        errors: errors,
      );
      expect(values, {
        OrderFields.item: const TextFieldValue('Shirt'),
        OrderFields.paid: const BooleanFieldValue(true),
      });
      expect(errors.details.map((d) => (d.path, d.code)), [
        ('cards[2].values.Price', ErrorCode.wrongType),
        ('cards[2].values.Sttus', ErrorCode.unknownField),
      ]);
    });

    test('a field named twice is invalid_args', () {
      final errors = InputErrors();
      codec.decodeValues(
        orders,
        {'Price': 1, OrderFields.price: 2},
        path: 'set',
        errors: errors,
      );
      expect(errors.details.single.code, ErrorCode.invalidArgs);
    });

    test('3 bad rows of 200 come back together', () {
      final errors = InputErrors();
      for (var i = 0; i < 200; i++) {
        codec.decodeValues(
          orders,
          {'Item': 'Shirt $i', 'Qty': i % 70 == 7 ? 'two' : i},
          path: 'cards[$i].values',
          errors: errors,
        );
      }
      final error = errorOf(errors.throwIfAny);
      expect(error.code, ErrorCode.wrongType);
      expect(error.path, 'cards[7].values.Qty');
      expect(error.details!.map((d) => d.path), [
        'cards[7].values.Qty',
        'cards[77].values.Qty',
        'cards[147].values.Qty',
      ]);
      expect(error.moreErrors, isNull);
    });

    test('details cap at 20 and count the rest', () {
      final errors = InputErrors();
      for (var i = 0; i < 25; i++) {
        codec.decodeValues(
          orders,
          {'Qty': 'x'},
          path: 'cards[$i].values',
          errors: errors,
        );
      }
      final error = errorOf(errors.throwIfAny);
      expect(error.details, hasLength(20));
      expect(error.moreErrors, 5);
    });
  });

  group('validationDetails', () {
    final now = DateTime.utc(2026, 11, 10);
    MorkvaObject card(Map<String, FieldValue> values) => MorkvaObject.create(
      id: 'b_new',
      collection: orders,
      values: values,
      createdAt: now,
      updatedAt: now,
    );

    test('creates report every rule with the field name in the path', () {
      final details = validationDetails(
        orders,
        card({OrderFields.qty: const NumberFieldValue(-1)}),
        path: 'cards[0].values',
      );
      expect(
        details.map((d) => (d.path, d.code)),
        containsAll([('cards[0].values.Item', ErrorCode.requiredValue)]),
      );
    });

    test('updates only report the touched fields', () {
      final details = validationDetails(
        orders,
        card({OrderFields.status: const SingleSelectFieldValue('o_gone')}),
        path: 'patches[0].set',
        onlyFieldIds: {OrderFields.status},
      );
      expect(details.map((d) => (d.path, d.code)), [
        ('patches[0].set.Status', ErrorCode.invalidOption),
      ]);
    });
  });
}
