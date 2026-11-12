import 'package:web/web.dart' as web;

import 'session_key_stub.dart' show mintSessionKey;

const _kKey = 'morkva.sessionKey';

/// The tab's id from `sessionStorage`, minted on first use; a fresh one when
/// storage is unavailable (e.g. blocked site data).
String loadSessionKey() {
  try {
    final storage = web.window.sessionStorage;
    final stored = storage.getItem(_kKey);
    if (stored != null && stored.isNotEmpty) return stored;
    final minted = mintSessionKey();
    storage.setItem(_kKey, minted);
    return minted;
  } catch (_) {
    return mintSessionKey();
  }
}
