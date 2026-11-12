import 'package:flutter/material.dart' show IconData, Icons;

import '../../../core/domain/automation/automation.dart';

/// How a chip, row or banner is coloured (the widget picks the tokens).
enum CopyTone {
  /// Plain, no colour (Ask first, Paused).
  neutral,

  /// The leaf tint (Installed, Auto, succeeded).
  success,

  /// Amber: needs the user (Needs consent, needs review, outcome unknown).
  warning,

  /// Error tone: failed, broken.
  error,

  /// Muted ink: skipped, expired, rejected, undone.
  muted,

  /// In progress: queued, running, applying.
  info,
}

/// The button a "what to do" line offers.
enum RunFix {
  reviewPermissions('Review permissions'),
  editAutomation('Edit automation'),
  resume('Resume'),
  runAgain('Run again'),
  changeAccess('Change access'),
  askMorkva('Ask Morkva to fix it');

  const RunFix(this.label);

  final String label;
}

/// "What to do": a sentence, an action button, or both.
typedef RunAdvice = ({String text, RunFix? fix});

/// The plain words for one run state (UX spec §9): the row's second line,
/// the run detail's outcome sentence and what to do ([advice] null = "—").
final class RunCopy {
  const RunCopy({
    required this.row,
    required this.detail,
    required this.tone,
    this.advice,
  });

  final String row;
  final String detail;
  final CopyTone tone;
  final RunAdvice? advice;
}

RunAdvice _fix(RunFix fix, [String? text]) =>
    (text: text ?? fix.label, fix: fix);

RunAdvice _say(String text) => (text: text, fix: null);

/// The copy of a run in [status] for [reason]. [timeoutSeconds] fills
/// "Timed out after N s"; [error] the module's own message.
RunCopy runCopy(
  RunStatus status,
  RunReason? reason, {
  int timeoutSeconds = 20,
  RunError? error,
}) {
  final tone = switch (status) {
    RunStatus.queued ||
    RunStatus.running ||
    RunStatus.sealing ||
    RunStatus.applying => CopyTone.info,
    RunStatus.awaitingReview => CopyTone.warning,
    RunStatus.succeeded => CopyTone.success,
    RunStatus.failed || RunStatus.timedOut => CopyTone.error,
    RunStatus.skipped ||
    RunStatus.rejected ||
    RunStatus.expired => CopyTone.muted,
  };
  switch (status) {
    case RunStatus.queued:
      return RunCopy(
        row: 'Queued',
        detail: 'Waiting for its turn.',
        tone: tone,
      );
    case RunStatus.running:
    case RunStatus.sealing:
      return RunCopy(
        row: 'Running…',
        detail: 'The action is running.',
        tone: tone,
      );
    case RunStatus.applying:
      return RunCopy(
        row: 'Applying…',
        detail: 'Applying the changes.',
        tone: tone,
      );
    case RunStatus.awaitingReview:
      return RunCopy(
        row: 'Needs your review',
        detail: 'The changes wait for you in a preview.',
        tone: tone,
      );
    case RunStatus.succeeded:
      return RunCopy(row: 'Done', detail: 'The action finished.', tone: tone);
    case RunStatus.timedOut:
      return RunCopy(
        row: 'Timed out after $timeoutSeconds s',
        detail:
            'The action took longer than $timeoutSeconds s and was stopped. '
            'Nothing was changed.',
        tone: tone,
        advice: _fix(RunFix.runAgain),
      );
    case RunStatus.skipped:
    case RunStatus.failed:
    case RunStatus.rejected:
    case RunStatus.expired:
      break;
  }
  if (reason == null) {
    return switch (status) {
      RunStatus.rejected => RunCopy(
        row: 'Rejected',
        detail: 'You rejected the preview.',
        tone: tone,
      ),
      RunStatus.expired => RunCopy(
        row: 'Expired',
        detail: 'The preview was kept only while Morkva was open.',
        tone: tone,
        advice: _fix(RunFix.runAgain),
      ),
      RunStatus.skipped => RunCopy(
        row: 'Didn\'t run',
        detail: 'Morkva didn\'t run this action.',
        tone: tone,
      ),
      _ => RunCopy(
        row: 'Failed',
        detail: 'The run failed.',
        tone: tone,
        advice: _fix(RunFix.runAgain),
      ),
    };
  }
  RunCopy copy(String row, String detail, [RunAdvice? advice, CopyTone? t]) =>
      RunCopy(row: row, detail: detail, tone: t ?? tone, advice: advice);
  return switch (reason) {
    RunReason.needsConsent => copy(
      'Needs consent',
      'The module changed or isn\'t allowed yet.',
      _fix(RunFix.reviewPermissions),
    ),
    RunReason.broken => copy(
      'Automation broken',
      'Its condition, action or collection no longer fits.',
      _fix(RunFix.editAutomation),
    ),
    RunReason.crashed => copy(
      'Stopped after a crash',
      'Morkva stopped while this ran, probably out of memory.',
      _fix(RunFix.resume, 'Resume on the automation'),
    ),
    RunReason.paused || RunReason.loopSuspected => copy(
      'Paused',
      'It was paused (by you, or because it looked like a loop).',
      _fix(RunFix.resume),
    ),
    RunReason.engineUnavailable => copy(
      'Can\'t run here',
      'The secure sandbox can\'t start on this device.',
      _say('Run it from another device or browser'),
    ),
    RunReason.notSettled => copy(
      'Card didn\'t update in time',
      'The change hadn\'t reached Morkva within 5 s, so it wasn\'t checked.',
      _fix(RunFix.runAgain),
    ),
    RunReason.notPermitted => copy(
      'Not allowed',
      'A change touched a collection this module isn\'t allowed in.',
      _fix(RunFix.changeAccess),
    ),
    RunReason.loop => copy(
      'Would loop',
      'This automation already ran in this chain.',
      _say('Change its conditions'),
    ),
    RunReason.depthLimit => copy(
      'Chain too long',
      'Automations triggered each other 3 levels deep; Morkva stopped here.',
      _say('Change the automations\' conditions'),
    ),
    RunReason.fanOut => copy(
      'Too many cards at once',
      'Only the first 100 cards of one change are processed.',
      _say('Split the change into smaller batches'),
    ),
    RunReason.queueFull => copy(
      'Too busy',
      'Too many runs were waiting.',
      _fix(RunFix.runAgain, 'Run again later'),
    ),
    RunReason.reviewBacklog => copy(
      'Too many waiting reviews',
      '50 reviews are already waiting.',
      _say('Review or reject the waiting ones'),
    ),
    RunReason.cardGone => copy(
      'Card was deleted',
      'The card no longer exists.',
    ),
    RunReason.cancelled => copy(
      'Stopped',
      'Stopped by you. Nothing was changed.',
      _fix(RunFix.runAgain),
    ),
    RunReason.duplicate => copy(
      'Already running',
      'This automation was already running on this card.',
    ),
    RunReason.loadError || RunReason.bootError || RunReason.loadTimeout => copy(
      'Module didn\'t start',
      'The module\'s code has an error or took too long to load.',
      _fix(RunFix.askMorkva, 'Ask Morkva to fix it, or import a fixed file'),
    ),
    RunReason.moduleError => copy(
      'Module failed',
      error == null
          ? 'The module failed.'
          : 'The module failed: ${error.message}',
      _fix(RunFix.askMorkva),
    ),
    RunReason.planRefused => copy(
      'Change refused',
      'A change the module asked for wasn\'t allowed — see Calls.',
      _fix(RunFix.changeAccess, 'Check Calls; change access if needed'),
    ),
    RunReason.limitExceeded => copy(
      'Too much work',
      'The module asked for more than one run may do (calls, data or time).',
      _say('Run it on fewer cards'),
    ),
    RunReason.abuse => copy(
      'Stopped',
      'The module sent too many or too large messages.',
      _fix(RunFix.askMorkva),
    ),
    RunReason.offline => copy(
      'Offline',
      'Couldn\'t apply without a connection.',
      _fix(RunFix.runAgain, 'Run again when online'),
    ),
    RunReason.notApplied => copy(
      'Nothing applied',
      'None of the changes could be applied — see the plan.',
      _fix(RunFix.runAgain),
    ),
    RunReason.interrupted => copy(
      'Outcome unknown',
      'Morkva was closed while applying — it may be partly applied.',
      _say('Check the card'),
      CopyTone.warning,
    ),
    RunReason.internal => copy(
      'Something went wrong',
      'Morkva hit an unexpected error.',
      _fix(RunFix.runAgain, 'Run again; copy the log if it repeats'),
    ),
    RunReason.codeChanged => copy(
      'Rejected',
      'The module\'s code changed before you reviewed the preview.',
      _fix(RunFix.reviewPermissions),
    ),
    RunReason.uninstalled => copy(
      'Rejected',
      'The module was removed before you reviewed the preview.',
    ),
    RunReason.superseded => copy('Expired', 'A new run replaced this preview.'),
  };
}

/// A run doc of another window or app start that was left applying: Morkva
/// can't tell what was written (no Run again).
const RunCopy kOutcomeUnknownCopy = RunCopy(
  row: 'Outcome unknown',
  detail: 'It was applying in another window — check the cards.',
  tone: CopyTone.warning,
  advice: (text: 'Check the cards', fix: null),
);

/// A review held by another window or an earlier app start.
const RunCopy kReviewNotHereCopy = RunCopy(
  row: 'Review not available here',
  detail: 'It was opened in another window, or before Morkva restarted.',
  tone: CopyTone.muted,
  advice: (text: 'Run again', fix: RunFix.runAgain),
);

/// The run log's policy line as the run detail Plan step shows it:
/// "review: auto-apply is off for this module" → "Asked first: auto-apply
/// is off for this module." (UX §7).
String askedFirstLine(String policy) => policy.startsWith('review: ')
    ? 'Asked first: ${policy.substring('review: '.length)}.'
    : policy;

/// A status chip: its words and tone.
typedef ChipCopy = ({String label, CopyTone tone, IconData? icon});

/// The module chip (UX §1a).
ChipCopy moduleChip(ModuleStatus status) => switch (status) {
  ModuleStatus.ok => (
    label: 'Installed',
    tone: CopyTone.success,
    icon: Icons.check_rounded,
  ),
  ModuleStatus.needsConsent => (
    label: 'Needs consent',
    tone: CopyTone.warning,
    icon: Icons.warning_amber_rounded,
  ),
  ModuleStatus.broken => (
    label: 'Broken',
    tone: CopyTone.error,
    icon: Icons.error_outline,
  ),
};

/// The automation chip (UX §1b); null while active (no chip).
ChipCopy? automationChip(AutomationStatus status) => switch (status) {
  AutomationStatus.needsConsent => (
    label: 'Needs consent',
    tone: CopyTone.warning,
    icon: Icons.warning_amber_rounded,
  ),
  AutomationStatus.broken => (
    label: 'Broken',
    tone: CopyTone.error,
    icon: Icons.error_outline,
  ),
  AutomationStatus.crashed => (
    label: 'Stopped after a crash',
    tone: CopyTone.warning,
    icon: Icons.warning_amber_rounded,
  ),
  AutomationStatus.loopSuspected => (
    label: 'Loop suspected',
    tone: CopyTone.warning,
    icon: Icons.warning_amber_rounded,
  ),
  AutomationStatus.paused => (
    label: 'Paused',
    tone: CopyTone.neutral,
    icon: Icons.pause_rounded,
  ),
  AutomationStatus.active => null,
};

/// An automation's effective apply mode (UX §1b).
enum EffectiveApply { ask, auto, autoOff }

ChipCopy applyChip(EffectiveApply apply) => switch (apply) {
  EffectiveApply.ask => (
    label: 'Ask first',
    tone: CopyTone.neutral,
    icon: Icons.visibility_outlined,
  ),
  EffectiveApply.auto => (
    label: 'Auto',
    tone: CopyTone.success,
    icon: Icons.bolt_rounded,
  ),
  EffectiveApply.autoOff => (
    label: 'Auto · off for this module',
    tone: CopyTone.warning,
    icon: Icons.bolt_rounded,
  ),
};

/// Auto only when stored Auto, by [uid], and [consent] still allows it for
/// the module as it is ([module] `ok`: an old consent to replaced code keeps
/// `autoApply` but no longer counts).
EffectiveApply effectiveApplyOf(
  AutomationRecord automation,
  GrantRecord? consent, {
  required String uid,
  required ModuleStatus? module,
}) {
  if (automation.apply == ApplyMode.ask) return EffectiveApply.ask;
  return automation.autoBy == uid &&
          module == ModuleStatus.ok &&
          (consent?.autoApply ?? false)
      ? EffectiveApply.auto
      : EffectiveApply.autoOff;
}
