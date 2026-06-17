@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/features/collections/util/id_generator.dart';

/// Web-platform regression guard for the id generator.
///
/// On the web, Dart `int` is a JS number and `<<` uses 32-bit shift semantics,
/// so the original `_random.nextInt(1 << 32)` evaluated `1 << 32` to 0 and
/// threw `RangeError: max must be in range 0 < max ≤ 2^32, was 0`. That broke
/// EVERY id mint (collection / field / option) on web, so no collection could
/// be created — yet VM tests passed because `1 << 32` is correct on the VM.
///
/// This suite runs ONLY on the browser (`flutter test --platform chrome`) so it
/// actually exercises the platform where the bug lived: it fails on the
/// unfixed code and passes on the fixed code.
void main() {
  final ids = IdGenerator();

  test('collectionId mints a well-formed id on web (no RangeError)', () {
    final id = ids.collectionId();
    expect(id, startsWith('c_'));
    expect(id.split('_').length, greaterThanOrEqualTo(3));
  });

  test('every id kind mints without throwing on web', () {
    expect(ids.collectionId, returnsNormally);
    expect(ids.fieldId, returnsNormally);
    expect(ids.optionId, returnsNormally);
  });

  test('ids are unique across many mints on web', () {
    final seen = <String>{};
    for (var i = 0; i < 500; i++) {
      expect(seen.add(ids.collectionId()), isTrue);
    }
  });
}
