import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/ids.dart';
import 'package:morkva_crm/features/collections/util/id_generator.dart'
    as old_path;

void main() {
  test('IdGenerator lives in the domain and keeps its prefixes', () {
    final ids = IdGenerator(random: Random(7));
    expect(ids.collectionId(), startsWith('c_'));
    expect(ids.fieldId(), startsWith('f_'));
    expect(ids.optionId(), startsWith('o_'));
    expect(ids.sectionId(), startsWith('s_'));
    expect(ids.rowId(), startsWith('r_'));
    expect(ids.viewId(), startsWith('v_'));
    expect(ids.objectId(), startsWith('b_'));
    expect(ids.attachmentId(), startsWith('a_'));
  });

  test('run and write ids are prefixed and unique', () {
    final ids = IdGenerator(random: Random(7));
    expect(ids.runId(), matches(RegExp(r'^run_[0-9a-z]+_[0-9a-z]+$')));
    expect(ids.writeId(), matches(RegExp(r'^w_[0-9a-z]+_[0-9a-z]+$')));
    final minted = {for (var i = 0; i < 1000; i++) ids.writeId()};
    expect(minted, hasLength(1000));
  });

  test('the old feature path re-exports the same class', () {
    final IdGenerator ids = old_path.IdGenerator();
    expect(ids.fieldId(), startsWith('f_'));
  });
}
