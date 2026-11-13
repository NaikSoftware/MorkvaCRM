// Temporary: merges lib/l10n/parts/<area>_<locale>.arb into lib/l10n/app_<locale>.arb
// so parallel extraction never edits one file. Fails on duplicate keys.
import 'dart:convert';
import 'dart:io';

void main() {
  for (final locale in ['en', 'uk']) {
    final out = <String, dynamic>{'@@locale': locale};
    final parts = Directory('lib/l10n/parts')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('_$locale.arb'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in parts) {
      final map = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      for (final e in map.entries) {
        if (e.key.startsWith('@@')) continue;
        if (out.containsKey(e.key)) {
          stderr.writeln('duplicate key ${e.key} in ${f.path}');
          exitCode = 1;
        }
        out[e.key] = e.value;
      }
    }
    File('lib/l10n/app_$locale.arb').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(out)}\n',
    );
  }
}
