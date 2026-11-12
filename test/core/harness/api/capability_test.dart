import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/harness/harness.dart';

void main() {
  group('Capability', () {
    test('wire names round-trip', () {
      for (final cap in Capability.values) {
        expect(Capability.fromWire(cap.wire), cap);
      }
      expect(
        [for (final c in Capability.values) c.wire],
        [
          'schema:read',
          'data:read',
          'data:write',
          'data:delete',
          'schema:write',
          'schema:delete',
          'views:write',
          'ui:navigate',
          'modules:read',
          'modules:write',
          'automations:write',
          'host:commit',
        ],
      );
    });

    test('modules may ask for the eight data and UI capabilities only', () {
      expect(
        [for (final c in kModuleGrantable) c.wire],
        [
          'schema:read',
          'data:read',
          'data:write',
          'data:delete',
          'schema:write',
          'schema:delete',
          'views:write',
          'ui:navigate',
        ],
      );
    });

    test('the assistant gets everything but host:commit', () {
      expect(kAssistantCaps, {
        ...Capability.values.where((c) => c != Capability.hostCommit),
      });
      expect(kAssistantCaps, contains(Capability.automationsWrite));
      expect(
        () => kAssistantCaps.add(Capability.hostCommit),
        throwsUnsupportedError,
      );
    });
  });

  group('Actor', () {
    test('is kind:id on the wire', () {
      expect(Actor.assistant.wire, 'agent:assistant');
      expect(const Actor.user('u1').wire, 'user:u1');
      expect(Actor.fromWire('plugin:invoices'), const Actor.plugin('invoices'));
      expect(Actor.fromWire('user:a:b'), const Actor.user('a:b'));
    });

    test('equality is by kind and id', () {
      expect(const Actor.user('u1'), const Actor(ActorKind.user, 'u1'));
      expect(const Actor.user('x'), isNot(const Actor.agent('x')));
    });

    test('rejects anything but kind:id', () {
      for (final bad in ['assistant', 'robot:x', 'user:', '']) {
        expect(() => Actor.fromWire(bad), throwsFormatException, reason: bad);
      }
    });
  });

  group('Grants', () {
    test('all allows every capability and every collection', () {
      final grants = Grants.all();
      expect(Capability.values.every(grants.allows), isTrue);
      expect(grants.allowsCollection('c_any'), isTrue);
      expect(grants.toJson(), {
        'caps': [for (final c in Capability.values) c.wire],
        'collections': null,
      });
    });

    test('toJson is always the explicit list, so a stored grant never widens '
        'when a capability is added', () {
      final json = Grants(kAssistantCaps).toJson();
      expect(json['caps'], isNot(contains('*')));
      expect(json['caps'], isNot(contains('host:commit')));
      expect(json['caps'], contains('automations:write'));
      expect(Grants.fromJson(json).caps, kAssistantCaps);
    });

    test('a collection-pinned plugin grant', () {
      final grants = Grants(
        [Capability.dataRead, Capability.schemaRead],
        collections: ['c_orders'],
      );
      expect(grants.allows(Capability.dataWrite), isFalse);
      expect(grants.allowsCollection('c_orders'), isTrue);
      expect(grants.allowsCollection('c_clients'), isFalse);
    });

    test('intersect is the manifest ∩ the user access', () {
      final user = Grants(
        Capability.values.where((c) => c != Capability.schemaDelete),
      );
      final manifest = Grants(
        [Capability.dataRead, Capability.schemaDelete],
        collections: ['c_orders'],
      );
      final effective = manifest.intersect(user);
      expect(effective.caps, {Capability.dataRead});
      expect(effective.collections, {'c_orders'});
      expect(
        Grants(Capability.values, collections: ['a', 'b'])
            .intersect(Grants(Capability.values, collections: ['b', 'c']))
            .collections,
        {'b'},
      );
    });

    test('round-trips through JSON', () {
      final grants = Grants(
        [Capability.uiNavigate, Capability.dataRead],
        collections: ['c_b', 'c_a'],
      );
      final json = grants.toJson();
      expect(json, {
        'caps': ['data:read', 'ui:navigate'],
        'collections': ['c_a', 'c_b'],
      });
      expect(Grants.fromJson(json).toJson(), json);
      expect(
        Grants.fromJson({
          'caps': ['*'],
        }).caps,
        Capability.values.toSet(),
      );
    });

    test('rejects unknown capabilities', () {
      expect(
        () => Grants.fromJson({
          'caps': ['data:everything'],
        }),
        throwsFormatException,
      );
      expect(() => Grants.fromJson({'caps': 'all'}), throwsFormatException);
    });

    test('is immutable', () {
      final grants = Grants([Capability.dataRead]);
      expect(
        () => grants.caps.add(Capability.dataWrite),
        throwsUnsupportedError,
      );
    });
  });
}
