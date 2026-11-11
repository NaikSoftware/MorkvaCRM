import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/assistant/assistant_config.dart';

void main() {
  group('AssistantConfig defaults', () {
    test('follow the owner decisions and the T0 findings', () {
      const config = AssistantConfig.defaults;

      expect(config.enabled, isTrue);
      expect(config.model, 'gemini-3.5-flash-lite');
      expect(config.fallbackModel, isNull);
      expect(config.thinking, AssistantThinking.off);
      expect(config.rpm, 12);
      expect(config.tpm, isNull);
      expect(config.maxRounds, 6);
      expect(config.dailyTurnsSoft, 200);
      expect(config.leaseTtlMinutes, 5);
      expect(config.dataUse, AssistantDataUse.free);
      expect(config.consented, isFalse);
    });

    test('no docs at all resolve to the defaults', () {
      expect(AssistantConfig.resolve(), AssistantConfig.defaults);
    });
  });

  group('AssistantConfig.resolve', () {
    test('reads every field an admin sets', () {
      final config = AssistantConfig.resolve(
        global: {
          'enabled': true,
          'model': 'gemini-3.5-flash',
          'fallbackModel': 'gemini-2.5-flash-lite',
          'thinking': 'low',
          'rpm': 10,
          'tpm': 250000,
          'maxRounds': 4,
          'dailyTurnsSoft': 50,
          'leaseTtlMinutes': 2,
          'dataUse': 'paid',
        },
      );

      expect(
        config,
        const AssistantConfig(
          model: 'gemini-3.5-flash',
          fallbackModel: 'gemini-2.5-flash-lite',
          thinking: AssistantThinking.low,
          rpm: 10,
          tpm: 250000,
          maxRounds: 4,
          dailyTurnsSoft: 50,
          leaseTtlMinutes: 2,
          dataUse: AssistantDataUse.paid,
        ),
      );
    });

    test('a malformed field falls back on its own, keeping the others', () {
      final config = AssistantConfig.resolve(
        global: {
          'enabled': 'yes',
          'model': '   ',
          'fallbackModel': 42,
          'thinking': 'extreme',
          'rpm': '12',
          'tpm': -1,
          'maxRounds': 0,
          'dailyTurnsSoft': double.nan,
          'leaseTtlMinutes': 3.0, // console numbers may arrive as doubles
          'dataUse': 'enterprise',
        },
      );

      expect(config, const AssistantConfig(leaseTtlMinutes: 3));
    });

    test('model names are trimmed', () {
      final config = AssistantConfig.resolve(
        global: {'model': ' gemini-x ', 'fallbackModel': ' gemini-y '},
      );

      expect(config.model, 'gemini-x');
      expect(config.fallbackModel, 'gemini-y');
    });

    test('the global switch turns the assistant off', () {
      expect(
        AssistantConfig.resolve(global: {'enabled': false}).enabled,
        isFalse,
      );
    });

    test('the user flag overrides the global switch both ways', () {
      expect(
        AssistantConfig.resolve(
          global: {'enabled': true},
          userFlags: {'assistant': false},
        ).enabled,
        isFalse,
      );
      expect(
        AssistantConfig.resolve(
          global: {'enabled': false},
          userFlags: {'assistant': true},
        ).enabled,
        isTrue,
      );
    });

    test('a flag doc without a boolean assistant key leaves the global '
        'switch in charge', () {
      expect(
        AssistantConfig.resolve(
          global: {'enabled': false},
          userFlags: {'assistant': 'off', 'other': true},
        ).enabled,
        isFalse,
      );
    });

    test('carries the workspace consent', () {
      final consent = AssistantConsent(
        consentedBy: 'u1',
        consentedAt: DateTime.utc(2026, 11, 10),
      );

      final config = AssistantConfig.resolve(consent: consent);

      expect(config.consented, isTrue);
      expect(config.consent, consent);
    });
  });
}
