// The layering rules of the AI assistant epic, checked over lib/:
// - nothing under lib/core imports Flutter, Firestore, Firebase or http;
// - lib/core/harness imports only lib/core/domain and the DataRepository
//   interface (plus itself);
// - lib/core/agent imports nothing from lib/api (or the app layers) and never
//   builds a user actor (`Actor.user` / `ActorKind.user`);
// - only three files construct a user actor (`Actor.user(`, D18), besides
//   its definition in capability.dart;
// - lib/api never imports lib/features;
// - firebase_ai is imported only in lib/api/ai.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _bannedInCore = [
  'package:flutter', // flutter, flutter_bloc, flutter_test, …
  'package:cloud_firestore/',
  'package:firebase', // firebase_core, firebase_auth, firebase_ai, …
  'package:http/',
  'dart:ui',
];

const _harnessMayImport = ['lib/core/domain/', 'lib/core/harness/'];
const _dataRepositoryInterface = 'lib/api/data/data_repository.dart';
const _agentMayNotImport = [
  'lib/api/',
  'lib/features/',
  'lib/app/',
  'lib/design/',
];

final _directive = RegExp(
  r'^\s*(?:import|export|part)\b[^;]*;',
  multiLine: true,
);
final _quoted = RegExp(r'''(['"])(.*?)\1''');
final _lineComment = RegExp(r'//.*$', multiLine: true);
final _userActor = RegExp(r'\b(?:Actor\.user|ActorKind\.user)\b');
final _userActorCtor = RegExp(r'\bActor\.user\(');
const _userActorSites = {
  'lib/core/harness/api/capability.dart', // the definition
  'lib/features/assistant/bloc/assistant_bloc.dart',
  'lib/core/automation/host_commits.dart',
  'lib/features/views/view_link.dart',
};

/// Every URI named by an import, export or part directive of [source],
/// including the branches of conditional imports.
List<String> directiveUris(String source) => [
  for (final directive in _directive.allMatches(source))
    for (final uri in _quoted.allMatches(directive.group(0)!)) uri.group(2)!,
];

/// The `lib/…` path [uri] points at from [file] (itself `lib/…`), or null
/// for `dart:` and other packages' URIs.
String? resolveProjectUri(String file, String uri) {
  if (uri.startsWith('package:morkva_crm/')) {
    return 'lib/${uri.substring('package:morkva_crm/'.length)}';
  }
  if (uri.contains(':')) return null;
  final segments = file.split('/')..removeLast();
  for (final part in uri.split('/')) {
    if (part == '..') {
      segments.removeLast();
    } else if (part != '.') {
      segments.add(part);
    }
  }
  return segments.join('/');
}

/// The layering problems of one file at [file] (`lib/…`) with [source].
List<String> boundaryViolations(String file, String source) {
  final problems = <String>[];
  for (final uri in directiveUris(source)) {
    final target = resolveProjectUri(file, uri);
    if (file.startsWith('lib/core/') && _bannedInCore.any(uri.startsWith)) {
      problems.add('$file: lib/core must stay pure Dart, imports $uri');
    }
    if (uri.startsWith('package:firebase_ai/') &&
        !file.startsWith('lib/api/ai/')) {
      problems.add('$file: firebase_ai belongs in lib/api/ai only');
    }
    if (target == null) continue;
    if (file.startsWith('lib/core/harness/') &&
        target != _dataRepositoryInterface &&
        !_harnessMayImport.any(target.startsWith)) {
      problems.add('$file: lib/core/harness may not import $target');
    }
    if (file.startsWith('lib/core/agent/') &&
        _agentMayNotImport.any(target.startsWith)) {
      problems.add('$file: lib/core/agent may not import $target');
    }
    if (file.startsWith('lib/api/') && target.startsWith('lib/features/')) {
      problems.add('$file: lib/api may not import $target');
    }
  }
  final code = source.replaceAll(_lineComment, '');
  if (file.startsWith('lib/core/agent/') && _userActor.hasMatch(code)) {
    problems.add('$file: lib/core/agent may not build a user actor');
  }
  if (!_userActorSites.contains(file) && _userActorCtor.hasMatch(code)) {
    problems.add('$file: only the user-actor sites may build Actor.user(');
  }
  return problems;
}

void main() {
  group('the checker', () {
    test('reads plain, conditional, export and part directives', () {
      expect(
        directiveUris('''
/// import 'package:flutter/doc_only.dart';
import 'dart:async';
import 'a.dart' as a show A;
import 'stub.dart'
    if (dart.library.io) 'io.dart'
    if (dart.library.js_interop) "web.dart";
export '../b.dart';
part 'c.g.dart';
'''),
        [
          'dart:async',
          'a.dart',
          'stub.dart',
          'io.dart',
          'web.dart',
          '../b.dart',
          'c.g.dart',
        ],
      );
    });

    test('resolves relative and package URIs to lib paths', () {
      const file = 'lib/core/harness/api/harness.dart';
      expect(
        resolveProjectUri(file, '../ops/registry.dart'),
        'lib/core/harness/ops/registry.dart',
      );
      expect(
        resolveProjectUri(file, './envelope.dart'),
        'lib/core/harness/api/envelope.dart',
      );
      expect(
        resolveProjectUri(file, '../../domain/domain.dart'),
        'lib/core/domain/domain.dart',
      );
      expect(
        resolveProjectUri(file, 'package:morkva_crm/api/api.dart'),
        'lib/api/api.dart',
      );
      expect(resolveProjectUri(file, 'dart:math'), isNull);
      expect(
        resolveProjectUri(file, 'package:equatable/equatable.dart'),
        isNull,
      );
    });

    test('flags each rule', () {
      expect(
        boundaryViolations(
          'lib/core/domain/x.dart',
          "import 'package:flutter/foundation.dart';",
        ),
        hasLength(1),
      );
      expect(
        boundaryViolations(
          'lib/core/harness/cache/x.dart',
          "import 'package:cloud_firestore/cloud_firestore.dart';",
        ),
        hasLength(1),
      );
      expect(
        boundaryViolations(
          'lib/core/harness/cache/x.dart',
          "import '../../../api/sync/sync_status.dart';",
        ),
        [
          'lib/core/harness/cache/x.dart: lib/core/harness may not import lib/api/sync/sync_status.dart',
        ],
      );
      expect(
        boundaryViolations(
          'lib/core/harness/cache/x.dart',
          "import 'package:morkva_crm/api/data/data_repository.dart';\n"
              "import '../../domain/domain.dart';\n"
              "import '../api/envelope.dart';\n"
              "import 'package:equatable/equatable.dart';",
        ),
        isEmpty,
      );
      expect(
        boundaryViolations(
          'lib/core/agent/agent_loop.dart',
          "import 'package:morkva_crm/api/ai/gemini_llm_client.dart';",
        ),
        hasLength(1),
      );
      expect(
        boundaryViolations(
          'lib/core/agent/agent_loop.dart',
          'final ctx = make(actor: const Actor.user(uid));',
        ),
        hasLength(2), // the agent rule and the user-actor sites rule
      );
      expect(
        boundaryViolations(
          'lib/core/agent/agent_loop.dart',
          'if (a.kind == ActorKind.user) {}',
        ),
        hasLength(1),
      );
      expect(
        boundaryViolations(
          'lib/core/agent/agent_loop.dart',
          '// The loop never builds Actor.user.\nfinal a = Actor.assistant;',
        ),
        isEmpty,
      );
      expect(
        boundaryViolations(
          'lib/core/automation/automation_runner.dart',
          'final ctx = make(actor: Actor.user(uid));',
        ),
        [
          'lib/core/automation/automation_runner.dart: only the user-actor '
              'sites may build Actor.user(',
        ],
      );
      expect(
        boundaryViolations(
          'lib/core/automation/host_commits.dart',
          'final ctx = make(actor: Actor.user(uid));\n'
              'if (a.kind == ActorKind.user) {}',
        ),
        isEmpty,
      );
      expect(
        boundaryViolations(
          'lib/core/harness/api/harness.dart',
          'if (a.kind == ActorKind.user) {}',
        ),
        isEmpty,
        reason: 'comparisons stay allowed',
      );
      expect(
        boundaryViolations(
          'lib/api/assistant/thread_repository.dart',
          "import '../../features/assistant/bloc/chat_item.dart';",
        ),
        hasLength(1),
      );
      expect(
        boundaryViolations(
          'lib/features/assistant/view/x.dart',
          "import 'package:firebase_ai/firebase_ai.dart';",
        ),
        hasLength(1),
      );
      expect(
        boundaryViolations(
          'lib/api/ai/gemini_llm_client.dart',
          "import 'package:firebase_ai/firebase_ai.dart';",
        ),
        isEmpty,
      );
    });
  });

  test('lib/ keeps the layering rules', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toList();
    expect(
      files.where((f) => f.startsWith('lib/core/harness/')),
      isNotEmpty,
      reason: 'run from the package root',
    );
    final violations = [
      for (final file in files)
        ...boundaryViolations(file, File(file).readAsStringSync()),
    ];
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
