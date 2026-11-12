import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';

import 'fixtures.dart';

void main() {
  group('automation record', () {
    test('an event automation round-trips', () {
      final a = automation();
      final json = a.toJson();
      expect(json['trigger'], {
        'kind': 'card.updated',
        'collectionId': 'c_orders',
        'where': [
          {
            'field': 'f_status',
            'op': 'anyOf',
            'value': ['o_shipped'],
          },
          {'field': 'f_due', 'op': 'onDay', 'relative': 'today'},
        ],
        'mode': 'enters',
        'fields': ['f_status'],
      });
      expect(AutomationRecord.fromJson('a_1', json), a);
    });

    test('a button automation with auto apply round-trips', () {
      final a = AutomationRecord(
        id: 'a_2',
        name: 'Stamp',
        enabled: true,
        moduleId: 'stamp-shipped-date',
        actionId: 'stamp',
        trigger: const ButtonTrigger(
          scope: ButtonScope.collection,
          collectionId: 'c_orders',
        ),
        button: const ButtonSpec(
          label: 'Stamp',
          icon: 'truck',
          tint: 'teal',
          order: 2,
        ),
        collections: const ['c_orders', 'c_clients'],
        apply: ApplyMode.auto,
        autoBy: 'u1',
        createdBy: 'agent:assistant',
        createdAt: fixtureNow,
        updatedAt: fixtureNow,
      );
      final json = a.toJson();
      expect(
        json.keys,
        containsAll([
          'moduleId',
          'actionId',
          'trigger',
          'enabled',
          'apply',
          'autoBy',
        ]),
      );
      expect(json['apply'], 'auto');
      expect(AutomationRecord.fromJson('a_2', json), a);
    });

    test('refuses malformed docs', () {
      final json = automation().toJson();
      expect(
        () => AutomationRecord.fromJson('a', {...json, 'apply': 'auto'}),
        throwsFormatException,
      );
      expect(
        () => AutomationRecord.fromJson('a', {
          ...json,
          'trigger': {'kind': 'schedule', 'collectionId': 'c'},
        }),
        throwsFormatException,
      );
      expect(
        () => AutomationRecord.fromJson('a', {...json, 'enabled': 'yes'}),
        throwsFormatException,
      );
    });

    test('accepts Firestore-style ISO dates and whole doubles', () {
      final json = automation().toJson()
        ..['createdAt'] = '2026-11-12T10:00:00.000Z'
        ..['button'] = {'label': 'x', 'order': 1.0};
      final a = AutomationRecord.fromJson('a_1', json);
      expect(a.createdAt, fixtureNow);
      expect(a.button!.order, 1);
    });

    test('withPause sets and clears the reason and detail', () {
      final later = fixtureNow.add(const Duration(minutes: 1));
      final broken = automation().withPause(
        PausedReason.broken,
        detail: 'The condition uses "Status", which was deleted',
        now: later,
      );
      expect(broken.toJson()['pausedReason'], 'broken');
      expect(broken.updatedAt, later);
      final resumed = broken.withPause(null, now: later);
      expect(resumed.pausedReason, isNull);
      expect(resumed.brokenDetail, isNull);
      expect(resumed.toJson().containsKey('pausedReason'), isFalse);
    });

    test('status: first match wins', () {
      expect(
        automationStatusOf(
          automation(paused: PausedReason.broken),
          ModuleStatus.needsConsent,
        ),
        AutomationStatus.needsConsent,
      );
      expect(automationStatusOf(automation(), null), AutomationStatus.broken);
      expect(
        automationStatusOf(automation(), ModuleStatus.broken),
        AutomationStatus.broken,
      );
      expect(
        automationStatusOf(
          automation(paused: PausedReason.crashed, enabled: false),
          ModuleStatus.ok,
        ),
        AutomationStatus.crashed,
      );
      expect(
        automationStatusOf(
          automation(paused: PausedReason.loopSuspected),
          ModuleStatus.ok,
        ),
        AutomationStatus.loopSuspected,
      );
      expect(
        automationStatusOf(automation(enabled: false), ModuleStatus.ok),
        AutomationStatus.paused,
      );
      expect(
        automationStatusOf(automation(), ModuleStatus.ok),
        AutomationStatus.active,
      );
    });
  });

  group('consent record', () {
    test('round-trips', () {
      final c = consent(autoApply: true);
      expect(GrantRecord.fromJson(c.moduleId, c.toJson()), c);
      final all = c.copyWith(collections: () => null, autoApply: false);
      expect(all.toJson()['collections'], isNull);
      expect(GrantRecord.fromJson(all.moduleId, all.toJson()), all);
    });

    test('a malformed consent never parses (the store reads it as none)', () {
      final json = consent().toJson();
      for (final bad in <Map<String, Object?>>[
        {
          ...json,
          'caps': ['*'],
        },
        {
          ...json,
          'caps': ['host:commit'],
        },
        {...json, 'caps': 'data:read'},
        {...json, 'via': 'console'},
        {...json, 'schema': 2},
        {...json, 'autoApply': true, 'via': 'assistant_plan'},
        {...json}..remove('codeHash'),
        {...json}..remove('collections'),
        {...json, 'moduleId': 'other-module'},
      ]) {
        expect(
          () => GrantRecord.fromJson('stamp-shipped-date', bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });
  });

  test('every run reason and status has a distinct wire', () {
    expect(
      RunReason.values.map((r) => r.wire).toSet(),
      hasLength(RunReason.values.length),
    );
    for (final wire in [
      'needs_consent',
      'broken',
      'crashed',
      'paused',
      'loop_suspected',
      'engine_unavailable',
      'not_settled',
      'not_permitted',
      'loop',
      'depth_limit',
      'fan_out',
      'queue_full',
      'review_backlog',
      'card_gone',
      'cancelled',
      'duplicate',
      'load_error',
      'boot_error',
      'load_timeout',
      'module_error',
      'plan_refused',
      'abuse',
      'limit_exceeded',
      'offline',
      'not_applied',
      'interrupted',
      'internal',
      'code_changed',
      'uninstalled',
      'superseded',
    ]) {
      expect(RunReason.fromWire(wire), isNotNull, reason: wire);
    }
    expect(
      [
        for (final s in RunStatus.values)
          if (s.persisted) s.wire,
      ],
      [
        'skipped',
        'failed',
        'timed_out',
        'succeeded',
        'awaiting_review',
        'applying',
        'rejected',
        'expired',
      ],
    );
  });
}
