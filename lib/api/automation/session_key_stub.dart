import 'dart:math';

/// A fresh id per app start.
String loadSessionKey() => mintSessionKey();

String mintSessionKey() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  // A literal bound: `1 << 32` wraps to 0 on the web.
  final suffix = Random().nextInt(0xFFFFFFFF).toRadixString(36);
  return 't_${time}_$suffix';
}
