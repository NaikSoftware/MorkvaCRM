import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

const _stage = SingleSelectFieldDefinition(
  id: 'stage',
  name: 'Stage',
  options: [
    SelectOption(id: 'lead', label: 'Lead', color: 'blue'),
    SelectOption(id: 'won', label: 'Won', color: 'green'),
    SelectOption(id: 'lost', label: 'Lost'),
  ],
);
const _tags = MultiSelectFieldDefinition(
  id: 'tags',
  name: 'Tags',
  options: [
    SelectOption(id: 'a', label: 'Alpha'),
    SelectOption(id: 'b', label: 'Beta'),
  ],
);
const _company = ReferenceFieldDefinition(
  id: 'company',
  name: 'Company',
  targetCollectionId: 'companies',
);
const _contacts = ReferenceFieldDefinition(
  id: 'contacts',
  name: 'Contacts',
  targetCollectionId: 'people',
  multiple: true,
);
const _due = DateFieldDefinition(id: 'due', name: 'Due');
const _at = DateFieldDefinition(id: 'at', name: 'At', includeTime: true);

const _collection = Collection(
  id: 'deals',
  name: 'Deals',
  fields: [
    TextFieldDefinition(id: 'name', name: 'Name'),
    NumberFieldDefinition(id: 'amount', name: 'Amount'),
    AutoNumberFieldDefinition(id: 'no', name: 'No'),
    _due,
    _at,
    BooleanFieldDefinition(id: 'hot', name: 'Hot'),
    _stage,
    _tags,
    _company,
    _contacts,
    FileFieldDefinition(id: 'files', name: 'Files'),
    CalculatedFieldDefinition(
      id: 'calc',
      name: 'Calc',
      declaredOutputType: 'number',
    ),
  ],
);

final _t0 = DateTime.utc(2026, 1, 1);

MorkvaObject _obj(
  String id,
  int minute, [
  Map<String, FieldValue> v = const {},
]) => MorkvaObject.create(
  id: id,
  collection: _collection,
  values: v,
  createdAt: _t0.add(Duration(minutes: minute)),
  updatedAt: _t0.add(Duration(minutes: 100 - minute)),
);

List<String> _ids(List<MorkvaObject> objects) => [
  for (final o in objects) o.id,
];

ViewDefinition _sorted(String fieldId, {bool ascending = true}) =>
    ViewDefinition(
      id: 'v',
      name: 'V',
      sort: ViewSort(fieldId: fieldId, ascending: ascending),
    );

void main() {
  group('applyView sort', () {
    void expectSort(
      String fieldId,
      List<MorkvaObject> objects,
      List<String> asc,
      List<String> desc,
    ) {
      expect(_ids(applyView(_collection, _sorted(fieldId), objects)), asc);
      expect(
        _ids(
          applyView(_collection, _sorted(fieldId, ascending: false), objects),
        ),
        desc,
      );
    }

    test('text: case-insensitive, empties last both ways', () {
      final objects = [
        _obj('e', 0),
        _obj('b', 1, {'name': const TextFieldValue('beta')}),
        _obj('a', 2, {'name': const TextFieldValue('Alpha')}),
        _obj('e2', 3, {'name': const TextFieldValue('')}),
        _obj('c', 4, {'name': const TextFieldValue('Gamma')}),
      ];
      expectSort(
        'name',
        objects,
        ['a', 'b', 'c', 'e', 'e2'],
        ['c', 'b', 'a', 'e', 'e2'],
      );
    });

    test('number and auto-number numerically', () {
      final objects = [
        _obj('ten', 0, {
          'amount': const NumberFieldValue(10),
          'no': const AutoNumberFieldValue(10),
        }),
        _obj('two', 1, {
          'amount': const NumberFieldValue(2.5),
          'no': const AutoNumberFieldValue(2),
        }),
        _obj('none', 2),
        _obj('neg', 3, {
          'amount': const NumberFieldValue(-1),
          'no': const AutoNumberFieldValue(1),
        }),
      ];
      expectSort(
        'amount',
        objects,
        ['neg', 'two', 'ten', 'none'],
        ['ten', 'two', 'neg', 'none'],
      );
      expectSort(
        'no',
        objects,
        ['neg', 'two', 'ten', 'none'],
        ['ten', 'two', 'neg', 'none'],
      );
    });

    test('date chronologically', () {
      final objects = [
        _obj('late', 0, {'due': DateFieldValue(DateTime.utc(2026, 5, 1))}),
        _obj('none', 1),
        _obj('early', 2, {'due': DateFieldValue(DateTime.utc(2025, 5, 1))}),
      ];
      expectSort(
        'due',
        objects,
        ['early', 'late', 'none'],
        ['late', 'early', 'none'],
      );
    });

    test('boolean false before true', () {
      final objects = [
        _obj('t', 0, {'hot': const BooleanFieldValue(true)}),
        _obj('n', 1),
        _obj('f', 2, {'hot': const BooleanFieldValue(false)}),
      ];
      expectSort('hot', objects, ['f', 't', 'n'], ['t', 'f', 'n']);
    });

    test('single-select by option order, unknown option after known', () {
      final objects = [
        _obj('lost', 0, {'stage': const SingleSelectFieldValue('lost')}),
        _obj('ghost', 1, {'stage': const SingleSelectFieldValue('gone')}),
        _obj('none', 2),
        _obj('lead', 3, {'stage': const SingleSelectFieldValue('lead')}),
        _obj('won', 4, {'stage': const SingleSelectFieldValue('won')}),
      ];
      expectSort(
        'stage',
        objects,
        ['lead', 'won', 'lost', 'ghost', 'none'],
        ['ghost', 'lost', 'won', 'lead', 'none'],
      );
    });

    test('multi-select, file and calculated sort by value, empties last', () {
      final objects = [
        _obj('b', 0, {
          'tags': const MultiSelectFieldValue(['b']),
          'files': const FileFieldValue([
            FileAttachment(id: '1', name: 'z.pdf'),
          ]),
          'calc': const CalculatedFieldValue(20),
        }),
        _obj('n', 1),
        _obj('a', 2, {
          'tags': const MultiSelectFieldValue(['a', 'b']),
          'files': const FileFieldValue([
            FileAttachment(id: '2', name: 'a.pdf'),
          ]),
          'calc': const CalculatedFieldValue(3),
        }),
      ];
      expectSort('tags', objects, ['a', 'b', 'n'], ['b', 'a', 'n']);
      expectSort('files', objects, ['a', 'b', 'n'], ['b', 'a', 'n']);
      expectSort('calc', objects, ['a', 'b', 'n'], ['b', 'a', 'n']);
    });

    test('pseudo fields @createdAt / @updatedAt', () {
      final objects = [_obj('mid', 5), _obj('old', 1), _obj('new', 9)];
      expectSort(
        ViewSort.createdAt,
        objects,
        ['old', 'mid', 'new'],
        ['new', 'mid', 'old'],
      );
      // updatedAt runs opposite to createdAt in the fixture.
      expectSort(
        ViewSort.updatedAt,
        objects,
        ['new', 'mid', 'old'],
        ['old', 'mid', 'new'],
      );
    });

    test(
      'ties keep createdAt order in both directions (stable, >32 items)',
      () {
        final objects = [
          for (var i = 39; i >= 0; i--)
            _obj('o$i', i, {'amount': NumberFieldValue(i.isEven ? 1 : 2)}),
        ];
        final evens = [for (var i = 0; i < 40; i += 2) 'o$i'];
        final odds = [for (var i = 1; i < 40; i += 2) 'o$i'];
        expectSort('amount', objects, [...evens, ...odds], [...odds, ...evens]);
      },
    );

    test('sort on a missing field falls back to manual order', () {
      final objects = [_obj('b', 1), _obj('a', 0)];
      final view = _sorted('deleted').copyWith(manualOrder: ['b']);
      expect(_ids(applyView(_collection, view, objects)), ['b', 'a']);
    });
  });

  group('applyView manual order', () {
    test('listed ids first, stale ignored, the rest oldest first', () {
      final objects = [_obj('x', 3), _obj('y', 1), _obj('z', 2), _obj('w', 0)];
      const view = ViewDefinition(
        id: 'v',
        name: 'V',
        manualOrder: ['z', 'stale', 'x', 'z'],
      );
      expect(_ids(applyView(_collection, view, objects)), ['z', 'x', 'w', 'y']);
    });

    test('no manual order → createdAt order', () {
      final objects = [_obj('b', 2), _obj('a', 1), _obj('c', 3)];
      const view = ViewDefinition(id: 'v', name: 'V');
      expect(_ids(applyView(_collection, view, objects)), ['a', 'b', 'c']);
    });
  });

  group('applyView filters', () {
    final objects = [
      _obj('acme-won', 0, {
        'name': const TextFieldValue('Acme deal'),
        'stage': const SingleSelectFieldValue('won'),
      }),
      _obj('acme-lead', 1, {
        'name': const TextFieldValue('ACME renewal'),
        'stage': const SingleSelectFieldValue('lead'),
      }),
      _obj('other-won', 2, {
        'name': const TextFieldValue('Globex'),
        'stage': const SingleSelectFieldValue('won'),
      }),
    ];

    test('filters are AND-ed', () {
      const view = ViewDefinition(
        id: 'v',
        name: 'V',
        filters: [
          ViewFilter(fieldId: 'name', op: FilterOp.contains, operand: 'acme'),
          ViewFilter(fieldId: 'stage', op: FilterOp.anyOf, operand: ['won']),
        ],
      );
      expect(_ids(applyView(_collection, view, objects)), ['acme-won']);
    });

    test('filter on a deleted field is ignored', () {
      const view = ViewDefinition(
        id: 'v',
        name: 'V',
        filters: [ViewFilter(fieldId: 'gone', op: FilterOp.isNotEmpty)],
      );
      expect(applyView(_collection, view, objects), hasLength(3));
    });

    test('does not mutate the input list', () {
      final input = [...objects.reversed];
      applyView(_collection, _sorted('name'), input);
      expect(_ids(input), ['other-won', 'acme-lead', 'acme-won']);
    });
  });

  group('groupableFields', () {
    test('single-select and single reference only, in schema order', () {
      expect(groupableFields(_collection), [_stage, _company]);
    });
  });

  group('groupObjects', () {
    test('select: one group per option in option order, then none', () {
      final objects = [
        _obj('1', 0, {'stage': const SingleSelectFieldValue('won')}),
        _obj('2', 1),
        _obj('3', 2, {'stage': const SingleSelectFieldValue('lead')}),
        _obj('4', 3, {'stage': const SingleSelectFieldValue('won')}),
        _obj('5', 4, {'stage': const SingleSelectFieldValue('deleted')}),
      ];
      final groups = groupObjects(_stage, objects);
      expect(groups.map((g) => g.key), ['lead', 'won', 'lost', null]);
      expect(groups.map((g) => g.label), ['Lead', 'Won', 'Lost', 'No Stage']);
      expect(groups.map((g) => g.color), ['blue', 'green', null, null]);
      expect(groups.map((g) => _ids(g.objects)), [
        ['3'],
        ['1', '4'],
        <String>[],
        ['2', '5'],
      ]);
    });

    test(
      'reference: columns follow referenceLabels order; dangling → none',
      () {
        final objects = [
          _obj('1', 0, {
            'company': const ReferenceFieldValue(['globex']),
          }),
          _obj('2', 1, {
            'company': const ReferenceFieldValue(['acme']),
          }),
          _obj('3', 2, {
            'company': const ReferenceFieldValue(['deleted']),
          }),
          _obj('4', 3),
        ];
        final groups = groupObjects(
          _company,
          objects,
          referenceLabels: const {
            'acme': 'Acme',
            'globex': 'Globex',
            'init': 'Initech',
          },
        );
        expect(groups.map((g) => g.key), ['acme', 'globex', 'init', null]);
        expect(groups.map((g) => g.label), [
          'Acme',
          'Globex',
          'Initech',
          'No Company',
        ]);
        expect(groups.map((g) => _ids(g.objects)), [
          ['2'],
          ['1'],
          <String>[],
          ['3', '4'],
        ]);
      },
    );

    test('a field with no columns yields just the none group', () {
      final groups = groupObjects(_company, [_obj('1', 0)]);
      expect(groups, hasLength(1));
      expect(groups.single.key, isNull);
      expect(_ids(groups.single.objects), ['1']);
    });
  });

  group('bucketByDay', () {
    test('date-only: UTC calendar date, keyed by local midnight', () {
      final objects = [
        _obj('b', 0, {'due': DateFieldValue(DateTime.utc(2026, 3, 10))}),
        _obj('none', 1),
        _obj('a', 2, {'due': DateFieldValue(DateTime.utc(2026, 3, 2))}),
        _obj('c', 3, {'due': DateFieldValue(DateTime.utc(2026, 3, 10))}),
      ];
      final buckets = bucketByDay(_due, objects);
      expect(buckets.days.keys, [DateTime(2026, 3, 2), DateTime(2026, 3, 10)]);
      expect(_ids(buckets.days[DateTime(2026, 3, 10)]!), ['b', 'c']);
      expect(_ids(buckets.undated), ['none']);
    });

    test('with time: local calendar day of the stored UTC instant', () {
      final lateNight = DateTime(2026, 3, 10, 23, 30).toUtc();
      final earlyMorning = DateTime(2026, 3, 11, 0, 15).toUtc();
      final objects = [
        _obj('late', 0, {'at': DateFieldValue(lateNight)}),
        _obj('early', 1, {'at': DateFieldValue(earlyMorning)}),
      ];
      final buckets = bucketByDay(_at, objects);
      expect(buckets.days.keys, [DateTime(2026, 3, 10), DateTime(2026, 3, 11)]);
      expect(_ids(buckets.days[DateTime(2026, 3, 10)]!), ['late']);
      expect(buckets.days.keys.every((k) => !k.isUtc), isTrue);
    });
  });

  group('formatFieldValue', () {
    String f(
      FieldDefinition field,
      FieldValue v, [
      Map<String, String>? labels,
    ]) => formatFieldValue(field, v, referenceLabels: labels ?? const {});

    test('every type', () {
      expect(
        f(
          const TextFieldDefinition(id: 't', name: 'T'),
          const TextFieldValue('Hi'),
        ),
        'Hi',
      );
      expect(
        f(
          const NumberFieldDefinition(id: 'n', name: 'N'),
          const NumberFieldValue(3.0),
        ),
        '3',
      );
      expect(
        f(
          const NumberFieldDefinition(id: 'n', name: 'N'),
          const NumberFieldValue(3.25),
        ),
        '3.25',
      );
      expect(
        f(
          const NumberFieldDefinition(
            id: 'n',
            name: 'N',
            decimalPlaces: 2,
            unitLabel: 'kg',
          ),
          const NumberFieldValue(3),
        ),
        '3.00 kg',
      );
      expect(
        f(
          const AutoNumberFieldDefinition(
            id: 'a',
            name: 'A',
            prefix: 'INV-',
            padding: 4,
          ),
          const AutoNumberFieldValue(42),
        ),
        'INV-0042',
      );
      expect(
        f(
          const AutoNumberFieldDefinition(id: 'a', name: 'A'),
          const AutoNumberFieldValue(7),
        ),
        '7',
      );
      expect(f(_due, DateFieldValue(DateTime.utc(2026, 11, 2))), 'Nov 2, 2026');
      expect(
        f(_at, DateFieldValue(DateTime(2026, 1, 5, 9, 7).toUtc())),
        'Jan 5, 2026 09:07',
      );
      expect(
        f(
          const BooleanFieldDefinition(id: 'b', name: 'B'),
          const BooleanFieldValue(true),
        ),
        'Yes',
      );
      expect(
        f(
          const BooleanFieldDefinition(id: 'b', name: 'B'),
          const BooleanFieldValue(false),
        ),
        'No',
      );
      expect(f(_stage, const SingleSelectFieldValue('won')), 'Won');
      expect(f(_stage, const SingleSelectFieldValue('gone')), '');
      expect(f(_tags, const MultiSelectFieldValue(['b', 'a'])), 'Alpha, Beta');
      expect(
        f(_contacts, const ReferenceFieldValue(['p1', 'p2']), {
          'p1': 'Ann',
          'p2': 'Bo',
        }),
        'Ann, Bo',
      );
      expect(
        f(_contacts, const ReferenceFieldValue(['p1', 'p2']), {'p1': 'Ann'}),
        '2 linked',
      );
      expect(
        f(
          const FileFieldDefinition(id: 'f', name: 'F'),
          const FileFieldValue([
            FileAttachment(id: '1', name: 'a.pdf'),
            FileAttachment(id: '2', name: 'b.png'),
          ]),
        ),
        'a.pdf, b.png',
      );
      expect(
        f(
          const CalculatedFieldDefinition(
            id: 'c',
            name: 'C',
            declaredOutputType: 'number',
          ),
          const CalculatedFieldValue(12),
        ),
        '12',
      );
    });

    test('empty values format as empty string', () {
      for (final field in _collection.fields) {
        expect(f(field, field.emptyValue()), '', reason: field.type);
      }
    });
  });

  group('titleOf', () {
    final object = _obj('1', 0, {
      'name': const TextFieldValue('Acme'),
      'amount': const NumberFieldValue(5),
    });

    test('first field of the view, formatted', () {
      const view = ViewDefinition(
        id: 'v',
        name: 'V',
        fieldIds: ['amount', 'name'],
      );
      expect(titleOf(view, _collection, object), '5');
    });

    test('Untitled when empty, missing or no fields', () {
      const empty = ViewDefinition(id: 'v', name: 'V', fieldIds: ['due']);
      const missing = ViewDefinition(id: 'v', name: 'V', fieldIds: ['gone']);
      const none = ViewDefinition(id: 'v', name: 'V');
      for (final view in [empty, missing, none]) {
        expect(titleOf(view, _collection, object), 'Untitled');
      }
    });
  });

  group('groupValueFor', () {
    test('select and reference values; null key clears', () {
      expect(groupValueFor(_stage, 'won'), const SingleSelectFieldValue('won'));
      expect(groupValueFor(_stage, null).isEmpty, isTrue);
      expect(
        groupValueFor(_company, 'acme'),
        const ReferenceFieldValue(['acme']),
      );
      expect(groupValueFor(_company, null), const ReferenceFieldValue());
    });

    test('non-groupable field throws', () {
      expect(() => groupValueFor(_due, 'x'), throwsArgumentError);
    });
  });

  group('withDay', () {
    test('with time: keeps the local time of day', () {
      final current = DateFieldValue(DateTime(2026, 3, 10, 14, 45, 30).toUtc());
      final moved = withDay(_at, current, DateTime(2026, 4, 2));
      expect(moved.value!.isUtc, isTrue);
      expect(moved.value!.toLocal(), DateTime(2026, 4, 2, 14, 45, 30));
    });

    test('with time and empty current: local midnight', () {
      final moved = withDay(
        _at,
        const DateFieldValue(null),
        DateTime(2026, 4, 2),
      );
      expect(moved.value!.toLocal(), DateTime(2026, 4, 2));
    });

    test('date-only: UTC midnight of the day, same bucket day', () {
      final moved = withDay(
        _due,
        DateFieldValue(DateTime.utc(2026, 3, 10)),
        DateTime(2026, 4, 2),
      );
      expect(moved.value, DateTime.utc(2026, 4, 2));
      expect(calendarDayOf(_due, moved.value!), DateTime(2026, 4, 2));
    });
  });
}
