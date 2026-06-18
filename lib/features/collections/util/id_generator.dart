import 'dart:math';

/// Mints stable, reasonably-unique ids for the schema editor.
///
/// Ids are prefixed by kind (`c_` collection, `f_` field, `o_` select option)
/// so they read clearly in JSON and logs, and combine a time-ordered component
/// with a random suffix so two ids minted in the same millisecond still differ.
///
/// `DateTime.now()`/`Random()` are intentional here: this is ordinary app code,
/// not a workflow script. Ids never have to be cryptographically random — only
/// unique enough that an author cannot realistically collide while editing.
class IdGenerator {
  IdGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// A new collection id, e.g. `c_l3k9f2_a7c1`.
  String collectionId() => _mint('c');

  /// A new field id, e.g. `f_l3k9f2_a7c1`.
  String fieldId() => _mint('f');

  /// A new select-option id, e.g. `o_l3k9f2_a7c1`.
  String optionId() => _mint('o');

  // The random suffix bound. Written as a literal (not `1 << 32`): on the web,
  // Dart `int` is a JS number and `<<` uses 32-bit shift semantics, so
  // `1 << 32` wraps to 0 and `Random.nextInt(0)` throws. `0xFFFFFFFF`
  // (2^32 - 1) is the largest bound `nextInt` accepts and is identical on the
  // VM and the web.
  static const int _suffixBound = 0xFFFFFFFF;

  String _mint(String prefix) {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final suffix = _random.nextInt(_suffixBound).toRadixString(36);
    return '${prefix}_${time}_$suffix';
  }
}
