import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/features/collections/util/id_generator.dart';

void main() {
  test('sectionId and rowId are prefixed and unique', () {
    final ids = IdGenerator(random: Random(1));
    final s = ids.sectionId();
    final r = ids.rowId();
    expect(s.startsWith('s_'), isTrue);
    expect(r.startsWith('r_'), isTrue);
    expect(ids.sectionId(), isNot(s));
  });
}
