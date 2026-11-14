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
  String assistantDayThreads(String day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conversations',
      one: '1 conversation',
    );
    return '$day, $_temp0';
  }

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
    return 'matching “$query”';
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
  String get automationJustNow => 'just now';

  @override
  String automationMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String automationHoursAgo(int count) {
    return '$count h ago';
  }

  @override
  String automationSizeBytes(int bytes) {
    return '$bytes B';
  }

  @override
  String automationSizeKb(String kb) {
    return '$kb KB';
  }

  @override
  String automationDurationMs(int ms) {
    return '$ms ms';
  }

  @override
  String automationDurationS(int s) {
    return '$s s';
  }

  @override
  String get automationScopeAll => 'In all collections';

  @override
  String automationScopeIn(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $names',
      one: 'In $names',
    );
    return '$_temp0';
  }

  @override
  String get automationRemovedCollectionInline => 'a removed collection';

  @override
  String automationWillAskFor(String titles) {
    return 'Will ask for: $titles';
  }

  @override
  String get automationWhenButtonCard => 'Button on a card';

  @override
  String get automationWhenButtonCollection => 'Button on a collection';

  @override
  String automationWhenButtonOn(String collection) {
    return 'Button on $collection';
  }

  @override
  String get automationWhenCreated => 'When a card is created';

  @override
  String get automationWhenUpdated => 'When a card is updated';

  @override
  String get automationWhenDeleted => 'When a card is deleted';

  @override
  String get automationListAnd => ' and ';

  @override
  String get automationListOr => ' or ';

  @override
  String automationWhenFieldsChange(String fields) {
    return 'when $fields changes';
  }

  @override
  String automationStartsMatchingField(String field, String condition) {
    return '$field starts matching \"$condition\"';
  }

  @override
  String automationStartsMatching(String condition) {
    return 'starts matching \"$condition\"';
  }

  @override
  String automationDoLine(String module, String action) {
    return 'Do: $module › $action';
  }

  @override
  String get automationRemovedModuleInline => 'a removed module';

  @override
  String get automationSourceImported => 'Imported';

  @override
  String get automationSourceAssistant => 'Made by Ask Morkva';

  @override
  String automationInstalledSnack(String name) {
    return 'Installed $name';
  }

  @override
  String get automationAskMorkva => 'Ask Morkva';

  @override
  String get automationAskMorkvaToWrite => 'Ask Morkva to write one';

  @override
  String get automationAskPrefill => 'Write a module that ';

  @override
  String get automationImportModule => 'Import module';

  @override
  String get automationEngineDownTitle =>
      'Automations can\'t run on this device right now.';

  @override
  String get automationEngineDownBody => 'Runs are skipped and logged.';

  @override
  String get automationPageSubtitle =>
      'Modules add actions. Automations put them on buttons or run them when cards change.';

  @override
  String get automationNewAutomation => 'New automation';

  @override
  String get automationInstallModuleFirst => 'Install a module first';

  @override
  String get automationTabModules => 'Modules';

  @override
  String get automationTabRuns => 'Runs';

  @override
  String get automationLoadErrorMessage =>
      'Check your connection and try again.';

  @override
  String get automationLoadModulesFailed => 'Couldn\'t load modules';

  @override
  String get automationLoadAutomationsFailed => 'Couldn\'t load automations';

  @override
  String get automationLoadRunsFailed => 'Couldn\'t load runs';

  @override
  String get automationNoModulesTitle => 'No modules yet';

  @override
  String get automationNoModulesMessage =>
      'Modules add actions to Morkva — like stamping a date or flagging low stock. Ask Morkva to write one, or import a .morkva.json file.';

  @override
  String automationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count automations',
      one: '1 automation',
    );
    return '$_temp0';
  }

  @override
  String get automationThisCollection => 'This collection';

  @override
  String get automationNoAutomationsTitle => 'No automations yet';

  @override
  String get automationNoAutomationsMessage =>
      'Put a module\'s action on a button, or run it when cards are created, changed or deleted.';

  @override
  String get automationRemovedCollection => 'Removed collection';

  @override
  String automationEnabledSemantics(String name) {
    return '$name enabled';
  }

  @override
  String automationClearFilter(String label) {
    return 'Clear $label';
  }

  @override
  String get automationThisCard => 'This card';

  @override
  String get automationThisModule => 'This module';

  @override
  String get automationFilterAll => 'All';

  @override
  String get automationFilterNeedsReview => 'Needs review';

  @override
  String get automationFilterFailed => 'Failed';

  @override
  String get automationFilterByAutomation => 'Filter by automation';

  @override
  String get automationAnyAutomation => 'Any automation';

  @override
  String get automationRunningNow => 'Running now';

  @override
  String get automationNoRunsTitle => 'No runs yet';

  @override
  String get automationNoRunsMessage =>
      'When an automation runs, its log shows up here — what triggered it, what it read, what it changed.';

  @override
  String automationSkippedGroup(int count, String reason) {
    return '$count skipped · $reason';
  }

  @override
  String get automationShow => 'Show';

  @override
  String get automationQueued => 'Queued';

  @override
  String automationQueuedAhead(int count) {
    return 'Queued · $count ahead';
  }

  @override
  String get automationApplyingEllipsis => 'Applying…';

  @override
  String get automationRunning => 'Running';

  @override
  String get automationStop => 'Stop';

  @override
  String automationSkippedTimes(int count, String reason) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Skipped $count times · $reason',
      one: 'Skipped 1 time · $reason',
    );
    return '$_temp0';
  }

  @override
  String get automationUndone => 'Undone';

  @override
  String automationChangedOffline(String changed, String ran) {
    return 'Changed offline $changed · ran $ran';
  }

  @override
  String get automationReview => 'Review';

  @override
  String get automationRunAgain => 'Run again';

  @override
  String automationRunAgainOn(String card) {
    return 'Run again on $card';
  }

  @override
  String get automationReviewPermissions => 'Review permissions';

  @override
  String get automationEditAutomation => 'Edit automation';

  @override
  String get automationEditAction => 'Edit automation';

  @override
  String automationChangeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes',
      one: '1 change',
    );
    return '$_temp0';
  }

  @override
  String get automationNeedsConnection => 'Needs a connection';

  @override
  String get automationImportUnreadable =>
      'Couldn\'t read that file. Choose it again, or paste it.';

  @override
  String get automationImportChooseFileHint => 'Choose a .morkva.json file';

  @override
  String get automationImportChooseFile => 'Choose file';

  @override
  String get automationImportPasteHint => 'Paste the module file (JSON)';

  @override
  String get automationImportSourceFile => 'File';

  @override
  String get automationImportSourcePaste => 'Paste';

  @override
  String automationImportSameVersion(String version) {
    return 'This version (v$version) is already installed.';
  }

  @override
  String automationImportReplacingTitle(String version) {
    return 'A module with this id is installed (v$version).';
  }

  @override
  String automationImportReplacingBody(int count, String version) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Allowing replaces it with v$version for its $count automations.',
      one: 'Allowing replaces it with v$version for its 1 automation.',
    );
    return '$_temp0';
  }

  @override
  String get automationScopeTagCard => 'On a card';

  @override
  String get automationScopeTagCollection => 'On a collection';

  @override
  String get automationScopeTagAny => 'Card or collection';

  @override
  String automationConsentCodeChanged(
    String fromVersion,
    String toVersion,
    String fromSize,
    String toSize,
  ) {
    return 'Code changed: v$fromVersion → v$toVersion · $fromSize → $toSize';
  }

  @override
  String get automationConsentSameVersion =>
      'This version is already installed.';

  @override
  String get automationConsentAutoApplyOffNew =>
      'Auto-apply turns off for the new version. Turn it on again in module details.';

  @override
  String get automationConsentAutoApplyOffAgain =>
      'Auto-apply turns off when you install it again. Turn it on again in module details.';

  @override
  String get automationConsentItCan => 'It can:';

  @override
  String get automationConsentCapNew => 'New';

  @override
  String get automationConsentCapRemoved => 'Removed';

  @override
  String get automationConsentActions => 'Actions:';

  @override
  String get automationViewCode => 'View code';

  @override
  String get automationConsentWhere => 'Where';

  @override
  String get automationConsentAllCollections => 'All collections';

  @override
  String get automationConsentAllCollectionsHint =>
      'Every collection, including new ones.';

  @override
  String get automationOnlyThese => 'Only these';

  @override
  String get automationConsentOnlyTheseHint =>
      'Pick the collections it may read and change.';

  @override
  String get automationConsentSandboxNote =>
      'Modules can\'t reach the internet, your account or other apps. You can change or revoke this later in module details.';

  @override
  String get automationConsentAllowAndInstall => 'Allow and install';

  @override
  String get automationConsentAllow => 'Allow';

  @override
  String automationConsentChangeAccessTitle(String name) {
    return 'Change access for \"$name\"';
  }

  @override
  String automationConsentAllowTitle(String name) {
    return 'Allow \"$name\"?';
  }

  @override
  String get automationConsentPickWhere => 'Choose where it can work';

  @override
  String get automationLoadModuleFailed => 'Couldn\'t load this module';

  @override
  String get automationModuleNotInstalledTitle =>
      'This module isn\'t installed';

  @override
  String get automationModuleNotInstalledMessage =>
      'It was uninstalled, or the link is out of date.';

  @override
  String get automationModuleAllowTitle => 'Allow this module to run.';

  @override
  String get automationModuleAllowBody =>
      'Review what it can do before its actions can run.';

  @override
  String automationModuleChangedTitle(String fromVersion, String toVersion) {
    return 'This module changed (v$fromVersion → v$toVersion).';
  }

  @override
  String get automationModuleChangedBody =>
      'Its automations are paused until you allow the new version.';

  @override
  String get automationReviewChanges => 'Review changes';

  @override
  String get automationModuleBrokenTitle =>
      'This module\'s file is no longer valid.';

  @override
  String get automationModuleBrokenBody => 'Import it again.';

  @override
  String automationExportedSnack(String fileName) {
    return 'Exported $fileName';
  }

  @override
  String automationUninstallTitle(String name) {
    return 'Uninstall \"$name\"?';
  }

  @override
  String get automationUninstallMessageNone =>
      'Its pending reviews are dropped and its permissions are removed. The run history stays.';

  @override
  String get automationUninstallMessageOne =>
      'Its automation and its button are deleted, its pending reviews are dropped and its permissions are removed. The run history stays.';

  @override
  String automationUninstallMessageMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Its $count automations and their buttons are deleted, its pending reviews are dropped and its permissions are removed. The run history stays.',
      one:
          'Its 1 automation and its button are deleted, its pending reviews are dropped and its permissions are removed. The run history stays.',
    );
    return '$_temp0';
  }

  @override
  String get automationUninstall => 'Uninstall';

  @override
  String automationUninstalledSnack(String name) {
    return 'Uninstalled $name';
  }

  @override
  String automationModuleAuthor(String author) {
    return 'Author: $author (from the file)';
  }

  @override
  String get automationExport => 'Export';

  @override
  String get automationModuleAbout => 'About';

  @override
  String automationRevokeTitle(String name) {
    return 'Revoke access for \"$name\"?';
  }

  @override
  String get automationRevokeMessage =>
      'Its automations stop running and pending reviews are dropped until you allow it again.';

  @override
  String get automationRevoke => 'Revoke';

  @override
  String get automationWhatItCanDo => 'What it can do';

  @override
  String get automationChangeAccess => 'Change access';

  @override
  String get automationModuleSandboxNote =>
      'Modules can\'t reach the internet, your account or other apps. Every change goes through a preview unless you turn on auto-apply below.';

  @override
  String get automationWillAskForLabel => 'Will ask for:';

  @override
  String get automationAutoApplyTitle => 'Apply changes automatically';

  @override
  String get automationAutoApplyNotOffered =>
      'This module can delete or change structure, so its changes always wait for your review.';

  @override
  String get automationAllowModuleFirst => 'Allow this module first';

  @override
  String get automationAutoApplyExplanation =>
      'Small card creates and edits from this module — up to 20 cards, nothing cleared — are applied without asking. Bigger changes, deletes and structure changes always wait for you. You can undo an applied run until you reload Morkva.';

  @override
  String get automationInputField => 'a field picker';

  @override
  String get automationInputCollection => 'a collection picker';

  @override
  String get automationInputChoice => 'a choice';

  @override
  String get automationInputOnOff => 'on or off';

  @override
  String get automationInputNumber => 'a number';

  @override
  String get automationInputText => 'text';

  @override
  String get automationActions => 'Actions';

  @override
  String get automationTestRun => 'Test run';

  @override
  String get automationAddToButton => 'Add to a button';

  @override
  String get automationUsingIt => 'Automations using it';

  @override
  String get automationUsingItNone => 'No automations use it yet.';

  @override
  String get automationCode => 'Code';

  @override
  String get automationRecentRuns => 'Recent runs';

  @override
  String get automationAllRuns => 'All runs';

  @override
  String get automationNoRunsShort => 'No runs yet.';

  @override
  String get automationNoChanges => 'No changes';

  @override
  String get automationLoadRunFailed => 'Couldn\'t load this run';

  @override
  String get automationRunNotInLogTitle => 'This run isn\'t in the log';

  @override
  String get automationRunNotInLogMessage =>
      'It may have been removed with older runs.';

  @override
  String get automationStatusApplying => 'Applying';

  @override
  String get automationStatusNeedsReview => 'Needs review';

  @override
  String get automationStatusSucceeded => 'Succeeded';

  @override
  String get automationStatusFailed => 'Failed';

  @override
  String get automationStatusTimedOut => 'Timed out';

  @override
  String get automationStatusSkipped => 'Skipped';

  @override
  String get automationStatusRejected => 'Rejected';

  @override
  String get automationStatusExpired => 'Expired';

  @override
  String automationAhead(int count) {
    return '$count ahead';
  }

  @override
  String get automationApplyAuto => 'Auto';

  @override
  String get automationApplyAskFirst => 'Ask first';

  @override
  String automationOnDevice(String device) {
    return 'on $device';
  }

  @override
  String automationUndoWithTime(String timeLeft) {
    return 'Undo · $timeLeft';
  }

  @override
  String automationMinutesLeft(int count) {
    return '$count min left';
  }

  @override
  String automationSecondsLeft(int count) {
    return '$count s left';
  }

  @override
  String get automationOpenCard => 'Open card';

  @override
  String get automationCopiedRunLog => 'Copied the run log';

  @override
  String get automationCopyLog => 'Copy log';

  @override
  String get automationStepTrigger => 'Trigger';

  @override
  String get automationAnAutomation => 'An automation';

  @override
  String automationThisRun(String name) {
    return '$name (this run)';
  }

  @override
  String get automationPreviousRun => 'Previous run';

  @override
  String get automationStepInputs => 'Inputs';

  @override
  String get automationStepCalls => 'Calls';

  @override
  String get automationNoCalls => 'No calls';

  @override
  String automationCallsDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count calls dropped',
      one: '+1 call dropped',
    );
    return '$_temp0';
  }

  @override
  String get automationStepConsole => 'Console';

  @override
  String automationLinesDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count lines dropped',
      one: '+1 line dropped',
    );
    return '$_temp0';
  }

  @override
  String get automationStepPlan => 'Plan';

  @override
  String automationApprovedAt(String time) {
    return 'approved by you at $time';
  }

  @override
  String get automationStepLinks => 'Links';

  @override
  String automationOpenLink(String label) {
    return 'Open $label';
  }

  @override
  String get automationStepOutcome => 'Outcome';

  @override
  String get automationRetryFailed => 'Retry failed';

  @override
  String get automationReviewElsewhere => 'Review elsewhere';

  @override
  String automationTriggerButtonCollection(int count, String collection) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Button pressed on $collection · $count cards',
      one: 'Button pressed on $collection · 1 card',
    );
    return '$_temp0';
  }

  @override
  String automationTriggerButtonSomeCollection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Button pressed on a collection · $count cards',
      one: 'Button pressed on a collection · 1 card',
    );
    return '$_temp0';
  }

  @override
  String automationTriggerButtonCard(String card) {
    return 'Button pressed on $card';
  }

  @override
  String get automationTriggerButtonSomeCard => 'Button pressed on a card';

  @override
  String automationTriggerCreated(String card) {
    return 'Created $card';
  }

  @override
  String get automationTriggerCreatedSomeCard => 'Created a card';

  @override
  String automationTriggerDeleted(String card) {
    return 'Deleted $card';
  }

  @override
  String get automationTriggerDeletedSomeCard => 'Deleted a card';

  @override
  String automationTriggerUpdated(String card) {
    return 'Updated $card';
  }

  @override
  String get automationTriggerUpdatedSomeCard => 'Updated a card';

  @override
  String automationTriggerFieldsChanged(String fields, String card) {
    return '$fields changed on $card';
  }

  @override
  String automationTriggerFieldsChangedSomeCard(String fields) {
    return '$fields changed on a card';
  }

  @override
  String automationUpdatedFailed(int applied, int failed) {
    return 'Updated $applied, $failed failed';
  }

  @override
  String automationAppliedChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Applied $count changes',
      one: 'Applied 1 change',
    );
    return '$_temp0';
  }

  @override
  String get automationUndoExpired => 'Undo expired';

  @override
  String get automationUndoAfterReload =>
      'Undo isn\'t available after a reload';

  @override
  String automationReverted(String time) {
    return 'Reverted · $time';
  }

  @override
  String automationAskFixPrefill(String name, String problem) {
    return 'Fix the module \"$name\": $problem';
  }

  @override
  String get automationDecideLater => 'Decide later';

  @override
  String get automationSavedForReview => 'Saved for review';

  @override
  String get automationButtonPressed => 'Button pressed';

  @override
  String automationBecauseCreated(String card) {
    return 'Because $card was created';
  }

  @override
  String get automationBecauseCreatedSomeCard => 'Because a card was created';

  @override
  String automationBecauseDeleted(String card) {
    return 'Because $card was deleted';
  }

  @override
  String get automationBecauseDeletedSomeCard => 'Because a card was deleted';

  @override
  String automationBecauseUpdated(String card) {
    return 'Because $card was updated';
  }

  @override
  String get automationBecauseUpdatedSomeCard => 'Because a card was updated';

  @override
  String get automationReviewExpiredTitle => 'This review expired.';

  @override
  String get automationReviewExpiredBody =>
      'Previews are kept only while Morkva is open. Run it again to get a fresh preview on the current data.';

  @override
  String get automationUndoneSentence => 'Undone.';

  @override
  String get automationDoneSentence => 'Done.';

  @override
  String automationNextReview(int count) {
    return 'Next review ($count left)';
  }

  @override
  String get automationTestRunNote =>
      'Test runs never change data — you\'ll see what would change.';

  @override
  String get automationTestRunCollection => 'Collection';

  @override
  String get automationTestRunCard => 'Card';

  @override
  String get automationTestRunCardOptional => 'Card (optional)';

  @override
  String get automationSearchCards => 'Search cards';

  @override
  String get automationLoadCardsFailed => 'Couldn\'t load cards';

  @override
  String automationTestRunTitle(String action) {
    return 'Test \"$action\"';
  }

  @override
  String get automationTestRunNeedsAllow => 'Allow the module to test it';

  @override
  String get automationRunTest => 'Run test';

  @override
  String automationWouldChangeCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Would change $count cards',
      one: 'Would change 1 card',
    );
    return '$_temp0';
  }

  @override
  String automationTestRunFailed(String reason) {
    return 'Failed: $reason';
  }

  @override
  String automationCallsCount(int count) {
    return 'Calls ($count)';
  }

  @override
  String automationConsoleCount(int count) {
    return 'Console ($count)';
  }

  @override
  String get automationCloseEditor => 'Close editor';

  @override
  String automationDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get automationDeleteMessage =>
      'Its button disappears. Run history stays.';

  @override
  String get automationEditorName => 'Name';

  @override
  String get automationEditorNameHint => 'Stamp when shipped';

  @override
  String get automationEditorWhen => 'When';

  @override
  String get automationEditorIn => 'In';

  @override
  String get automationEditorDo => 'Do';

  @override
  String get automationEditorButton => 'Button';

  @override
  String get automationEditorApply => 'Apply';

  @override
  String get automationEditorEnabled => 'Enabled';

  @override
  String get automationPausedBroken => 'This automation is paused.';

  @override
  String get automationPausedLoopTitle =>
      'Paused: it ran too often in a minute,';

  @override
  String get automationPausedLoopMessage =>
      'which looks like a loop (it may be changing the cards it watches).';

  @override
  String get automationPausedCrashedTitle =>
      'Paused: Morkva stopped while this ran';

  @override
  String get automationPausedCrashedMessage => '(probably out of memory).';

  @override
  String get automationResume => 'Resume';

  @override
  String get automationKindCardButtonHint => 'Shows in the card\'s header.';

  @override
  String get automationKindCollectionButtonHint =>
      'Shows in the collection\'s Actions menu.';

  @override
  String get automationPickCollection => 'Pick a collection';

  @override
  String get automationNotAllowedNote => 'Not allowed for this module';

  @override
  String automationNotAllowedForModule(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names aren\'t allowed for this module.',
      one: '$names isn\'t allowed for this module.',
    );
    return '$_temp0';
  }

  @override
  String get automationAddCondition => 'Add condition';

  @override
  String get automationEditCondition => 'Edit condition';

  @override
  String get automationEditorIf => 'If';

  @override
  String get automationCondition => 'Condition';

  @override
  String get automationRunOnAnyChange => 'Run on any change';

  @override
  String get automationOnlyWhenFieldsChange => 'Only when these fields change';

  @override
  String get automationLeaveEmptyAnyChange =>
      'Leave empty to react to any change.';

  @override
  String get automationEditorRun => 'Run';

  @override
  String get automationModeEnters => 'Once, when the card starts matching';

  @override
  String get automationModeEntersHint =>
      'Won\'t run again while it keeps matching.';

  @override
  String get automationModeMatches => 'Every time it\'s updated and matches';

  @override
  String get automationEventHelp =>
      'Runs on the device where the change is made, while Morkva is open there. Offline changes run when they sync. Calculated values don\'t trigger on their own.';

  @override
  String get automationLastChecked => 'Last checked';

  @override
  String get automationFieldFallback => 'Field';

  @override
  String automationRemoveCondition(String label) {
    return 'Remove $label';
  }

  @override
  String get automationPickModule => 'Pick a module';

  @override
  String get automationPickAction => 'Pick an action';

  @override
  String automationActionRunsOnCollection(String action) {
    return '$action · Runs on a collection';
  }

  @override
  String automationActionRunsOnCard(String action) {
    return '$action · Runs on a card';
  }

  @override
  String get automationModule => 'Module';

  @override
  String get automationAction => 'Action';

  @override
  String automationFieldsOf(String collection) {
    return 'Fields of $collection.';
  }

  @override
  String get automationButtonLabel => 'Label';

  @override
  String get automationButtonIcon => 'Icon';

  @override
  String get automationButtonColor => 'Color';

  @override
  String get automationButtonPreview => 'Preview';

  @override
  String get automationAskFirstButtonHint =>
      'You review each change in a preview.';

  @override
  String get automationAskFirstEventHint => 'Each card waits in Needs review.';

  @override
  String get automationApplyAutomatically => 'Apply automatically';

  @override
  String get automationApplyAutomaticallyHint =>
      'Small card creates and edits apply without asking. Bigger changes, deletes and structure changes still wait.';

  @override
  String get automationAlwaysAsks =>
      'This module can delete or change structure, so it always asks.';

  @override
  String get automationTurnOnAutoApplyFirst =>
      'Turn on auto-apply for this module first.';

  @override
  String get automationModuleDetails => 'Module details';

  @override
  String get automationScopeSameAsModuleSummary =>
      'Collections it may touch: same as the module\'s access';

  @override
  String automationScopeCountSummary(int count) {
    return 'Collections it may touch: $count';
  }

  @override
  String get automationAdvanced => 'Advanced';

  @override
  String get automationScopeSameAsModule => 'Same as the module\'s access';

  @override
  String get automationCallDone => 'Done';

  @override
  String get automationCallNoChange => 'Already up to date';

  @override
  String get automationErrorCrashed =>
      'The page stopped while this ran — probably out of memory';

  @override
  String get automationErrorInterrupted =>
      'Interrupted — may be partly applied, check the cards.';

  @override
  String get automationTintCarrot => 'carrot';

  @override
  String get automationTintLeaf => 'leaf';

  @override
  String get automationTintSky => 'sky';

  @override
  String get automationTintPlum => 'plum';

  @override
  String get automationTintSand => 'sand';

  @override
  String get automationTintRose => 'rose';

  @override
  String get automationTintSlate => 'slate';

  @override
  String get automationTintTeal => 'teal';

  @override
  String get automationWidgetsFixReviewPermissions => 'Review permissions';

  @override
  String get automationWidgetsFixEditAutomation => 'Edit automation';

  @override
  String get automationWidgetsFixResume => 'Resume';

  @override
  String get automationWidgetsFixRunAgain => 'Run again';

  @override
  String get automationWidgetsFixChangeAccess => 'Change access';

  @override
  String get automationWidgetsFixAskMorkva => 'Ask Morkva to fix it';

  @override
  String get automationWidgetsRunQueued => 'Queued';

  @override
  String get automationWidgetsRunQueuedDetail => 'Waiting for its turn.';

  @override
  String get automationWidgetsRunRunning => 'Running…';

  @override
  String get automationWidgetsRunRunningDetail => 'The action is running.';

  @override
  String get automationWidgetsRunApplying => 'Applying…';

  @override
  String get automationWidgetsRunApplyingDetail => 'Applying the changes.';

  @override
  String get automationWidgetsRunAwaitingReview => 'Needs your review';

  @override
  String get automationWidgetsRunAwaitingReviewDetail =>
      'The changes wait for you in a preview.';

  @override
  String get automationWidgetsRunDoneDetail => 'The action finished.';

  @override
  String automationWidgetsRunTimedOut(int seconds) {
    return 'Timed out after $seconds s';
  }

  @override
  String automationWidgetsRunTimedOutDetail(int seconds) {
    return 'The action took longer than $seconds s and was stopped. Nothing was changed.';
  }

  @override
  String get automationWidgetsRunRejected => 'Rejected';

  @override
  String get automationWidgetsRunRejectedDetail => 'You rejected the preview.';

  @override
  String get automationWidgetsRunExpired => 'Expired';

  @override
  String get automationWidgetsRunExpiredDetail =>
      'The preview was kept only while Morkva was open.';

  @override
  String get automationWidgetsRunSkipped => 'Didn\'t run';

  @override
  String get automationWidgetsRunSkippedDetail =>
      'Morkva didn\'t run this action.';

  @override
  String get automationWidgetsRunFailed => 'Failed';

  @override
  String get automationWidgetsRunFailedDetail => 'The run failed.';

  @override
  String get automationWidgetsNeedsConsent => 'Needs consent';

  @override
  String get automationWidgetsReasonNeedsConsentDetail =>
      'The module changed or isn\'t allowed yet.';

  @override
  String get automationWidgetsReasonBroken => 'Automation broken';

  @override
  String get automationWidgetsReasonBrokenDetail =>
      'Its condition, action or collection no longer fits.';

  @override
  String get automationWidgetsStoppedAfterCrash => 'Stopped after a crash';

  @override
  String get automationWidgetsReasonCrashedDetail =>
      'Morkva stopped while this ran, probably out of memory.';

  @override
  String get automationWidgetsReasonCrashedAdvice => 'Resume on the automation';

  @override
  String get automationWidgetsPaused => 'Paused';

  @override
  String get automationWidgetsReasonPausedDetail =>
      'It was paused (by you, or because it looked like a loop).';

  @override
  String get automationWidgetsReasonEngineUnavailable => 'Can\'t run here';

  @override
  String get automationWidgetsReasonEngineUnavailableDetail =>
      'The secure sandbox can\'t start on this device.';

  @override
  String get automationWidgetsReasonEngineUnavailableAdvice =>
      'Run it from another device or browser';

  @override
  String get automationWidgetsReasonNotSettled => 'Card didn\'t update in time';

  @override
  String get automationWidgetsReasonNotSettledDetail =>
      'The change hadn\'t reached Morkva within 5 s, so it wasn\'t checked.';

  @override
  String get automationWidgetsReasonNotPermitted => 'Not allowed';

  @override
  String get automationWidgetsReasonNotPermittedDetail =>
      'A change touched a collection this module isn\'t allowed in.';

  @override
  String get automationWidgetsReasonLoop => 'Would loop';

  @override
  String get automationWidgetsReasonLoopDetail =>
      'This automation already ran in this chain.';

  @override
  String get automationWidgetsReasonLoopAdvice => 'Change its conditions';

  @override
  String get automationWidgetsReasonDepthLimit => 'Chain too long';

  @override
  String get automationWidgetsReasonDepthLimitDetail =>
      'Automations triggered each other 3 levels deep; Morkva stopped here.';

  @override
  String get automationWidgetsReasonDepthLimitAdvice =>
      'Change the automations\' conditions';

  @override
  String get automationWidgetsReasonFanOut => 'Too many cards at once';

  @override
  String get automationWidgetsReasonFanOutDetail =>
      'Only the first 100 cards of one change are processed.';

  @override
  String get automationWidgetsReasonFanOutAdvice =>
      'Split the change into smaller batches';

  @override
  String get automationWidgetsReasonQueueFull => 'Too busy';

  @override
  String get automationWidgetsReasonQueueFullDetail =>
      'Too many runs were waiting.';

  @override
  String get automationWidgetsReasonQueueFullAdvice => 'Run again later';

  @override
  String get automationWidgetsReasonReviewBacklog => 'Too many waiting reviews';

  @override
  String get automationWidgetsReasonReviewBacklogDetail =>
      '50 reviews are already waiting.';

  @override
  String get automationWidgetsReasonReviewBacklogAdvice =>
      'Review or reject the waiting ones';

  @override
  String get automationWidgetsReasonCardGone => 'Card was deleted';

  @override
  String get automationWidgetsReasonCardGoneDetail =>
      'The card no longer exists.';

  @override
  String get automationWidgetsStopped => 'Stopped';

  @override
  String get automationWidgetsReasonCancelledDetail =>
      'Stopped by you. Nothing was changed.';

  @override
  String get automationWidgetsReasonDuplicate => 'Already running';

  @override
  String get automationWidgetsReasonDuplicateDetail =>
      'This automation was already running on this card.';

  @override
  String get automationWidgetsReasonLoadError => 'Module didn\'t start';

  @override
  String get automationWidgetsReasonLoadErrorDetail =>
      'The module\'s code has an error or took too long to load.';

  @override
  String get automationWidgetsReasonLoadErrorAdvice =>
      'Ask Morkva to fix it, or import a fixed file';

  @override
  String get automationWidgetsReasonModuleError => 'Module failed';

  @override
  String get automationWidgetsReasonModuleErrorDetail => 'The module failed.';

  @override
  String automationWidgetsReasonModuleErrorMessage(String message) {
    return 'The module failed: $message';
  }

  @override
  String get automationWidgetsReasonPlanRefused => 'Change refused';

  @override
  String get automationWidgetsReasonPlanRefusedDetail =>
      'A change the module asked for wasn\'t allowed — see Calls.';

  @override
  String get automationWidgetsReasonPlanRefusedAdvice =>
      'Check Calls; change access if needed';

  @override
  String get automationWidgetsReasonLimitExceeded => 'Too much work';

  @override
  String get automationWidgetsReasonLimitExceededDetail =>
      'The module asked for more than one run may do (calls, data or time).';

  @override
  String get automationWidgetsReasonLimitExceededAdvice =>
      'Run it on fewer cards';

  @override
  String get automationWidgetsReasonAbuseDetail =>
      'The module sent too many or too large messages.';

  @override
  String get automationWidgetsReasonOffline => 'Offline';

  @override
  String get automationWidgetsReasonOfflineDetail =>
      'Couldn\'t apply without a connection.';

  @override
  String get automationWidgetsReasonOfflineAdvice => 'Run again when online';

  @override
  String get automationWidgetsReasonNotApplied => 'Nothing applied';

  @override
  String get automationWidgetsReasonNotAppliedDetail =>
      'None of the changes could be applied — see the plan.';

  @override
  String get automationWidgetsOutcomeUnknown => 'Outcome unknown';

  @override
  String get automationWidgetsReasonInterruptedDetail =>
      'Morkva was closed while applying — it may be partly applied.';

  @override
  String get automationWidgetsReasonInterruptedAdvice => 'Check the card';

  @override
  String get automationWidgetsReasonInternalDetail =>
      'Morkva hit an unexpected error.';

  @override
  String get automationWidgetsReasonInternalAdvice =>
      'Run again; copy the log if it repeats';

  @override
  String get automationWidgetsReasonCodeChangedDetail =>
      'The module\'s code changed before you reviewed the preview.';

  @override
  String get automationWidgetsReasonUninstalledDetail =>
      'The module was removed before you reviewed the preview.';

  @override
  String get automationWidgetsReasonSupersededDetail =>
      'A new run replaced this preview.';

  @override
  String get automationWidgetsOutcomeUnknownDetail =>
      'It was applying in another window — check the cards.';

  @override
  String get automationWidgetsOutcomeUnknownAdvice => 'Check the cards';

  @override
  String get automationWidgetsReviewNotHere => 'Review not available here';

  @override
  String get automationWidgetsReviewNotHereDetail =>
      'It was opened in another window, or before Morkva restarted.';

  @override
  String automationWidgetsAskedFirst(String policy) {
    return 'Asked first: $policy.';
  }

  @override
  String get automationWidgetsChipInstalled => 'Installed';

  @override
  String get automationWidgetsChipBroken => 'Broken';

  @override
  String get automationWidgetsChipLoopSuspected => 'Loop suspected';

  @override
  String get automationWidgetsChipAskFirst => 'Ask first';

  @override
  String get automationWidgetsChipAuto => 'Auto';

  @override
  String get automationWidgetsChipAutoOff => 'Auto · off for this module';

  @override
  String automationWidgetsQueuedAhead(int count) {
    return 'Queued · $count ahead';
  }

  @override
  String automationWidgetsRunOnCard(String label, String card) {
    return '$label on $card';
  }

  @override
  String automationWidgetsNoticeNeedsReview(String label) {
    return '$label needs your review';
  }

  @override
  String get automationWidgetsNoChanges => 'No changes';

  @override
  String automationWidgetsNoticeTimedOut(String label) {
    return '$label timed out after 20 s';
  }

  @override
  String automationWidgetsNoticeStopped(String label) {
    return '$label was stopped. Nothing was changed.';
  }

  @override
  String get automationWidgetsNoticeOffline =>
      'Couldn\'t apply — you\'re offline';

  @override
  String automationWidgetsNoticeOfflineOn(String label) {
    return 'Couldn\'t apply $label — you\'re offline';
  }

  @override
  String automationWidgetsNoticeFailed(String label) {
    return '$label failed';
  }

  @override
  String automationWidgetsNoticeFailedMessage(String label, String message) {
    return '$label failed — $message';
  }

  @override
  String get automationWidgetsCantRunOnDevice =>
      'Automations can\'t run on this device';

  @override
  String get automationWidgetsViewRun => 'View run';

  @override
  String get automationWidgetsReview => 'Review';

  @override
  String get automationWidgetsStateSavesFirst => 'saves first';

  @override
  String get automationWidgetsStateNeedsConsent => 'needs consent';

  @override
  String get automationWidgetsStateQueued => 'queued';

  @override
  String get automationWidgetsStateRunning => 'running';

  @override
  String get automationWidgetsStateWaitingForReview => 'waiting for review';

  @override
  String get automationWidgetsStateLastRunFailed => 'last run failed';

  @override
  String get automationWidgetsStop => 'Stop';

  @override
  String automationWidgetsStopLabel(String label) {
    return 'Stop $label';
  }

  @override
  String get automationWidgetsSaveAndRun => 'Save and run';

  @override
  String get automationWidgetsWorksOnSavedCard =>
      'The action works on the saved card.';

  @override
  String get automationWidgetsMoreActions => 'More actions';

  @override
  String automationWidgetsMoreActionsState(String label, String state) {
    return 'More actions, $label $state';
  }

  @override
  String get automationWidgetsActions => 'Actions';

  @override
  String automationWidgetsActionsLive(String label, String state) {
    return 'Actions, $label $state';
  }

  @override
  String get automationWidgetsNoButtons => 'No buttons yet.';

  @override
  String get automationWidgetsNeedsReview => 'Needs review';

  @override
  String get automationWidgetsLastRunFailed => 'Last run failed';

  @override
  String automationWidgetsRunsOnShown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Runs on $count shown cards',
      one: 'Runs on 1 shown card',
    );
    return '$_temp0';
  }

  @override
  String automationWidgetsRunsOnAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Runs on all $count cards',
      one: 'Runs on all 1 card',
    );
    return '$_temp0';
  }

  @override
  String automationWidgetsAutomationsFor(String collection) {
    return 'Automations for $collection…';
  }

  @override
  String get automationWidgetsNewAutomation => 'New automation…';

  @override
  String automationWidgetsRunningLabel(String label) {
    return 'Running $label';
  }

  @override
  String automationWidgetsRunningLabelEllipsis(String label) {
    return 'Running $label…';
  }

  @override
  String get automationWidgetsLongPressToStop => 'Long-press to stop';

  @override
  String get automationWidgetsRunAction => 'Run action…';

  @override
  String get automationWidgetsAutomationsEllipsis => 'Automations…';

  @override
  String automationWidgetsPillRunning(int count) {
    return 'Running · $count';
  }

  @override
  String automationWidgetsNeedReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count need review',
      one: '1 needs review',
    );
    return '$_temp0';
  }

  @override
  String automationWidgetsPillFailed(int count) {
    return '$count failed';
  }

  @override
  String automationWidgetsPillDidntRun(int count) {
    return '$count didn\'t run';
  }

  @override
  String automationWidgetsSentenceRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count automations running',
      one: '1 automation running',
    );
    return '$_temp0';
  }

  @override
  String automationWidgetsSentenceAlsoNeedReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count need review',
    );
    return '$_temp0';
  }

  @override
  String automationWidgetsSentenceNeedsReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count automations need review',
      one: '1 automation needs review',
    );
    return '$_temp0';
  }

  @override
  String automationWidgetsSentenceFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count failed',
    );
    return '$_temp0';
  }

  @override
  String automationWidgetsSentenceDidntRun(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count automations didn\'t run',
      one: '1 automation didn\'t run',
    );
    return '$_temp0';
  }

  @override
  String automationWidgetsSentenceReviewsExpired(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews expired · View',
      one: '1 review expired · View',
    );
    return '$_temp0';
  }

  @override
  String automationWidgetsAutoApplyPaused(String status) {
    return '$status · Auto-apply paused for 10 min';
  }

  @override
  String automationWidgetsDefaultName(String action, String collection) {
    return '$action on $collection';
  }

  @override
  String get automationWidgetsProblemName => 'Give it a name';

  @override
  String get automationWidgetsProblemCollection => 'Pick a collection';

  @override
  String automationWidgetsProblemCollectionNotAllowed(String collection) {
    return 'The module isn\'t allowed in $collection';
  }

  @override
  String get automationWidgetsProblemAction => 'Pick an action';

  @override
  String get automationWidgetsProblemCardAction =>
      'This action runs on a card — use a card button or an event';

  @override
  String get automationWidgetsProblemCollectionAction =>
      'This action runs on a collection — use a collection button';

  @override
  String automationWidgetsProblemFillIn(String field) {
    return 'Fill in $field';
  }

  @override
  String get automationWidgetsProblemWhere =>
      'Add at least one condition or pick fields to watch';

  @override
  String get automationWidgetsProblemAlwaysAsks =>
      'This module can delete or change structure, so it always asks.';

  @override
  String get automationWidgetsProblemTurnOnAutoFirst =>
      'Turn on auto-apply for this module first';

  @override
  String get automationWidgetsAutoApplyOnTitle =>
      'Apply this module\'s changes automatically?';

  @override
  String get automationWidgetsTurnOn => 'Turn on';

  @override
  String get automationWidgetsAutoApplyOffTitle => 'Turn off auto-apply?';

  @override
  String automationWidgetsAutoApplyOffBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count automations will ask first.',
      one: '1 automation will ask first.',
    );
    return '$_temp0';
  }

  @override
  String get automationWidgetsTurnOff => 'Turn off';

  @override
  String automationWidgetsProvenance(String name, String id) {
    return 'Module · $name ($id)';
  }

  @override
  String get collectionsTypeText => 'Text';

  @override
  String get collectionsTypeTextDescription =>
      'Free text, single- or multi-line.';

  @override
  String get collectionsTypeNumber => 'Number';

  @override
  String get collectionsTypeNumberDescription =>
      'A numeric value, optionally bounded.';

  @override
  String get collectionsTypeBoolean => 'Yes / No';

  @override
  String get collectionsTypeBooleanDescription => 'A simple true/false toggle.';

  @override
  String get collectionsTypeDate => 'Date';

  @override
  String get collectionsTypeDateDescription =>
      'A calendar date, optionally with a time.';

  @override
  String get collectionsTypeSingleSelect => 'Single select';

  @override
  String get collectionsTypeSingleSelectDescription =>
      'Pick exactly one option from a fixed set.';

  @override
  String get collectionsTypeMultiSelect => 'Multi select';

  @override
  String get collectionsTypeMultiSelectDescription =>
      'Pick any number of options (tags).';

  @override
  String get collectionsTypeReference => 'Reference';

  @override
  String get collectionsTypeReferenceDescription =>
      'Link to objects in another collection.';

  @override
  String get collectionsTypeFile => 'File';

  @override
  String get collectionsTypeFileDescription => 'One or more file attachments.';

  @override
  String get collectionsTypeAutoNumber => 'Auto number';

  @override
  String get collectionsTypeAutoNumberDescription =>
      'An automatically assigned sequence number.';

  @override
  String get collectionsTypeCalculated => 'Calculated';

  @override
  String get collectionsTypeCalculatedDescription =>
      'A formula, a total over linked items, or a linked item\'s field.';

  @override
  String get collectionsMultiline => 'Multiline';

  @override
  String get collectionsMultilineHint => 'Allow line breaks in the value.';

  @override
  String get collectionsMaxLength => 'Max length';

  @override
  String get collectionsNoLimit => 'No limit';

  @override
  String get collectionsSummaryMultiline => 'multiline';

  @override
  String collectionsSummaryMax(int max) {
    return 'max $max';
  }

  @override
  String get collectionsDecimalPlaces => 'Decimal places';

  @override
  String get collectionsWholeNumber => 'Whole number';

  @override
  String get collectionsUnitLabel => 'Unit label';

  @override
  String get collectionsUnitLabelHint => 'e.g. kg, \$';

  @override
  String get collectionsMinimum => 'Minimum';

  @override
  String get collectionsNoMinimum => 'No minimum';

  @override
  String get collectionsMaximum => 'Maximum';

  @override
  String get collectionsNoMaximum => 'No maximum';

  @override
  String collectionsSummaryDecimals(int count) {
    return '$count dp';
  }

  @override
  String get collectionsIncludeTime => 'Include time';

  @override
  String get collectionsIncludeTimeHint => 'Capture a time alongside the date.';

  @override
  String get collectionsEarliest => 'Earliest';

  @override
  String get collectionsLatest => 'Latest';

  @override
  String get collectionsAnyDate => 'Any';

  @override
  String get collectionsSummaryDate => 'date';

  @override
  String get collectionsSummaryDateTime => 'date & time';

  @override
  String collectionsOptionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count options',
      one: '1 option',
    );
    return '$_temp0';
  }

  @override
  String collectionsOptionDefault(int number) {
    return 'Option $number';
  }

  @override
  String get collectionsNoOptions => 'No options yet — add the first choice.';

  @override
  String get collectionsAddOption => 'Add option';

  @override
  String get collectionsDragToReorder => 'Drag to reorder';

  @override
  String get collectionsOptionLabel => 'Option label';

  @override
  String get collectionsRemoveOption => 'Remove option';

  @override
  String collectionsColorSwatch(String hex) {
    return 'Color $hex';
  }

  @override
  String get collectionsNoColor => 'No color';

  @override
  String get collectionsBooleanNoSettings =>
      'A yes/no field has no extra settings.';

  @override
  String get collectionsTargetCollection => 'Target collection';

  @override
  String get collectionsChooseCollection => 'Choose a collection';

  @override
  String collectionsThisCollection(String name) {
    return '$name (this collection)';
  }

  @override
  String get collectionsPickTargetWarning =>
      'Pick a target collection — this reference points nowhere until you do.';

  @override
  String get collectionsAllowMultiple => 'Allow multiple';

  @override
  String get collectionsReferenceMultipleHint =>
      'Reference more than one object.';

  @override
  String get collectionsSummaryNoTarget => '(no target)';

  @override
  String get collectionsSummaryUnknownTarget => '(unknown)';

  @override
  String collectionsSummaryReferenceMany(String name) {
    return '→ $name (many)';
  }

  @override
  String get collectionsFileMultipleHint => 'Attach more than one file.';

  @override
  String get collectionsAllowedExtensions => 'Allowed extensions';

  @override
  String get collectionsAllowedExtensionsHint =>
      'e.g. png, jpg, pdf — comma separated, blank for any';

  @override
  String get collectionsSummaryMultiple => 'multiple';

  @override
  String get collectionsNoFile => 'No file';

  @override
  String get collectionsStartAt => 'Start at';

  @override
  String get collectionsPrefix => 'Prefix';

  @override
  String get collectionsPrefixHint => 'e.g. ORD-';

  @override
  String get collectionsDigits => 'Digits';

  @override
  String get collectionsDigitsHint => 'e.g. 4 → 0042';

  @override
  String get collectionsFirstNumber => 'First number';

  @override
  String get collectionsAutoNumberNote =>
      'New items get the next number when they are saved. Items that already exist stay unnumbered.';

  @override
  String collectionsSummaryDigits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count digits',
      one: '1 digit',
    );
    return '$_temp0';
  }

  @override
  String collectionsSummaryFrom(int start) {
    return 'from $start';
  }

  @override
  String get collectionsSummaryAuto => 'auto';

  @override
  String collectionsSummaryFormula(String type) {
    return 'Formula → $type';
  }

  @override
  String get collectionsModeFormula => 'Formula';

  @override
  String get collectionsModeAggregate => 'Aggregate';

  @override
  String get collectionsModeLookup => 'Lookup';

  @override
  String get collectionsModeFormulaHint =>
      'Computes from this item\'s own fields.';

  @override
  String get collectionsModeAggregateHint =>
      'Totals values from other items, like SUMIF in a spreadsheet.';

  @override
  String get collectionsModeLookupHint =>
      'Shows a field of the linked item, like VLOOKUP.';

  @override
  String get collectionsDecimals => 'Decimals';

  @override
  String get collectionsDecimalsAuto => 'auto';

  @override
  String get collectionsUnit => 'Unit';

  @override
  String get collectionsUnitHint => 'e.g. ₴, kg';

  @override
  String collectionsFormulaCircular(String chain) {
    return 'Circular: $chain';
  }

  @override
  String collectionsFormulaExample(String open, String close) {
    return 'e.g. ${open}Price$close * ${open}Quantity$close';
  }

  @override
  String collectionsFormulaResult(String type) {
    return 'Result: $type';
  }

  @override
  String get collectionsInsertField => 'Insert field';

  @override
  String get collectionsFunctions => 'Functions';

  @override
  String get collectionsJoinChip => '& join';

  @override
  String collectionsJoinTooltip(String open, String close) {
    return 'Joins text: ${open}First$close & \" \" & ${open}Last$close';
  }

  @override
  String get collectionsAllFunctions => 'All functions';

  @override
  String get collectionsAllFunctionsTooltip =>
      'Every function with how to use it';

  @override
  String get collectionsSummarize => 'Summarize';

  @override
  String get collectionsPickSource => 'Pick what to summarize';

  @override
  String get collectionsNoSources =>
      'Add a Reference field to link items, or summarize a whole collection.';

  @override
  String get collectionsCalculate => 'Calculate';

  @override
  String get collectionsAggregateOf => 'Of';

  @override
  String get collectionsPickSourceFirst => 'Pick what to summarize first.';

  @override
  String collectionsNoNumberFields(String name) {
    return '$name has no number fields.';
  }

  @override
  String collectionsNoNumberOrDateFields(String name) {
    return '$name has no number or date fields.';
  }

  @override
  String get collectionsOnlyWhere => 'Only where';

  @override
  String get collectionsAddCondition => 'Add condition';

  @override
  String get collectionsEditCondition => 'Edit condition';

  @override
  String get collectionsRemoveCondition => 'Remove condition';

  @override
  String get collectionsAndCondition => 'And…';

  @override
  String collectionsSourceLinkingToThis(String name) {
    return '$name linking to this one';
  }

  @override
  String collectionsSourceLinkingHere(String name) {
    return '$name linking here';
  }

  @override
  String collectionsSourceVia(String field) {
    return 'via $field';
  }

  @override
  String collectionsSourceLinked(String name) {
    return 'Linked $name';
  }

  @override
  String collectionsSourceIn(String field) {
    return 'in $field';
  }

  @override
  String collectionsSourceAll(String name) {
    return 'All $name';
  }

  @override
  String get collectionsSourceEveryItem => 'every item';

  @override
  String get collectionsThrough => 'Through';

  @override
  String get collectionsNoLookupReferences =>
      'Add a Reference field (one linked item) to look up its fields.';

  @override
  String get collectionsPickReference => 'Pick a reference';

  @override
  String collectionsLinksTo(String name) {
    return 'links to $name';
  }

  @override
  String get collectionsShow => 'Show';

  @override
  String collectionsNoFieldsToShow(String name) {
    return '$name has no fields to show.';
  }

  @override
  String get collectionsThatCollectionNoFields =>
      'That collection has no fields to show.';

  @override
  String get collectionsPickField => 'Pick a field';

  @override
  String get collectionsLookupKeepsType =>
      'Keeps its type: a select stays a select, so filters and totals can use its options.';

  @override
  String get collectionsInWords => 'IN WORDS';

  @override
  String get collectionsAddFieldTitle => 'Add a field';

  @override
  String get collectionsAddFieldSubtitle =>
      'Pick a type — you can configure and rename it next.';

  @override
  String get collectionsAutomatic => 'Automatic';

  @override
  String collectionsAddFieldOfType(String type) {
    return 'Add $type field';
  }

  @override
  String get collectionsRequired => 'Required';

  @override
  String get collectionsRequiredHint =>
      'A value must be set before an object is valid.';

  @override
  String get collectionsOptions => 'Options';

  @override
  String get collectionsFieldName => 'Field name';

  @override
  String get collectionsFieldNameHint => 'Title, Status, Due date…';

  @override
  String get collectionsHelpText => 'Help text';

  @override
  String get collectionsHelpTextHint =>
      'Optional — guidance shown with this field';

  @override
  String get collectionsTypeLocked =>
      'Type is locked after the first save. To change it, remove this field and add a new one.';

  @override
  String get collectionsGroup => 'Group';

  @override
  String get collectionsGroupName => 'Group name';

  @override
  String get collectionsGroupNameHint => 'Leave empty for an ungrouped section';

  @override
  String get collectionsCollapsedByDefault => 'Collapsed by default';

  @override
  String get collectionsCollapsedByDefaultHint =>
      'The group starts collapsed when a card is opened.';

  @override
  String get collectionsDeleteGroup => 'Delete group';

  @override
  String get collectionsDeleteGroupTitle => 'Delete group?';

  @override
  String get collectionsDeleteGroupMessage =>
      'The group is removed from the layout. Its fields are not deleted and will be moved to the default section.';

  @override
  String get collectionsUntitledCollection => 'Untitled collection';

  @override
  String get collectionsNewGroup => 'New group';

  @override
  String get collectionsAddGroup => 'Add group';

  @override
  String get collectionsDropFieldHere => 'Drop a field here';

  @override
  String get collectionsAddField => 'Add field';

  @override
  String get collectionsUntitledSection => 'Untitled section';

  @override
  String get collectionsUntitledField => 'Untitled field';

  @override
  String get collectionsFields => 'Fields';

  @override
  String collectionsFirstRunQuestion(String item) {
    return 'What do you track for each $item?';
  }

  @override
  String get collectionsFirstRunHint =>
      'Tap to add — you can rename or tweak any field afterwards.';

  @override
  String get collectionsCustomField => 'Custom field';

  @override
  String get collectionsSuggestStatus => 'Status';

  @override
  String get collectionsSuggestStatusHint => 'choice';

  @override
  String get collectionsSuggestToDo => 'To do';

  @override
  String get collectionsSuggestInProgress => 'In progress';

  @override
  String get collectionsSuggestDone => 'Done';

  @override
  String get collectionsSuggestDueDate => 'Due date';

  @override
  String get collectionsSuggestDueDateHint => 'date';

  @override
  String get collectionsSuggestAmount => 'Amount';

  @override
  String get collectionsSuggestAmountHint => 'number';

  @override
  String get collectionsSuggestCustomer => 'Customer';

  @override
  String get collectionsSuggestCustomerHint => 'reference';

  @override
  String get collectionsSuggestNotes => 'Notes';

  @override
  String get collectionsSuggestNotesHint => 'text';

  @override
  String collectionsSaveFailed(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get collectionsNotFoundTitle => 'Collection not found';

  @override
  String get collectionsNotFoundMessage =>
      'This collection may have been deleted, or the link is wrong. Head back home to pick another.';

  @override
  String get collectionsBackToCollections => 'Back to collections';

  @override
  String get collectionsDescriptionTitle => 'Collection description';

  @override
  String get collectionsDescriptionHint => 'What this collection holds';

  @override
  String get collectionsChooseIcon => 'Choose icon';

  @override
  String get collectionsCustomizing => 'Customizing';

  @override
  String get collectionsNameHint => 'Collection name';

  @override
  String get collectionsAddDescription => 'Add a description';

  @override
  String get collectionsSaved => 'Saved';

  @override
  String get collectionsSaving => 'Saving…';

  @override
  String get collectionsUnsavedChanges => 'Unsaved changes';

  @override
  String get collectionsObjectForm => 'Object form';

  @override
  String get collectionsObjectFormHint => 'How a card looks when opened';

  @override
  String get collectionsConfigureField => 'Configure field';

  @override
  String get collectionsSelectToEdit => 'Select a field or group to edit it.';

  @override
  String get collectionsLeaveTitle => 'Save your changes?';

  @override
  String get collectionsLeaveMessage =>
      'You have unsaved changes to this collection. Save them before leaving, or discard them.';

  @override
  String get collectionsDiscard => 'Discard';

  @override
  String get collectionsLoading => 'Loading your collections…';

  @override
  String get collectionsTitleFieldName => 'Name';

  @override
  String collectionsTemplateAdded(String name) {
    return 'Added $name';
  }

  @override
  String collectionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collections',
      one: '1 collection',
    );
    return '$_temp0';
  }

  @override
  String collectionsCountWithPinnedShort(int count, int pinned) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collections',
      one: '1 collection',
    );
    return '$_temp0 · $pinned pinned';
  }

  @override
  String collectionsCountWithPinned(int count, int pinned) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collections',
      one: '1 collection',
    );
    return '$_temp0 · $pinned pinned to the sidebar';
  }

  @override
  String get collectionsFromTemplate => 'From template';

  @override
  String get collectionsNewCollection => 'New collection';

  @override
  String get collectionsHeaderAll => 'COLLECTIONS';

  @override
  String get collectionsHeaderOthers => 'EVERYTHING ELSE';

  @override
  String get collectionsDeleteTitle => 'Delete collection?';

  @override
  String collectionsDeleteMessage(String name) {
    return 'This permanently deletes \"$name\" and its schema. Objects in it are no longer reachable. This cannot be undone.';
  }

  @override
  String get collectionsEmptyTitle => 'No collections yet';

  @override
  String get collectionsEmptyMessage =>
      'Collections hold your cards — orders, clients, inventory, anything. Create your first one to start organizing your work.';

  @override
  String get collectionsStartFromTemplate => 'Start from a template';

  @override
  String get collectionsLoadErrorTitle => 'Couldn\'t load collections';

  @override
  String collectionsLoadFailed(String error) {
    return 'Failed to load collections: $error';
  }

  @override
  String get collectionsRenameCollection => 'Rename collection';

  @override
  String get collectionsNameRequired => 'Give your collection a name';

  @override
  String get collectionsNameLabel => 'Name';

  @override
  String get collectionsNameExamples => 'Orders, Clients, Inventory…';

  @override
  String get collectionsDescriptionLabel => 'Description';

  @override
  String get collectionsDescriptionOptionalHint =>
      'Optional — what this collection holds';

  @override
  String collectionsOpenCollection(String name) {
    return 'Open $name';
  }

  @override
  String get collectionsPinToSidebar => 'Pin to sidebar';

  @override
  String get collectionsUnpinFromSidebar => 'Unpin from sidebar';

  @override
  String get collectionsNoFieldsYet => 'No fields yet';

  @override
  String get collectionsMoreActions => 'More actions';

  @override
  String get collectionsCustomize => 'Customize';

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
  String objectsNewItem(String item) {
    return 'New $item';
  }

  @override
  String get objectsCloseEditor => 'Close editor';

  @override
  String get objectsDiscardTitle => 'Discard changes?';

  @override
  String objectsDiscardMessage(String item) {
    return 'Your changes to this $item haven\'t been saved.';
  }

  @override
  String get objectsDiscard => 'Discard';

  @override
  String get objectsKeepEditing => 'Keep editing';

  @override
  String get objectsAnotherCard => 'another card';

  @override
  String objectsRunReverted(String run) {
    return '$run · Reverted';
  }

  @override
  String objectsRunRevertedOnCard(String run, String card) {
    return '$run on $card · Reverted';
  }

  @override
  String objectsDeleteItemTitle(String item) {
    return 'Delete $item?';
  }

  @override
  String objectsDeleteItemMessage(String title) {
    return '\"$title\" will be deleted.';
  }

  @override
  String objectsDeleteItem(String item) {
    return 'Delete $item';
  }

  @override
  String get objectsUploading => 'Uploading…';

  @override
  String get objectsSaveAsNew => 'Save as new';

  @override
  String objectsHeaderMeta(String item, String created, String edited) {
    return '$item · created $created · edited $edited';
  }

  @override
  String get objectsJustNow => 'just now';

  @override
  String objectsMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String objectsHoursAgo(int count) {
    return '$count h ago';
  }

  @override
  String objectsFixFields(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fix $count fields to save',
      one: 'Fix 1 field to save',
    );
    return '$_temp0';
  }

  @override
  String get objectsSaveFailed => 'Couldn\'t save — check your connection';

  @override
  String objectsDeletedElsewhere(String item) {
    return 'This $item was deleted elsewhere.';
  }

  @override
  String get objectsSaveAsNewToRestore => 'Save as new to restore it.';

  @override
  String objectsChangedElsewhere(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names were changed elsewhere.',
      one: '$names was changed elsewhere.',
    );
    return '$_temp0';
  }

  @override
  String objectsNamesAnd(String names, String last) {
    return '$names and $last';
  }

  @override
  String get objectsOverwriteNote =>
      'Saving will overwrite it with your value.';

  @override
  String get objectsNeedsConnection => 'Needs a connection';

  @override
  String get objectsDismiss => 'Dismiss';

  @override
  String get objectsChanged => 'Changed';

  @override
  String objectsCouldNotOpen(String name) {
    return 'Couldn\'t open $name';
  }

  @override
  String objectsUploadFailed(String name) {
    return 'Couldn\'t upload $name';
  }

  @override
  String objectsUploadTooLarge(String name) {
    return 'Couldn\'t upload $name: files must be under 25 MB';
  }

  @override
  String get objectsAssignedOnSave => 'Assigned on save';

  @override
  String get objectsSetAutomatically => 'Set automatically';

  @override
  String get objectsNothingToCalculate => 'Nothing to calculate yet';

  @override
  String get objectsCalculated => 'Calculated';

  @override
  String objectsCantEditType(String type) {
    return 'Can\'t edit $type here';
  }

  @override
  String get objectsReplaceFile => 'Replace';

  @override
  String get objectsUploadFile => 'Upload file';

  @override
  String objectsFileSizeBytes(String size) {
    return '$size B';
  }

  @override
  String objectsFileSizeKb(String size) {
    return '$size KB';
  }

  @override
  String objectsFileSizeMb(String size) {
    return '$size MB';
  }

  @override
  String get objectsFileBadge => 'FILE';

  @override
  String objectsRemoveNamed(String name) {
    return 'Remove $name';
  }

  @override
  String objectsUploadingNamed(String name) {
    return 'Uploading $name';
  }

  @override
  String get objectsCancelUpload => 'Cancel upload';

  @override
  String objectsUnknownItem(String item) {
    return 'Unknown $item';
  }

  @override
  String objectsUnlinkNamed(String name) {
    return 'Unlink $name';
  }

  @override
  String objectsLinkItem(String item) {
    return 'Link $item';
  }

  @override
  String get objectsEnterNumber => 'Enter a number';

  @override
  String get objectsNoOptions => 'No options yet';

  @override
  String get objectsChoose => 'Choose…';

  @override
  String get objectsPickDate => 'Pick a date';

  @override
  String get objectsPickDateTime => 'Pick date and time';

  @override
  String objectsClearNamed(String name) {
    return 'Clear $name';
  }

  @override
  String objectsLinkedToThis(String item) {
    return 'Linked to this $item';
  }

  @override
  String objectsCouldNotDeleteItem(String item) {
    return 'Couldn\'t delete the $item';
  }

  @override
  String objectsCouldNotUpdate(String name) {
    return 'Couldn\'t update $name';
  }

  @override
  String objectsCheckedOf(int done, int total, String check) {
    return '$done of $total $check';
  }

  @override
  String objectsAddItem(String item) {
    return 'Add $item';
  }

  @override
  String objectsLinkingVia(String field) {
    return 'Linking here via $field';
  }

  @override
  String objectsNoItemsYet(String items) {
    return 'No $items yet';
  }

  @override
  String objectsLinkItems(String items) {
    return 'Link $items';
  }

  @override
  String objectsFromCollection(String collection) {
    return 'from $collection';
  }

  @override
  String objectsSearchItems(String items) {
    return 'Search $items';
  }

  @override
  String objectsShownOf(int shown, int total) {
    return '$shown of $total';
  }

  @override
  String objectsCollectionEmpty(String collection) {
    return '$collection has no items yet';
  }

  @override
  String get objectsThisCollectionEmpty => 'This collection has no items yet';

  @override
  String objectsNoMatch(String items, String query) {
    return 'No $items match “$query”';
  }

  @override
  String get objectsTryAnotherName => 'Try another name';

  @override
  String get objectsUnlink => 'Unlink';

  @override
  String get objectsLinked => 'Linked';

  @override
  String get authErrorSignInFailed => 'Google sign-in failed.';

  @override
  String get authErrorNoUser => 'Google sign-in returned no user.';

  @override
  String get authErrorUnsupportedPlatform =>
      'Google sign-in is not supported on this platform.';

  @override
  String get authErrorNoIdToken => 'Google sign-in did not return an ID token.';

  @override
  String get authErrorSignOutFailed => 'Sign-out failed.';

  @override
  String get trelloImportTitle => 'Import from Trello';

  @override
  String get trelloImportFiles => 'Files';

  @override
  String get trelloImportPaste => 'Paste';

  @override
  String get trelloImportProblemNotABoard =>
      'This isn\'t a Trello board export. Use Export as JSON on the board.';

  @override
  String get trelloImportProblemAlreadyAdded => 'Already added';

  @override
  String get trelloImportProblemUnreadable =>
      'Couldn\'t read the chosen files. Choose them again, or paste one.';

  @override
  String get trelloImportDropHint => 'Trello board exports (.json)';

  @override
  String get trelloImportChooseFiles => 'Choose files';

  @override
  String get trelloImportBoardJson => 'Board JSON';

  @override
  String get trelloImportPasteHint => 'Paste a board\'s whole export';

  @override
  String get trelloImportPasteHelp =>
      'Paste one board\'s whole export, then add it. Repeat for more boards.';

  @override
  String get trelloImportAddBoard => 'Add board';

  @override
  String get trelloImportStep1 => 'Step 1 of 2 · Add boards';

  @override
  String get trelloImportBoardsToImport => 'Boards to import';

  @override
  String get trelloImportAddAtLeastOne => 'Add at least one board';

  @override
  String get trelloImportHowToTitle => 'Export each board from Trello';

  @override
  String get trelloImportHowToOpen => 'Open the board → ';

  @override
  String get trelloImportHowToMenu => 'Menu';

  @override
  String get trelloImportHowToShare => 'Print, export, and share';

  @override
  String get trelloImportHowToExport => 'Export as JSON';

  @override
  String get trelloImportHowToRest =>
      '. If Trello opens it in a new tab, save the page as a .json file (Ctrl+S), or copy all of it and use Paste. Nothing is imported until you choose.';

  @override
  String get trelloImportNoBoards => 'No boards yet';

  @override
  String get trelloImportNoBoardsBody =>
      'Boards you add show up here with their lists and cards.';

  @override
  String trelloImportListCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n lists',
      one: '$n list',
    );
    return '$_temp0';
  }

  @override
  String trelloImportCardCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n cards',
      one: '$n card',
    );
    return '$_temp0';
  }

  @override
  String trelloImportChecklistItemCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n checklist items',
      one: '$n checklist item',
    );
    return '$_temp0';
  }

  @override
  String trelloImportCommentCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n comments',
      one: '$n comment',
    );
    return '$_temp0';
  }

  @override
  String trelloImportItemCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n items',
      one: '$n item',
    );
    return '$_temp0';
  }

  @override
  String trelloImportCollectionCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n collections',
      one: '$n collection',
    );
    return '$_temp0';
  }

  @override
  String trelloImportCollectionsButton(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $n collections',
      one: 'Import $n collection',
    );
    return '$_temp0';
  }

  @override
  String trelloImportArchivedCards(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$n archived cards. They get an Archived checkbox and stay off the board view.',
      one:
          '$n archived card. They get an Archived checkbox and stay off the board view.',
    );
    return '$_temp0';
  }

  @override
  String trelloImportMoreFields(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$n more fields',
      one: '+$n more field',
    );
    return '$_temp0';
  }

  @override
  String trelloImportBoardViewByList(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n cards · board view by List',
      one: '$n card · board view by List',
    );
    return '$_temp0';
  }

  @override
  String trelloImportRemoveNamed(String name) {
    return 'Remove $name';
  }

  @override
  String trelloImportDismissNamed(String name) {
    return 'Dismiss $name';
  }

  @override
  String get trelloImportStep2 => 'Step 2 of 2 · Choose what to import';

  @override
  String get trelloImportNoAutomationsTitle => 'Automations can\'t come along.';

  @override
  String get trelloImportNoAutomationsBody =>
      'Trello leaves Butler rules and buttons out of board exports — set them up again in Automations once your boards are in.';

  @override
  String get trelloImportIncludeArchived => 'Include archived cards and lists';

  @override
  String get trelloImportNoArchived => 'No archived cards.';

  @override
  String get trelloImportCollectionsHelp =>
      'Each board becomes a collection with a board view grouped by list. Checklist items and comments show as lists on each card.';

  @override
  String get trelloImportNothingChosen => 'Choose at least one collection';

  @override
  String get trelloImportOffline => 'You\'re offline — connect to import';

  @override
  String get trelloImportNeedsBoard => 'needs the board';

  @override
  String get trelloImportChecklistItems => 'Checklist items';

  @override
  String get trelloImportComments => 'Comments';

  @override
  String get trelloImportCapped =>
      'Trello exports keep only the newest 1,000 activities, so older comments may be missing.';

  @override
  String get trelloImportWritingCardsAndItems => 'Writing cards and items';

  @override
  String get trelloImportWritingCards => 'Writing cards';

  @override
  String get trelloImportImporting => 'Importing from Trello';

  @override
  String get trelloImportKeepOpen => 'Keep this open until it finishes.';

  @override
  String get trelloImportPaused => 'Import paused.';

  @override
  String get trelloImportStalled =>
      'Morkva couldn\'t reach the server for 30 seconds. Check your connection, then retry — cards already written won\'t be added twice. Closing keeps what\'s already imported.';

  @override
  String get trelloImportRefused =>
      'Morkva couldn\'t save some cards. Check your connection, then retry — cards already written won\'t be added twice. Closing keeps what\'s already imported.';

  @override
  String trelloImportWrittenOf(String written, String total) {
    return '$written of $total';
  }

  @override
  String get trelloImportNoAutomationsStart =>
      'Imported cards don\'t start automations.';

  @override
  String get trelloImportWritingKeepOpen => 'Writing — keep this open';

  @override
  String get trelloImportRowPaused => 'Paused';

  @override
  String get trelloImportRowWriting => 'Writing';

  @override
  String get trelloImportRowWaiting => 'Waiting';

  @override
  String get trelloImportDoneTitle => 'Your boards are in';

  @override
  String get trelloImportButlerHint =>
      'Used Butler in Trello? Set up the same steps as Morkva automations.';

  @override
  String get settingsWorkspaceSection => 'Workspace';

  @override
  String get settingsAutomationsSubtitle => 'Modules, buttons and runs';

  @override
  String get settingsAccountSection => 'Account';

  @override
  String get settingsImportSection => 'Import from other apps';

  @override
  String get settingsTrelloSubtitle =>
      'Boards become collections — lists, cards, labels, checklists and comments';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get viewsGroupBy => 'Group by';

  @override
  String get viewsAddField => 'Add field';

  @override
  String get viewsSetupCard => 'Setup card';

  @override
  String get viewsModeTable => 'Table';

  @override
  String get viewsModeTableDescription =>
      'Rows and columns, sortable by any field.';

  @override
  String get viewsColumns => 'Columns';

  @override
  String get viewsModeBoard => 'Board';

  @override
  String get viewsModeBoardDescription =>
      'Cards in columns by a choice or reference field.';

  @override
  String get viewsModeList => 'List';

  @override
  String get viewsModeListDescription =>
      'Compact rows, optionally in sections.';

  @override
  String get viewsModeCalendar => 'Calendar';

  @override
  String get viewsModeCalendarDescription =>
      'Items on the days of a date field.';

  @override
  String get viewsModeSummary => 'Summary';

  @override
  String get viewsModeSummaryDescription =>
      'Big numbers per item, like a dashboard.';

  @override
  String get viewsSetupTiles => 'Setup tiles';

  @override
  String get viewsDateField => 'Date field';

  @override
  String get viewsAddDateField => 'Add date field';

  @override
  String get viewsNeedsChoiceOrReference => 'Needs a choice or reference field';

  @override
  String get viewsNeedsDateField => 'Needs a date field';

  @override
  String viewsNewItem(String item) {
    return 'New $item';
  }

  @override
  String viewsShownOfTotal(int shown, int total) {
    return '$shown of $total';
  }

  @override
  String viewsTotalCount(int count, String noun) {
    return '$count $noun';
  }

  @override
  String viewsSortBy(String field) {
    return 'Sort by $field';
  }

  @override
  String get viewsSortAscending => 'ascending';

  @override
  String get viewsSortDescending => 'descending';

  @override
  String get viewsChangeFields => 'Change fields';

  @override
  String get viewsEnteredByHand => 'Entered by hand';

  @override
  String get viewsEditValues => 'Edit values';

  @override
  String get viewsPickTilesHint => 'Pick fields to show with “Setup tiles”.';

  @override
  String viewsTileEmpty(String label) {
    return '$label: empty';
  }

  @override
  String viewsGroupChip(String name) {
    return 'Group: $name';
  }

  @override
  String get viewsGroupChipNone => 'Group: None';

  @override
  String viewsReorderedIn(String group) {
    return 'Reordered in $group';
  }

  @override
  String viewsReorderedInSortOff(String group) {
    return 'Reordered in $group — sort turned off';
  }

  @override
  String viewsMovedTo(String group) {
    return 'Moved to $group';
  }

  @override
  String viewsMovedToHidden(String group) {
    return 'Moved to $group — hidden by filter';
  }

  @override
  String get viewsItemsFallback => 'items';

  @override
  String viewsColumnOf(int index, int count) {
    return 'Column $index of $count';
  }

  @override
  String get viewsJumpToColumn => 'Jump to column';

  @override
  String get viewsBoardNeedsField => 'Board needs a choice or reference field';

  @override
  String viewsBoardNeedsFieldMessage(String items) {
    return 'Add a choice or reference field, and each of its values becomes a column you can drag $items between.';
  }

  @override
  String get viewsBoardChooseGroup => 'Choose how to group this board';

  @override
  String get viewsBoardChooseGroupMessage =>
      'Each value of the field becomes a column.';

  @override
  String get viewsGroupByAction => 'Group by…';

  @override
  String viewsDateChip(String name) {
    return 'Date: $name';
  }

  @override
  String get viewsDateChipEmpty => 'Date';

  @override
  String get viewsCalendarNeedsDate => 'Calendar needs a date field';

  @override
  String viewsCalendarNeedsDateMessage(String item) {
    return 'Add a date field to place each $item on a day.';
  }

  @override
  String get viewsCalendarChooseDate => 'Choose a date field';

  @override
  String viewsCalendarChooseDateMessage(String item) {
    return 'Pick the date that places each $item on a day.';
  }

  @override
  String get viewsOrderChanged => 'Order changed';

  @override
  String get viewsDragToReorder => 'Drag to reorder';

  @override
  String viewsLinkCardGone(String item) {
    return 'This link\'s $item is gone';
  }

  @override
  String viewsAddFirstItem(String item) {
    return 'Add your first $item';
  }

  @override
  String get viewsAddFilter => 'Add filter';

  @override
  String get viewsEditFilter => 'Edit filter';

  @override
  String get viewsSort => 'Sort';

  @override
  String get viewsTitleFallback => 'Title';

  @override
  String get viewsAddedHidden => 'Added — hidden by the filters';

  @override
  String get viewsSavedHidden => 'Saved — hidden by the filters';

  @override
  String viewsFilledFromColumn(String group) {
    return 'Filled from the $group column';
  }

  @override
  String viewsFilledFromGroup(String group) {
    return 'Filled from the $group group';
  }

  @override
  String viewsFilledFromDay(String date) {
    return 'Filled from $date';
  }

  @override
  String viewsDeletedTitle(String title) {
    return 'Deleted \"$title\"';
  }

  @override
  String get viewsDeleteViewTitle => 'Delete view?';

  @override
  String viewsDeleteViewMessage(String name) {
    return 'This deletes the view \"$name\" and its filters and sort. Your data stays as it is.';
  }

  @override
  String get viewsCustomize => 'Customize';

  @override
  String get viewsViewSettings => 'View settings';

  @override
  String get viewsCustomizeCollection => 'Customize collection';

  @override
  String get viewsNoFieldsTitle => 'This collection has no fields yet';

  @override
  String viewsNoFieldsMessage(String item) {
    return 'Add the fields you track for each $item, then come back to work with them here.';
  }

  @override
  String get viewsSaveAsView => 'Save as view';

  @override
  String get viewsNoMatchesTitle => 'Nothing matches these filters';

  @override
  String viewsNoMatchesMessage(int count, String items) {
    return 'None of your $count $items pass the filters above.';
  }

  @override
  String get viewsClearFilters => 'Clear filters';

  @override
  String viewsAssistantFiltersTooltip(String filters) {
    return 'Filters from Ask Morkva, not saved: $filters';
  }

  @override
  String viewsFromAssistant(String filters) {
    return 'From assistant · $filters';
  }

  @override
  String get viewsClearAssistantFilters => 'Clear assistant filters';

  @override
  String viewsUnknownMode(String mode, String fallback) {
    return 'This view uses the \"$mode\" mode, which this version doesn\'t have yet. Showing it as a $fallback.';
  }

  @override
  String get viewsNotFoundTitle => 'Collection not found';

  @override
  String get viewsNotFoundMessage =>
      'This collection may have been deleted, or the link is wrong. Head back home to pick another.';

  @override
  String get viewsBackToCollections => 'Back to collections';

  @override
  String get viewsLoadError => 'Couldn\'t load this view';

  @override
  String get viewsLoadErrorMessage => 'Check your connection and try again.';

  @override
  String viewsLoadTargetFailed(String name) {
    return 'Couldn\'t load $name';
  }

  @override
  String get viewsLinkFilterInvalid => 'This link\'s filter isn\'t valid';

  @override
  String get viewsSaveViewFailed => 'Couldn\'t save the view';

  @override
  String get viewsSaveChangeFailed => 'Couldn\'t save the change';

  @override
  String get viewsDeleteFailed => 'Couldn\'t delete it';

  @override
  String get viewsUntitledView => 'Untitled view';

  @override
  String viewsCopyName(String name) {
    return '$name copy';
  }

  @override
  String viewsFilteredName(String name) {
    return '$name · filtered';
  }

  @override
  String get viewWidgetsPopover => 'Popover';

  @override
  String get viewWidgetsLastViewCantDelete => 'The last view can\'t be deleted';

  @override
  String get viewWidgetsNewView => 'New view';

  @override
  String get viewWidgetsViewOptions => 'View options';

  @override
  String get viewWidgetsSortCreated => 'Created';

  @override
  String get viewWidgetsSortUpdated => 'Updated';

  @override
  String get viewWidgetsPickLookupReference => 'Pick a reference to look up';

  @override
  String get viewWidgetsPickLookupField => 'Pick a field to show';

  @override
  String viewWidgetsLookupSummary(String field, String item, String reference) {
    return '$field of the linked $item ($reference)';
  }

  @override
  String get viewWidgetsNoFormulaYet => 'No formula yet';

  @override
  String get viewWidgetsPickAggregateSource => 'Pick what to summarize';

  @override
  String viewWidgetsAggregateOfLinkingHere(
    String op,
    String field,
    String source,
    String reference,
  ) {
    return '$op of $field of $source linking here via $reference';
  }

  @override
  String viewWidgetsAggregateOfLinked(
    String op,
    String field,
    String source,
    String reference,
  ) {
    return '$op of $field of linked $source ($reference)';
  }

  @override
  String viewWidgetsAggregateOfAll(String op, String field, String source) {
    return '$op of $field of all $source';
  }

  @override
  String viewWidgetsCountLinkingHere(String source, String reference) {
    return 'Count of $source linking here via $reference';
  }

  @override
  String viewWidgetsCountLinked(String source, String reference) {
    return 'Count of linked $source ($reference)';
  }

  @override
  String viewWidgetsCountAll(String source) {
    return 'Count of all $source';
  }

  @override
  String viewWidgetsSummaryWhere(String summary, String conditions) {
    return '$summary where $conditions';
  }

  @override
  String get viewWidgetsConditionSeparator => ' and ';

  @override
  String get viewWidgetsUnknownField => 'Unknown field';

  @override
  String get viewWidgetsUnknownItem => 'Unknown item';

  @override
  String viewWidgetsFilterChip(String field, String condition) {
    return '$field $condition';
  }

  @override
  String get viewWidgetsOpIs => 'is';

  @override
  String get viewWidgetsOpIsNot => 'is not';

  @override
  String get viewWidgetsOpHas => 'has';

  @override
  String get viewWidgetsOpHasNo => 'has no';

  @override
  String get viewWidgetsOpIsEmpty => 'is empty';

  @override
  String get viewWidgetsOpIsNotEmpty => 'is not empty';

  @override
  String get viewWidgetsOpEquals => 'is';

  @override
  String get viewWidgetsOpContains => 'contains';

  @override
  String get viewWidgetsOpNotContains => 'does not contain';

  @override
  String get viewWidgetsOpBefore => 'is before';

  @override
  String get viewWidgetsOpAfter => 'is after';

  @override
  String get viewWidgetsOpOnDay => 'is on';

  @override
  String get viewWidgetsOpHasAnyOf => 'has any of';

  @override
  String get viewWidgetsOpIsAnyOf => 'is any of';

  @override
  String get viewWidgetsOpHasNoneOf => 'has none of';

  @override
  String get viewWidgetsOpIsNoneOf => 'is none of';

  @override
  String get viewWidgetsOpIsChecked => 'is checked';

  @override
  String get viewWidgetsOpIsNotChecked => 'is not checked';

  @override
  String get viewWidgetsSort => 'Sort';

  @override
  String get viewWidgetsRemoveFilter => 'Remove filter';

  @override
  String get viewWidgetsAddFilter => 'Add filter';

  @override
  String get viewWidgetsFilter => 'Filter';

  @override
  String viewWidgetsFieldsIntroTiles(String view) {
    return 'Choose which fields show as tiles in “$view” and drag to set their order.';
  }

  @override
  String viewWidgetsFieldsIntroCard(String view) {
    return 'Choose which fields show on each card in “$view” and drag to set their order.';
  }

  @override
  String get viewWidgetsPreviewHeading => 'PREVIEW';

  @override
  String get viewWidgetsPreview => 'Preview';

  @override
  String get viewWidgetsEmptyFieldsSkipped =>
      'Empty fields are skipped on the card.';

  @override
  String get viewWidgetsShowColumn => 'Show';

  @override
  String viewWidgetsLayoutBoard(String field) {
    return '$field is shown as the columns';
  }

  @override
  String viewWidgetsLayoutCalendar(String field) {
    return '$field places each card on its day';
  }

  @override
  String viewWidgetsLayoutSeparate(String field) {
    return '$field is shown separately';
  }

  @override
  String get viewWidgetsTitleColumn => 'Title column';

  @override
  String get viewWidgetsCardTitle => 'Card title';

  @override
  String get viewWidgetsChangeTitleColumn => 'Change title column';

  @override
  String get viewWidgetsChangeCardTitle => 'Change card title';

  @override
  String viewWidgetsReorderField(String field) {
    return 'Reorder $field';
  }

  @override
  String viewWidgetsMoveField(String field) {
    return 'Move $field';
  }

  @override
  String get viewWidgetsMoveUp => 'Move up';

  @override
  String get viewWidgetsMoveDown => 'Move down';

  @override
  String get viewWidgetsSortManual => 'Manual';

  @override
  String get viewWidgetsSortBy => 'Sort by';

  @override
  String get viewWidgetsSortAsc => 'Asc';

  @override
  String get viewWidgetsSortAscending => 'Ascending';

  @override
  String get viewWidgetsSortDesc => 'Desc';

  @override
  String get viewWidgetsSortDescending => 'Descending';

  @override
  String get viewWidgetsModeGallery => 'Gallery';

  @override
  String get viewWidgetsModeGalleryDescription => 'Cards with pictures';

  @override
  String get viewWidgetsModeGalleryReason => 'Needs image files';

  @override
  String get viewWidgetsName => 'Name';

  @override
  String get viewWidgetsNameHint => 'e.g. Pipeline';

  @override
  String get viewWidgetsCreateView => 'Create view';

  @override
  String viewWidgetsNewItem(String item) {
    return 'New $item';
  }

  @override
  String get viewWidgetsAddDetails => 'Add details';

  @override
  String get viewWidgetsLoading => 'Loading';

  @override
  String get viewWidgetsNothingMatchesFilters =>
      'Nothing matches these filters';

  @override
  String get viewWidgetsClearFilters => 'Clear filters';

  @override
  String get viewWidgetsNoDate => 'No date';

  @override
  String viewWidgetsShowNoDate(int count) {
    return 'Show No date ($count)';
  }

  @override
  String get viewWidgetsHideNoDate => 'Hide No date';

  @override
  String get viewWidgetsDropToClearDate => 'Drop to clear the date';

  @override
  String viewWidgetsEveryItemHasDate(String item) {
    return 'Every $item has a date. Drop one here to clear it.';
  }

  @override
  String get viewWidgetsNothingScheduled => 'Nothing scheduled yet';

  @override
  String get viewWidgetsCollapse => 'Collapse';

  @override
  String get viewWidgetsExpand => 'Expand';

  @override
  String viewWidgetsDayToday(String day) {
    return '$day · Today';
  }

  @override
  String get viewWidgetsMoveToDate => 'Move to date';

  @override
  String viewWidgetsClearedDate(String title) {
    return 'Cleared the date of \"$title\"';
  }

  @override
  String viewWidgetsMovedToDay(String title, String day) {
    return 'Moved \"$title\" to $day';
  }

  @override
  String get viewWidgetsPreviousMonth => 'Previous month';

  @override
  String get viewWidgetsNextMonth => 'Next month';

  @override
  String viewWidgetsClickDayToAdd(String item) {
    return 'Click a day to add a $item';
  }

  @override
  String viewWidgetsNewItemOnDay(String item, String day) {
    return 'New $item on $day';
  }

  @override
  String viewWidgetsShowAllMore(int count) {
    return 'Show all, $count more';
  }

  @override
  String viewWidgetsMoreCount(int count) {
    return '+$count more';
  }

  @override
  String viewWidgetsJumpToColumn(String column, int count) {
    return '$column, $count. Jump to column';
  }

  @override
  String viewWidgetsNewItemInColumn(String item, String column) {
    return 'New $item in $column';
  }

  @override
  String viewWidgetsCollapseColumn(String column) {
    return 'Collapse $column';
  }

  @override
  String viewWidgetsDropToClearField(String field) {
    return 'Drop here to clear $field';
  }

  @override
  String viewWidgetsNoItems(String items) {
    return 'No $items';
  }

  @override
  String viewWidgetsExpandColumn(
    String column,
    int count,
    String item,
    String items,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count $items',
      one: '1 $item',
      zero: 'No $items',
    );
    return 'Expand $column, $_temp0';
  }

  @override
  String get viewWidgetsViewSettings => 'View settings';

  @override
  String get viewWidgetsMode => 'Mode';

  @override
  String get viewWidgetsManualOrder => 'Manual order';

  @override
  String get viewWidgetsColumns => 'Columns';

  @override
  String get viewWidgetsCardFields => 'Card fields';

  @override
  String viewWidgetsShownCount(int count) {
    return '$count shown';
  }

  @override
  String get viewWidgetsFilterBy => 'Filter by';

  @override
  String get viewWidgetsUpdateFilter => 'Update filter';

  @override
  String get viewWidgetsSearchFields => 'Search fields';

  @override
  String get viewWidgetsNoFieldsMatch => 'No fields match';

  @override
  String get viewWidgetsNoOptionsYet => 'This field has no options yet';

  @override
  String get viewWidgetsMissingItem => 'Missing item';

  @override
  String get viewWidgetsNothingToLink => 'Nothing to link to yet';

  @override
  String get viewWidgetsNumberHint => 'Number';

  @override
  String get viewWidgetsTextHint => 'Text';

  @override
  String get viewWidgetsEnterNumber => 'Enter a number';

  @override
  String get viewWidgetsNoMatches => 'No matches';

  @override
  String get viewWidgetsLoadingItems => 'Loading items';

  @override
  String get viewWidgetsLoadingItemsEllipsis => 'Loading items…';
}
