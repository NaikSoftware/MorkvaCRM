import 'package:flutter/material.dart' show IconData, Icons;

import '../../../core/domain/automation/automation.dart';
import '../../../l10n/l10n.dart';
import '../../assistant/bloc/assistant_bloc.dart' show currentAppStrings;

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
  reviewPermissions,
  editAutomation,
  resume,
  runAgain,
  changeAccess,
  askMorkva;

  /// The button's words in the app's language.
  String get label => labelIn(currentAppStrings());

  String labelIn(AppLocalizations l10n) => switch (this) {
    reviewPermissions => l10n.automationWidgetsFixReviewPermissions,
    editAutomation => l10n.automationWidgetsFixEditAutomation,
    resume => l10n.automationWidgetsFixResume,
    runAgain => l10n.automationWidgetsFixRunAgain,
    changeAccess => l10n.automationWidgetsFixChangeAccess,
    askMorkva => l10n.automationWidgetsFixAskMorkva,
  };
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

/// The copy of a run in [status] for [reason]. [timeoutSeconds] fills
/// "Timed out after N s"; [error] the module's own message. [l10n] defaults
/// to the app's language (cubits have no context).
RunCopy runCopy(
  RunStatus status,
  RunReason? reason, {
  int timeoutSeconds = 20,
  RunError? error,
  AppLocalizations? l10n,
}) {
  final t = l10n ?? currentAppStrings();
  RunAdvice fix(RunFix fix, [String? text]) =>
      (text: text ?? fix.labelIn(t), fix: fix);
  RunAdvice say(String text) => (text: text, fix: null);
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
        row: t.automationWidgetsRunQueued,
        detail: t.automationWidgetsRunQueuedDetail,
        tone: tone,
      );
    case RunStatus.running:
    case RunStatus.sealing:
      return RunCopy(
        row: t.automationWidgetsRunRunning,
        detail: t.automationWidgetsRunRunningDetail,
        tone: tone,
      );
    case RunStatus.applying:
      return RunCopy(
        row: t.automationWidgetsRunApplying,
        detail: t.automationWidgetsRunApplyingDetail,
        tone: tone,
      );
    case RunStatus.awaitingReview:
      return RunCopy(
        row: t.automationWidgetsRunAwaitingReview,
        detail: t.automationWidgetsRunAwaitingReviewDetail,
        tone: tone,
      );
    case RunStatus.succeeded:
      return RunCopy(
        row: t.commonDone,
        detail: t.automationWidgetsRunDoneDetail,
        tone: tone,
      );
    case RunStatus.timedOut:
      return RunCopy(
        row: t.automationWidgetsRunTimedOut(timeoutSeconds),
        detail: t.automationWidgetsRunTimedOutDetail(timeoutSeconds),
        tone: tone,
        advice: fix(RunFix.runAgain),
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
        row: t.automationWidgetsRunRejected,
        detail: t.automationWidgetsRunRejectedDetail,
        tone: tone,
      ),
      RunStatus.expired => RunCopy(
        row: t.automationWidgetsRunExpired,
        detail: t.automationWidgetsRunExpiredDetail,
        tone: tone,
        advice: fix(RunFix.runAgain),
      ),
      RunStatus.skipped => RunCopy(
        row: t.automationWidgetsRunSkipped,
        detail: t.automationWidgetsRunSkippedDetail,
        tone: tone,
      ),
      _ => RunCopy(
        row: t.automationWidgetsRunFailed,
        detail: t.automationWidgetsRunFailedDetail,
        tone: tone,
        advice: fix(RunFix.runAgain),
      ),
    };
  }
  RunCopy copy(String row, String detail, [RunAdvice? advice, CopyTone? c]) =>
      RunCopy(row: row, detail: detail, tone: c ?? tone, advice: advice);
  return switch (reason) {
    RunReason.needsConsent => copy(
      t.automationWidgetsNeedsConsent,
      t.automationWidgetsReasonNeedsConsentDetail,
      fix(RunFix.reviewPermissions),
    ),
    RunReason.broken => copy(
      t.automationWidgetsReasonBroken,
      t.automationWidgetsReasonBrokenDetail,
      fix(RunFix.editAutomation),
    ),
    RunReason.crashed => copy(
      t.automationWidgetsStoppedAfterCrash,
      t.automationWidgetsReasonCrashedDetail,
      fix(RunFix.resume, t.automationWidgetsReasonCrashedAdvice),
    ),
    RunReason.paused || RunReason.loopSuspected => copy(
      t.automationWidgetsPaused,
      t.automationWidgetsReasonPausedDetail,
      fix(RunFix.resume),
    ),
    RunReason.engineUnavailable => copy(
      t.automationWidgetsReasonEngineUnavailable,
      t.automationWidgetsReasonEngineUnavailableDetail,
      say(t.automationWidgetsReasonEngineUnavailableAdvice),
    ),
    RunReason.notSettled => copy(
      t.automationWidgetsReasonNotSettled,
      t.automationWidgetsReasonNotSettledDetail,
      fix(RunFix.runAgain),
    ),
    RunReason.notPermitted => copy(
      t.automationWidgetsReasonNotPermitted,
      t.automationWidgetsReasonNotPermittedDetail,
      fix(RunFix.changeAccess),
    ),
    RunReason.loop => copy(
      t.automationWidgetsReasonLoop,
      t.automationWidgetsReasonLoopDetail,
      say(t.automationWidgetsReasonLoopAdvice),
    ),
    RunReason.depthLimit => copy(
      t.automationWidgetsReasonDepthLimit,
      t.automationWidgetsReasonDepthLimitDetail,
      say(t.automationWidgetsReasonDepthLimitAdvice),
    ),
    RunReason.fanOut => copy(
      t.automationWidgetsReasonFanOut,
      t.automationWidgetsReasonFanOutDetail,
      say(t.automationWidgetsReasonFanOutAdvice),
    ),
    RunReason.queueFull => copy(
      t.automationWidgetsReasonQueueFull,
      t.automationWidgetsReasonQueueFullDetail,
      fix(RunFix.runAgain, t.automationWidgetsReasonQueueFullAdvice),
    ),
    RunReason.reviewBacklog => copy(
      t.automationWidgetsReasonReviewBacklog,
      t.automationWidgetsReasonReviewBacklogDetail,
      say(t.automationWidgetsReasonReviewBacklogAdvice),
    ),
    RunReason.cardGone => copy(
      t.automationWidgetsReasonCardGone,
      t.automationWidgetsReasonCardGoneDetail,
    ),
    RunReason.cancelled => copy(
      t.automationWidgetsStopped,
      t.automationWidgetsReasonCancelledDetail,
      fix(RunFix.runAgain),
    ),
    RunReason.duplicate => copy(
      t.automationWidgetsReasonDuplicate,
      t.automationWidgetsReasonDuplicateDetail,
    ),
    RunReason.loadError || RunReason.bootError || RunReason.loadTimeout => copy(
      t.automationWidgetsReasonLoadError,
      t.automationWidgetsReasonLoadErrorDetail,
      fix(RunFix.askMorkva, t.automationWidgetsReasonLoadErrorAdvice),
    ),
    RunReason.moduleError => copy(
      t.automationWidgetsReasonModuleError,
      error == null
          ? t.automationWidgetsReasonModuleErrorDetail
          : t.automationWidgetsReasonModuleErrorMessage(error.message),
      fix(RunFix.askMorkva),
    ),
    RunReason.planRefused => copy(
      t.automationWidgetsReasonPlanRefused,
      t.automationWidgetsReasonPlanRefusedDetail,
      fix(RunFix.changeAccess, t.automationWidgetsReasonPlanRefusedAdvice),
    ),
    RunReason.limitExceeded => copy(
      t.automationWidgetsReasonLimitExceeded,
      t.automationWidgetsReasonLimitExceededDetail,
      say(t.automationWidgetsReasonLimitExceededAdvice),
    ),
    RunReason.abuse => copy(
      t.automationWidgetsStopped,
      t.automationWidgetsReasonAbuseDetail,
      fix(RunFix.askMorkva),
    ),
    RunReason.offline => copy(
      t.automationWidgetsReasonOffline,
      t.automationWidgetsReasonOfflineDetail,
      fix(RunFix.runAgain, t.automationWidgetsReasonOfflineAdvice),
    ),
    RunReason.notApplied => copy(
      t.automationWidgetsReasonNotApplied,
      t.automationWidgetsReasonNotAppliedDetail,
      fix(RunFix.runAgain),
    ),
    RunReason.interrupted => copy(
      t.automationWidgetsOutcomeUnknown,
      t.automationWidgetsReasonInterruptedDetail,
      say(t.automationWidgetsReasonInterruptedAdvice),
      CopyTone.warning,
    ),
    RunReason.internal => copy(
      t.commonSomethingWentWrong,
      t.automationWidgetsReasonInternalDetail,
      fix(RunFix.runAgain, t.automationWidgetsReasonInternalAdvice),
    ),
    RunReason.codeChanged => copy(
      t.automationWidgetsRunRejected,
      t.automationWidgetsReasonCodeChangedDetail,
      fix(RunFix.reviewPermissions),
    ),
    RunReason.uninstalled => copy(
      t.automationWidgetsRunRejected,
      t.automationWidgetsReasonUninstalledDetail,
    ),
    RunReason.superseded => copy(
      t.automationWidgetsRunExpired,
      t.automationWidgetsReasonSupersededDetail,
    ),
  };
}

/// A run doc of another window or app start that was left applying: Morkva
/// can't tell what was written (no Run again).
RunCopy outcomeUnknownCopy([AppLocalizations? l10n]) {
  final t = l10n ?? currentAppStrings();
  return RunCopy(
    row: t.automationWidgetsOutcomeUnknown,
    detail: t.automationWidgetsOutcomeUnknownDetail,
    tone: CopyTone.warning,
    advice: (text: t.automationWidgetsOutcomeUnknownAdvice, fix: null),
  );
}

/// A review held by another window or an earlier app start.
RunCopy reviewNotHereCopy([AppLocalizations? l10n]) {
  final t = l10n ?? currentAppStrings();
  return RunCopy(
    row: t.automationWidgetsReviewNotHere,
    detail: t.automationWidgetsReviewNotHereDetail,
    tone: CopyTone.muted,
    advice: (text: RunFix.runAgain.labelIn(t), fix: RunFix.runAgain),
  );
}

/// The run log's policy line as the run detail Plan step shows it:
/// "review: auto-apply is off for this module" → "Asked first: auto-apply
/// is off for this module." (UX §7). The policy text is the runner's own.
String askedFirstLine(String policy, {AppLocalizations? l10n}) =>
    policy.startsWith('review: ')
    ? (l10n ?? currentAppStrings()).automationWidgetsAskedFirst(
        policy.substring('review: '.length),
      )
    : policy;

/// A status chip: its words and tone.
typedef ChipCopy = ({String label, CopyTone tone, IconData? icon});

/// The module chip (UX §1a).
ChipCopy moduleChip(ModuleStatus status, {AppLocalizations? l10n}) {
  final t = l10n ?? currentAppStrings();
  return switch (status) {
    ModuleStatus.ok => (
      label: t.automationWidgetsChipInstalled,
      tone: CopyTone.success,
      icon: Icons.check_rounded,
    ),
    ModuleStatus.needsConsent => (
      label: t.automationWidgetsNeedsConsent,
      tone: CopyTone.warning,
      icon: Icons.warning_amber_rounded,
    ),
    ModuleStatus.broken => (
      label: t.automationWidgetsChipBroken,
      tone: CopyTone.error,
      icon: Icons.error_outline,
    ),
  };
}

/// The automation chip (UX §1b); null while active (no chip).
ChipCopy? automationChip(AutomationStatus status, {AppLocalizations? l10n}) {
  final t = l10n ?? currentAppStrings();
  return switch (status) {
    AutomationStatus.needsConsent => (
      label: t.automationWidgetsNeedsConsent,
      tone: CopyTone.warning,
      icon: Icons.warning_amber_rounded,
    ),
    AutomationStatus.broken => (
      label: t.automationWidgetsChipBroken,
      tone: CopyTone.error,
      icon: Icons.error_outline,
    ),
    AutomationStatus.crashed => (
      label: t.automationWidgetsStoppedAfterCrash,
      tone: CopyTone.warning,
      icon: Icons.warning_amber_rounded,
    ),
    AutomationStatus.loopSuspected => (
      label: t.automationWidgetsChipLoopSuspected,
      tone: CopyTone.warning,
      icon: Icons.warning_amber_rounded,
    ),
    AutomationStatus.paused => (
      label: t.automationWidgetsPaused,
      tone: CopyTone.neutral,
      icon: Icons.pause_rounded,
    ),
    AutomationStatus.active => null,
  };
}

/// An automation's effective apply mode (UX §1b).
enum EffectiveApply { ask, auto, autoOff }

ChipCopy applyChip(EffectiveApply apply, {AppLocalizations? l10n}) {
  final t = l10n ?? currentAppStrings();
  return switch (apply) {
    EffectiveApply.ask => (
      label: t.automationWidgetsChipAskFirst,
      tone: CopyTone.neutral,
      icon: Icons.visibility_outlined,
    ),
    EffectiveApply.auto => (
      label: t.automationWidgetsChipAuto,
      tone: CopyTone.success,
      icon: Icons.bolt_rounded,
    ),
    EffectiveApply.autoOff => (
      label: t.automationWidgetsChipAutoOff,
      tone: CopyTone.warning,
      icon: Icons.bolt_rounded,
    ),
  };
}

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
