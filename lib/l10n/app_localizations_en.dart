// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get shellAllCollections => 'All collections';

  @override
  String get shellNavAll => 'All';

  @override
  String get shellCollapseSidebar => 'Collapse sidebar';

  @override
  String get shellExpandSidebar => 'Expand sidebar';

  @override
  String get shellPinnedHeader => 'PINNED';

  @override
  String get shellPinnedEmpty =>
      'Pin the collections you use most — tap the pin on any collection in All collections.';

  @override
  String get shellUnpin => 'Unpin';

  @override
  String get shellDragToReorder => 'Drag to reorder';

  @override
  String get shellJumpTo => 'Jump to…';

  @override
  String shellJumpToShortcut(String shortcut) {
    return 'Jump to… ($shortcut)';
  }

  @override
  String get shellJumpHint => 'Jump to a collection';

  @override
  String shellJumpNoMatch(String query) {
    return 'No collection matches \"$query\"';
  }

  @override
  String get shellAskMorkva => 'Ask Morkva';

  @override
  String shellAskMorkvaShortcut(String shortcut) {
    return 'Ask Morkva · $shortcut';
  }

  @override
  String get shellAccountAndSettings => 'Account and settings';

  @override
  String get shellSyncSynced => 'Synced';

  @override
  String get shellSyncSyncing => 'Syncing…';

  @override
  String get shellSyncOffline => 'Offline';

  @override
  String get shellSyncConflict => 'Conflict';

  @override
  String get shellSyncError => 'Sync error';

  @override
  String shellSyncStatus(String status) {
    return 'Sync status: $status';
  }

  @override
  String shellSyncStatusDismiss(String status) {
    return 'Sync status: $status. Tap to dismiss.';
  }

  @override
  String designTypeToConfirm(String text) {
    return 'Type “$text” to confirm';
  }

  @override
  String get designChangeIcon => 'Change icon';

  @override
  String get designChooseIcon => 'Choose an icon';

  @override
  String get designIconNone => 'None';

  @override
  String get designIconCards => 'Cards';

  @override
  String get designIconGrid => 'Grid';

  @override
  String get designIconInventory => 'Inventory';

  @override
  String get designIconShipping => 'Shipping';

  @override
  String get designIconOrders => 'Orders';

  @override
  String get designIconProducts => 'Products';

  @override
  String get designIconPricing => 'Pricing';

  @override
  String get designIconPeople => 'People';

  @override
  String get designIconContact => 'Contact';

  @override
  String get designIconCompany => 'Company';

  @override
  String get designIconStore => 'Store';

  @override
  String get designIconFinance => 'Finance';

  @override
  String get designIconInvoices => 'Invoices';

  @override
  String get designIconSchedule => 'Schedule';

  @override
  String get designIconTasks => 'Tasks';

  @override
  String get designIconDocuments => 'Documents';

  @override
  String get designIconNotes => 'Notes';

  @override
  String get designIconFavorites => 'Favorites';

  @override
  String get designIconPriorities => 'Priorities';

  @override
  String get designIconProperties => 'Properties';

  @override
  String get designIconVehicles => 'Vehicles';

  @override
  String get designIconServices => 'Services';

  @override
  String get designIconPets => 'Pets';

  @override
  String get designIconMenu => 'Menu';

  @override
  String get assistantAskMorkva => 'Ask Morkva';

  @override
  String get assistantConversationHistory => 'Conversation history';

  @override
  String get assistantNewConversation => 'New conversation';

  @override
  String get assistantCloseAssistant => 'Close assistant';

  @override
  String get assistantBackToConversation => 'Back to the conversation';

  @override
  String get assistantConversations => 'Conversations';

  @override
  String get assistantGreeting => 'Hi. What should we look at?';

  @override
  String assistantGreetingNamed(String name) {
    return 'Hi $name. What should we look at?';
  }

  @override
  String assistantIntroOne(String name) {
    return 'I can read your $name collection, crunch numbers, and make changes — you approve every change before it happens.';
  }

  @override
  String assistantIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'I can read all $count of your collections, crunch numbers, and make changes — you approve every change before it happens.',
      zero:
          'I can help you set up collections, crunch numbers, and make changes — you approve every change before it happens.',
    );
    return '$_temp0';
  }

  @override
  String get assistantSuggestAsk => 'Ask';

  @override
  String get assistantSuggestAnalyze => 'Analyze';

  @override
  String get assistantSuggestAct => 'Act';

  @override
  String get assistantSuggestHelp => 'What can you help me with?';

  @override
  String get assistantSuggestCreateClients =>
      'Create a Clients collection with name, phone and city';

  @override
  String get assistantSuggestSetUpOrders =>
      'Set up an Orders collection linked to Clients';

  @override
  String assistantSuggestHowMany(String name) {
    return 'How many $name were added this month?';
  }

  @override
  String assistantSuggestNewest(String name) {
    return 'Show the 5 newest $name';
  }

  @override
  String assistantSuggestByMonth(String name) {
    return '$name by month this year';
  }

  @override
  String assistantSuggestCompare(String name) {
    return 'Compare $name this month with last month';
  }

  @override
  String assistantSuggestLinked(String name) {
    return 'Add a new collection linked to $name';
  }

  @override
  String assistantSuggestNotes(String name) {
    return 'Add a Notes field to $name';
  }

  @override
  String get assistantConsentTitle => 'Before you start';

  @override
  String get assistantConsentData =>
      'To answer, Ask Morkva sends your question and the parts of your data it needs to Google’s Gemini.';

  @override
  String get assistantConsentFreeTier =>
      'On the free tier Google may use prompts and answers to improve its products, so keep sensitive details out of your questions.';

  @override
  String get assistantDisclaimer =>
      'Answers can be wrong — check important numbers.';

  @override
  String get assistantEnable => 'Enable Ask Morkva';

  @override
  String get assistantOffTitle => 'Ask Morkva is off';

  @override
  String get assistantOffBody => 'Ask Morkva isn’t enabled for your account.';

  @override
  String get assistantNotSetUpTitle => 'Not set up yet';

  @override
  String get assistantNotSetUpBody =>
      'Ask Morkva isn’t set up for this project yet.';

  @override
  String get assistantUnavailableTitle => 'Ask Morkva is unavailable';

  @override
  String get assistantTryLater => 'Try again later.';

  @override
  String assistantOpenObject(String label) {
    return 'Open $label';
  }

  @override
  String get assistantRemoveContext => 'Remove context';

  @override
  String assistantLookingAt(String target) {
    return 'Looking at: $target';
  }

  @override
  String assistantShownCount(int count) {
    return '$count shown';
  }

  @override
  String get assistantJumpToLatest => 'Jump to latest';

  @override
  String get assistantThinking => 'Thinking…';

  @override
  String assistantWaitLarge(int seconds) {
    return 'This conversation is large; waiting $seconds s.';
  }

  @override
  String get assistantBusyRetryingNow => 'Gemini is busy. Retrying now…';

  @override
  String assistantBusyRetryingIn(int seconds) {
    return 'Gemini is busy. Retrying in $seconds s.';
  }

  @override
  String get assistantWaitLargeSpoken =>
      'This conversation is large; waiting before it continues.';

  @override
  String get assistantBusyRetryingShortly =>
      'Gemini is busy. Retrying shortly.';

  @override
  String assistantDailyLimit(String time) {
    return 'Today’s free AI limit is used up. It resets at $time.';
  }

  @override
  String get assistantRetryNow => 'Retry now';

  @override
  String get assistantDeleteThreadTitle => 'Delete this conversation?';

  @override
  String assistantDeleteThreadBody(String title) {
    return '“$title” and its messages will be deleted. Changes it made to your data stay.';
  }

  @override
  String assistantDeleteThreadTooltip(String title) {
    return 'Delete “$title”';
  }

  @override
  String get assistantNoThreads => 'No conversations yet';

  @override
  String get assistantNoThreadsBody => 'Ask something to start one.';

  @override
  String get assistantNothingFound => 'Nothing found';

  @override
  String assistantNoThreadsMatch(String query) {
    return 'No conversations match “$query”.';
  }

  @override
  String get assistantApplyingSwitchLater =>
      'Applying changes… you can switch conversations when it’s done.';

  @override
  String get assistantSearchThreads => 'Search conversations';

  @override
  String get assistantComposerHint =>
      'Ask about your data, or tell me what to change…';

  @override
  String get assistantComposerFollowUp => 'Ask a follow-up…';

  @override
  String get assistantMessageField => 'Message Morkva';

  @override
  String get assistantOffline =>
      'You’re offline — Ask Morkva needs a connection.';

  @override
  String assistantPausedUntil(String time) {
    return 'Ask Morkva is paused until $time.';
  }

  @override
  String get assistantApplyingChanges => 'Applying changes…';

  @override
  String assistantApproveOrKeep(String noun) {
    return 'Approve or keep the $noun above — or send a new message to skip them.';
  }

  @override
  String get assistantApproveOrKeepItems =>
      'Approve or keep the items above — or send a new message to skip them.';

  @override
  String get assistantApproveOrReject =>
      'Approve or reject the changes above — or send a new message to skip them.';

  @override
  String get assistantStopGenerating => 'Stop generating';

  @override
  String get assistantSend => 'Send';

  @override
  String assistantStepsShow(String headline) {
    return 'Steps: $headline. Show each step';
  }

  @override
  String get assistantSteps => 'Steps';

  @override
  String get assistantHideSteps => 'Hide steps';

  @override
  String get assistantStepFailed => 'failed';

  @override
  String get assistantNoChartData => 'No data to chart';

  @override
  String get assistantShowAsChart => 'Show as chart';

  @override
  String get assistantShowAsTable => 'Show as table';

  @override
  String assistantSaveAsView(String name) {
    return 'Save as a view on $name';
  }

  @override
  String assistantSaveAsViewPrompt(String title, String name) {
    return 'Save “$title” as a view on $name';
  }

  @override
  String get assistantSoFar => 'so far';

  @override
  String assistantPointSoFar(String label) {
    return '$label (so far)';
  }

  @override
  String assistantChartSemantics(
    String kind,
    String metric,
    String first,
    String last,
    String details,
  ) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'bar': 'Bar chart',
      'other': 'Line chart',
    });
    return '$_temp0: $metric, from $first to $last$details';
  }

  @override
  String assistantChartPeak(String label, String value) {
    return ', peak $label at $value';
  }

  @override
  String assistantShowingRows(int shown, int total) {
    return 'Showing $shown of $total';
  }

  @override
  String get assistantOpenAsFilteredView => 'Open as filtered view';

  @override
  String get assistantCopyTable => 'Copy table';

  @override
  String get assistantTableCopied => 'Table copied';

  @override
  String assistantOpenCell(String column, String value) {
    return 'Open $column $value';
  }

  @override
  String get assistantRetryFailed => 'Retry failed';

  @override
  String get assistantAppliedSchemaChange => 'Applied schema change';

  @override
  String get assistantAppliedChanges => 'Applied changes';

  @override
  String assistantStaleLeft(int count) {
    return '$count changed elsewhere since the preview — left as they were';
  }

  @override
  String assistantStartedRuns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Started $count automation runs ·',
      one: 'Started 1 automation run ·',
    );
    return '$_temp0';
  }

  @override
  String get assistantView => 'View';

  @override
  String get assistantReverted => 'Reverted — nothing is changed now';

  @override
  String get assistantUndoFailed => 'Couldn’t undo these changes';

  @override
  String assistantUpdatedSomeFailed(int done, int failed) {
    return 'Updated $done, $failed failed';
  }

  @override
  String assistantApprovedOf(int done, int total) {
    return 'You approved $done of $total';
  }

  @override
  String get assistantApplied => 'Applied';

  @override
  String assistantQueued(int count) {
    return '$count waiting for a connection';
  }

  @override
  String assistantAppliedNote(String note) {
    return 'Applied · $note';
  }

  @override
  String get assistantUndoExpired => 'Undo expired';

  @override
  String get assistantUndoUntilClose => 'undo available until you close Morkva';

  @override
  String assistantUndoForMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'undo available for $minutes min',
      one: 'undo available for a minute',
    );
    return '$_temp0';
  }

  @override
  String get assistantStopped => 'Stopped';

  @override
  String get assistantCutShort => 'Cut short — ask me to continue';

  @override
  String get assistantProposedDeletion => 'Proposed deletion';

  @override
  String get assistantProposedChanges => 'Proposed changes';

  @override
  String assistantMoreNotShown(int count) {
    return '$count more not shown yet';
  }

  @override
  String assistantShowMore(int count) {
    return 'Show $count more';
  }

  @override
  String assistantAllSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count selected',
      two: 'Both selected',
    );
    return '$_temp0';
  }

  @override
  String get assistantNoneSelected => 'None selected';

  @override
  String assistantSomeSelected(int picked, int total) {
    return '$picked of $total selected';
  }

  @override
  String assistantDeleteCollectionTitle(String name) {
    return 'Delete the $name collection?';
  }

  @override
  String assistantDeleteCollectionBody(String name, String undo) {
    return 'Every card in $name goes with it. $undo';
  }

  @override
  String get assistantDeleteCollection => 'Delete collection';

  @override
  String get assistantAppliesWithoutAsking => 'Applies changes without asking';

  @override
  String assistantPlanKind(String kind, String fallback) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'createCard': 'Create card',
      'updateCard': 'Update card',
      'deleteCard': 'Delete card',
      'createCollection': 'Create collection',
      'updateCollection': 'Update collection',
      'deleteCollection': 'Delete collection',
      'addField': 'Add field',
      'updateField': 'Update field',
      'deleteField': 'Delete field',
      'createView': 'Create view',
      'updateView': 'Update view',
      'deleteView': 'Delete view',
      'saveModule': 'Save module',
      'saveAutomation': 'Save automation',
      'deleteAutomation': 'Delete automation',
      'other': '$fallback',
    });
    return '$_temp0';
  }

  @override
  String get assistantUndoNone => 'This can’t be undone.';

  @override
  String assistantUndoPartialFor(int minutes) {
    return 'Some of it can be undone for $minutes minutes.';
  }

  @override
  String get assistantUndoPartialLater =>
      'Some of it can be undone afterwards.';

  @override
  String assistantUndoFor(int minutes) {
    return 'You can undo this for $minutes minutes.';
  }

  @override
  String get assistantUndoLater => 'You can undo afterwards.';

  @override
  String assistantNothingChangesUntilApproved(String undo) {
    return 'Nothing changes until you approve. $undo';
  }

  @override
  String assistantModuleSource(String name, String id) {
    return 'Module · $name ($id)';
  }

  @override
  String get assistantDiffFromEmpty => 'from empty';

  @override
  String get assistantDiffEmpty => 'empty';

  @override
  String assistantDiffFrom(String value) {
    return 'from $value';
  }

  @override
  String assistantDiffTo(String value) {
    return 'to $value';
  }

  @override
  String get assistantViewCode => 'View code';

  @override
  String get assistantApplyingChangesLabel => 'Applying changes';

  @override
  String get assistantUpdateModule => 'Update module';

  @override
  String get assistantInstallModule => 'Install module';

  @override
  String assistantDeleteSomeOf(int count, int total) {
    return 'Delete $count of $total';
  }

  @override
  String assistantApproveChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Approve $count changes',
      one: 'Approve 1 change',
    );
    return '$_temp0';
  }

  @override
  String get assistantKeepIt => 'Keep it';

  @override
  String get assistantKeepThem => 'Keep them';

  @override
  String get assistantReject => 'Reject';

  @override
  String get assistantApplying => 'Applying…';

  @override
  String assistantUpdatingProgress(int done, int total) {
    return 'Updating $done of $total…';
  }

  @override
  String get assistantRejectedNothingChanged => 'Rejected — nothing changed';

  @override
  String get assistantSkippedNothingChanged => 'Skipped — nothing changed';

  @override
  String assistantNothingChangedAfter(String message) {
    return '$message — nothing changed';
  }

  @override
  String get assistantChangedElsewhere => 'Changed elsewhere since the preview';

  @override
  String get assistantPreviewExpired =>
      'This preview expired — nothing changed';

  @override
  String get assistantInterrupted =>
      'Interrupted while applying — may have been partly applied, check your data';

  @override
  String get assistantCouldNotApply => 'Couldn’t apply the changes';

  @override
  String get assistantRebuild => 'Rebuild';

  @override
  String get assistantErrorLoadPartial =>
      'Couldn’t load this whole conversation, so the message wasn’t sent. Try again in a moment.';

  @override
  String get assistantErrorOpen => 'Couldn’t open this conversation.';

  @override
  String get assistantNothingWasChanged => 'Nothing was changed.';

  @override
  String get assistantApprovedWereApplied =>
      'The changes you approved were applied.';

  @override
  String assistantErrorWithOutcome(String message, String outcome) {
    return '$message $outcome';
  }

  @override
  String get assistantBlocked => 'I can\'t help with that request.';

  @override
  String get assistantErrorDailyLimit => 'Today\'s AI limit is used up.';

  @override
  String get assistantErrorBusy => 'Gemini is busy right now.';

  @override
  String get assistantErrorDropped =>
      'I couldn\'t finish — the connection dropped.';

  @override
  String get assistantErrorUnknown =>
      'Something went wrong and I couldn\'t finish.';

  @override
  String assistantCouldNotReadResult(String message) {
    return 'Couldn’t read the result ($message)';
  }

  @override
  String assistantCouldNotRetry(String message) {
    return 'Couldn’t retry ($message)';
  }

  @override
  String get assistantNeedsConnection => 'Needs a connection';

  @override
  String get assistantNeedsConnectionToUndo => 'Needs a connection to undo';

  @override
  String get assistantSnippetChart => 'chart';

  @override
  String get assistantSnippetTable => 'table';

  @override
  String assistantStepsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps didn\'t go through',
      one: '1 step didn\'t go through',
    );
    return '$_temp0';
  }

  @override
  String assistantResultShown(String name, int count) {
    return '$name · $count shown';
  }

  @override
  String assistantResultCards(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name · $count cards',
      one: '$name · 1 card',
    );
    return '$_temp0';
  }

  @override
  String assistantResultBy(String name, String group) {
    return '$name by $group';
  }

  @override
  String assistantResultWhere(String clauses) {
    return 'where $clauses';
  }

  @override
  String assistantResultMatching(String query) {
    return 'matching $query';
  }

  @override
  String assistantStepLookedAt(String name) {
    return 'Looked at $name';
  }

  @override
  String assistantStepFilteredTo(int count) {
    return 'filtered to $count';
  }

  @override
  String assistantStepFiltered(int from, int to) {
    return 'filtered $from → $to';
  }

  @override
  String assistantStepGroupedBy(String group) {
    return 'grouped by $group';
  }

  @override
  String get assistantTableTotal => 'Total';

  @override
  String get assistantTableAll => 'All';

  @override
  String assistantResultBucket(String field, String bucket) {
    return '$field ($bucket)';
  }

  @override
  String get assistantBucketDay => 'day';

  @override
  String get assistantBucketWeek => 'week';

  @override
  String get assistantBucketMonth => 'month';

  @override
  String get assistantBucketQuarter => 'quarter';

  @override
  String get assistantBucketYear => 'year';

  @override
  String get assistantOpCount => 'count';

  @override
  String get assistantOpSum => 'sum';

  @override
  String get assistantOpAverage => 'average';

  @override
  String get assistantOpMin => 'min';

  @override
  String get assistantOpMax => 'max';

  @override
  String assistantMetricOf(String op, String field) {
    return '$op of $field';
  }

  @override
  String assistantMetricSummed(String field) {
    return 'summed $field';
  }

  @override
  String assistantMetricAveraged(String field) {
    return 'averaged $field';
  }

  @override
  String assistantMetricLowest(String field) {
    return 'lowest $field';
  }

  @override
  String assistantMetricHighest(String field) {
    return 'highest $field';
  }

  @override
  String get assistantMetricCounted => 'counted';

  @override
  String get authWelcomeTitle => 'Welcome to your workspace';

  @override
  String get authWelcomeBody =>
      'One tidy home for your collections and cards — synced securely across every device you sign in on.';

  @override
  String get authPrivacyNote =>
      'We only use your Google account to sign you in. Your data stays yours.';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get syncConflictSemantics => 'Sync conflict warning';

  @override
  String syncConflictTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'A newer version of $count items was saved elsewhere',
      one: 'A newer version of an item was saved elsewhere',
    );
    return '$_temp0';
  }

  @override
  String get syncConflictBody =>
      'We kept your latest changes and replaced the other copy. If that other version mattered, re-enter those edits now.';

  @override
  String get syncConflictDismiss => 'Dismiss conflict warning';

  @override
  String get appTitle => 'Morkva CRM';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDone => 'Done';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonDuplicate => 'Duplicate';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonOk => 'OK';

  @override
  String get commonGotIt => 'Got it';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonCopied => 'Copied';

  @override
  String get commonMore => 'More';

  @override
  String get commonMoreOptions => 'More options';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonNone => 'None';

  @override
  String get commonUntitled => 'Untitled';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonSomethingWentWrong => 'Something went wrong';

  @override
  String get commonToday => 'Today';

  @override
  String get commonYesterday => 'Yesterday';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonCollections => 'Collections';

  @override
  String get commonAutomations => 'Automations';

  @override
  String commonCardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return '$_temp0';
  }

  @override
  String commonFieldCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fields',
      one: '1 field',
    );
    return '$_temp0';
  }

  @override
  String get coreYes => 'Yes';

  @override
  String get coreNo => 'No';

  @override
  String coreLinkedCount(int count) {
    return '$count linked';
  }

  @override
  String coreNoValueGroup(String field) {
    return 'No $field';
  }

  @override
  String coreWeekOf(String day) {
    return 'Week of $day';
  }

  @override
  String get coreDefaultViewName => 'All';

  @override
  String get coreFormulaTypeNumber => 'Number';

  @override
  String get coreFormulaTypeText => 'Text';

  @override
  String get coreFormulaTypeBoolean => 'Yes / No';

  @override
  String get coreFormulaTypeDate => 'Date';

  @override
  String get coreAggregateOpCount => 'Count';

  @override
  String get coreAggregateOpSum => 'Sum';

  @override
  String get coreAggregateOpAverage => 'Average';

  @override
  String get coreAggregateOpMin => 'Min';

  @override
  String get coreAggregateOpMax => 'Max';

  @override
  String formulaFunctionUsage(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'IF': 'IF(condition, then, else)',
      'AND': 'AND(a, b, …)',
      'OR': 'OR(a, b, …)',
      'NOT': 'NOT(condition)',
      'ROUND': 'ROUND(number, digits)',
      'FLOOR': 'FLOOR(number)',
      'CEIL': 'CEIL(number)',
      'ABS': 'ABS(number)',
      'MIN': 'MIN(a, b, …)',
      'MAX': 'MAX(a, b, …)',
      'CONCAT': 'CONCAT(a, b, …)',
      'LEN': 'LEN(text)',
      'UPPER': 'UPPER(text)',
      'LOWER': 'LOWER(text)',
      'TODAY': 'TODAY()',
      'YEAR': 'YEAR(date)',
      'MONTH': 'MONTH(date)',
      'DAY': 'DAY(date)',
      'ISBLANK': 'ISBLANK(value)',
      'other': '$name',
    });
    return '$_temp0';
  }

  @override
  String formulaFunctionSummary(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'IF': 'Picks a value by a Yes / No condition.',
      'AND': 'Yes when every condition is Yes.',
      'OR': 'Yes when any condition is Yes.',
      'NOT': 'Flips Yes and No.',
      'ROUND': 'Rounds to the given decimal digits (0 by default).',
      'FLOOR': 'Rounds down to a whole number.',
      'CEIL': 'Rounds up to a whole number.',
      'ABS': 'The number without its sign.',
      'MIN': 'The smallest number.',
      'MAX': 'The largest number.',
      'CONCAT': 'Joins values into one text.',
      'LEN': 'How many characters the text has.',
      'UPPER': 'The text in capitals.',
      'LOWER': 'The text in lower case.',
      'TODAY': 'Today\'s date.',
      'YEAR': 'The year of a date.',
      'MONTH': 'The month of a date (1–12).',
      'DAY': 'The day of the month of a date.',
      'ISBLANK': 'Yes when the value is empty.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get formulaErrorEmpty => 'Enter a formula';

  @override
  String formulaErrorNotANumber(String text) {
    return '\"$text\" is not a number';
  }

  @override
  String get formulaErrorUnclosedText => 'Close the text with \"';

  @override
  String formulaErrorUnclosedField(String brace) {
    return 'Close the field with $brace';
  }

  @override
  String formulaErrorUnexpected(String text) {
    return 'Unexpected \"$text\"';
  }

  @override
  String formulaErrorNoSuchField(String name) {
    return 'No field named \"$name\"';
  }

  @override
  String get formulaErrorOwnField => 'A formula can\'t use its own field';

  @override
  String formulaErrorFieldNotUsable(String name) {
    return '\"$name\" can\'t be used in a formula — use an Aggregate field to summarize linked items';
  }

  @override
  String formulaErrorFieldWithoutBraces(String token) {
    return 'Put field names in braces: $token';
  }

  @override
  String formulaErrorUnknownFunction(String name) {
    return 'Unknown function \"$name\"';
  }

  @override
  String formulaErrorWrongArguments(String usage) {
    return 'Use $usage';
  }

  @override
  String formulaErrorUnclosedCall(String name) {
    return 'Close $name( with )';
  }

  @override
  String formulaErrorExpectsNumbers(String name) {
    return '$name expects numbers';
  }

  @override
  String formulaErrorExpectsBooleans(String name) {
    return '$name expects Yes / No values';
  }

  @override
  String formulaErrorExpectsText(String name) {
    return '$name expects text';
  }

  @override
  String formulaErrorExpectsDate(String name) {
    return '$name expects a date';
  }

  @override
  String formulaErrorNeedsCondition(String name) {
    return '$name needs a Yes / No condition';
  }

  @override
  String formulaErrorBranchTypesDiffer(String name, String left, String right) {
    return '$name needs \"then\" and \"else\" of the same type ($left vs $right)';
  }

  @override
  String get formulaErrorUnclosedBracket => 'Close the bracket with )';

  @override
  String get formulaErrorEndsEarly => 'The formula ends too early';

  @override
  String get formulaErrorNegateNeedsNumber => '\"-\" needs a number';

  @override
  String get formulaErrorJoinWithAmpersand => 'Use & to join text';

  @override
  String formulaErrorCannotCombine(String op, String left, String right) {
    return '\"$op\" can\'t combine $left and $right';
  }

  @override
  String get capabilitySchemaReadTitle => 'See your collections and fields';

  @override
  String get capabilitySchemaReadExplanation =>
      'Reads collection and field names and types.';

  @override
  String get capabilityDataReadTitle => 'Read cards';

  @override
  String get capabilityDataReadExplanation =>
      'Reads card values in the allowed collections.';

  @override
  String get capabilityDataWriteTitle => 'Create and change cards';

  @override
  String get capabilityDataWriteExplanation => 'Proposes new cards and edits.';

  @override
  String get capabilityDataDeleteTitle => 'Delete cards';

  @override
  String get capabilityDataDeleteExplanation =>
      'Proposes deleting cards. Never applied automatically.';

  @override
  String get capabilitySchemaWriteTitle => 'Change collections and fields';

  @override
  String get capabilitySchemaWriteExplanation =>
      'Proposes new fields or field changes. Never applied automatically.';

  @override
  String get capabilitySchemaDeleteTitle => 'Delete fields and collections';

  @override
  String get capabilitySchemaDeleteExplanation =>
      'Proposes deleting fields or collections. Never applied automatically.';

  @override
  String get capabilityViewsWriteTitle => 'Change views';

  @override
  String get capabilityViewsWriteExplanation =>
      'Proposes view changes — filters, sort, columns. Never applied automatically.';

  @override
  String get capabilityUiNavigateTitle => 'Link to cards';

  @override
  String get capabilityUiNavigateExplanation =>
      'Shows links that open a card or view when you tap them.';

  @override
  String get coreSchemaCollectionNameRequired => 'Collection name is required';

  @override
  String get coreSchemaFieldNameRequired => 'Field name is required';

  @override
  String coreSchemaDuplicateFieldName(String name) {
    return 'Duplicate field name \"$name\"';
  }

  @override
  String coreSchemaTypeLocked(String name) {
    return 'The type of \"$name\" is locked after save; add a new field instead';
  }

  @override
  String get templatesTitle => 'Start from a template';

  @override
  String get templatesSubtitle =>
      'Ready-made collections you can change like any other.';

  @override
  String get templatesLoadFailed => 'Couldn\'t load the templates.';

  @override
  String get templatesSampleHint =>
      'Sample cards come along so you can see it working — delete them anytime.';

  @override
  String templatesContents(int collections, int cards) {
    String _temp0 = intl.Intl.pluralLogic(
      collections,
      locale: localeName,
      other: '$collections collections',
      one: '1 collection',
    );
    String _temp1 = intl.Intl.pluralLogic(
      cards,
      locale: localeName,
      other: '$cards sample cards',
      one: '1 sample card',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get templatesAdd => 'Add to workspace';

  @override
  String templatesAddFailed(String name) {
    return 'Couldn\'t add $name. Check your connection.';
  }

  @override
  String get coreTrelloBoard => 'Trello board';

  @override
  String get coreTrelloUntitledCard => 'Untitled card';

  @override
  String get coreTrelloUntitledList => 'Untitled list';

  @override
  String get coreTrelloUntitledField => 'Untitled field';

  @override
  String get coreTrelloUntitledOption => 'Untitled option';

  @override
  String get coreTrelloUntitledItem => 'Untitled item';

  @override
  String get coreTrelloNoList => 'No list';

  @override
  String get coreTrelloLabel => 'Label';

  @override
  String get coreTrelloMember => 'Member';

  @override
  String get coreTrelloName => 'Name';

  @override
  String get coreTrelloDescription => 'Description';

  @override
  String get coreTrelloList => 'List';

  @override
  String get coreTrelloLabels => 'Labels';

  @override
  String get coreTrelloMembers => 'Members';

  @override
  String get coreTrelloStart => 'Start';

  @override
  String get coreTrelloDue => 'Due';

  @override
  String get coreTrelloDueDone => 'Due done';

  @override
  String get coreTrelloAttachments => 'Attachments';

  @override
  String get coreTrelloLink => 'Trello link';

  @override
  String get coreTrelloArchived => 'Archived';

  @override
  String get coreTrelloBoardView => 'Board';

  @override
  String get coreTrelloItem => 'Item';

  @override
  String get coreTrelloDone => 'Done';

  @override
  String get coreTrelloChecklist => 'Checklist';

  @override
  String get coreTrelloCard => 'Card';

  @override
  String get coreTrelloComment => 'Comment';

  @override
  String get coreTrelloAuthor => 'Author';

  @override
  String get coreTrelloDate => 'Date';

  @override
  String coreTrelloChecklistItems(String board) {
    return '$board · Checklist items';
  }

  @override
  String coreTrelloComments(String board) {
    return '$board · Comments';
  }

  @override
  String coreTrelloFieldRenamed(String field) {
    return '$field (Trello field)';
  }

  @override
  String coreTrelloFieldRenamedNumbered(String field, int number) {
    return '$field (Trello field $number)';
  }

  @override
  String get coreTrelloColorGreen => 'Green';

  @override
  String get coreTrelloColorYellow => 'Yellow';

  @override
  String get coreTrelloColorOrange => 'Orange';

  @override
  String get coreTrelloColorRed => 'Red';

  @override
  String get coreTrelloColorPurple => 'Purple';

  @override
  String get coreTrelloColorBlue => 'Blue';

  @override
  String get coreTrelloColorSky => 'Sky';

  @override
  String get coreTrelloColorLime => 'Lime';

  @override
  String get coreTrelloColorPink => 'Pink';

  @override
  String get coreTrelloColorBlack => 'Black';

  @override
  String coreTrelloColorShade(String color, String shade) {
    String _temp0 = intl.Intl.selectLogic(shade, {
      'light': '$color light',
      'dark': '$color dark',
      'other': '$color $shade',
    });
    return '$_temp0';
  }

  @override
  String validationRequired(String name) {
    return '$name is required';
  }

  @override
  String validationDateMin(String name, String date) {
    return '$name must be on or after $date';
  }

  @override
  String validationDateMax(String name, String date) {
    return '$name must be on or before $date';
  }

  @override
  String validationNumberMin(String name, String min) {
    return '$name must be at least $min';
  }

  @override
  String validationNumberMax(String name, String max) {
    return '$name must be at most $max';
  }

  @override
  String validationTooLong(String name, int max) {
    return '$name must be at most $max characters';
  }

  @override
  String validationOneFile(String name) {
    return '$name allows only one file';
  }

  @override
  String validationFileType(String file, String name) {
    return '$file has an unsupported type for $name';
  }

  @override
  String validationNoOption(String name, String option) {
    return '$name has no option \"$option\"';
  }

  @override
  String validationInvalidOption(String option, String name) {
    return '\"$option\" is not a valid option for $name';
  }

  @override
  String validationBlankReference(String name) {
    return '$name contains a blank reference';
  }

  @override
  String validationOneReference(String name) {
    return '$name may reference at most one object';
  }

  @override
  String get settingsWorkspaceSection => 'Workspace';

  @override
  String get settingsAutomationsSubtitle => 'Modules, buttons and runs';

  @override
  String get settingsImportSection => 'Import from other apps';

  @override
  String get settingsTrelloSubtitle =>
      'Boards become collections — lists, cards, labels, checklists and comments';

  @override
  String get settingsSignOut => 'Sign out';
}
