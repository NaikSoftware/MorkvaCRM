import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_cubit.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_state.dart';
import 'package:morkva_crm/features/collections/field_editors/built_in_field_editors.dart';

import 'fake_data_repository.dart';

void main() {
  late FakeDataRepository repository;
  late CollectionEditorCubit cubit;
  final registry = defaultFieldEditorRegistry();

  setUp(() {
    repository = FakeDataRepository(const [
      Collection(
        id: 'c1',
        name: 'Orders',
        fields: [TextFieldDefinition(id: 'f_title', name: 'Title')],
      ),
    ]);
    cubit = CollectionEditorCubit(repository, registry);
  });

  tearDown(() async {
    await cubit.close();
    await repository.dispose();
  });

  CollectionEditorReady ready() => cubit.state as CollectionEditorReady;

  test('load resolves the collection into a clean draft', () async {
    await cubit.load('c1');
    expect(ready().draft.name, 'Orders');
    expect(ready().dirty, isFalse);
    expect(ready().persistedFieldIds, {'f_title'});
  });

  test('load of a missing id emits not-found', () async {
    await cubit.load('nope');
    expect(cubit.state, isA<CollectionEditorNotFound>());
  });

  test('addField appends a default, selects it, and marks dirty', () async {
    await cubit.load('c1');
    cubit.addField('number');

    expect(ready().draft.fields, hasLength(2));
    final added = ready().draft.fields.last;
    expect(added, isA<NumberFieldDefinition>());
    expect(ready().selectedFieldId, added.id);
    expect(ready().dirty, isTrue);
    // The added field is draft-only, not persisted.
    expect(ready().isFieldTypeLocked(added.id), isFalse);
  });

  test('addField gives a unique default name on repeats', () async {
    await cubit.load('c1');
    cubit.addField('text');
    cubit.addField('text');
    final names = ready().draft.fields.map((f) => f.name).toList();
    expect(names.toSet().length, names.length, reason: 'names must be unique');
  });

  test('updateField replaces config on a draft field', () async {
    await cubit.load('c1');
    cubit.addField('text');
    final id = ready().draft.fields.last.id;

    cubit.updateField(
      TextFieldDefinition(id: id, name: 'Notes', multiline: true),
    );

    final field = ready().draft.fieldById(id) as TextFieldDefinition;
    expect(field.multiline, isTrue);
    expect(field.name, 'Notes');
  });

  test('removeField drops the field and clears its selection', () async {
    await cubit.load('c1');
    cubit.selectField('f_title');
    cubit.removeField('f_title');

    expect(ready().draft.fields, isEmpty);
    expect(ready().selectedFieldId, isNull);
  });

  test('reorderFields moves a field (ReorderableListView semantics)', () async {
    await cubit.load('c1');
    cubit.addField('number'); // index 1
    cubit.addField('boolean'); // index 2
    final ids = ready().draft.fields.map((f) => f.id).toList();

    // Move the first field to the end: oldIndex 0, newIndex 3.
    cubit.reorderFields(0, 3);

    final reordered = ready().draft.fields.map((f) => f.id).toList();
    expect(reordered, [ids[1], ids[2], ids[0]]);
  });

  test('renameCollection updates the draft and dirties', () async {
    await cubit.load('c1');
    cubit.renameCollection('Invoices', description: 'billing');
    expect(ready().draft.name, 'Invoices');
    expect(ready().draft.description, 'billing');
    expect(ready().dirty, isTrue);
  });

  test('save commits the whole draft and clears dirty', () async {
    await cubit.load('c1');
    cubit.addField('number');
    cubit.renameCollection('Orders v2');
    expect(ready().dirty, isTrue);

    final ok = await cubit.save();

    expect(ok, isTrue);
    expect(ready().dirty, isFalse);
    final persisted = await repository.getCollection('c1');
    expect(persisted!.name, 'Orders v2');
    expect(persisted.fields, hasLength(2));
  });

  test('save promotes draft fields to persisted/type-locked', () async {
    await cubit.load('c1');
    cubit.addField('text');
    final newId = ready().draft.fields.last.id;
    expect(ready().isFieldTypeLocked(newId), isFalse);

    await cubit.save();

    expect(ready().isFieldTypeLocked(newId), isTrue);
  });

  group('validation', () {
    test('empty collection name blocks save', () async {
      await cubit.load('c1');
      cubit.renameCollection('   ');
      final result = cubit.validate();
      expect(result.hasBlocking, isTrue);

      final ok = await cubit.save();
      expect(ok, isFalse);
      expect(ready().error, isNotNull);
      expect(repository.saveCount, 0);
    });

    test('duplicate field names block save', () async {
      await cubit.load('c1');
      cubit.addField('text');
      final id = ready().draft.fields.last.id;
      cubit.updateField(TextFieldDefinition(id: id, name: 'Title'));

      final result = cubit.validate();
      expect(result.hasBlocking, isTrue);
      expect(await cubit.save(), isFalse);
    });

    test('select with no options is a non-blocking warning', () async {
      await cubit.load('c1');
      cubit.addField('single_select');
      final result = cubit.validate();
      expect(result.hasBlocking, isFalse);
      expect(result.warnings, isNotEmpty);
      // Still saves.
      expect(await cubit.save(), isTrue);
    });

    test('reference with no target is a non-blocking warning', () async {
      await cubit.load('c1');
      cubit.addField('reference');
      final result = cubit.validate();
      expect(result.hasBlocking, isFalse);
      expect(result.warnings, isNotEmpty);
      expect(await cubit.save(), isTrue);
    });
  });

  group('type lock', () {
    test('persisted field rejects a type change', () async {
      await cubit.load('c1');
      // f_title is persisted (text). Try to swap it for a number definition.
      expect(
        () => cubit.updateField(
          NumberFieldDefinition(id: 'f_title', name: 'Title'),
        ),
        throwsA(isA<AssertionError>()),
      );
      // Draft unchanged: still a text field.
      expect(ready().draft.fieldById('f_title'), isA<TextFieldDefinition>());
    });

    test('persisted field still accepts same-type config edits', () async {
      await cubit.load('c1');
      cubit.updateField(
        const TextFieldDefinition(id: 'f_title', name: 'Title', maxLength: 80),
      );
      final field = ready().draft.fieldById('f_title') as TextFieldDefinition;
      expect(field.maxLength, 80);
    });

    test('draft-only field may change type freely', () async {
      await cubit.load('c1');
      cubit.addField('text');
      final id = ready().draft.fields.last.id;
      // Replace the draft-only text field with a number field of the same id.
      cubit.updateField(NumberFieldDefinition(id: id, name: 'Count'));
      expect(ready().draft.fieldById(id), isA<NumberFieldDefinition>());
    });
  });

  test('save failure retains draft, stays dirty, surfaces error', () async {
    await cubit.load('c1');
    cubit.renameCollection('New Name');
    repository.saveError = () => StateError('network down');

    final ok = await cubit.save();

    expect(ok, isFalse);
    expect(ready().dirty, isTrue);
    expect(ready().error, contains('Failed to save'));
    expect(ready().draft.name, 'New Name');
  });
}
