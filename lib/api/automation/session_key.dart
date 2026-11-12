import 'session_key_stub.dart'
    if (dart.library.js_interop) 'session_key_web.dart'
    as impl;

/// This tab's session id (`t_…`), stamped on run docs so a review can be
/// told apart from one opened elsewhere. On web it lives in
/// `sessionStorage`, so it survives a reload of the same tab; elsewhere it is
/// random per app start.
final String sessionKey = impl.loadSessionKey();
