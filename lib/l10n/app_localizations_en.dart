// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
