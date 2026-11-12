@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/automation/engine/web/sandbox_sources.dart';
import 'package:morkva_crm/api/automation/engine/web/web_script_engine.dart';

/// A control sandbox whose CSP lets everything through: it must reach the
/// server and pass both probe signals, or "blocked" proves nothing.
const _permissive =
    "default-src * data: blob: 'unsafe-inline' 'unsafe-eval'; "
    "script-src * data: blob: 'unsafe-inline' 'unsafe-eval'";

/// A request-counting server on the VM side.
const _server = r'''
import 'dart:io';
import 'package:stream_channel/stream_channel.dart';

Future<void> hybridMain(StreamChannel channel) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  var hits = 0;
  server.listen((r) {
    hits++;
    r.response
      ..headers.set('access-control-allow-origin', '*')
      ..headers.contentType = ContentType('text', 'javascript')
      ..write('export default 1;')
      ..close();
  });
  channel.sink.add('http://127.0.0.1:${server.port}');
  channel.stream.listen((_) => channel.sink.add(hits));
}
''';

/// A lockdown-free worker: tries the network two ways and counts CSP
/// violation events.
String _netWorker(String url) =>
    '''
self.onmessage = async function (e) {
  const port = e.ports[0], r = { violations: 0 };
  self.addEventListener('securitypolicyviolation', () => { r.violations++; });
  try { const res = await fetch('$url/fetch', { mode: 'no-cors' }); r.fetch = 'status ' + res.status; }
  catch (err) { r.fetch = 'rejected'; }
  try { await import('$url/import.js'); r.import = 'loaded'; }
  catch (err) { r.import = 'rejected'; }
  await new Promise((z) => setTimeout(z, 200));
  port.postMessage(JSON.stringify(r));
};
''';

Future<Map<String, Object?>> _runNet(String csp, String url) async {
  final done = Completer<Map<String, Object?>>();
  final frame = SandboxFrame(
    csp: csp,
    workerSource: _netWorker(url),
    onMessage: (data) => done.complete(
      jsonDecode((data! as JSString).toDart) as Map<String, Object?>,
    ),
    onError: (m) => done.completeError(StateError(m)),
  );
  try {
    return await done.future.timeout(const Duration(seconds: 10));
  } finally {
    frame.destroy();
  }
}

void main() {
  late Stream<Object?> replies;
  late String url;
  late StreamSink<Object?> requests;

  setUpAll(() async {
    final channel = spawnHybridCode(_server);
    replies = channel.stream.asBroadcastStream();
    requests = channel.sink;
    url = await replies.first as String;
  });

  Future<int> hits() async {
    requests.add('count');
    return await replies.first as int;
  }

  test(
    'the sandbox CSP blocks fetch and import(); a permissive control does not',
    () async {
      final start = await hits();
      final blocked = await _runNet(kSandboxCsp, url);
      expect(blocked['fetch'], 'rejected');
      expect(blocked['import'], 'rejected');
      expect(blocked['violations'], 2);
      expect(await hits(), start, reason: 'no request may leave the sandbox');

      final control = await _runNet(_permissive, url);
      expect(control['fetch'], 'status 0');
      expect(control['violations'], 0);
      expect(await hits(), greaterThan(start));
    },
  );

  test(
    'both probe signals tell the sandbox CSP from the permissive control',
    () async {
      final strict = await probeSandbox(kSandboxCsp);
      expect(strict.eval, 'EvalError');
      expect(strict.dataImport, 'blocked');
      expect(strict.cspEnforced, isTrue);

      final control = await probeSandbox(_permissive);
      expect(control.eval, 'allowed');
      expect(control.dataImport, 'allowed');
      expect(control.cspEnforced, isFalse);
    },
  );

  test('a sandbox without any CSP meta fails the probe', () async {
    final none = await probeSandbox('');
    expect(none.cspEnforced, isFalse);
  });
}
