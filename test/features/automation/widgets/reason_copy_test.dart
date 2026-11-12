import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/features/automation/widgets/reason_copy.dart';

import '../../../core/domain/automation/fixtures.dart';

void main() {
  group('runCopy', () {
    // Reasons with nothing to do ("—").
    const noAdvice = {
      RunReason.cardGone,
      RunReason.duplicate,
      RunReason.uninstalled,
      RunReason.superseded,
    };

    test('every status and reason has row text, detail and what to do', () {
      for (final status in [
        RunStatus.skipped,
        RunStatus.failed,
        RunStatus.rejected,
        RunStatus.expired,
      ]) {
        for (final reason in RunReason.values) {
          final copy = runCopy(status, reason);
          final at = '${status.wire}/${reason.wire}';
          expect(copy.row, isNotEmpty, reason: at);
          expect(copy.detail, isNotEmpty, reason: at);
          if (noAdvice.contains(reason)) {
            expect(copy.advice, isNull, reason: at);
          } else {
            expect(copy.advice?.text, isNotEmpty, reason: at);
          }
        }
      }
      for (final status in RunStatus.values) {
        final copy = runCopy(status, null);
        expect(copy.row, isNotEmpty, reason: status.wire);
        expect(copy.detail, isNotEmpty, reason: status.wire);
      }
      for (final copy in [kOutcomeUnknownCopy, kReviewNotHereCopy]) {
        expect(copy.advice?.text, isNotEmpty);
      }
    });

    test('tone follows the status; interrupted is amber', () {
      expect(
        runCopy(RunStatus.failed, RunReason.notPermitted).tone,
        CopyTone.error,
      );
      expect(
        runCopy(RunStatus.skipped, RunReason.notPermitted).tone,
        CopyTone.muted,
      );
      expect(
        runCopy(RunStatus.failed, RunReason.interrupted).tone,
        CopyTone.warning,
      );
      expect(runCopy(RunStatus.awaitingReview, null).tone, CopyTone.warning);
      expect(runCopy(RunStatus.succeeded, null).tone, CopyTone.success);
      expect(runCopy(RunStatus.running, null).tone, CopyTone.info);
    });

    test('UX §9 words', () {
      final consent = runCopy(RunStatus.skipped, RunReason.needsConsent);
      expect(consent.row, 'Needs consent');
      expect(consent.detail, 'The module changed or isn\'t allowed yet.');
      expect(consent.advice?.fix, RunFix.reviewPermissions);
      expect(
        runCopy(RunStatus.skipped, RunReason.broken).advice?.fix,
        RunFix.editAutomation,
      );
      expect(
        runCopy(RunStatus.skipped, RunReason.notSettled).row,
        'Card didn\'t update in time',
      );
      final timedOut = runCopy(RunStatus.timedOut, null, timeoutSeconds: 20);
      expect(timedOut.row, 'Timed out after 20 s');
      expect(
        timedOut.detail,
        'The action took longer than 20 s and was stopped. Nothing was '
        'changed.',
      );
      expect(
        runCopy(
          RunStatus.failed,
          RunReason.moduleError,
          error: const RunError(code: 'module_error', message: 'TypeError: x'),
        ).detail,
        'The module failed: TypeError: x',
      );
      expect(
        runCopy(RunStatus.skipped, RunReason.cancelled).detail,
        'Stopped by you. Nothing was changed.',
      );
    });
  });

  test('the plan policy line reads as words', () {
    expect(
      askedFirstLine('review: auto-apply is off for this module'),
      'Asked first: auto-apply is off for this module.',
    );
    expect(askedFirstLine('auto'), 'auto');
  });

  group('chips', () {
    test('module, automation and apply chips', () {
      expect(moduleChip(ModuleStatus.ok), (
        label: 'Installed',
        tone: CopyTone.success,
        icon: Icons.check_rounded,
      ));
      expect(applyChip(EffectiveApply.ask).icon, Icons.visibility_outlined);
      expect(moduleChip(ModuleStatus.needsConsent).tone, CopyTone.warning);
      expect(moduleChip(ModuleStatus.broken).tone, CopyTone.error);
      for (final status in AutomationStatus.values) {
        expect(
          automationChip(status) == null,
          status == AutomationStatus.active,
        );
      }
      expect(
        automationChip(AutomationStatus.crashed)?.label,
        'Stopped after a crash',
      );
      expect(
        applyChip(EffectiveApply.autoOff).label,
        'Auto · off for this module',
      );
    });

    test('effective apply: Auto only by this uid with the consent on', () {
      final auto = automation(apply: ApplyMode.auto, autoBy: 'u1');
      expect(
        effectiveApplyOf(
          automation(),
          consent(),
          uid: 'u1',
          module: ModuleStatus.ok,
        ),
        EffectiveApply.ask,
      );
      expect(
        effectiveApplyOf(
          auto,
          consent(autoApply: true),
          uid: 'u1',
          module: ModuleStatus.ok,
        ),
        EffectiveApply.auto,
      );
      expect(
        effectiveApplyOf(auto, consent(), uid: 'u1', module: ModuleStatus.ok),
        EffectiveApply.autoOff,
      );
      expect(
        effectiveApplyOf(
          auto,
          consent(autoApply: true),
          uid: 'u2',
          module: ModuleStatus.ok,
        ),
        EffectiveApply.autoOff,
      );
      expect(
        effectiveApplyOf(auto, null, uid: 'u1', module: ModuleStatus.ok),
        EffectiveApply.autoOff,
      );
      // An auto-apply consent to code that was since replaced.
      expect(
        effectiveApplyOf(
          auto,
          consent(autoApply: true),
          uid: 'u1',
          module: ModuleStatus.needsConsent,
        ),
        EffectiveApply.autoOff,
      );
    });
  });
}
