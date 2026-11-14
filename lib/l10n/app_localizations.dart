import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('uk'),
  ];

  /// No description provided for @shellAllCollections.
  ///
  /// In en, this message translates to:
  /// **'All collections'**
  String get shellAllCollections;

  /// No description provided for @shellNavAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get shellNavAll;

  /// No description provided for @shellCollapseSidebar.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get shellCollapseSidebar;

  /// No description provided for @shellExpandSidebar.
  ///
  /// In en, this message translates to:
  /// **'Expand sidebar'**
  String get shellExpandSidebar;

  /// No description provided for @shellPinnedHeader.
  ///
  /// In en, this message translates to:
  /// **'PINNED'**
  String get shellPinnedHeader;

  /// No description provided for @shellPinnedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Pin the collections you use most — tap the pin on any collection in All collections.'**
  String get shellPinnedEmpty;

  /// No description provided for @shellUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get shellUnpin;

  /// No description provided for @shellDragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get shellDragToReorder;

  /// No description provided for @shellJumpTo.
  ///
  /// In en, this message translates to:
  /// **'Jump to…'**
  String get shellJumpTo;

  /// No description provided for @shellJumpToShortcut.
  ///
  /// In en, this message translates to:
  /// **'Jump to… ({shortcut})'**
  String shellJumpToShortcut(String shortcut);

  /// No description provided for @shellJumpHint.
  ///
  /// In en, this message translates to:
  /// **'Jump to a collection'**
  String get shellJumpHint;

  /// No description provided for @shellJumpNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No collection matches \"{query}\"'**
  String shellJumpNoMatch(String query);

  /// No description provided for @shellAskMorkva.
  ///
  /// In en, this message translates to:
  /// **'Ask Morkva'**
  String get shellAskMorkva;

  /// No description provided for @shellAskMorkvaShortcut.
  ///
  /// In en, this message translates to:
  /// **'Ask Morkva · {shortcut}'**
  String shellAskMorkvaShortcut(String shortcut);

  /// No description provided for @shellAccountAndSettings.
  ///
  /// In en, this message translates to:
  /// **'Account and settings'**
  String get shellAccountAndSettings;

  /// No description provided for @shellSyncSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get shellSyncSynced;

  /// No description provided for @shellSyncSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get shellSyncSyncing;

  /// No description provided for @shellSyncOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get shellSyncOffline;

  /// No description provided for @shellSyncConflict.
  ///
  /// In en, this message translates to:
  /// **'Conflict'**
  String get shellSyncConflict;

  /// No description provided for @shellSyncError.
  ///
  /// In en, this message translates to:
  /// **'Sync error'**
  String get shellSyncError;

  /// No description provided for @shellSyncStatus.
  ///
  /// In en, this message translates to:
  /// **'Sync status: {status}'**
  String shellSyncStatus(String status);

  /// No description provided for @shellSyncStatusDismiss.
  ///
  /// In en, this message translates to:
  /// **'Sync status: {status}. Tap to dismiss.'**
  String shellSyncStatusDismiss(String status);

  /// No description provided for @designTypeToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type “{text}” to confirm'**
  String designTypeToConfirm(String text);

  /// No description provided for @designChangeIcon.
  ///
  /// In en, this message translates to:
  /// **'Change icon'**
  String get designChangeIcon;

  /// No description provided for @designChooseIcon.
  ///
  /// In en, this message translates to:
  /// **'Choose an icon'**
  String get designChooseIcon;

  /// No description provided for @designIconNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get designIconNone;

  /// No description provided for @designIconCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get designIconCards;

  /// No description provided for @designIconGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get designIconGrid;

  /// No description provided for @designIconInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get designIconInventory;

  /// No description provided for @designIconShipping.
  ///
  /// In en, this message translates to:
  /// **'Shipping'**
  String get designIconShipping;

  /// No description provided for @designIconOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get designIconOrders;

  /// No description provided for @designIconProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get designIconProducts;

  /// No description provided for @designIconPricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get designIconPricing;

  /// No description provided for @designIconPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get designIconPeople;

  /// No description provided for @designIconContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get designIconContact;

  /// No description provided for @designIconCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get designIconCompany;

  /// No description provided for @designIconStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get designIconStore;

  /// No description provided for @designIconFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get designIconFinance;

  /// No description provided for @designIconInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get designIconInvoices;

  /// No description provided for @designIconSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get designIconSchedule;

  /// No description provided for @designIconTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get designIconTasks;

  /// No description provided for @designIconDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get designIconDocuments;

  /// No description provided for @designIconNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get designIconNotes;

  /// No description provided for @designIconFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get designIconFavorites;

  /// No description provided for @designIconPriorities.
  ///
  /// In en, this message translates to:
  /// **'Priorities'**
  String get designIconPriorities;

  /// No description provided for @designIconProperties.
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get designIconProperties;

  /// No description provided for @designIconVehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get designIconVehicles;

  /// No description provided for @designIconServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get designIconServices;

  /// No description provided for @designIconPets.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get designIconPets;

  /// No description provided for @designIconMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get designIconMenu;

  /// No description provided for @assistantAskMorkva.
  ///
  /// In en, this message translates to:
  /// **'Ask Morkva'**
  String get assistantAskMorkva;

  /// No description provided for @assistantConversationHistory.
  ///
  /// In en, this message translates to:
  /// **'Conversation history'**
  String get assistantConversationHistory;

  /// No description provided for @assistantNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get assistantNewConversation;

  /// No description provided for @assistantCloseAssistant.
  ///
  /// In en, this message translates to:
  /// **'Close assistant'**
  String get assistantCloseAssistant;

  /// No description provided for @assistantBackToConversation.
  ///
  /// In en, this message translates to:
  /// **'Back to the conversation'**
  String get assistantBackToConversation;

  /// No description provided for @assistantConversations.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get assistantConversations;

  /// Screen-reader label of a day header in the conversation history: the day and how many conversations it holds.
  ///
  /// In en, this message translates to:
  /// **'{day}, {count, plural, =1{1 conversation} other{{count} conversations}}'**
  String assistantDayThreads(String day, int count);

  /// No description provided for @assistantGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi. What should we look at?'**
  String get assistantGreeting;

  /// No description provided for @assistantGreetingNamed.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}. What should we look at?'**
  String assistantGreetingNamed(String name);

  /// No description provided for @assistantIntroOne.
  ///
  /// In en, this message translates to:
  /// **'I can read your {name} collection, crunch numbers, and make changes — you approve every change before it happens.'**
  String assistantIntroOne(String name);

  /// No description provided for @assistantIntro.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{I can help you set up collections, crunch numbers, and make changes — you approve every change before it happens.} other{I can read all {count} of your collections, crunch numbers, and make changes — you approve every change before it happens.}}'**
  String assistantIntro(int count);

  /// No description provided for @assistantSuggestAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get assistantSuggestAsk;

  /// No description provided for @assistantSuggestAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get assistantSuggestAnalyze;

  /// No description provided for @assistantSuggestAct.
  ///
  /// In en, this message translates to:
  /// **'Act'**
  String get assistantSuggestAct;

  /// No description provided for @assistantSuggestHelp.
  ///
  /// In en, this message translates to:
  /// **'What can you help me with?'**
  String get assistantSuggestHelp;

  /// No description provided for @assistantSuggestCreateClients.
  ///
  /// In en, this message translates to:
  /// **'Create a Clients collection with name, phone and city'**
  String get assistantSuggestCreateClients;

  /// No description provided for @assistantSuggestSetUpOrders.
  ///
  /// In en, this message translates to:
  /// **'Set up an Orders collection linked to Clients'**
  String get assistantSuggestSetUpOrders;

  /// No description provided for @assistantSuggestHowMany.
  ///
  /// In en, this message translates to:
  /// **'How many {name} were added this month?'**
  String assistantSuggestHowMany(String name);

  /// No description provided for @assistantSuggestNewest.
  ///
  /// In en, this message translates to:
  /// **'Show the 5 newest {name}'**
  String assistantSuggestNewest(String name);

  /// No description provided for @assistantSuggestByMonth.
  ///
  /// In en, this message translates to:
  /// **'{name} by month this year'**
  String assistantSuggestByMonth(String name);

  /// No description provided for @assistantSuggestCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare {name} this month with last month'**
  String assistantSuggestCompare(String name);

  /// No description provided for @assistantSuggestLinked.
  ///
  /// In en, this message translates to:
  /// **'Add a new collection linked to {name}'**
  String assistantSuggestLinked(String name);

  /// No description provided for @assistantSuggestNotes.
  ///
  /// In en, this message translates to:
  /// **'Add a Notes field to {name}'**
  String assistantSuggestNotes(String name);

  /// No description provided for @assistantDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Answers can be wrong — check important numbers.'**
  String get assistantDisclaimer;

  /// No description provided for @assistantOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask Morkva is off'**
  String get assistantOffTitle;

  /// No description provided for @assistantOffBody.
  ///
  /// In en, this message translates to:
  /// **'Ask Morkva isn’t enabled for your account.'**
  String get assistantOffBody;

  /// No description provided for @assistantNotSetUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Not set up yet'**
  String get assistantNotSetUpTitle;

  /// No description provided for @assistantNotSetUpBody.
  ///
  /// In en, this message translates to:
  /// **'Ask Morkva isn’t set up for this project yet.'**
  String get assistantNotSetUpBody;

  /// No description provided for @assistantUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask Morkva is unavailable'**
  String get assistantUnavailableTitle;

  /// No description provided for @assistantTryLater.
  ///
  /// In en, this message translates to:
  /// **'Try again later.'**
  String get assistantTryLater;

  /// No description provided for @assistantOpenObject.
  ///
  /// In en, this message translates to:
  /// **'Open {label}'**
  String assistantOpenObject(String label);

  /// No description provided for @assistantRemoveContext.
  ///
  /// In en, this message translates to:
  /// **'Remove context'**
  String get assistantRemoveContext;

  /// No description provided for @assistantLookingAt.
  ///
  /// In en, this message translates to:
  /// **'Looking at: {target}'**
  String assistantLookingAt(String target);

  /// No description provided for @assistantShownCount.
  ///
  /// In en, this message translates to:
  /// **'{count} shown'**
  String assistantShownCount(int count);

  /// No description provided for @assistantJumpToLatest.
  ///
  /// In en, this message translates to:
  /// **'Jump to latest'**
  String get assistantJumpToLatest;

  /// No description provided for @assistantThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get assistantThinking;

  /// No description provided for @assistantWaitLarge.
  ///
  /// In en, this message translates to:
  /// **'This conversation is large; waiting {seconds} s.'**
  String assistantWaitLarge(int seconds);

  /// No description provided for @assistantBusyRetryingNow.
  ///
  /// In en, this message translates to:
  /// **'Gemini is busy. Retrying now…'**
  String get assistantBusyRetryingNow;

  /// No description provided for @assistantBusyRetryingIn.
  ///
  /// In en, this message translates to:
  /// **'Gemini is busy. Retrying in {seconds} s.'**
  String assistantBusyRetryingIn(int seconds);

  /// No description provided for @assistantWaitLargeSpoken.
  ///
  /// In en, this message translates to:
  /// **'This conversation is large; waiting before it continues.'**
  String get assistantWaitLargeSpoken;

  /// No description provided for @assistantBusyRetryingShortly.
  ///
  /// In en, this message translates to:
  /// **'Gemini is busy. Retrying shortly.'**
  String get assistantBusyRetryingShortly;

  /// No description provided for @assistantDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'Today’s free AI limit is used up. It resets at {time}.'**
  String assistantDailyLimit(String time);

  /// No description provided for @assistantRetryNow.
  ///
  /// In en, this message translates to:
  /// **'Retry now'**
  String get assistantRetryNow;

  /// No description provided for @assistantDeleteThreadTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this conversation?'**
  String get assistantDeleteThreadTitle;

  /// No description provided for @assistantDeleteThreadBody.
  ///
  /// In en, this message translates to:
  /// **'“{title}” and its messages will be deleted. Changes it made to your data stay.'**
  String assistantDeleteThreadBody(String title);

  /// No description provided for @assistantDeleteThreadTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete “{title}”'**
  String assistantDeleteThreadTooltip(String title);

  /// No description provided for @assistantNoThreads.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get assistantNoThreads;

  /// No description provided for @assistantNoThreadsBody.
  ///
  /// In en, this message translates to:
  /// **'Ask something to start one.'**
  String get assistantNoThreadsBody;

  /// No description provided for @assistantNothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get assistantNothingFound;

  /// No description provided for @assistantNoThreadsMatch.
  ///
  /// In en, this message translates to:
  /// **'No conversations match “{query}”.'**
  String assistantNoThreadsMatch(String query);

  /// No description provided for @assistantApplyingSwitchLater.
  ///
  /// In en, this message translates to:
  /// **'Applying changes… you can switch conversations when it’s done.'**
  String get assistantApplyingSwitchLater;

  /// No description provided for @assistantSearchThreads.
  ///
  /// In en, this message translates to:
  /// **'Search conversations'**
  String get assistantSearchThreads;

  /// No description provided for @assistantComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about your data, or tell me what to change…'**
  String get assistantComposerHint;

  /// No description provided for @assistantComposerFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Ask a follow-up…'**
  String get assistantComposerFollowUp;

  /// No description provided for @assistantMessageField.
  ///
  /// In en, this message translates to:
  /// **'Message Morkva'**
  String get assistantMessageField;

  /// No description provided for @assistantOffline.
  ///
  /// In en, this message translates to:
  /// **'You’re offline — Ask Morkva needs a connection.'**
  String get assistantOffline;

  /// No description provided for @assistantPausedUntil.
  ///
  /// In en, this message translates to:
  /// **'Ask Morkva is paused until {time}.'**
  String assistantPausedUntil(String time);

  /// No description provided for @assistantApplyingChanges.
  ///
  /// In en, this message translates to:
  /// **'Applying changes…'**
  String get assistantApplyingChanges;

  /// No description provided for @assistantApproveOrKeep.
  ///
  /// In en, this message translates to:
  /// **'Approve or keep the {noun} above — or send a new message to skip them.'**
  String assistantApproveOrKeep(String noun);

  /// No description provided for @assistantApproveOrKeepItems.
  ///
  /// In en, this message translates to:
  /// **'Approve or keep the items above — or send a new message to skip them.'**
  String get assistantApproveOrKeepItems;

  /// No description provided for @assistantApproveOrReject.
  ///
  /// In en, this message translates to:
  /// **'Approve or reject the changes above — or send a new message to skip them.'**
  String get assistantApproveOrReject;

  /// No description provided for @assistantStopGenerating.
  ///
  /// In en, this message translates to:
  /// **'Stop generating'**
  String get assistantStopGenerating;

  /// No description provided for @assistantSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get assistantSend;

  /// No description provided for @assistantStepsShow.
  ///
  /// In en, this message translates to:
  /// **'Steps: {headline}. Show each step'**
  String assistantStepsShow(String headline);

  /// No description provided for @assistantSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get assistantSteps;

  /// No description provided for @assistantHideSteps.
  ///
  /// In en, this message translates to:
  /// **'Hide steps'**
  String get assistantHideSteps;

  /// No description provided for @assistantStepFailed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get assistantStepFailed;

  /// No description provided for @assistantNoChartData.
  ///
  /// In en, this message translates to:
  /// **'No data to chart'**
  String get assistantNoChartData;

  /// No description provided for @assistantShowAsChart.
  ///
  /// In en, this message translates to:
  /// **'Show as chart'**
  String get assistantShowAsChart;

  /// No description provided for @assistantShowAsTable.
  ///
  /// In en, this message translates to:
  /// **'Show as table'**
  String get assistantShowAsTable;

  /// No description provided for @assistantSaveAsView.
  ///
  /// In en, this message translates to:
  /// **'Save as a view on {name}'**
  String assistantSaveAsView(String name);

  /// No description provided for @assistantSaveAsViewPrompt.
  ///
  /// In en, this message translates to:
  /// **'Save “{title}” as a view on {name}'**
  String assistantSaveAsViewPrompt(String title, String name);

  /// No description provided for @assistantSoFar.
  ///
  /// In en, this message translates to:
  /// **'so far'**
  String get assistantSoFar;

  /// No description provided for @assistantPointSoFar.
  ///
  /// In en, this message translates to:
  /// **'{label} (so far)'**
  String assistantPointSoFar(String label);

  /// No description provided for @assistantChartSemantics.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, bar{Bar chart} other{Line chart}}: {metric}, from {first} to {last}{details}'**
  String assistantChartSemantics(
    String kind,
    String metric,
    String first,
    String last,
    String details,
  );

  /// No description provided for @assistantChartPeak.
  ///
  /// In en, this message translates to:
  /// **', peak {label} at {value}'**
  String assistantChartPeak(String label, String value);

  /// No description provided for @assistantShowingRows.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total}'**
  String assistantShowingRows(int shown, int total);

  /// No description provided for @assistantOpenAsFilteredView.
  ///
  /// In en, this message translates to:
  /// **'Open as filtered view'**
  String get assistantOpenAsFilteredView;

  /// No description provided for @assistantCopyTable.
  ///
  /// In en, this message translates to:
  /// **'Copy table'**
  String get assistantCopyTable;

  /// No description provided for @assistantTableCopied.
  ///
  /// In en, this message translates to:
  /// **'Table copied'**
  String get assistantTableCopied;

  /// No description provided for @assistantOpenCell.
  ///
  /// In en, this message translates to:
  /// **'Open {column} {value}'**
  String assistantOpenCell(String column, String value);

  /// No description provided for @assistantRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry failed'**
  String get assistantRetryFailed;

  /// No description provided for @assistantAppliedSchemaChange.
  ///
  /// In en, this message translates to:
  /// **'Applied schema change'**
  String get assistantAppliedSchemaChange;

  /// No description provided for @assistantAppliedChanges.
  ///
  /// In en, this message translates to:
  /// **'Applied changes'**
  String get assistantAppliedChanges;

  /// No description provided for @assistantStaleLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} changed elsewhere since the preview — left as they were'**
  String assistantStaleLeft(int count);

  /// No description provided for @assistantStartedRuns.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Started 1 automation run ·} other{Started {count} automation runs ·}}'**
  String assistantStartedRuns(int count);

  /// No description provided for @assistantView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get assistantView;

  /// No description provided for @assistantReverted.
  ///
  /// In en, this message translates to:
  /// **'Reverted — nothing is changed now'**
  String get assistantReverted;

  /// No description provided for @assistantUndoFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t undo these changes'**
  String get assistantUndoFailed;

  /// No description provided for @assistantUpdatedSomeFailed.
  ///
  /// In en, this message translates to:
  /// **'Updated {done}, {failed} failed'**
  String assistantUpdatedSomeFailed(int done, int failed);

  /// No description provided for @assistantApprovedOf.
  ///
  /// In en, this message translates to:
  /// **'You approved {done} of {total}'**
  String assistantApprovedOf(int done, int total);

  /// No description provided for @assistantApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get assistantApplied;

  /// No description provided for @assistantQueued.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting for a connection'**
  String assistantQueued(int count);

  /// No description provided for @assistantAppliedNote.
  ///
  /// In en, this message translates to:
  /// **'Applied · {note}'**
  String assistantAppliedNote(String note);

  /// No description provided for @assistantUndoExpired.
  ///
  /// In en, this message translates to:
  /// **'Undo expired'**
  String get assistantUndoExpired;

  /// No description provided for @assistantUndoUntilClose.
  ///
  /// In en, this message translates to:
  /// **'undo available until you close Morkva'**
  String get assistantUndoUntilClose;

  /// No description provided for @assistantUndoForMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{undo available for a minute} other{undo available for {minutes} min}}'**
  String assistantUndoForMinutes(int minutes);

  /// No description provided for @assistantStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get assistantStopped;

  /// No description provided for @assistantCutShort.
  ///
  /// In en, this message translates to:
  /// **'Cut short — ask me to continue'**
  String get assistantCutShort;

  /// No description provided for @assistantProposedDeletion.
  ///
  /// In en, this message translates to:
  /// **'Proposed deletion'**
  String get assistantProposedDeletion;

  /// No description provided for @assistantProposedChanges.
  ///
  /// In en, this message translates to:
  /// **'Proposed changes'**
  String get assistantProposedChanges;

  /// No description provided for @assistantMoreNotShown.
  ///
  /// In en, this message translates to:
  /// **'{count} more not shown yet'**
  String assistantMoreNotShown(int count);

  /// No description provided for @assistantShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show {count} more'**
  String assistantShowMore(int count);

  /// No description provided for @assistantAllSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =2{Both selected} other{All {count} selected}}'**
  String assistantAllSelected(int count);

  /// No description provided for @assistantNoneSelected.
  ///
  /// In en, this message translates to:
  /// **'None selected'**
  String get assistantNoneSelected;

  /// No description provided for @assistantSomeSelected.
  ///
  /// In en, this message translates to:
  /// **'{picked} of {total} selected'**
  String assistantSomeSelected(int picked, int total);

  /// No description provided for @assistantDeleteCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the {name} collection?'**
  String assistantDeleteCollectionTitle(String name);

  /// No description provided for @assistantDeleteCollectionBody.
  ///
  /// In en, this message translates to:
  /// **'Every card in {name} goes with it. {undo}'**
  String assistantDeleteCollectionBody(String name, String undo);

  /// No description provided for @assistantDeleteCollection.
  ///
  /// In en, this message translates to:
  /// **'Delete collection'**
  String get assistantDeleteCollection;

  /// No description provided for @assistantAppliesWithoutAsking.
  ///
  /// In en, this message translates to:
  /// **'Applies changes without asking'**
  String get assistantAppliesWithoutAsking;

  /// No description provided for @assistantPlanKind.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, createCard{Create card} updateCard{Update card} deleteCard{Delete card} createCollection{Create collection} updateCollection{Update collection} deleteCollection{Delete collection} addField{Add field} updateField{Update field} deleteField{Delete field} createView{Create view} updateView{Update view} deleteView{Delete view} saveModule{Save module} saveAutomation{Save automation} deleteAutomation{Delete automation} other{{fallback}}}'**
  String assistantPlanKind(String kind, String fallback);

  /// No description provided for @assistantUndoNone.
  ///
  /// In en, this message translates to:
  /// **'This can’t be undone.'**
  String get assistantUndoNone;

  /// No description provided for @assistantUndoPartialFor.
  ///
  /// In en, this message translates to:
  /// **'Some of it can be undone for {minutes} minutes.'**
  String assistantUndoPartialFor(int minutes);

  /// No description provided for @assistantUndoPartialLater.
  ///
  /// In en, this message translates to:
  /// **'Some of it can be undone afterwards.'**
  String get assistantUndoPartialLater;

  /// No description provided for @assistantUndoFor.
  ///
  /// In en, this message translates to:
  /// **'You can undo this for {minutes} minutes.'**
  String assistantUndoFor(int minutes);

  /// No description provided for @assistantUndoLater.
  ///
  /// In en, this message translates to:
  /// **'You can undo afterwards.'**
  String get assistantUndoLater;

  /// No description provided for @assistantNothingChangesUntilApproved.
  ///
  /// In en, this message translates to:
  /// **'Nothing changes until you approve. {undo}'**
  String assistantNothingChangesUntilApproved(String undo);

  /// No description provided for @assistantModuleSource.
  ///
  /// In en, this message translates to:
  /// **'Module · {name} ({id})'**
  String assistantModuleSource(String name, String id);

  /// No description provided for @assistantDiffFromEmpty.
  ///
  /// In en, this message translates to:
  /// **'from empty'**
  String get assistantDiffFromEmpty;

  /// No description provided for @assistantDiffEmpty.
  ///
  /// In en, this message translates to:
  /// **'empty'**
  String get assistantDiffEmpty;

  /// No description provided for @assistantDiffFrom.
  ///
  /// In en, this message translates to:
  /// **'from {value}'**
  String assistantDiffFrom(String value);

  /// No description provided for @assistantDiffTo.
  ///
  /// In en, this message translates to:
  /// **'to {value}'**
  String assistantDiffTo(String value);

  /// No description provided for @assistantViewCode.
  ///
  /// In en, this message translates to:
  /// **'View code'**
  String get assistantViewCode;

  /// No description provided for @assistantApplyingChangesLabel.
  ///
  /// In en, this message translates to:
  /// **'Applying changes'**
  String get assistantApplyingChangesLabel;

  /// No description provided for @assistantUpdateModule.
  ///
  /// In en, this message translates to:
  /// **'Update module'**
  String get assistantUpdateModule;

  /// No description provided for @assistantInstallModule.
  ///
  /// In en, this message translates to:
  /// **'Install module'**
  String get assistantInstallModule;

  /// No description provided for @assistantDeleteSomeOf.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} of {total}'**
  String assistantDeleteSomeOf(int count, int total);

  /// No description provided for @assistantApproveChanges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Approve 1 change} other{Approve {count} changes}}'**
  String assistantApproveChanges(int count);

  /// No description provided for @assistantKeepIt.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get assistantKeepIt;

  /// No description provided for @assistantKeepThem.
  ///
  /// In en, this message translates to:
  /// **'Keep them'**
  String get assistantKeepThem;

  /// No description provided for @assistantReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get assistantReject;

  /// No description provided for @assistantApplying.
  ///
  /// In en, this message translates to:
  /// **'Applying…'**
  String get assistantApplying;

  /// No description provided for @assistantUpdatingProgress.
  ///
  /// In en, this message translates to:
  /// **'Updating {done} of {total}…'**
  String assistantUpdatingProgress(int done, int total);

  /// No description provided for @assistantRejectedNothingChanged.
  ///
  /// In en, this message translates to:
  /// **'Rejected — nothing changed'**
  String get assistantRejectedNothingChanged;

  /// No description provided for @assistantSkippedNothingChanged.
  ///
  /// In en, this message translates to:
  /// **'Skipped — nothing changed'**
  String get assistantSkippedNothingChanged;

  /// No description provided for @assistantNothingChangedAfter.
  ///
  /// In en, this message translates to:
  /// **'{message} — nothing changed'**
  String assistantNothingChangedAfter(String message);

  /// No description provided for @assistantChangedElsewhere.
  ///
  /// In en, this message translates to:
  /// **'Changed elsewhere since the preview'**
  String get assistantChangedElsewhere;

  /// No description provided for @assistantPreviewExpired.
  ///
  /// In en, this message translates to:
  /// **'This preview expired — nothing changed'**
  String get assistantPreviewExpired;

  /// No description provided for @assistantInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Interrupted while applying — may have been partly applied, check your data'**
  String get assistantInterrupted;

  /// No description provided for @assistantCouldNotApply.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t apply the changes'**
  String get assistantCouldNotApply;

  /// No description provided for @assistantRebuild.
  ///
  /// In en, this message translates to:
  /// **'Rebuild'**
  String get assistantRebuild;

  /// No description provided for @assistantErrorLoadPartial.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load this whole conversation, so the message wasn’t sent. Try again in a moment.'**
  String get assistantErrorLoadPartial;

  /// No description provided for @assistantErrorOpen.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open this conversation.'**
  String get assistantErrorOpen;

  /// No description provided for @assistantNothingWasChanged.
  ///
  /// In en, this message translates to:
  /// **'Nothing was changed.'**
  String get assistantNothingWasChanged;

  /// No description provided for @assistantApprovedWereApplied.
  ///
  /// In en, this message translates to:
  /// **'The changes you approved were applied.'**
  String get assistantApprovedWereApplied;

  /// No description provided for @assistantErrorWithOutcome.
  ///
  /// In en, this message translates to:
  /// **'{message} {outcome}'**
  String assistantErrorWithOutcome(String message, String outcome);

  /// No description provided for @assistantBlocked.
  ///
  /// In en, this message translates to:
  /// **'I can\'t help with that request.'**
  String get assistantBlocked;

  /// No description provided for @assistantErrorDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'Today\'s AI limit is used up.'**
  String get assistantErrorDailyLimit;

  /// No description provided for @assistantErrorBusy.
  ///
  /// In en, this message translates to:
  /// **'Gemini is busy right now.'**
  String get assistantErrorBusy;

  /// No description provided for @assistantErrorDropped.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t finish — the connection dropped.'**
  String get assistantErrorDropped;

  /// No description provided for @assistantErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong and I couldn\'t finish.'**
  String get assistantErrorUnknown;

  /// No description provided for @assistantCouldNotReadResult.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t read the result ({message})'**
  String assistantCouldNotReadResult(String message);

  /// No description provided for @assistantCouldNotRetry.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t retry ({message})'**
  String assistantCouldNotRetry(String message);

  /// No description provided for @assistantNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Needs a connection'**
  String get assistantNeedsConnection;

  /// No description provided for @assistantNeedsConnectionToUndo.
  ///
  /// In en, this message translates to:
  /// **'Needs a connection to undo'**
  String get assistantNeedsConnectionToUndo;

  /// No description provided for @assistantSnippetChart.
  ///
  /// In en, this message translates to:
  /// **'chart'**
  String get assistantSnippetChart;

  /// No description provided for @assistantSnippetTable.
  ///
  /// In en, this message translates to:
  /// **'table'**
  String get assistantSnippetTable;

  /// No description provided for @assistantStepsFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 step didn\'t go through} other{{count} steps didn\'t go through}}'**
  String assistantStepsFailed(int count);

  /// No description provided for @assistantResultShown.
  ///
  /// In en, this message translates to:
  /// **'{name} · {count} shown'**
  String assistantResultShown(String name, int count);

  /// No description provided for @assistantResultCards.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{name} · 1 card} other{{name} · {count} cards}}'**
  String assistantResultCards(String name, int count);

  /// No description provided for @assistantResultBy.
  ///
  /// In en, this message translates to:
  /// **'{name} by {group}'**
  String assistantResultBy(String name, String group);

  /// No description provided for @assistantResultWhere.
  ///
  /// In en, this message translates to:
  /// **'where {clauses}'**
  String assistantResultWhere(String clauses);

  /// No description provided for @assistantResultMatching.
  ///
  /// In en, this message translates to:
  /// **'matching “{query}”'**
  String assistantResultMatching(String query);

  /// No description provided for @assistantStepLookedAt.
  ///
  /// In en, this message translates to:
  /// **'Looked at {name}'**
  String assistantStepLookedAt(String name);

  /// No description provided for @assistantStepFilteredTo.
  ///
  /// In en, this message translates to:
  /// **'filtered to {count}'**
  String assistantStepFilteredTo(int count);

  /// No description provided for @assistantStepFiltered.
  ///
  /// In en, this message translates to:
  /// **'filtered {from} → {to}'**
  String assistantStepFiltered(int from, int to);

  /// No description provided for @assistantStepGroupedBy.
  ///
  /// In en, this message translates to:
  /// **'grouped by {group}'**
  String assistantStepGroupedBy(String group);

  /// No description provided for @assistantTableTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get assistantTableTotal;

  /// No description provided for @assistantTableAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get assistantTableAll;

  /// No description provided for @assistantResultBucket.
  ///
  /// In en, this message translates to:
  /// **'{field} ({bucket})'**
  String assistantResultBucket(String field, String bucket);

  /// No description provided for @assistantBucketDay.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get assistantBucketDay;

  /// No description provided for @assistantBucketWeek.
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get assistantBucketWeek;

  /// No description provided for @assistantBucketMonth.
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get assistantBucketMonth;

  /// No description provided for @assistantBucketQuarter.
  ///
  /// In en, this message translates to:
  /// **'quarter'**
  String get assistantBucketQuarter;

  /// No description provided for @assistantBucketYear.
  ///
  /// In en, this message translates to:
  /// **'year'**
  String get assistantBucketYear;

  /// No description provided for @assistantOpCount.
  ///
  /// In en, this message translates to:
  /// **'count'**
  String get assistantOpCount;

  /// No description provided for @assistantOpSum.
  ///
  /// In en, this message translates to:
  /// **'sum'**
  String get assistantOpSum;

  /// No description provided for @assistantOpAverage.
  ///
  /// In en, this message translates to:
  /// **'average'**
  String get assistantOpAverage;

  /// No description provided for @assistantOpMin.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get assistantOpMin;

  /// No description provided for @assistantOpMax.
  ///
  /// In en, this message translates to:
  /// **'max'**
  String get assistantOpMax;

  /// No description provided for @assistantMetricOf.
  ///
  /// In en, this message translates to:
  /// **'{op} of {field}'**
  String assistantMetricOf(String op, String field);

  /// No description provided for @assistantMetricSummed.
  ///
  /// In en, this message translates to:
  /// **'summed {field}'**
  String assistantMetricSummed(String field);

  /// No description provided for @assistantMetricAveraged.
  ///
  /// In en, this message translates to:
  /// **'averaged {field}'**
  String assistantMetricAveraged(String field);

  /// No description provided for @assistantMetricLowest.
  ///
  /// In en, this message translates to:
  /// **'lowest {field}'**
  String assistantMetricLowest(String field);

  /// No description provided for @assistantMetricHighest.
  ///
  /// In en, this message translates to:
  /// **'highest {field}'**
  String assistantMetricHighest(String field);

  /// No description provided for @assistantMetricCounted.
  ///
  /// In en, this message translates to:
  /// **'counted'**
  String get assistantMetricCounted;

  /// No description provided for @authWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to your workspace'**
  String get authWelcomeTitle;

  /// No description provided for @authWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'One tidy home for your collections and cards — synced securely across every device you sign in on.'**
  String get authWelcomeBody;

  /// No description provided for @authPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'We only use your Google account to sign you in. Your data stays yours.'**
  String get authPrivacyNote;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// No description provided for @syncConflictSemantics.
  ///
  /// In en, this message translates to:
  /// **'Sync conflict warning'**
  String get syncConflictSemantics;

  /// No description provided for @syncConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{A newer version of an item was saved elsewhere} other{A newer version of {count} items was saved elsewhere}}'**
  String syncConflictTitle(int count);

  /// No description provided for @syncConflictBody.
  ///
  /// In en, this message translates to:
  /// **'We kept your latest changes and replaced the other copy. If that other version mattered, re-enter those edits now.'**
  String get syncConflictBody;

  /// No description provided for @syncConflictDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss conflict warning'**
  String get syncConflictDismiss;

  /// No description provided for @automationJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get automationJustNow;

  /// No description provided for @automationMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String automationMinutesAgo(int count);

  /// No description provided for @automationHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String automationHoursAgo(int count);

  /// No description provided for @automationSizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{bytes} B'**
  String automationSizeBytes(int bytes);

  /// No description provided for @automationSizeKb.
  ///
  /// In en, this message translates to:
  /// **'{kb} KB'**
  String automationSizeKb(String kb);

  /// No description provided for @automationDurationMs.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String automationDurationMs(int ms);

  /// No description provided for @automationDurationS.
  ///
  /// In en, this message translates to:
  /// **'{s} s'**
  String automationDurationS(int s);

  /// No description provided for @automationScopeAll.
  ///
  /// In en, this message translates to:
  /// **'In all collections'**
  String get automationScopeAll;

  /// No description provided for @automationScopeIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{In {names}} other{In {names}}}'**
  String automationScopeIn(int count, String names);

  /// No description provided for @automationRemovedCollectionInline.
  ///
  /// In en, this message translates to:
  /// **'a removed collection'**
  String get automationRemovedCollectionInline;

  /// No description provided for @automationWillAskFor.
  ///
  /// In en, this message translates to:
  /// **'Will ask for: {titles}'**
  String automationWillAskFor(String titles);

  /// No description provided for @automationWhenButtonCard.
  ///
  /// In en, this message translates to:
  /// **'Button on a card'**
  String get automationWhenButtonCard;

  /// No description provided for @automationWhenButtonCollection.
  ///
  /// In en, this message translates to:
  /// **'Button on a collection'**
  String get automationWhenButtonCollection;

  /// No description provided for @automationWhenButtonOn.
  ///
  /// In en, this message translates to:
  /// **'Button on {collection}'**
  String automationWhenButtonOn(String collection);

  /// No description provided for @automationWhenCreated.
  ///
  /// In en, this message translates to:
  /// **'When a card is created'**
  String get automationWhenCreated;

  /// No description provided for @automationWhenUpdated.
  ///
  /// In en, this message translates to:
  /// **'When a card is updated'**
  String get automationWhenUpdated;

  /// No description provided for @automationWhenDeleted.
  ///
  /// In en, this message translates to:
  /// **'When a card is deleted'**
  String get automationWhenDeleted;

  /// No description provided for @automationListAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get automationListAnd;

  /// No description provided for @automationListOr.
  ///
  /// In en, this message translates to:
  /// **' or '**
  String get automationListOr;

  /// No description provided for @automationWhenFieldsChange.
  ///
  /// In en, this message translates to:
  /// **'when {fields} changes'**
  String automationWhenFieldsChange(String fields);

  /// No description provided for @automationStartsMatchingField.
  ///
  /// In en, this message translates to:
  /// **'{field} starts matching \"{condition}\"'**
  String automationStartsMatchingField(String field, String condition);

  /// No description provided for @automationStartsMatching.
  ///
  /// In en, this message translates to:
  /// **'starts matching \"{condition}\"'**
  String automationStartsMatching(String condition);

  /// No description provided for @automationDoLine.
  ///
  /// In en, this message translates to:
  /// **'Do: {module} › {action}'**
  String automationDoLine(String module, String action);

  /// No description provided for @automationRemovedModuleInline.
  ///
  /// In en, this message translates to:
  /// **'a removed module'**
  String get automationRemovedModuleInline;

  /// No description provided for @automationSourceImported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get automationSourceImported;

  /// No description provided for @automationSourceAssistant.
  ///
  /// In en, this message translates to:
  /// **'Made by Ask Morkva'**
  String get automationSourceAssistant;

  /// No description provided for @automationInstalledSnack.
  ///
  /// In en, this message translates to:
  /// **'Installed {name}'**
  String automationInstalledSnack(String name);

  /// No description provided for @automationAskMorkva.
  ///
  /// In en, this message translates to:
  /// **'Ask Morkva'**
  String get automationAskMorkva;

  /// No description provided for @automationAskMorkvaToWrite.
  ///
  /// In en, this message translates to:
  /// **'Ask Morkva to write one'**
  String get automationAskMorkvaToWrite;

  /// No description provided for @automationAskPrefill.
  ///
  /// In en, this message translates to:
  /// **'Write a module that '**
  String get automationAskPrefill;

  /// No description provided for @automationImportModule.
  ///
  /// In en, this message translates to:
  /// **'Import module'**
  String get automationImportModule;

  /// No description provided for @automationEngineDownTitle.
  ///
  /// In en, this message translates to:
  /// **'Automations can\'t run on this device right now.'**
  String get automationEngineDownTitle;

  /// No description provided for @automationEngineDownBody.
  ///
  /// In en, this message translates to:
  /// **'Runs are skipped and logged.'**
  String get automationEngineDownBody;

  /// No description provided for @automationPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Modules add actions. Automations put them on buttons or run them when cards change.'**
  String get automationPageSubtitle;

  /// No description provided for @automationNewAutomation.
  ///
  /// In en, this message translates to:
  /// **'New automation'**
  String get automationNewAutomation;

  /// No description provided for @automationInstallModuleFirst.
  ///
  /// In en, this message translates to:
  /// **'Install a module first'**
  String get automationInstallModuleFirst;

  /// No description provided for @automationTabModules.
  ///
  /// In en, this message translates to:
  /// **'Modules'**
  String get automationTabModules;

  /// No description provided for @automationTabRuns.
  ///
  /// In en, this message translates to:
  /// **'Runs'**
  String get automationTabRuns;

  /// No description provided for @automationLoadErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get automationLoadErrorMessage;

  /// No description provided for @automationLoadModulesFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load modules'**
  String get automationLoadModulesFailed;

  /// No description provided for @automationLoadAutomationsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load automations'**
  String get automationLoadAutomationsFailed;

  /// No description provided for @automationLoadRunsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load runs'**
  String get automationLoadRunsFailed;

  /// No description provided for @automationNoModulesTitle.
  ///
  /// In en, this message translates to:
  /// **'No modules yet'**
  String get automationNoModulesTitle;

  /// No description provided for @automationNoModulesMessage.
  ///
  /// In en, this message translates to:
  /// **'Modules add actions to Morkva — like stamping a date or flagging low stock. Ask Morkva to write one, or import a .morkva.json file.'**
  String get automationNoModulesMessage;

  /// No description provided for @automationCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 automation} other{{count} automations}}'**
  String automationCount(int count);

  /// No description provided for @automationThisCollection.
  ///
  /// In en, this message translates to:
  /// **'This collection'**
  String get automationThisCollection;

  /// No description provided for @automationNoAutomationsTitle.
  ///
  /// In en, this message translates to:
  /// **'No automations yet'**
  String get automationNoAutomationsTitle;

  /// No description provided for @automationNoAutomationsMessage.
  ///
  /// In en, this message translates to:
  /// **'Put a module\'s action on a button, or run it when cards are created, changed or deleted.'**
  String get automationNoAutomationsMessage;

  /// No description provided for @automationRemovedCollection.
  ///
  /// In en, this message translates to:
  /// **'Removed collection'**
  String get automationRemovedCollection;

  /// No description provided for @automationEnabledSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name} enabled'**
  String automationEnabledSemantics(String name);

  /// No description provided for @automationClearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear {label}'**
  String automationClearFilter(String label);

  /// No description provided for @automationThisCard.
  ///
  /// In en, this message translates to:
  /// **'This card'**
  String get automationThisCard;

  /// No description provided for @automationThisModule.
  ///
  /// In en, this message translates to:
  /// **'This module'**
  String get automationThisModule;

  /// No description provided for @automationFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get automationFilterAll;

  /// No description provided for @automationFilterNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get automationFilterNeedsReview;

  /// No description provided for @automationFilterFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get automationFilterFailed;

  /// No description provided for @automationFilterByAutomation.
  ///
  /// In en, this message translates to:
  /// **'Filter by automation'**
  String get automationFilterByAutomation;

  /// No description provided for @automationAnyAutomation.
  ///
  /// In en, this message translates to:
  /// **'Any automation'**
  String get automationAnyAutomation;

  /// No description provided for @automationRunningNow.
  ///
  /// In en, this message translates to:
  /// **'Running now'**
  String get automationRunningNow;

  /// No description provided for @automationNoRunsTitle.
  ///
  /// In en, this message translates to:
  /// **'No runs yet'**
  String get automationNoRunsTitle;

  /// No description provided for @automationNoRunsMessage.
  ///
  /// In en, this message translates to:
  /// **'When an automation runs, its log shows up here — what triggered it, what it read, what it changed.'**
  String get automationNoRunsMessage;

  /// No description provided for @automationSkippedGroup.
  ///
  /// In en, this message translates to:
  /// **'{count} skipped · {reason}'**
  String automationSkippedGroup(int count, String reason);

  /// No description provided for @automationShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get automationShow;

  /// No description provided for @automationQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get automationQueued;

  /// No description provided for @automationQueuedAhead.
  ///
  /// In en, this message translates to:
  /// **'Queued · {count} ahead'**
  String automationQueuedAhead(int count);

  /// No description provided for @automationApplyingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Applying…'**
  String get automationApplyingEllipsis;

  /// No description provided for @automationRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get automationRunning;

  /// No description provided for @automationStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get automationStop;

  /// No description provided for @automationSkippedTimes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Skipped 1 time · {reason}} other{Skipped {count} times · {reason}}}'**
  String automationSkippedTimes(int count, String reason);

  /// No description provided for @automationUndone.
  ///
  /// In en, this message translates to:
  /// **'Undone'**
  String get automationUndone;

  /// No description provided for @automationChangedOffline.
  ///
  /// In en, this message translates to:
  /// **'Changed offline {changed} · ran {ran}'**
  String automationChangedOffline(String changed, String ran);

  /// No description provided for @automationReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get automationReview;

  /// No description provided for @automationRunAgain.
  ///
  /// In en, this message translates to:
  /// **'Run again'**
  String get automationRunAgain;

  /// No description provided for @automationRunAgainOn.
  ///
  /// In en, this message translates to:
  /// **'Run again on {card}'**
  String automationRunAgainOn(String card);

  /// No description provided for @automationReviewPermissions.
  ///
  /// In en, this message translates to:
  /// **'Review permissions'**
  String get automationReviewPermissions;

  /// No description provided for @automationEditAutomation.
  ///
  /// In en, this message translates to:
  /// **'Edit automation'**
  String get automationEditAutomation;

  /// No description provided for @automationEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit automation'**
  String get automationEditAction;

  /// No description provided for @automationChangeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change} other{{count} changes}}'**
  String automationChangeCount(int count);

  /// No description provided for @automationNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Needs a connection'**
  String get automationNeedsConnection;

  /// No description provided for @automationImportUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read that file. Choose it again, or paste it.'**
  String get automationImportUnreadable;

  /// No description provided for @automationImportChooseFileHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a .morkva.json file'**
  String get automationImportChooseFileHint;

  /// No description provided for @automationImportChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get automationImportChooseFile;

  /// No description provided for @automationImportPasteHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the module file (JSON)'**
  String get automationImportPasteHint;

  /// No description provided for @automationImportSourceFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get automationImportSourceFile;

  /// No description provided for @automationImportSourcePaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get automationImportSourcePaste;

  /// No description provided for @automationImportSameVersion.
  ///
  /// In en, this message translates to:
  /// **'This version (v{version}) is already installed.'**
  String automationImportSameVersion(String version);

  /// No description provided for @automationImportReplacingTitle.
  ///
  /// In en, this message translates to:
  /// **'A module with this id is installed (v{version}).'**
  String automationImportReplacingTitle(String version);

  /// No description provided for @automationImportReplacingBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Allowing replaces it with v{version} for its 1 automation.} other{Allowing replaces it with v{version} for its {count} automations.}}'**
  String automationImportReplacingBody(int count, String version);

  /// No description provided for @automationScopeTagCard.
  ///
  /// In en, this message translates to:
  /// **'On a card'**
  String get automationScopeTagCard;

  /// No description provided for @automationScopeTagCollection.
  ///
  /// In en, this message translates to:
  /// **'On a collection'**
  String get automationScopeTagCollection;

  /// No description provided for @automationScopeTagAny.
  ///
  /// In en, this message translates to:
  /// **'Card or collection'**
  String get automationScopeTagAny;

  /// No description provided for @automationConsentCodeChanged.
  ///
  /// In en, this message translates to:
  /// **'Code changed: v{fromVersion} → v{toVersion} · {fromSize} → {toSize}'**
  String automationConsentCodeChanged(
    String fromVersion,
    String toVersion,
    String fromSize,
    String toSize,
  );

  /// No description provided for @automationConsentSameVersion.
  ///
  /// In en, this message translates to:
  /// **'This version is already installed.'**
  String get automationConsentSameVersion;

  /// No description provided for @automationConsentAutoApplyOffNew.
  ///
  /// In en, this message translates to:
  /// **'Auto-apply turns off for the new version. Turn it on again in module details.'**
  String get automationConsentAutoApplyOffNew;

  /// No description provided for @automationConsentAutoApplyOffAgain.
  ///
  /// In en, this message translates to:
  /// **'Auto-apply turns off when you install it again. Turn it on again in module details.'**
  String get automationConsentAutoApplyOffAgain;

  /// No description provided for @automationConsentItCan.
  ///
  /// In en, this message translates to:
  /// **'It can:'**
  String get automationConsentItCan;

  /// No description provided for @automationConsentCapNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get automationConsentCapNew;

  /// No description provided for @automationConsentCapRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get automationConsentCapRemoved;

  /// No description provided for @automationConsentActions.
  ///
  /// In en, this message translates to:
  /// **'Actions:'**
  String get automationConsentActions;

  /// No description provided for @automationViewCode.
  ///
  /// In en, this message translates to:
  /// **'View code'**
  String get automationViewCode;

  /// No description provided for @automationConsentWhere.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get automationConsentWhere;

  /// No description provided for @automationConsentAllCollections.
  ///
  /// In en, this message translates to:
  /// **'All collections'**
  String get automationConsentAllCollections;

  /// No description provided for @automationConsentAllCollectionsHint.
  ///
  /// In en, this message translates to:
  /// **'Every collection, including new ones.'**
  String get automationConsentAllCollectionsHint;

  /// No description provided for @automationOnlyThese.
  ///
  /// In en, this message translates to:
  /// **'Only these'**
  String get automationOnlyThese;

  /// No description provided for @automationConsentOnlyTheseHint.
  ///
  /// In en, this message translates to:
  /// **'Pick the collections it may read and change.'**
  String get automationConsentOnlyTheseHint;

  /// No description provided for @automationConsentSandboxNote.
  ///
  /// In en, this message translates to:
  /// **'Modules can\'t reach the internet, your account or other apps. You can change or revoke this later in module details.'**
  String get automationConsentSandboxNote;

  /// No description provided for @automationConsentAllowAndInstall.
  ///
  /// In en, this message translates to:
  /// **'Allow and install'**
  String get automationConsentAllowAndInstall;

  /// No description provided for @automationConsentAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get automationConsentAllow;

  /// No description provided for @automationConsentChangeAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Change access for \"{name}\"'**
  String automationConsentChangeAccessTitle(String name);

  /// No description provided for @automationConsentAllowTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow \"{name}\"?'**
  String automationConsentAllowTitle(String name);

  /// No description provided for @automationConsentPickWhere.
  ///
  /// In en, this message translates to:
  /// **'Choose where it can work'**
  String get automationConsentPickWhere;

  /// No description provided for @automationLoadModuleFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this module'**
  String get automationLoadModuleFailed;

  /// No description provided for @automationModuleNotInstalledTitle.
  ///
  /// In en, this message translates to:
  /// **'This module isn\'t installed'**
  String get automationModuleNotInstalledTitle;

  /// No description provided for @automationModuleNotInstalledMessage.
  ///
  /// In en, this message translates to:
  /// **'It was uninstalled, or the link is out of date.'**
  String get automationModuleNotInstalledMessage;

  /// No description provided for @automationModuleAllowTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow this module to run.'**
  String get automationModuleAllowTitle;

  /// No description provided for @automationModuleAllowBody.
  ///
  /// In en, this message translates to:
  /// **'Review what it can do before its actions can run.'**
  String get automationModuleAllowBody;

  /// No description provided for @automationModuleChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'This module changed (v{fromVersion} → v{toVersion}).'**
  String automationModuleChangedTitle(String fromVersion, String toVersion);

  /// No description provided for @automationModuleChangedBody.
  ///
  /// In en, this message translates to:
  /// **'Its automations are paused until you allow the new version.'**
  String get automationModuleChangedBody;

  /// No description provided for @automationReviewChanges.
  ///
  /// In en, this message translates to:
  /// **'Review changes'**
  String get automationReviewChanges;

  /// No description provided for @automationModuleBrokenTitle.
  ///
  /// In en, this message translates to:
  /// **'This module\'s file is no longer valid.'**
  String get automationModuleBrokenTitle;

  /// No description provided for @automationModuleBrokenBody.
  ///
  /// In en, this message translates to:
  /// **'Import it again.'**
  String get automationModuleBrokenBody;

  /// No description provided for @automationExportedSnack.
  ///
  /// In en, this message translates to:
  /// **'Exported {fileName}'**
  String automationExportedSnack(String fileName);

  /// No description provided for @automationUninstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Uninstall \"{name}\"?'**
  String automationUninstallTitle(String name);

  /// No description provided for @automationUninstallMessageNone.
  ///
  /// In en, this message translates to:
  /// **'Its pending reviews are dropped and its permissions are removed. The run history stays.'**
  String get automationUninstallMessageNone;

  /// No description provided for @automationUninstallMessageOne.
  ///
  /// In en, this message translates to:
  /// **'Its automation and its button are deleted, its pending reviews are dropped and its permissions are removed. The run history stays.'**
  String get automationUninstallMessageOne;

  /// No description provided for @automationUninstallMessageMany.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Its 1 automation and its button are deleted, its pending reviews are dropped and its permissions are removed. The run history stays.} other{Its {count} automations and their buttons are deleted, its pending reviews are dropped and its permissions are removed. The run history stays.}}'**
  String automationUninstallMessageMany(int count);

  /// No description provided for @automationUninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get automationUninstall;

  /// No description provided for @automationUninstalledSnack.
  ///
  /// In en, this message translates to:
  /// **'Uninstalled {name}'**
  String automationUninstalledSnack(String name);

  /// No description provided for @automationModuleAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author: {author} (from the file)'**
  String automationModuleAuthor(String author);

  /// No description provided for @automationExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get automationExport;

  /// No description provided for @automationModuleAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get automationModuleAbout;

  /// No description provided for @automationRevokeTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke access for \"{name}\"?'**
  String automationRevokeTitle(String name);

  /// No description provided for @automationRevokeMessage.
  ///
  /// In en, this message translates to:
  /// **'Its automations stop running and pending reviews are dropped until you allow it again.'**
  String get automationRevokeMessage;

  /// No description provided for @automationRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get automationRevoke;

  /// No description provided for @automationWhatItCanDo.
  ///
  /// In en, this message translates to:
  /// **'What it can do'**
  String get automationWhatItCanDo;

  /// No description provided for @automationChangeAccess.
  ///
  /// In en, this message translates to:
  /// **'Change access'**
  String get automationChangeAccess;

  /// No description provided for @automationModuleSandboxNote.
  ///
  /// In en, this message translates to:
  /// **'Modules can\'t reach the internet, your account or other apps. Every change goes through a preview unless you turn on auto-apply below.'**
  String get automationModuleSandboxNote;

  /// No description provided for @automationWillAskForLabel.
  ///
  /// In en, this message translates to:
  /// **'Will ask for:'**
  String get automationWillAskForLabel;

  /// No description provided for @automationAutoApplyTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply changes automatically'**
  String get automationAutoApplyTitle;

  /// No description provided for @automationAutoApplyNotOffered.
  ///
  /// In en, this message translates to:
  /// **'This module can delete or change structure, so its changes always wait for your review.'**
  String get automationAutoApplyNotOffered;

  /// No description provided for @automationAllowModuleFirst.
  ///
  /// In en, this message translates to:
  /// **'Allow this module first'**
  String get automationAllowModuleFirst;

  /// No description provided for @automationAutoApplyExplanation.
  ///
  /// In en, this message translates to:
  /// **'Small card creates and edits from this module — up to 20 cards, nothing cleared — are applied without asking. Bigger changes, deletes and structure changes always wait for you. You can undo an applied run until you reload Morkva.'**
  String get automationAutoApplyExplanation;

  /// No description provided for @automationInputField.
  ///
  /// In en, this message translates to:
  /// **'a field picker'**
  String get automationInputField;

  /// No description provided for @automationInputCollection.
  ///
  /// In en, this message translates to:
  /// **'a collection picker'**
  String get automationInputCollection;

  /// No description provided for @automationInputChoice.
  ///
  /// In en, this message translates to:
  /// **'a choice'**
  String get automationInputChoice;

  /// No description provided for @automationInputOnOff.
  ///
  /// In en, this message translates to:
  /// **'on or off'**
  String get automationInputOnOff;

  /// No description provided for @automationInputNumber.
  ///
  /// In en, this message translates to:
  /// **'a number'**
  String get automationInputNumber;

  /// No description provided for @automationInputText.
  ///
  /// In en, this message translates to:
  /// **'text'**
  String get automationInputText;

  /// No description provided for @automationActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get automationActions;

  /// No description provided for @automationTestRun.
  ///
  /// In en, this message translates to:
  /// **'Test run'**
  String get automationTestRun;

  /// No description provided for @automationAddToButton.
  ///
  /// In en, this message translates to:
  /// **'Add to a button'**
  String get automationAddToButton;

  /// No description provided for @automationUsingIt.
  ///
  /// In en, this message translates to:
  /// **'Automations using it'**
  String get automationUsingIt;

  /// No description provided for @automationUsingItNone.
  ///
  /// In en, this message translates to:
  /// **'No automations use it yet.'**
  String get automationUsingItNone;

  /// No description provided for @automationCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get automationCode;

  /// No description provided for @automationRecentRuns.
  ///
  /// In en, this message translates to:
  /// **'Recent runs'**
  String get automationRecentRuns;

  /// No description provided for @automationAllRuns.
  ///
  /// In en, this message translates to:
  /// **'All runs'**
  String get automationAllRuns;

  /// No description provided for @automationNoRunsShort.
  ///
  /// In en, this message translates to:
  /// **'No runs yet.'**
  String get automationNoRunsShort;

  /// No description provided for @automationNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes'**
  String get automationNoChanges;

  /// No description provided for @automationLoadRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this run'**
  String get automationLoadRunFailed;

  /// No description provided for @automationRunNotInLogTitle.
  ///
  /// In en, this message translates to:
  /// **'This run isn\'t in the log'**
  String get automationRunNotInLogTitle;

  /// No description provided for @automationRunNotInLogMessage.
  ///
  /// In en, this message translates to:
  /// **'It may have been removed with older runs.'**
  String get automationRunNotInLogMessage;

  /// No description provided for @automationStatusApplying.
  ///
  /// In en, this message translates to:
  /// **'Applying'**
  String get automationStatusApplying;

  /// No description provided for @automationStatusNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get automationStatusNeedsReview;

  /// No description provided for @automationStatusSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Succeeded'**
  String get automationStatusSucceeded;

  /// No description provided for @automationStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get automationStatusFailed;

  /// No description provided for @automationStatusTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Timed out'**
  String get automationStatusTimedOut;

  /// No description provided for @automationStatusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get automationStatusSkipped;

  /// No description provided for @automationStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get automationStatusRejected;

  /// No description provided for @automationStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get automationStatusExpired;

  /// No description provided for @automationAhead.
  ///
  /// In en, this message translates to:
  /// **'{count} ahead'**
  String automationAhead(int count);

  /// No description provided for @automationApplyAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get automationApplyAuto;

  /// No description provided for @automationApplyAskFirst.
  ///
  /// In en, this message translates to:
  /// **'Ask first'**
  String get automationApplyAskFirst;

  /// No description provided for @automationOnDevice.
  ///
  /// In en, this message translates to:
  /// **'on {device}'**
  String automationOnDevice(String device);

  /// No description provided for @automationUndoWithTime.
  ///
  /// In en, this message translates to:
  /// **'Undo · {timeLeft}'**
  String automationUndoWithTime(String timeLeft);

  /// No description provided for @automationMinutesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} min left'**
  String automationMinutesLeft(int count);

  /// No description provided for @automationSecondsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} s left'**
  String automationSecondsLeft(int count);

  /// No description provided for @automationOpenCard.
  ///
  /// In en, this message translates to:
  /// **'Open card'**
  String get automationOpenCard;

  /// No description provided for @automationCopiedRunLog.
  ///
  /// In en, this message translates to:
  /// **'Copied the run log'**
  String get automationCopiedRunLog;

  /// No description provided for @automationCopyLog.
  ///
  /// In en, this message translates to:
  /// **'Copy log'**
  String get automationCopyLog;

  /// No description provided for @automationStepTrigger.
  ///
  /// In en, this message translates to:
  /// **'Trigger'**
  String get automationStepTrigger;

  /// No description provided for @automationAnAutomation.
  ///
  /// In en, this message translates to:
  /// **'An automation'**
  String get automationAnAutomation;

  /// No description provided for @automationThisRun.
  ///
  /// In en, this message translates to:
  /// **'{name} (this run)'**
  String automationThisRun(String name);

  /// No description provided for @automationPreviousRun.
  ///
  /// In en, this message translates to:
  /// **'Previous run'**
  String get automationPreviousRun;

  /// No description provided for @automationStepInputs.
  ///
  /// In en, this message translates to:
  /// **'Inputs'**
  String get automationStepInputs;

  /// No description provided for @automationStepCalls.
  ///
  /// In en, this message translates to:
  /// **'Calls'**
  String get automationStepCalls;

  /// No description provided for @automationNoCalls.
  ///
  /// In en, this message translates to:
  /// **'No calls'**
  String get automationNoCalls;

  /// No description provided for @automationCallsDropped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+1 call dropped} other{+{count} calls dropped}}'**
  String automationCallsDropped(int count);

  /// No description provided for @automationStepConsole.
  ///
  /// In en, this message translates to:
  /// **'Console'**
  String get automationStepConsole;

  /// No description provided for @automationLinesDropped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+1 line dropped} other{+{count} lines dropped}}'**
  String automationLinesDropped(int count);

  /// No description provided for @automationStepPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get automationStepPlan;

  /// No description provided for @automationApprovedAt.
  ///
  /// In en, this message translates to:
  /// **'approved by you at {time}'**
  String automationApprovedAt(String time);

  /// No description provided for @automationStepLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get automationStepLinks;

  /// No description provided for @automationOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Open {label}'**
  String automationOpenLink(String label);

  /// No description provided for @automationStepOutcome.
  ///
  /// In en, this message translates to:
  /// **'Outcome'**
  String get automationStepOutcome;

  /// No description provided for @automationRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry failed'**
  String get automationRetryFailed;

  /// No description provided for @automationReviewElsewhere.
  ///
  /// In en, this message translates to:
  /// **'Review elsewhere'**
  String get automationReviewElsewhere;

  /// No description provided for @automationTriggerButtonCollection.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Button pressed on {collection} · 1 card} other{Button pressed on {collection} · {count} cards}}'**
  String automationTriggerButtonCollection(int count, String collection);

  /// No description provided for @automationTriggerButtonSomeCollection.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Button pressed on a collection · 1 card} other{Button pressed on a collection · {count} cards}}'**
  String automationTriggerButtonSomeCollection(int count);

  /// No description provided for @automationTriggerButtonCard.
  ///
  /// In en, this message translates to:
  /// **'Button pressed on {card}'**
  String automationTriggerButtonCard(String card);

  /// No description provided for @automationTriggerButtonSomeCard.
  ///
  /// In en, this message translates to:
  /// **'Button pressed on a card'**
  String get automationTriggerButtonSomeCard;

  /// No description provided for @automationTriggerCreated.
  ///
  /// In en, this message translates to:
  /// **'Created {card}'**
  String automationTriggerCreated(String card);

  /// No description provided for @automationTriggerCreatedSomeCard.
  ///
  /// In en, this message translates to:
  /// **'Created a card'**
  String get automationTriggerCreatedSomeCard;

  /// No description provided for @automationTriggerDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted {card}'**
  String automationTriggerDeleted(String card);

  /// No description provided for @automationTriggerDeletedSomeCard.
  ///
  /// In en, this message translates to:
  /// **'Deleted a card'**
  String get automationTriggerDeletedSomeCard;

  /// No description provided for @automationTriggerUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {card}'**
  String automationTriggerUpdated(String card);

  /// No description provided for @automationTriggerUpdatedSomeCard.
  ///
  /// In en, this message translates to:
  /// **'Updated a card'**
  String get automationTriggerUpdatedSomeCard;

  /// No description provided for @automationTriggerFieldsChanged.
  ///
  /// In en, this message translates to:
  /// **'{fields} changed on {card}'**
  String automationTriggerFieldsChanged(String fields, String card);

  /// No description provided for @automationTriggerFieldsChangedSomeCard.
  ///
  /// In en, this message translates to:
  /// **'{fields} changed on a card'**
  String automationTriggerFieldsChangedSomeCard(String fields);

  /// No description provided for @automationUpdatedFailed.
  ///
  /// In en, this message translates to:
  /// **'Updated {applied}, {failed} failed'**
  String automationUpdatedFailed(int applied, int failed);

  /// No description provided for @automationAppliedChanges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Applied 1 change} other{Applied {count} changes}}'**
  String automationAppliedChanges(int count);

  /// No description provided for @automationUndoExpired.
  ///
  /// In en, this message translates to:
  /// **'Undo expired'**
  String get automationUndoExpired;

  /// No description provided for @automationUndoAfterReload.
  ///
  /// In en, this message translates to:
  /// **'Undo isn\'t available after a reload'**
  String get automationUndoAfterReload;

  /// No description provided for @automationReverted.
  ///
  /// In en, this message translates to:
  /// **'Reverted · {time}'**
  String automationReverted(String time);

  /// No description provided for @automationAskFixPrefill.
  ///
  /// In en, this message translates to:
  /// **'Fix the module \"{name}\": {problem}'**
  String automationAskFixPrefill(String name, String problem);

  /// No description provided for @automationDecideLater.
  ///
  /// In en, this message translates to:
  /// **'Decide later'**
  String get automationDecideLater;

  /// No description provided for @automationSavedForReview.
  ///
  /// In en, this message translates to:
  /// **'Saved for review'**
  String get automationSavedForReview;

  /// No description provided for @automationButtonPressed.
  ///
  /// In en, this message translates to:
  /// **'Button pressed'**
  String get automationButtonPressed;

  /// No description provided for @automationBecauseCreated.
  ///
  /// In en, this message translates to:
  /// **'Because {card} was created'**
  String automationBecauseCreated(String card);

  /// No description provided for @automationBecauseCreatedSomeCard.
  ///
  /// In en, this message translates to:
  /// **'Because a card was created'**
  String get automationBecauseCreatedSomeCard;

  /// No description provided for @automationBecauseDeleted.
  ///
  /// In en, this message translates to:
  /// **'Because {card} was deleted'**
  String automationBecauseDeleted(String card);

  /// No description provided for @automationBecauseDeletedSomeCard.
  ///
  /// In en, this message translates to:
  /// **'Because a card was deleted'**
  String get automationBecauseDeletedSomeCard;

  /// No description provided for @automationBecauseUpdated.
  ///
  /// In en, this message translates to:
  /// **'Because {card} was updated'**
  String automationBecauseUpdated(String card);

  /// No description provided for @automationBecauseUpdatedSomeCard.
  ///
  /// In en, this message translates to:
  /// **'Because a card was updated'**
  String get automationBecauseUpdatedSomeCard;

  /// No description provided for @automationReviewExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'This review expired.'**
  String get automationReviewExpiredTitle;

  /// No description provided for @automationReviewExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'Previews are kept only while Morkva is open. Run it again to get a fresh preview on the current data.'**
  String get automationReviewExpiredBody;

  /// No description provided for @automationUndoneSentence.
  ///
  /// In en, this message translates to:
  /// **'Undone.'**
  String get automationUndoneSentence;

  /// No description provided for @automationDoneSentence.
  ///
  /// In en, this message translates to:
  /// **'Done.'**
  String get automationDoneSentence;

  /// No description provided for @automationNextReview.
  ///
  /// In en, this message translates to:
  /// **'Next review ({count} left)'**
  String automationNextReview(int count);

  /// No description provided for @automationTestRunNote.
  ///
  /// In en, this message translates to:
  /// **'Test runs never change data — you\'ll see what would change.'**
  String get automationTestRunNote;

  /// No description provided for @automationTestRunCollection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get automationTestRunCollection;

  /// No description provided for @automationTestRunCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get automationTestRunCard;

  /// No description provided for @automationTestRunCardOptional.
  ///
  /// In en, this message translates to:
  /// **'Card (optional)'**
  String get automationTestRunCardOptional;

  /// No description provided for @automationSearchCards.
  ///
  /// In en, this message translates to:
  /// **'Search cards'**
  String get automationSearchCards;

  /// No description provided for @automationLoadCardsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load cards'**
  String get automationLoadCardsFailed;

  /// No description provided for @automationTestRunTitle.
  ///
  /// In en, this message translates to:
  /// **'Test \"{action}\"'**
  String automationTestRunTitle(String action);

  /// No description provided for @automationTestRunNeedsAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow the module to test it'**
  String get automationTestRunNeedsAllow;

  /// No description provided for @automationRunTest.
  ///
  /// In en, this message translates to:
  /// **'Run test'**
  String get automationRunTest;

  /// No description provided for @automationWouldChangeCards.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Would change 1 card} other{Would change {count} cards}}'**
  String automationWouldChangeCards(int count);

  /// No description provided for @automationTestRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {reason}'**
  String automationTestRunFailed(String reason);

  /// No description provided for @automationCallsCount.
  ///
  /// In en, this message translates to:
  /// **'Calls ({count})'**
  String automationCallsCount(int count);

  /// No description provided for @automationConsoleCount.
  ///
  /// In en, this message translates to:
  /// **'Console ({count})'**
  String automationConsoleCount(int count);

  /// No description provided for @automationCloseEditor.
  ///
  /// In en, this message translates to:
  /// **'Close editor'**
  String get automationCloseEditor;

  /// No description provided for @automationDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String automationDeleteTitle(String name);

  /// No description provided for @automationDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Its button disappears. Run history stays.'**
  String get automationDeleteMessage;

  /// No description provided for @automationEditorName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get automationEditorName;

  /// No description provided for @automationEditorNameHint.
  ///
  /// In en, this message translates to:
  /// **'Stamp when shipped'**
  String get automationEditorNameHint;

  /// No description provided for @automationEditorWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get automationEditorWhen;

  /// No description provided for @automationEditorIn.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get automationEditorIn;

  /// No description provided for @automationEditorDo.
  ///
  /// In en, this message translates to:
  /// **'Do'**
  String get automationEditorDo;

  /// No description provided for @automationEditorButton.
  ///
  /// In en, this message translates to:
  /// **'Button'**
  String get automationEditorButton;

  /// No description provided for @automationEditorApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get automationEditorApply;

  /// No description provided for @automationEditorEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get automationEditorEnabled;

  /// No description provided for @automationPausedBroken.
  ///
  /// In en, this message translates to:
  /// **'This automation is paused.'**
  String get automationPausedBroken;

  /// No description provided for @automationPausedLoopTitle.
  ///
  /// In en, this message translates to:
  /// **'Paused: it ran too often in a minute,'**
  String get automationPausedLoopTitle;

  /// No description provided for @automationPausedLoopMessage.
  ///
  /// In en, this message translates to:
  /// **'which looks like a loop (it may be changing the cards it watches).'**
  String get automationPausedLoopMessage;

  /// No description provided for @automationPausedCrashedTitle.
  ///
  /// In en, this message translates to:
  /// **'Paused: Morkva stopped while this ran'**
  String get automationPausedCrashedTitle;

  /// No description provided for @automationPausedCrashedMessage.
  ///
  /// In en, this message translates to:
  /// **'(probably out of memory).'**
  String get automationPausedCrashedMessage;

  /// No description provided for @automationResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get automationResume;

  /// No description provided for @automationKindCardButtonHint.
  ///
  /// In en, this message translates to:
  /// **'Shows in the card\'s header.'**
  String get automationKindCardButtonHint;

  /// No description provided for @automationKindCollectionButtonHint.
  ///
  /// In en, this message translates to:
  /// **'Shows in the collection\'s Actions menu.'**
  String get automationKindCollectionButtonHint;

  /// No description provided for @automationPickCollection.
  ///
  /// In en, this message translates to:
  /// **'Pick a collection'**
  String get automationPickCollection;

  /// No description provided for @automationNotAllowedNote.
  ///
  /// In en, this message translates to:
  /// **'Not allowed for this module'**
  String get automationNotAllowedNote;

  /// No description provided for @automationNotAllowedForModule.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{names} isn\'t allowed for this module.} other{{names} aren\'t allowed for this module.}}'**
  String automationNotAllowedForModule(int count, String names);

  /// No description provided for @automationAddCondition.
  ///
  /// In en, this message translates to:
  /// **'Add condition'**
  String get automationAddCondition;

  /// No description provided for @automationEditCondition.
  ///
  /// In en, this message translates to:
  /// **'Edit condition'**
  String get automationEditCondition;

  /// No description provided for @automationEditorIf.
  ///
  /// In en, this message translates to:
  /// **'If'**
  String get automationEditorIf;

  /// No description provided for @automationCondition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get automationCondition;

  /// No description provided for @automationRunOnAnyChange.
  ///
  /// In en, this message translates to:
  /// **'Run on any change'**
  String get automationRunOnAnyChange;

  /// No description provided for @automationOnlyWhenFieldsChange.
  ///
  /// In en, this message translates to:
  /// **'Only when these fields change'**
  String get automationOnlyWhenFieldsChange;

  /// No description provided for @automationLeaveEmptyAnyChange.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to react to any change.'**
  String get automationLeaveEmptyAnyChange;

  /// No description provided for @automationEditorRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get automationEditorRun;

  /// No description provided for @automationModeEnters.
  ///
  /// In en, this message translates to:
  /// **'Once, when the card starts matching'**
  String get automationModeEnters;

  /// No description provided for @automationModeEntersHint.
  ///
  /// In en, this message translates to:
  /// **'Won\'t run again while it keeps matching.'**
  String get automationModeEntersHint;

  /// No description provided for @automationModeMatches.
  ///
  /// In en, this message translates to:
  /// **'Every time it\'s updated and matches'**
  String get automationModeMatches;

  /// No description provided for @automationEventHelp.
  ///
  /// In en, this message translates to:
  /// **'Runs on the device where the change is made, while Morkva is open there. Offline changes run when they sync. Calculated values don\'t trigger on their own.'**
  String get automationEventHelp;

  /// No description provided for @automationLastChecked.
  ///
  /// In en, this message translates to:
  /// **'Last checked'**
  String get automationLastChecked;

  /// No description provided for @automationFieldFallback.
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get automationFieldFallback;

  /// No description provided for @automationRemoveCondition.
  ///
  /// In en, this message translates to:
  /// **'Remove {label}'**
  String automationRemoveCondition(String label);

  /// No description provided for @automationPickModule.
  ///
  /// In en, this message translates to:
  /// **'Pick a module'**
  String get automationPickModule;

  /// No description provided for @automationPickAction.
  ///
  /// In en, this message translates to:
  /// **'Pick an action'**
  String get automationPickAction;

  /// No description provided for @automationActionRunsOnCollection.
  ///
  /// In en, this message translates to:
  /// **'{action} · Runs on a collection'**
  String automationActionRunsOnCollection(String action);

  /// No description provided for @automationActionRunsOnCard.
  ///
  /// In en, this message translates to:
  /// **'{action} · Runs on a card'**
  String automationActionRunsOnCard(String action);

  /// No description provided for @automationModule.
  ///
  /// In en, this message translates to:
  /// **'Module'**
  String get automationModule;

  /// No description provided for @automationAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get automationAction;

  /// No description provided for @automationFieldsOf.
  ///
  /// In en, this message translates to:
  /// **'Fields of {collection}.'**
  String automationFieldsOf(String collection);

  /// No description provided for @automationButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get automationButtonLabel;

  /// No description provided for @automationButtonIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get automationButtonIcon;

  /// No description provided for @automationButtonColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get automationButtonColor;

  /// No description provided for @automationButtonPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get automationButtonPreview;

  /// No description provided for @automationAskFirstButtonHint.
  ///
  /// In en, this message translates to:
  /// **'You review each change in a preview.'**
  String get automationAskFirstButtonHint;

  /// No description provided for @automationAskFirstEventHint.
  ///
  /// In en, this message translates to:
  /// **'Each card waits in Needs review.'**
  String get automationAskFirstEventHint;

  /// No description provided for @automationApplyAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Apply automatically'**
  String get automationApplyAutomatically;

  /// No description provided for @automationApplyAutomaticallyHint.
  ///
  /// In en, this message translates to:
  /// **'Small card creates and edits apply without asking. Bigger changes, deletes and structure changes still wait.'**
  String get automationApplyAutomaticallyHint;

  /// No description provided for @automationAlwaysAsks.
  ///
  /// In en, this message translates to:
  /// **'This module can delete or change structure, so it always asks.'**
  String get automationAlwaysAsks;

  /// No description provided for @automationTurnOnAutoApplyFirst.
  ///
  /// In en, this message translates to:
  /// **'Turn on auto-apply for this module first.'**
  String get automationTurnOnAutoApplyFirst;

  /// No description provided for @automationModuleDetails.
  ///
  /// In en, this message translates to:
  /// **'Module details'**
  String get automationModuleDetails;

  /// No description provided for @automationScopeSameAsModuleSummary.
  ///
  /// In en, this message translates to:
  /// **'Collections it may touch: same as the module\'s access'**
  String get automationScopeSameAsModuleSummary;

  /// No description provided for @automationScopeCountSummary.
  ///
  /// In en, this message translates to:
  /// **'Collections it may touch: {count}'**
  String automationScopeCountSummary(int count);

  /// No description provided for @automationAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get automationAdvanced;

  /// No description provided for @automationScopeSameAsModule.
  ///
  /// In en, this message translates to:
  /// **'Same as the module\'s access'**
  String get automationScopeSameAsModule;

  /// No description provided for @automationCallDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get automationCallDone;

  /// No description provided for @automationCallNoChange.
  ///
  /// In en, this message translates to:
  /// **'Already up to date'**
  String get automationCallNoChange;

  /// No description provided for @automationErrorCrashed.
  ///
  /// In en, this message translates to:
  /// **'The page stopped while this ran — probably out of memory'**
  String get automationErrorCrashed;

  /// No description provided for @automationErrorInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Interrupted — may be partly applied, check the cards.'**
  String get automationErrorInterrupted;

  /// No description provided for @automationTintCarrot.
  ///
  /// In en, this message translates to:
  /// **'carrot'**
  String get automationTintCarrot;

  /// No description provided for @automationTintLeaf.
  ///
  /// In en, this message translates to:
  /// **'leaf'**
  String get automationTintLeaf;

  /// No description provided for @automationTintSky.
  ///
  /// In en, this message translates to:
  /// **'sky'**
  String get automationTintSky;

  /// No description provided for @automationTintPlum.
  ///
  /// In en, this message translates to:
  /// **'plum'**
  String get automationTintPlum;

  /// No description provided for @automationTintSand.
  ///
  /// In en, this message translates to:
  /// **'sand'**
  String get automationTintSand;

  /// No description provided for @automationTintRose.
  ///
  /// In en, this message translates to:
  /// **'rose'**
  String get automationTintRose;

  /// No description provided for @automationTintSlate.
  ///
  /// In en, this message translates to:
  /// **'slate'**
  String get automationTintSlate;

  /// No description provided for @automationTintTeal.
  ///
  /// In en, this message translates to:
  /// **'teal'**
  String get automationTintTeal;

  /// No description provided for @automationWidgetsFixReviewPermissions.
  ///
  /// In en, this message translates to:
  /// **'Review permissions'**
  String get automationWidgetsFixReviewPermissions;

  /// No description provided for @automationWidgetsFixEditAutomation.
  ///
  /// In en, this message translates to:
  /// **'Edit automation'**
  String get automationWidgetsFixEditAutomation;

  /// No description provided for @automationWidgetsFixResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get automationWidgetsFixResume;

  /// No description provided for @automationWidgetsFixRunAgain.
  ///
  /// In en, this message translates to:
  /// **'Run again'**
  String get automationWidgetsFixRunAgain;

  /// No description provided for @automationWidgetsFixChangeAccess.
  ///
  /// In en, this message translates to:
  /// **'Change access'**
  String get automationWidgetsFixChangeAccess;

  /// No description provided for @automationWidgetsFixAskMorkva.
  ///
  /// In en, this message translates to:
  /// **'Ask Morkva to fix it'**
  String get automationWidgetsFixAskMorkva;

  /// No description provided for @automationWidgetsRunQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get automationWidgetsRunQueued;

  /// No description provided for @automationWidgetsRunQueuedDetail.
  ///
  /// In en, this message translates to:
  /// **'Waiting for its turn.'**
  String get automationWidgetsRunQueuedDetail;

  /// No description provided for @automationWidgetsRunRunning.
  ///
  /// In en, this message translates to:
  /// **'Running…'**
  String get automationWidgetsRunRunning;

  /// No description provided for @automationWidgetsRunRunningDetail.
  ///
  /// In en, this message translates to:
  /// **'The action is running.'**
  String get automationWidgetsRunRunningDetail;

  /// No description provided for @automationWidgetsRunApplying.
  ///
  /// In en, this message translates to:
  /// **'Applying…'**
  String get automationWidgetsRunApplying;

  /// No description provided for @automationWidgetsRunApplyingDetail.
  ///
  /// In en, this message translates to:
  /// **'Applying the changes.'**
  String get automationWidgetsRunApplyingDetail;

  /// No description provided for @automationWidgetsRunAwaitingReview.
  ///
  /// In en, this message translates to:
  /// **'Needs your review'**
  String get automationWidgetsRunAwaitingReview;

  /// No description provided for @automationWidgetsRunAwaitingReviewDetail.
  ///
  /// In en, this message translates to:
  /// **'The changes wait for you in a preview.'**
  String get automationWidgetsRunAwaitingReviewDetail;

  /// No description provided for @automationWidgetsRunDoneDetail.
  ///
  /// In en, this message translates to:
  /// **'The action finished.'**
  String get automationWidgetsRunDoneDetail;

  /// No description provided for @automationWidgetsRunTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Timed out after {seconds} s'**
  String automationWidgetsRunTimedOut(int seconds);

  /// No description provided for @automationWidgetsRunTimedOutDetail.
  ///
  /// In en, this message translates to:
  /// **'The action took longer than {seconds} s and was stopped. Nothing was changed.'**
  String automationWidgetsRunTimedOutDetail(int seconds);

  /// No description provided for @automationWidgetsRunRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get automationWidgetsRunRejected;

  /// No description provided for @automationWidgetsRunRejectedDetail.
  ///
  /// In en, this message translates to:
  /// **'You rejected the preview.'**
  String get automationWidgetsRunRejectedDetail;

  /// No description provided for @automationWidgetsRunExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get automationWidgetsRunExpired;

  /// No description provided for @automationWidgetsRunExpiredDetail.
  ///
  /// In en, this message translates to:
  /// **'The preview was kept only while Morkva was open.'**
  String get automationWidgetsRunExpiredDetail;

  /// No description provided for @automationWidgetsRunSkipped.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t run'**
  String get automationWidgetsRunSkipped;

  /// No description provided for @automationWidgetsRunSkippedDetail.
  ///
  /// In en, this message translates to:
  /// **'Morkva didn\'t run this action.'**
  String get automationWidgetsRunSkippedDetail;

  /// No description provided for @automationWidgetsRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get automationWidgetsRunFailed;

  /// No description provided for @automationWidgetsRunFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'The run failed.'**
  String get automationWidgetsRunFailedDetail;

  /// No description provided for @automationWidgetsNeedsConsent.
  ///
  /// In en, this message translates to:
  /// **'Needs consent'**
  String get automationWidgetsNeedsConsent;

  /// No description provided for @automationWidgetsReasonNeedsConsentDetail.
  ///
  /// In en, this message translates to:
  /// **'The module changed or isn\'t allowed yet.'**
  String get automationWidgetsReasonNeedsConsentDetail;

  /// No description provided for @automationWidgetsReasonBroken.
  ///
  /// In en, this message translates to:
  /// **'Automation broken'**
  String get automationWidgetsReasonBroken;

  /// No description provided for @automationWidgetsReasonBrokenDetail.
  ///
  /// In en, this message translates to:
  /// **'Its condition, action or collection no longer fits.'**
  String get automationWidgetsReasonBrokenDetail;

  /// No description provided for @automationWidgetsStoppedAfterCrash.
  ///
  /// In en, this message translates to:
  /// **'Stopped after a crash'**
  String get automationWidgetsStoppedAfterCrash;

  /// No description provided for @automationWidgetsReasonCrashedDetail.
  ///
  /// In en, this message translates to:
  /// **'Morkva stopped while this ran, probably out of memory.'**
  String get automationWidgetsReasonCrashedDetail;

  /// No description provided for @automationWidgetsReasonCrashedAdvice.
  ///
  /// In en, this message translates to:
  /// **'Resume on the automation'**
  String get automationWidgetsReasonCrashedAdvice;

  /// No description provided for @automationWidgetsPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get automationWidgetsPaused;

  /// No description provided for @automationWidgetsReasonPausedDetail.
  ///
  /// In en, this message translates to:
  /// **'It was paused (by you, or because it looked like a loop).'**
  String get automationWidgetsReasonPausedDetail;

  /// No description provided for @automationWidgetsReasonEngineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t run here'**
  String get automationWidgetsReasonEngineUnavailable;

  /// No description provided for @automationWidgetsReasonEngineUnavailableDetail.
  ///
  /// In en, this message translates to:
  /// **'The secure sandbox can\'t start on this device.'**
  String get automationWidgetsReasonEngineUnavailableDetail;

  /// No description provided for @automationWidgetsReasonEngineUnavailableAdvice.
  ///
  /// In en, this message translates to:
  /// **'Run it from another device or browser'**
  String get automationWidgetsReasonEngineUnavailableAdvice;

  /// No description provided for @automationWidgetsReasonNotSettled.
  ///
  /// In en, this message translates to:
  /// **'Card didn\'t update in time'**
  String get automationWidgetsReasonNotSettled;

  /// No description provided for @automationWidgetsReasonNotSettledDetail.
  ///
  /// In en, this message translates to:
  /// **'The change hadn\'t reached Morkva within 5 s, so it wasn\'t checked.'**
  String get automationWidgetsReasonNotSettledDetail;

  /// No description provided for @automationWidgetsReasonNotPermitted.
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get automationWidgetsReasonNotPermitted;

  /// No description provided for @automationWidgetsReasonNotPermittedDetail.
  ///
  /// In en, this message translates to:
  /// **'A change touched a collection this module isn\'t allowed in.'**
  String get automationWidgetsReasonNotPermittedDetail;

  /// No description provided for @automationWidgetsReasonLoop.
  ///
  /// In en, this message translates to:
  /// **'Would loop'**
  String get automationWidgetsReasonLoop;

  /// No description provided for @automationWidgetsReasonLoopDetail.
  ///
  /// In en, this message translates to:
  /// **'This automation already ran in this chain.'**
  String get automationWidgetsReasonLoopDetail;

  /// No description provided for @automationWidgetsReasonLoopAdvice.
  ///
  /// In en, this message translates to:
  /// **'Change its conditions'**
  String get automationWidgetsReasonLoopAdvice;

  /// No description provided for @automationWidgetsReasonDepthLimit.
  ///
  /// In en, this message translates to:
  /// **'Chain too long'**
  String get automationWidgetsReasonDepthLimit;

  /// No description provided for @automationWidgetsReasonDepthLimitDetail.
  ///
  /// In en, this message translates to:
  /// **'Automations triggered each other 3 levels deep; Morkva stopped here.'**
  String get automationWidgetsReasonDepthLimitDetail;

  /// No description provided for @automationWidgetsReasonDepthLimitAdvice.
  ///
  /// In en, this message translates to:
  /// **'Change the automations\' conditions'**
  String get automationWidgetsReasonDepthLimitAdvice;

  /// No description provided for @automationWidgetsReasonFanOut.
  ///
  /// In en, this message translates to:
  /// **'Too many cards at once'**
  String get automationWidgetsReasonFanOut;

  /// No description provided for @automationWidgetsReasonFanOutDetail.
  ///
  /// In en, this message translates to:
  /// **'Only the first 100 cards of one change are processed.'**
  String get automationWidgetsReasonFanOutDetail;

  /// No description provided for @automationWidgetsReasonFanOutAdvice.
  ///
  /// In en, this message translates to:
  /// **'Split the change into smaller batches'**
  String get automationWidgetsReasonFanOutAdvice;

  /// No description provided for @automationWidgetsReasonQueueFull.
  ///
  /// In en, this message translates to:
  /// **'Too busy'**
  String get automationWidgetsReasonQueueFull;

  /// No description provided for @automationWidgetsReasonQueueFullDetail.
  ///
  /// In en, this message translates to:
  /// **'Too many runs were waiting.'**
  String get automationWidgetsReasonQueueFullDetail;

  /// No description provided for @automationWidgetsReasonQueueFullAdvice.
  ///
  /// In en, this message translates to:
  /// **'Run again later'**
  String get automationWidgetsReasonQueueFullAdvice;

  /// No description provided for @automationWidgetsReasonReviewBacklog.
  ///
  /// In en, this message translates to:
  /// **'Too many waiting reviews'**
  String get automationWidgetsReasonReviewBacklog;

  /// No description provided for @automationWidgetsReasonReviewBacklogDetail.
  ///
  /// In en, this message translates to:
  /// **'50 reviews are already waiting.'**
  String get automationWidgetsReasonReviewBacklogDetail;

  /// No description provided for @automationWidgetsReasonReviewBacklogAdvice.
  ///
  /// In en, this message translates to:
  /// **'Review or reject the waiting ones'**
  String get automationWidgetsReasonReviewBacklogAdvice;

  /// No description provided for @automationWidgetsReasonCardGone.
  ///
  /// In en, this message translates to:
  /// **'Card was deleted'**
  String get automationWidgetsReasonCardGone;

  /// No description provided for @automationWidgetsReasonCardGoneDetail.
  ///
  /// In en, this message translates to:
  /// **'The card no longer exists.'**
  String get automationWidgetsReasonCardGoneDetail;

  /// No description provided for @automationWidgetsStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get automationWidgetsStopped;

  /// No description provided for @automationWidgetsReasonCancelledDetail.
  ///
  /// In en, this message translates to:
  /// **'Stopped by you. Nothing was changed.'**
  String get automationWidgetsReasonCancelledDetail;

  /// No description provided for @automationWidgetsReasonDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Already running'**
  String get automationWidgetsReasonDuplicate;

  /// No description provided for @automationWidgetsReasonDuplicateDetail.
  ///
  /// In en, this message translates to:
  /// **'This automation was already running on this card.'**
  String get automationWidgetsReasonDuplicateDetail;

  /// No description provided for @automationWidgetsReasonLoadError.
  ///
  /// In en, this message translates to:
  /// **'Module didn\'t start'**
  String get automationWidgetsReasonLoadError;

  /// No description provided for @automationWidgetsReasonLoadErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'The module\'s code has an error or took too long to load.'**
  String get automationWidgetsReasonLoadErrorDetail;

  /// No description provided for @automationWidgetsReasonLoadErrorAdvice.
  ///
  /// In en, this message translates to:
  /// **'Ask Morkva to fix it, or import a fixed file'**
  String get automationWidgetsReasonLoadErrorAdvice;

  /// No description provided for @automationWidgetsReasonModuleError.
  ///
  /// In en, this message translates to:
  /// **'Module failed'**
  String get automationWidgetsReasonModuleError;

  /// No description provided for @automationWidgetsReasonModuleErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'The module failed.'**
  String get automationWidgetsReasonModuleErrorDetail;

  /// No description provided for @automationWidgetsReasonModuleErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'The module failed: {message}'**
  String automationWidgetsReasonModuleErrorMessage(String message);

  /// No description provided for @automationWidgetsReasonPlanRefused.
  ///
  /// In en, this message translates to:
  /// **'Change refused'**
  String get automationWidgetsReasonPlanRefused;

  /// No description provided for @automationWidgetsReasonPlanRefusedDetail.
  ///
  /// In en, this message translates to:
  /// **'A change the module asked for wasn\'t allowed — see Calls.'**
  String get automationWidgetsReasonPlanRefusedDetail;

  /// No description provided for @automationWidgetsReasonPlanRefusedAdvice.
  ///
  /// In en, this message translates to:
  /// **'Check Calls; change access if needed'**
  String get automationWidgetsReasonPlanRefusedAdvice;

  /// No description provided for @automationWidgetsReasonLimitExceeded.
  ///
  /// In en, this message translates to:
  /// **'Too much work'**
  String get automationWidgetsReasonLimitExceeded;

  /// No description provided for @automationWidgetsReasonLimitExceededDetail.
  ///
  /// In en, this message translates to:
  /// **'The module asked for more than one run may do (calls, data or time).'**
  String get automationWidgetsReasonLimitExceededDetail;

  /// No description provided for @automationWidgetsReasonLimitExceededAdvice.
  ///
  /// In en, this message translates to:
  /// **'Run it on fewer cards'**
  String get automationWidgetsReasonLimitExceededAdvice;

  /// No description provided for @automationWidgetsReasonAbuseDetail.
  ///
  /// In en, this message translates to:
  /// **'The module sent too many or too large messages.'**
  String get automationWidgetsReasonAbuseDetail;

  /// No description provided for @automationWidgetsReasonOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get automationWidgetsReasonOffline;

  /// No description provided for @automationWidgetsReasonOfflineDetail.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t apply without a connection.'**
  String get automationWidgetsReasonOfflineDetail;

  /// No description provided for @automationWidgetsReasonOfflineAdvice.
  ///
  /// In en, this message translates to:
  /// **'Run again when online'**
  String get automationWidgetsReasonOfflineAdvice;

  /// No description provided for @automationWidgetsReasonNotApplied.
  ///
  /// In en, this message translates to:
  /// **'Nothing applied'**
  String get automationWidgetsReasonNotApplied;

  /// No description provided for @automationWidgetsReasonNotAppliedDetail.
  ///
  /// In en, this message translates to:
  /// **'None of the changes could be applied — see the plan.'**
  String get automationWidgetsReasonNotAppliedDetail;

  /// No description provided for @automationWidgetsOutcomeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Outcome unknown'**
  String get automationWidgetsOutcomeUnknown;

  /// No description provided for @automationWidgetsReasonInterruptedDetail.
  ///
  /// In en, this message translates to:
  /// **'Morkva was closed while applying — it may be partly applied.'**
  String get automationWidgetsReasonInterruptedDetail;

  /// No description provided for @automationWidgetsReasonInterruptedAdvice.
  ///
  /// In en, this message translates to:
  /// **'Check the card'**
  String get automationWidgetsReasonInterruptedAdvice;

  /// No description provided for @automationWidgetsReasonInternalDetail.
  ///
  /// In en, this message translates to:
  /// **'Morkva hit an unexpected error.'**
  String get automationWidgetsReasonInternalDetail;

  /// No description provided for @automationWidgetsReasonInternalAdvice.
  ///
  /// In en, this message translates to:
  /// **'Run again; copy the log if it repeats'**
  String get automationWidgetsReasonInternalAdvice;

  /// No description provided for @automationWidgetsReasonCodeChangedDetail.
  ///
  /// In en, this message translates to:
  /// **'The module\'s code changed before you reviewed the preview.'**
  String get automationWidgetsReasonCodeChangedDetail;

  /// No description provided for @automationWidgetsReasonUninstalledDetail.
  ///
  /// In en, this message translates to:
  /// **'The module was removed before you reviewed the preview.'**
  String get automationWidgetsReasonUninstalledDetail;

  /// No description provided for @automationWidgetsReasonSupersededDetail.
  ///
  /// In en, this message translates to:
  /// **'A new run replaced this preview.'**
  String get automationWidgetsReasonSupersededDetail;

  /// No description provided for @automationWidgetsOutcomeUnknownDetail.
  ///
  /// In en, this message translates to:
  /// **'It was applying in another window — check the cards.'**
  String get automationWidgetsOutcomeUnknownDetail;

  /// No description provided for @automationWidgetsOutcomeUnknownAdvice.
  ///
  /// In en, this message translates to:
  /// **'Check the cards'**
  String get automationWidgetsOutcomeUnknownAdvice;

  /// No description provided for @automationWidgetsReviewNotHere.
  ///
  /// In en, this message translates to:
  /// **'Review not available here'**
  String get automationWidgetsReviewNotHere;

  /// No description provided for @automationWidgetsReviewNotHereDetail.
  ///
  /// In en, this message translates to:
  /// **'It was opened in another window, or before Morkva restarted.'**
  String get automationWidgetsReviewNotHereDetail;

  /// No description provided for @automationWidgetsAskedFirst.
  ///
  /// In en, this message translates to:
  /// **'Asked first: {policy}.'**
  String automationWidgetsAskedFirst(String policy);

  /// No description provided for @automationWidgetsChipInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get automationWidgetsChipInstalled;

  /// No description provided for @automationWidgetsChipBroken.
  ///
  /// In en, this message translates to:
  /// **'Broken'**
  String get automationWidgetsChipBroken;

  /// No description provided for @automationWidgetsChipLoopSuspected.
  ///
  /// In en, this message translates to:
  /// **'Loop suspected'**
  String get automationWidgetsChipLoopSuspected;

  /// No description provided for @automationWidgetsChipAskFirst.
  ///
  /// In en, this message translates to:
  /// **'Ask first'**
  String get automationWidgetsChipAskFirst;

  /// No description provided for @automationWidgetsChipAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get automationWidgetsChipAuto;

  /// No description provided for @automationWidgetsChipAutoOff.
  ///
  /// In en, this message translates to:
  /// **'Auto · off for this module'**
  String get automationWidgetsChipAutoOff;

  /// No description provided for @automationWidgetsQueuedAhead.
  ///
  /// In en, this message translates to:
  /// **'Queued · {count} ahead'**
  String automationWidgetsQueuedAhead(int count);

  /// No description provided for @automationWidgetsRunOnCard.
  ///
  /// In en, this message translates to:
  /// **'{label} on {card}'**
  String automationWidgetsRunOnCard(String label, String card);

  /// No description provided for @automationWidgetsNoticeNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'{label} needs your review'**
  String automationWidgetsNoticeNeedsReview(String label);

  /// No description provided for @automationWidgetsNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes'**
  String get automationWidgetsNoChanges;

  /// No description provided for @automationWidgetsNoticeTimedOut.
  ///
  /// In en, this message translates to:
  /// **'{label} timed out after 20 s'**
  String automationWidgetsNoticeTimedOut(String label);

  /// No description provided for @automationWidgetsNoticeStopped.
  ///
  /// In en, this message translates to:
  /// **'{label} was stopped. Nothing was changed.'**
  String automationWidgetsNoticeStopped(String label);

  /// No description provided for @automationWidgetsNoticeOffline.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t apply — you\'re offline'**
  String get automationWidgetsNoticeOffline;

  /// No description provided for @automationWidgetsNoticeOfflineOn.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t apply {label} — you\'re offline'**
  String automationWidgetsNoticeOfflineOn(String label);

  /// No description provided for @automationWidgetsNoticeFailed.
  ///
  /// In en, this message translates to:
  /// **'{label} failed'**
  String automationWidgetsNoticeFailed(String label);

  /// No description provided for @automationWidgetsNoticeFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'{label} failed — {message}'**
  String automationWidgetsNoticeFailedMessage(String label, String message);

  /// No description provided for @automationWidgetsCantRunOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Automations can\'t run on this device'**
  String get automationWidgetsCantRunOnDevice;

  /// No description provided for @automationWidgetsViewRun.
  ///
  /// In en, this message translates to:
  /// **'View run'**
  String get automationWidgetsViewRun;

  /// No description provided for @automationWidgetsReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get automationWidgetsReview;

  /// No description provided for @automationWidgetsStateSavesFirst.
  ///
  /// In en, this message translates to:
  /// **'saves first'**
  String get automationWidgetsStateSavesFirst;

  /// No description provided for @automationWidgetsStateNeedsConsent.
  ///
  /// In en, this message translates to:
  /// **'needs consent'**
  String get automationWidgetsStateNeedsConsent;

  /// No description provided for @automationWidgetsStateQueued.
  ///
  /// In en, this message translates to:
  /// **'queued'**
  String get automationWidgetsStateQueued;

  /// No description provided for @automationWidgetsStateRunning.
  ///
  /// In en, this message translates to:
  /// **'running'**
  String get automationWidgetsStateRunning;

  /// No description provided for @automationWidgetsStateWaitingForReview.
  ///
  /// In en, this message translates to:
  /// **'waiting for review'**
  String get automationWidgetsStateWaitingForReview;

  /// No description provided for @automationWidgetsStateLastRunFailed.
  ///
  /// In en, this message translates to:
  /// **'last run failed'**
  String get automationWidgetsStateLastRunFailed;

  /// No description provided for @automationWidgetsStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get automationWidgetsStop;

  /// No description provided for @automationWidgetsStopLabel.
  ///
  /// In en, this message translates to:
  /// **'Stop {label}'**
  String automationWidgetsStopLabel(String label);

  /// No description provided for @automationWidgetsSaveAndRun.
  ///
  /// In en, this message translates to:
  /// **'Save and run'**
  String get automationWidgetsSaveAndRun;

  /// No description provided for @automationWidgetsWorksOnSavedCard.
  ///
  /// In en, this message translates to:
  /// **'The action works on the saved card.'**
  String get automationWidgetsWorksOnSavedCard;

  /// No description provided for @automationWidgetsMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get automationWidgetsMoreActions;

  /// No description provided for @automationWidgetsMoreActionsState.
  ///
  /// In en, this message translates to:
  /// **'More actions, {label} {state}'**
  String automationWidgetsMoreActionsState(String label, String state);

  /// No description provided for @automationWidgetsActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get automationWidgetsActions;

  /// No description provided for @automationWidgetsActionsLive.
  ///
  /// In en, this message translates to:
  /// **'Actions, {label} {state}'**
  String automationWidgetsActionsLive(String label, String state);

  /// No description provided for @automationWidgetsNoButtons.
  ///
  /// In en, this message translates to:
  /// **'No buttons yet.'**
  String get automationWidgetsNoButtons;

  /// No description provided for @automationWidgetsNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get automationWidgetsNeedsReview;

  /// No description provided for @automationWidgetsLastRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Last run failed'**
  String get automationWidgetsLastRunFailed;

  /// No description provided for @automationWidgetsRunsOnShown.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Runs on 1 shown card} other{Runs on {count} shown cards}}'**
  String automationWidgetsRunsOnShown(int count);

  /// No description provided for @automationWidgetsRunsOnAll.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Runs on all 1 card} other{Runs on all {count} cards}}'**
  String automationWidgetsRunsOnAll(int count);

  /// No description provided for @automationWidgetsAutomationsFor.
  ///
  /// In en, this message translates to:
  /// **'Automations for {collection}…'**
  String automationWidgetsAutomationsFor(String collection);

  /// No description provided for @automationWidgetsNewAutomation.
  ///
  /// In en, this message translates to:
  /// **'New automation…'**
  String get automationWidgetsNewAutomation;

  /// No description provided for @automationWidgetsRunningLabel.
  ///
  /// In en, this message translates to:
  /// **'Running {label}'**
  String automationWidgetsRunningLabel(String label);

  /// No description provided for @automationWidgetsRunningLabelEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Running {label}…'**
  String automationWidgetsRunningLabelEllipsis(String label);

  /// No description provided for @automationWidgetsLongPressToStop.
  ///
  /// In en, this message translates to:
  /// **'Long-press to stop'**
  String get automationWidgetsLongPressToStop;

  /// No description provided for @automationWidgetsRunAction.
  ///
  /// In en, this message translates to:
  /// **'Run action…'**
  String get automationWidgetsRunAction;

  /// No description provided for @automationWidgetsAutomationsEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Automations…'**
  String get automationWidgetsAutomationsEllipsis;

  /// No description provided for @automationWidgetsPillRunning.
  ///
  /// In en, this message translates to:
  /// **'Running · {count}'**
  String automationWidgetsPillRunning(int count);

  /// No description provided for @automationWidgetsNeedReviewCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 needs review} other{{count} need review}}'**
  String automationWidgetsNeedReviewCount(int count);

  /// No description provided for @automationWidgetsPillFailed.
  ///
  /// In en, this message translates to:
  /// **'{count} failed'**
  String automationWidgetsPillFailed(int count);

  /// No description provided for @automationWidgetsPillDidntRun.
  ///
  /// In en, this message translates to:
  /// **'{count} didn\'t run'**
  String automationWidgetsPillDidntRun(int count);

  /// No description provided for @automationWidgetsSentenceRunning.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 automation running} other{{count} automations running}}'**
  String automationWidgetsSentenceRunning(int count);

  /// No description provided for @automationWidgetsSentenceAlsoNeedReview.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} need review}}'**
  String automationWidgetsSentenceAlsoNeedReview(int count);

  /// No description provided for @automationWidgetsSentenceNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 automation needs review} other{{count} automations need review}}'**
  String automationWidgetsSentenceNeedsReview(int count);

  /// No description provided for @automationWidgetsSentenceFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} failed}}'**
  String automationWidgetsSentenceFailed(int count);

  /// No description provided for @automationWidgetsSentenceDidntRun.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 automation didn\'t run} other{{count} automations didn\'t run}}'**
  String automationWidgetsSentenceDidntRun(int count);

  /// No description provided for @automationWidgetsSentenceReviewsExpired.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 review expired · View} other{{count} reviews expired · View}}'**
  String automationWidgetsSentenceReviewsExpired(int count);

  /// No description provided for @automationWidgetsAutoApplyPaused.
  ///
  /// In en, this message translates to:
  /// **'{status} · Auto-apply paused for 10 min'**
  String automationWidgetsAutoApplyPaused(String status);

  /// No description provided for @automationWidgetsDefaultName.
  ///
  /// In en, this message translates to:
  /// **'{action} on {collection}'**
  String automationWidgetsDefaultName(String action, String collection);

  /// No description provided for @automationWidgetsProblemName.
  ///
  /// In en, this message translates to:
  /// **'Give it a name'**
  String get automationWidgetsProblemName;

  /// No description provided for @automationWidgetsProblemCollection.
  ///
  /// In en, this message translates to:
  /// **'Pick a collection'**
  String get automationWidgetsProblemCollection;

  /// No description provided for @automationWidgetsProblemCollectionNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'The module isn\'t allowed in {collection}'**
  String automationWidgetsProblemCollectionNotAllowed(String collection);

  /// No description provided for @automationWidgetsProblemAction.
  ///
  /// In en, this message translates to:
  /// **'Pick an action'**
  String get automationWidgetsProblemAction;

  /// No description provided for @automationWidgetsProblemCardAction.
  ///
  /// In en, this message translates to:
  /// **'This action runs on a card — use a card button or an event'**
  String get automationWidgetsProblemCardAction;

  /// No description provided for @automationWidgetsProblemCollectionAction.
  ///
  /// In en, this message translates to:
  /// **'This action runs on a collection — use a collection button'**
  String get automationWidgetsProblemCollectionAction;

  /// No description provided for @automationWidgetsProblemFillIn.
  ///
  /// In en, this message translates to:
  /// **'Fill in {field}'**
  String automationWidgetsProblemFillIn(String field);

  /// No description provided for @automationWidgetsProblemWhere.
  ///
  /// In en, this message translates to:
  /// **'Add at least one condition or pick fields to watch'**
  String get automationWidgetsProblemWhere;

  /// No description provided for @automationWidgetsProblemAlwaysAsks.
  ///
  /// In en, this message translates to:
  /// **'This module can delete or change structure, so it always asks.'**
  String get automationWidgetsProblemAlwaysAsks;

  /// No description provided for @automationWidgetsProblemTurnOnAutoFirst.
  ///
  /// In en, this message translates to:
  /// **'Turn on auto-apply for this module first'**
  String get automationWidgetsProblemTurnOnAutoFirst;

  /// No description provided for @automationWidgetsAutoApplyOnTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply this module\'s changes automatically?'**
  String get automationWidgetsAutoApplyOnTitle;

  /// No description provided for @automationWidgetsTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get automationWidgetsTurnOn;

  /// No description provided for @automationWidgetsAutoApplyOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off auto-apply?'**
  String get automationWidgetsAutoApplyOffTitle;

  /// No description provided for @automationWidgetsAutoApplyOffBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 automation will ask first.} other{{count} automations will ask first.}}'**
  String automationWidgetsAutoApplyOffBody(int count);

  /// No description provided for @automationWidgetsTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get automationWidgetsTurnOff;

  /// No description provided for @automationWidgetsProvenance.
  ///
  /// In en, this message translates to:
  /// **'Module · {name} ({id})'**
  String automationWidgetsProvenance(String name, String id);

  /// No description provided for @collectionsTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get collectionsTypeText;

  /// No description provided for @collectionsTypeTextDescription.
  ///
  /// In en, this message translates to:
  /// **'Free text, single- or multi-line.'**
  String get collectionsTypeTextDescription;

  /// No description provided for @collectionsTypeNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get collectionsTypeNumber;

  /// No description provided for @collectionsTypeNumberDescription.
  ///
  /// In en, this message translates to:
  /// **'A numeric value, optionally bounded.'**
  String get collectionsTypeNumberDescription;

  /// No description provided for @collectionsTypeBoolean.
  ///
  /// In en, this message translates to:
  /// **'Yes / No'**
  String get collectionsTypeBoolean;

  /// No description provided for @collectionsTypeBooleanDescription.
  ///
  /// In en, this message translates to:
  /// **'A simple true/false toggle.'**
  String get collectionsTypeBooleanDescription;

  /// No description provided for @collectionsTypeDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get collectionsTypeDate;

  /// No description provided for @collectionsTypeDateDescription.
  ///
  /// In en, this message translates to:
  /// **'A calendar date, optionally with a time.'**
  String get collectionsTypeDateDescription;

  /// No description provided for @collectionsTypeSingleSelect.
  ///
  /// In en, this message translates to:
  /// **'Single select'**
  String get collectionsTypeSingleSelect;

  /// No description provided for @collectionsTypeSingleSelectDescription.
  ///
  /// In en, this message translates to:
  /// **'Pick exactly one option from a fixed set.'**
  String get collectionsTypeSingleSelectDescription;

  /// No description provided for @collectionsTypeMultiSelect.
  ///
  /// In en, this message translates to:
  /// **'Multi select'**
  String get collectionsTypeMultiSelect;

  /// No description provided for @collectionsTypeMultiSelectDescription.
  ///
  /// In en, this message translates to:
  /// **'Pick any number of options (tags).'**
  String get collectionsTypeMultiSelectDescription;

  /// No description provided for @collectionsTypeReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get collectionsTypeReference;

  /// No description provided for @collectionsTypeReferenceDescription.
  ///
  /// In en, this message translates to:
  /// **'Link to objects in another collection.'**
  String get collectionsTypeReferenceDescription;

  /// No description provided for @collectionsTypeFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get collectionsTypeFile;

  /// No description provided for @collectionsTypeFileDescription.
  ///
  /// In en, this message translates to:
  /// **'One or more file attachments.'**
  String get collectionsTypeFileDescription;

  /// No description provided for @collectionsTypeAutoNumber.
  ///
  /// In en, this message translates to:
  /// **'Auto number'**
  String get collectionsTypeAutoNumber;

  /// No description provided for @collectionsTypeAutoNumberDescription.
  ///
  /// In en, this message translates to:
  /// **'An automatically assigned sequence number.'**
  String get collectionsTypeAutoNumberDescription;

  /// No description provided for @collectionsTypeCalculated.
  ///
  /// In en, this message translates to:
  /// **'Calculated'**
  String get collectionsTypeCalculated;

  /// No description provided for @collectionsTypeCalculatedDescription.
  ///
  /// In en, this message translates to:
  /// **'A formula, a total over linked items, or a linked item\'s field.'**
  String get collectionsTypeCalculatedDescription;

  /// No description provided for @collectionsMultiline.
  ///
  /// In en, this message translates to:
  /// **'Multiline'**
  String get collectionsMultiline;

  /// No description provided for @collectionsMultilineHint.
  ///
  /// In en, this message translates to:
  /// **'Allow line breaks in the value.'**
  String get collectionsMultilineHint;

  /// No description provided for @collectionsMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Max length'**
  String get collectionsMaxLength;

  /// No description provided for @collectionsNoLimit.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get collectionsNoLimit;

  /// No description provided for @collectionsSummaryMultiline.
  ///
  /// In en, this message translates to:
  /// **'multiline'**
  String get collectionsSummaryMultiline;

  /// No description provided for @collectionsSummaryMax.
  ///
  /// In en, this message translates to:
  /// **'max {max}'**
  String collectionsSummaryMax(int max);

  /// No description provided for @collectionsDecimalPlaces.
  ///
  /// In en, this message translates to:
  /// **'Decimal places'**
  String get collectionsDecimalPlaces;

  /// No description provided for @collectionsWholeNumber.
  ///
  /// In en, this message translates to:
  /// **'Whole number'**
  String get collectionsWholeNumber;

  /// No description provided for @collectionsUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit label'**
  String get collectionsUnitLabel;

  /// No description provided for @collectionsUnitLabelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. kg, \$'**
  String get collectionsUnitLabelHint;

  /// No description provided for @collectionsMinimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum'**
  String get collectionsMinimum;

  /// No description provided for @collectionsNoMinimum.
  ///
  /// In en, this message translates to:
  /// **'No minimum'**
  String get collectionsNoMinimum;

  /// No description provided for @collectionsMaximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get collectionsMaximum;

  /// No description provided for @collectionsNoMaximum.
  ///
  /// In en, this message translates to:
  /// **'No maximum'**
  String get collectionsNoMaximum;

  /// No description provided for @collectionsSummaryDecimals.
  ///
  /// In en, this message translates to:
  /// **'{count} dp'**
  String collectionsSummaryDecimals(int count);

  /// No description provided for @collectionsIncludeTime.
  ///
  /// In en, this message translates to:
  /// **'Include time'**
  String get collectionsIncludeTime;

  /// No description provided for @collectionsIncludeTimeHint.
  ///
  /// In en, this message translates to:
  /// **'Capture a time alongside the date.'**
  String get collectionsIncludeTimeHint;

  /// No description provided for @collectionsEarliest.
  ///
  /// In en, this message translates to:
  /// **'Earliest'**
  String get collectionsEarliest;

  /// No description provided for @collectionsLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get collectionsLatest;

  /// No description provided for @collectionsAnyDate.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get collectionsAnyDate;

  /// No description provided for @collectionsSummaryDate.
  ///
  /// In en, this message translates to:
  /// **'date'**
  String get collectionsSummaryDate;

  /// No description provided for @collectionsSummaryDateTime.
  ///
  /// In en, this message translates to:
  /// **'date & time'**
  String get collectionsSummaryDateTime;

  /// No description provided for @collectionsOptionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 option} other{{count} options}}'**
  String collectionsOptionCount(int count);

  /// No description provided for @collectionsOptionDefault.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String collectionsOptionDefault(int number);

  /// No description provided for @collectionsNoOptions.
  ///
  /// In en, this message translates to:
  /// **'No options yet — add the first choice.'**
  String get collectionsNoOptions;

  /// No description provided for @collectionsAddOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get collectionsAddOption;

  /// No description provided for @collectionsDragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get collectionsDragToReorder;

  /// No description provided for @collectionsOptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Option label'**
  String get collectionsOptionLabel;

  /// No description provided for @collectionsRemoveOption.
  ///
  /// In en, this message translates to:
  /// **'Remove option'**
  String get collectionsRemoveOption;

  /// No description provided for @collectionsColorSwatch.
  ///
  /// In en, this message translates to:
  /// **'Color {hex}'**
  String collectionsColorSwatch(String hex);

  /// No description provided for @collectionsNoColor.
  ///
  /// In en, this message translates to:
  /// **'No color'**
  String get collectionsNoColor;

  /// No description provided for @collectionsBooleanNoSettings.
  ///
  /// In en, this message translates to:
  /// **'A yes/no field has no extra settings.'**
  String get collectionsBooleanNoSettings;

  /// No description provided for @collectionsTargetCollection.
  ///
  /// In en, this message translates to:
  /// **'Target collection'**
  String get collectionsTargetCollection;

  /// No description provided for @collectionsChooseCollection.
  ///
  /// In en, this message translates to:
  /// **'Choose a collection'**
  String get collectionsChooseCollection;

  /// No description provided for @collectionsThisCollection.
  ///
  /// In en, this message translates to:
  /// **'{name} (this collection)'**
  String collectionsThisCollection(String name);

  /// No description provided for @collectionsPickTargetWarning.
  ///
  /// In en, this message translates to:
  /// **'Pick a target collection — this reference points nowhere until you do.'**
  String get collectionsPickTargetWarning;

  /// No description provided for @collectionsAllowMultiple.
  ///
  /// In en, this message translates to:
  /// **'Allow multiple'**
  String get collectionsAllowMultiple;

  /// No description provided for @collectionsReferenceMultipleHint.
  ///
  /// In en, this message translates to:
  /// **'Reference more than one object.'**
  String get collectionsReferenceMultipleHint;

  /// No description provided for @collectionsSummaryNoTarget.
  ///
  /// In en, this message translates to:
  /// **'(no target)'**
  String get collectionsSummaryNoTarget;

  /// No description provided for @collectionsSummaryUnknownTarget.
  ///
  /// In en, this message translates to:
  /// **'(unknown)'**
  String get collectionsSummaryUnknownTarget;

  /// No description provided for @collectionsSummaryReferenceMany.
  ///
  /// In en, this message translates to:
  /// **'→ {name} (many)'**
  String collectionsSummaryReferenceMany(String name);

  /// No description provided for @collectionsFileMultipleHint.
  ///
  /// In en, this message translates to:
  /// **'Attach more than one file.'**
  String get collectionsFileMultipleHint;

  /// No description provided for @collectionsAllowedExtensions.
  ///
  /// In en, this message translates to:
  /// **'Allowed extensions'**
  String get collectionsAllowedExtensions;

  /// No description provided for @collectionsAllowedExtensionsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. png, jpg, pdf — comma separated, blank for any'**
  String get collectionsAllowedExtensionsHint;

  /// No description provided for @collectionsSummaryMultiple.
  ///
  /// In en, this message translates to:
  /// **'multiple'**
  String get collectionsSummaryMultiple;

  /// No description provided for @collectionsNoFile.
  ///
  /// In en, this message translates to:
  /// **'No file'**
  String get collectionsNoFile;

  /// No description provided for @collectionsStartAt.
  ///
  /// In en, this message translates to:
  /// **'Start at'**
  String get collectionsStartAt;

  /// No description provided for @collectionsPrefix.
  ///
  /// In en, this message translates to:
  /// **'Prefix'**
  String get collectionsPrefix;

  /// No description provided for @collectionsPrefixHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. ORD-'**
  String get collectionsPrefixHint;

  /// No description provided for @collectionsDigits.
  ///
  /// In en, this message translates to:
  /// **'Digits'**
  String get collectionsDigits;

  /// No description provided for @collectionsDigitsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 4 → 0042'**
  String get collectionsDigitsHint;

  /// No description provided for @collectionsFirstNumber.
  ///
  /// In en, this message translates to:
  /// **'First number'**
  String get collectionsFirstNumber;

  /// No description provided for @collectionsAutoNumberNote.
  ///
  /// In en, this message translates to:
  /// **'New items get the next number when they are saved. Items that already exist stay unnumbered.'**
  String get collectionsAutoNumberNote;

  /// No description provided for @collectionsSummaryDigits.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 digit} other{{count} digits}}'**
  String collectionsSummaryDigits(int count);

  /// No description provided for @collectionsSummaryFrom.
  ///
  /// In en, this message translates to:
  /// **'from {start}'**
  String collectionsSummaryFrom(int start);

  /// No description provided for @collectionsSummaryAuto.
  ///
  /// In en, this message translates to:
  /// **'auto'**
  String get collectionsSummaryAuto;

  /// No description provided for @collectionsSummaryFormula.
  ///
  /// In en, this message translates to:
  /// **'Formula → {type}'**
  String collectionsSummaryFormula(String type);

  /// No description provided for @collectionsModeFormula.
  ///
  /// In en, this message translates to:
  /// **'Formula'**
  String get collectionsModeFormula;

  /// No description provided for @collectionsModeAggregate.
  ///
  /// In en, this message translates to:
  /// **'Aggregate'**
  String get collectionsModeAggregate;

  /// No description provided for @collectionsModeLookup.
  ///
  /// In en, this message translates to:
  /// **'Lookup'**
  String get collectionsModeLookup;

  /// No description provided for @collectionsModeFormulaHint.
  ///
  /// In en, this message translates to:
  /// **'Computes from this item\'s own fields.'**
  String get collectionsModeFormulaHint;

  /// No description provided for @collectionsModeAggregateHint.
  ///
  /// In en, this message translates to:
  /// **'Totals values from other items, like SUMIF in a spreadsheet.'**
  String get collectionsModeAggregateHint;

  /// No description provided for @collectionsModeLookupHint.
  ///
  /// In en, this message translates to:
  /// **'Shows a field of the linked item, like VLOOKUP.'**
  String get collectionsModeLookupHint;

  /// No description provided for @collectionsDecimals.
  ///
  /// In en, this message translates to:
  /// **'Decimals'**
  String get collectionsDecimals;

  /// No description provided for @collectionsDecimalsAuto.
  ///
  /// In en, this message translates to:
  /// **'auto'**
  String get collectionsDecimalsAuto;

  /// No description provided for @collectionsUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get collectionsUnit;

  /// No description provided for @collectionsUnitHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. ₴, kg'**
  String get collectionsUnitHint;

  /// No description provided for @collectionsFormulaCircular.
  ///
  /// In en, this message translates to:
  /// **'Circular: {chain}'**
  String collectionsFormulaCircular(String chain);

  /// No description provided for @collectionsFormulaExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. {open}Price{close} * {open}Quantity{close}'**
  String collectionsFormulaExample(String open, String close);

  /// No description provided for @collectionsFormulaResult.
  ///
  /// In en, this message translates to:
  /// **'Result: {type}'**
  String collectionsFormulaResult(String type);

  /// No description provided for @collectionsInsertField.
  ///
  /// In en, this message translates to:
  /// **'Insert field'**
  String get collectionsInsertField;

  /// No description provided for @collectionsFunctions.
  ///
  /// In en, this message translates to:
  /// **'Functions'**
  String get collectionsFunctions;

  /// No description provided for @collectionsJoinChip.
  ///
  /// In en, this message translates to:
  /// **'& join'**
  String get collectionsJoinChip;

  /// No description provided for @collectionsJoinTooltip.
  ///
  /// In en, this message translates to:
  /// **'Joins text: {open}First{close} & \" \" & {open}Last{close}'**
  String collectionsJoinTooltip(String open, String close);

  /// No description provided for @collectionsAllFunctions.
  ///
  /// In en, this message translates to:
  /// **'All functions'**
  String get collectionsAllFunctions;

  /// No description provided for @collectionsAllFunctionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Every function with how to use it'**
  String get collectionsAllFunctionsTooltip;

  /// No description provided for @collectionsSummarize.
  ///
  /// In en, this message translates to:
  /// **'Summarize'**
  String get collectionsSummarize;

  /// No description provided for @collectionsPickSource.
  ///
  /// In en, this message translates to:
  /// **'Pick what to summarize'**
  String get collectionsPickSource;

  /// No description provided for @collectionsNoSources.
  ///
  /// In en, this message translates to:
  /// **'Add a Reference field to link items, or summarize a whole collection.'**
  String get collectionsNoSources;

  /// No description provided for @collectionsCalculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate'**
  String get collectionsCalculate;

  /// No description provided for @collectionsAggregateOf.
  ///
  /// In en, this message translates to:
  /// **'Of'**
  String get collectionsAggregateOf;

  /// No description provided for @collectionsPickSourceFirst.
  ///
  /// In en, this message translates to:
  /// **'Pick what to summarize first.'**
  String get collectionsPickSourceFirst;

  /// No description provided for @collectionsNoNumberFields.
  ///
  /// In en, this message translates to:
  /// **'{name} has no number fields.'**
  String collectionsNoNumberFields(String name);

  /// No description provided for @collectionsNoNumberOrDateFields.
  ///
  /// In en, this message translates to:
  /// **'{name} has no number or date fields.'**
  String collectionsNoNumberOrDateFields(String name);

  /// No description provided for @collectionsOnlyWhere.
  ///
  /// In en, this message translates to:
  /// **'Only where'**
  String get collectionsOnlyWhere;

  /// No description provided for @collectionsAddCondition.
  ///
  /// In en, this message translates to:
  /// **'Add condition'**
  String get collectionsAddCondition;

  /// No description provided for @collectionsEditCondition.
  ///
  /// In en, this message translates to:
  /// **'Edit condition'**
  String get collectionsEditCondition;

  /// No description provided for @collectionsRemoveCondition.
  ///
  /// In en, this message translates to:
  /// **'Remove condition'**
  String get collectionsRemoveCondition;

  /// No description provided for @collectionsAndCondition.
  ///
  /// In en, this message translates to:
  /// **'And…'**
  String get collectionsAndCondition;

  /// No description provided for @collectionsSourceLinkingToThis.
  ///
  /// In en, this message translates to:
  /// **'{name} linking to this one'**
  String collectionsSourceLinkingToThis(String name);

  /// No description provided for @collectionsSourceLinkingHere.
  ///
  /// In en, this message translates to:
  /// **'{name} linking here'**
  String collectionsSourceLinkingHere(String name);

  /// No description provided for @collectionsSourceVia.
  ///
  /// In en, this message translates to:
  /// **'via {field}'**
  String collectionsSourceVia(String field);

  /// No description provided for @collectionsSourceLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked {name}'**
  String collectionsSourceLinked(String name);

  /// No description provided for @collectionsSourceIn.
  ///
  /// In en, this message translates to:
  /// **'in {field}'**
  String collectionsSourceIn(String field);

  /// No description provided for @collectionsSourceAll.
  ///
  /// In en, this message translates to:
  /// **'All {name}'**
  String collectionsSourceAll(String name);

  /// No description provided for @collectionsSourceEveryItem.
  ///
  /// In en, this message translates to:
  /// **'every item'**
  String get collectionsSourceEveryItem;

  /// No description provided for @collectionsThrough.
  ///
  /// In en, this message translates to:
  /// **'Through'**
  String get collectionsThrough;

  /// No description provided for @collectionsNoLookupReferences.
  ///
  /// In en, this message translates to:
  /// **'Add a Reference field (one linked item) to look up its fields.'**
  String get collectionsNoLookupReferences;

  /// No description provided for @collectionsPickReference.
  ///
  /// In en, this message translates to:
  /// **'Pick a reference'**
  String get collectionsPickReference;

  /// No description provided for @collectionsLinksTo.
  ///
  /// In en, this message translates to:
  /// **'links to {name}'**
  String collectionsLinksTo(String name);

  /// No description provided for @collectionsShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get collectionsShow;

  /// No description provided for @collectionsNoFieldsToShow.
  ///
  /// In en, this message translates to:
  /// **'{name} has no fields to show.'**
  String collectionsNoFieldsToShow(String name);

  /// No description provided for @collectionsThatCollectionNoFields.
  ///
  /// In en, this message translates to:
  /// **'That collection has no fields to show.'**
  String get collectionsThatCollectionNoFields;

  /// No description provided for @collectionsPickField.
  ///
  /// In en, this message translates to:
  /// **'Pick a field'**
  String get collectionsPickField;

  /// No description provided for @collectionsLookupKeepsType.
  ///
  /// In en, this message translates to:
  /// **'Keeps its type: a select stays a select, so filters and totals can use its options.'**
  String get collectionsLookupKeepsType;

  /// No description provided for @collectionsInWords.
  ///
  /// In en, this message translates to:
  /// **'IN WORDS'**
  String get collectionsInWords;

  /// No description provided for @collectionsAddFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a field'**
  String get collectionsAddFieldTitle;

  /// No description provided for @collectionsAddFieldSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a type — you can configure and rename it next.'**
  String get collectionsAddFieldSubtitle;

  /// No description provided for @collectionsAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get collectionsAutomatic;

  /// No description provided for @collectionsAddFieldOfType.
  ///
  /// In en, this message translates to:
  /// **'Add {type} field'**
  String collectionsAddFieldOfType(String type);

  /// No description provided for @collectionsRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get collectionsRequired;

  /// No description provided for @collectionsRequiredHint.
  ///
  /// In en, this message translates to:
  /// **'A value must be set before an object is valid.'**
  String get collectionsRequiredHint;

  /// No description provided for @collectionsOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get collectionsOptions;

  /// No description provided for @collectionsFieldName.
  ///
  /// In en, this message translates to:
  /// **'Field name'**
  String get collectionsFieldName;

  /// No description provided for @collectionsFieldNameHint.
  ///
  /// In en, this message translates to:
  /// **'Title, Status, Due date…'**
  String get collectionsFieldNameHint;

  /// No description provided for @collectionsHelpText.
  ///
  /// In en, this message translates to:
  /// **'Help text'**
  String get collectionsHelpText;

  /// No description provided for @collectionsHelpTextHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — guidance shown with this field'**
  String get collectionsHelpTextHint;

  /// No description provided for @collectionsTypeLocked.
  ///
  /// In en, this message translates to:
  /// **'Type is locked after the first save. To change it, remove this field and add a new one.'**
  String get collectionsTypeLocked;

  /// No description provided for @collectionsGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get collectionsGroup;

  /// No description provided for @collectionsGroupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get collectionsGroupName;

  /// No description provided for @collectionsGroupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for an ungrouped section'**
  String get collectionsGroupNameHint;

  /// No description provided for @collectionsCollapsedByDefault.
  ///
  /// In en, this message translates to:
  /// **'Collapsed by default'**
  String get collectionsCollapsedByDefault;

  /// No description provided for @collectionsCollapsedByDefaultHint.
  ///
  /// In en, this message translates to:
  /// **'The group starts collapsed when a card is opened.'**
  String get collectionsCollapsedByDefaultHint;

  /// No description provided for @collectionsDeleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get collectionsDeleteGroup;

  /// No description provided for @collectionsDeleteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete group?'**
  String get collectionsDeleteGroupTitle;

  /// No description provided for @collectionsDeleteGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'The group is removed from the layout. Its fields are not deleted and will be moved to the default section.'**
  String get collectionsDeleteGroupMessage;

  /// No description provided for @collectionsUntitledCollection.
  ///
  /// In en, this message translates to:
  /// **'Untitled collection'**
  String get collectionsUntitledCollection;

  /// No description provided for @collectionsNewGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get collectionsNewGroup;

  /// No description provided for @collectionsAddGroup.
  ///
  /// In en, this message translates to:
  /// **'Add group'**
  String get collectionsAddGroup;

  /// No description provided for @collectionsDropFieldHere.
  ///
  /// In en, this message translates to:
  /// **'Drop a field here'**
  String get collectionsDropFieldHere;

  /// No description provided for @collectionsAddField.
  ///
  /// In en, this message translates to:
  /// **'Add field'**
  String get collectionsAddField;

  /// No description provided for @collectionsUntitledSection.
  ///
  /// In en, this message translates to:
  /// **'Untitled section'**
  String get collectionsUntitledSection;

  /// No description provided for @collectionsUntitledField.
  ///
  /// In en, this message translates to:
  /// **'Untitled field'**
  String get collectionsUntitledField;

  /// No description provided for @collectionsFields.
  ///
  /// In en, this message translates to:
  /// **'Fields'**
  String get collectionsFields;

  /// No description provided for @collectionsFirstRunQuestion.
  ///
  /// In en, this message translates to:
  /// **'What do you track for each {item}?'**
  String collectionsFirstRunQuestion(String item);

  /// No description provided for @collectionsFirstRunHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to add — you can rename or tweak any field afterwards.'**
  String get collectionsFirstRunHint;

  /// No description provided for @collectionsCustomField.
  ///
  /// In en, this message translates to:
  /// **'Custom field'**
  String get collectionsCustomField;

  /// No description provided for @collectionsSuggestStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get collectionsSuggestStatus;

  /// No description provided for @collectionsSuggestStatusHint.
  ///
  /// In en, this message translates to:
  /// **'choice'**
  String get collectionsSuggestStatusHint;

  /// No description provided for @collectionsSuggestToDo.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get collectionsSuggestToDo;

  /// No description provided for @collectionsSuggestInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get collectionsSuggestInProgress;

  /// No description provided for @collectionsSuggestDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get collectionsSuggestDone;

  /// No description provided for @collectionsSuggestDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get collectionsSuggestDueDate;

  /// No description provided for @collectionsSuggestDueDateHint.
  ///
  /// In en, this message translates to:
  /// **'date'**
  String get collectionsSuggestDueDateHint;

  /// No description provided for @collectionsSuggestAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get collectionsSuggestAmount;

  /// No description provided for @collectionsSuggestAmountHint.
  ///
  /// In en, this message translates to:
  /// **'number'**
  String get collectionsSuggestAmountHint;

  /// No description provided for @collectionsSuggestCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get collectionsSuggestCustomer;

  /// No description provided for @collectionsSuggestCustomerHint.
  ///
  /// In en, this message translates to:
  /// **'reference'**
  String get collectionsSuggestCustomerHint;

  /// No description provided for @collectionsSuggestNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get collectionsSuggestNotes;

  /// No description provided for @collectionsSuggestNotesHint.
  ///
  /// In en, this message translates to:
  /// **'text'**
  String get collectionsSuggestNotesHint;

  /// No description provided for @collectionsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String collectionsSaveFailed(String error);

  /// No description provided for @collectionsNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Collection not found'**
  String get collectionsNotFoundTitle;

  /// No description provided for @collectionsNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This collection may have been deleted, or the link is wrong. Head back home to pick another.'**
  String get collectionsNotFoundMessage;

  /// No description provided for @collectionsBackToCollections.
  ///
  /// In en, this message translates to:
  /// **'Back to collections'**
  String get collectionsBackToCollections;

  /// No description provided for @collectionsDescriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Collection description'**
  String get collectionsDescriptionTitle;

  /// No description provided for @collectionsDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'What this collection holds'**
  String get collectionsDescriptionHint;

  /// No description provided for @collectionsChooseIcon.
  ///
  /// In en, this message translates to:
  /// **'Choose icon'**
  String get collectionsChooseIcon;

  /// No description provided for @collectionsCustomizing.
  ///
  /// In en, this message translates to:
  /// **'Customizing'**
  String get collectionsCustomizing;

  /// No description provided for @collectionsNameHint.
  ///
  /// In en, this message translates to:
  /// **'Collection name'**
  String get collectionsNameHint;

  /// No description provided for @collectionsAddDescription.
  ///
  /// In en, this message translates to:
  /// **'Add a description'**
  String get collectionsAddDescription;

  /// No description provided for @collectionsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get collectionsSaved;

  /// No description provided for @collectionsSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get collectionsSaving;

  /// No description provided for @collectionsUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get collectionsUnsavedChanges;

  /// No description provided for @collectionsObjectForm.
  ///
  /// In en, this message translates to:
  /// **'Object form'**
  String get collectionsObjectForm;

  /// No description provided for @collectionsObjectFormHint.
  ///
  /// In en, this message translates to:
  /// **'How a card looks when opened'**
  String get collectionsObjectFormHint;

  /// No description provided for @collectionsConfigureField.
  ///
  /// In en, this message translates to:
  /// **'Configure field'**
  String get collectionsConfigureField;

  /// No description provided for @collectionsSelectToEdit.
  ///
  /// In en, this message translates to:
  /// **'Select a field or group to edit it.'**
  String get collectionsSelectToEdit;

  /// No description provided for @collectionsLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save your changes?'**
  String get collectionsLeaveTitle;

  /// No description provided for @collectionsLeaveMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes to this collection. Save them before leaving, or discard them.'**
  String get collectionsLeaveMessage;

  /// No description provided for @collectionsDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get collectionsDiscard;

  /// No description provided for @collectionsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your collections…'**
  String get collectionsLoading;

  /// No description provided for @collectionsTitleFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get collectionsTitleFieldName;

  /// No description provided for @collectionsTemplateAdded.
  ///
  /// In en, this message translates to:
  /// **'Added {name}'**
  String collectionsTemplateAdded(String name);

  /// No description provided for @collectionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 collection} other{{count} collections}}'**
  String collectionsCount(int count);

  /// No description provided for @collectionsCountWithPinnedShort.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 collection} other{{count} collections}} · {pinned} pinned'**
  String collectionsCountWithPinnedShort(int count, int pinned);

  /// No description provided for @collectionsCountWithPinned.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 collection} other{{count} collections}} · {pinned} pinned to the sidebar'**
  String collectionsCountWithPinned(int count, int pinned);

  /// No description provided for @collectionsFromTemplate.
  ///
  /// In en, this message translates to:
  /// **'From template'**
  String get collectionsFromTemplate;

  /// No description provided for @collectionsNewCollection.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get collectionsNewCollection;

  /// No description provided for @collectionsHeaderAll.
  ///
  /// In en, this message translates to:
  /// **'COLLECTIONS'**
  String get collectionsHeaderAll;

  /// No description provided for @collectionsHeaderOthers.
  ///
  /// In en, this message translates to:
  /// **'EVERYTHING ELSE'**
  String get collectionsHeaderOthers;

  /// No description provided for @collectionsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete collection?'**
  String get collectionsDeleteTitle;

  /// No description provided for @collectionsDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes \"{name}\" and its schema. Objects in it are no longer reachable. This cannot be undone.'**
  String collectionsDeleteMessage(String name);

  /// No description provided for @collectionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No collections yet'**
  String get collectionsEmptyTitle;

  /// No description provided for @collectionsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Collections hold your cards — orders, clients, inventory, anything. Create your first one to start organizing your work.'**
  String get collectionsEmptyMessage;

  /// No description provided for @collectionsStartFromTemplate.
  ///
  /// In en, this message translates to:
  /// **'Start from a template'**
  String get collectionsStartFromTemplate;

  /// No description provided for @collectionsLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load collections'**
  String get collectionsLoadErrorTitle;

  /// No description provided for @collectionsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load collections: {error}'**
  String collectionsLoadFailed(String error);

  /// No description provided for @collectionsRenameCollection.
  ///
  /// In en, this message translates to:
  /// **'Rename collection'**
  String get collectionsRenameCollection;

  /// No description provided for @collectionsNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Give your collection a name'**
  String get collectionsNameRequired;

  /// No description provided for @collectionsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get collectionsNameLabel;

  /// No description provided for @collectionsNameExamples.
  ///
  /// In en, this message translates to:
  /// **'Orders, Clients, Inventory…'**
  String get collectionsNameExamples;

  /// No description provided for @collectionsDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get collectionsDescriptionLabel;

  /// No description provided for @collectionsDescriptionOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — what this collection holds'**
  String get collectionsDescriptionOptionalHint;

  /// No description provided for @collectionsOpenCollection.
  ///
  /// In en, this message translates to:
  /// **'Open {name}'**
  String collectionsOpenCollection(String name);

  /// No description provided for @collectionsPinToSidebar.
  ///
  /// In en, this message translates to:
  /// **'Pin to sidebar'**
  String get collectionsPinToSidebar;

  /// No description provided for @collectionsUnpinFromSidebar.
  ///
  /// In en, this message translates to:
  /// **'Unpin from sidebar'**
  String get collectionsUnpinFromSidebar;

  /// No description provided for @collectionsNoFieldsYet.
  ///
  /// In en, this message translates to:
  /// **'No fields yet'**
  String get collectionsNoFieldsYet;

  /// No description provided for @collectionsMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get collectionsMoreActions;

  /// No description provided for @collectionsCustomize.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get collectionsCustomize;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Morkva CRM'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// No description provided for @commonDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get commonDuplicate;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get commonGotIt;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get commonOpen;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get commonCopied;

  /// No description provided for @commonMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get commonMore;

  /// No description provided for @commonMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get commonMoreOptions;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get commonUntitled;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonSomethingWentWrong;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get commonYesterday;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonCollections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get commonCollections;

  /// No description provided for @commonAutomations.
  ///
  /// In en, this message translates to:
  /// **'Automations'**
  String get commonAutomations;

  /// No description provided for @commonCardCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card} other{{count} cards}}'**
  String commonCardCount(int count);

  /// No description provided for @commonFieldCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 field} other{{count} fields}}'**
  String commonFieldCount(int count);

  /// No description provided for @coreYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get coreYes;

  /// No description provided for @coreNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get coreNo;

  /// No description provided for @coreLinkedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} linked'**
  String coreLinkedCount(int count);

  /// No description provided for @coreNoValueGroup.
  ///
  /// In en, this message translates to:
  /// **'No {field}'**
  String coreNoValueGroup(String field);

  /// No description provided for @coreWeekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {day}'**
  String coreWeekOf(String day);

  /// No description provided for @coreDefaultViewName.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get coreDefaultViewName;

  /// No description provided for @coreFormulaTypeNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get coreFormulaTypeNumber;

  /// No description provided for @coreFormulaTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get coreFormulaTypeText;

  /// No description provided for @coreFormulaTypeBoolean.
  ///
  /// In en, this message translates to:
  /// **'Yes / No'**
  String get coreFormulaTypeBoolean;

  /// No description provided for @coreFormulaTypeDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get coreFormulaTypeDate;

  /// No description provided for @coreAggregateOpCount.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get coreAggregateOpCount;

  /// No description provided for @coreAggregateOpSum.
  ///
  /// In en, this message translates to:
  /// **'Sum'**
  String get coreAggregateOpSum;

  /// No description provided for @coreAggregateOpAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get coreAggregateOpAverage;

  /// No description provided for @coreAggregateOpMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get coreAggregateOpMin;

  /// No description provided for @coreAggregateOpMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get coreAggregateOpMax;

  /// No description provided for @formulaFunctionUsage.
  ///
  /// In en, this message translates to:
  /// **'{name, select, IF{IF(condition, then, else)} AND{AND(a, b, …)} OR{OR(a, b, …)} NOT{NOT(condition)} ROUND{ROUND(number, digits)} FLOOR{FLOOR(number)} CEIL{CEIL(number)} ABS{ABS(number)} MIN{MIN(a, b, …)} MAX{MAX(a, b, …)} CONCAT{CONCAT(a, b, …)} LEN{LEN(text)} UPPER{UPPER(text)} LOWER{LOWER(text)} TODAY{TODAY()} YEAR{YEAR(date)} MONTH{MONTH(date)} DAY{DAY(date)} ISBLANK{ISBLANK(value)} other{{name}}}'**
  String formulaFunctionUsage(String name);

  /// No description provided for @formulaFunctionSummary.
  ///
  /// In en, this message translates to:
  /// **'{name, select, IF{Picks a value by a Yes / No condition.} AND{Yes when every condition is Yes.} OR{Yes when any condition is Yes.} NOT{Flips Yes and No.} ROUND{Rounds to the given decimal digits (0 by default).} FLOOR{Rounds down to a whole number.} CEIL{Rounds up to a whole number.} ABS{The number without its sign.} MIN{The smallest number.} MAX{The largest number.} CONCAT{Joins values into one text.} LEN{How many characters the text has.} UPPER{The text in capitals.} LOWER{The text in lower case.} TODAY{Today\'s date.} YEAR{The year of a date.} MONTH{The month of a date (1–12).} DAY{The day of the month of a date.} ISBLANK{Yes when the value is empty.} other{}}'**
  String formulaFunctionSummary(String name);

  /// No description provided for @formulaErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a formula'**
  String get formulaErrorEmpty;

  /// No description provided for @formulaErrorNotANumber.
  ///
  /// In en, this message translates to:
  /// **'\"{text}\" is not a number'**
  String formulaErrorNotANumber(String text);

  /// No description provided for @formulaErrorUnclosedText.
  ///
  /// In en, this message translates to:
  /// **'Close the text with \"'**
  String get formulaErrorUnclosedText;

  /// No description provided for @formulaErrorUnclosedField.
  ///
  /// In en, this message translates to:
  /// **'Close the field with {brace}'**
  String formulaErrorUnclosedField(String brace);

  /// No description provided for @formulaErrorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Unexpected \"{text}\"'**
  String formulaErrorUnexpected(String text);

  /// No description provided for @formulaErrorNoSuchField.
  ///
  /// In en, this message translates to:
  /// **'No field named \"{name}\"'**
  String formulaErrorNoSuchField(String name);

  /// No description provided for @formulaErrorOwnField.
  ///
  /// In en, this message translates to:
  /// **'A formula can\'t use its own field'**
  String get formulaErrorOwnField;

  /// No description provided for @formulaErrorFieldNotUsable.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" can\'t be used in a formula — use an Aggregate field to summarize linked items'**
  String formulaErrorFieldNotUsable(String name);

  /// No description provided for @formulaErrorFieldWithoutBraces.
  ///
  /// In en, this message translates to:
  /// **'Put field names in braces: {token}'**
  String formulaErrorFieldWithoutBraces(String token);

  /// No description provided for @formulaErrorUnknownFunction.
  ///
  /// In en, this message translates to:
  /// **'Unknown function \"{name}\"'**
  String formulaErrorUnknownFunction(String name);

  /// No description provided for @formulaErrorWrongArguments.
  ///
  /// In en, this message translates to:
  /// **'Use {usage}'**
  String formulaErrorWrongArguments(String usage);

  /// No description provided for @formulaErrorUnclosedCall.
  ///
  /// In en, this message translates to:
  /// **'Close {name}( with )'**
  String formulaErrorUnclosedCall(String name);

  /// No description provided for @formulaErrorExpectsNumbers.
  ///
  /// In en, this message translates to:
  /// **'{name} expects numbers'**
  String formulaErrorExpectsNumbers(String name);

  /// No description provided for @formulaErrorExpectsBooleans.
  ///
  /// In en, this message translates to:
  /// **'{name} expects Yes / No values'**
  String formulaErrorExpectsBooleans(String name);

  /// No description provided for @formulaErrorExpectsText.
  ///
  /// In en, this message translates to:
  /// **'{name} expects text'**
  String formulaErrorExpectsText(String name);

  /// No description provided for @formulaErrorExpectsDate.
  ///
  /// In en, this message translates to:
  /// **'{name} expects a date'**
  String formulaErrorExpectsDate(String name);

  /// No description provided for @formulaErrorNeedsCondition.
  ///
  /// In en, this message translates to:
  /// **'{name} needs a Yes / No condition'**
  String formulaErrorNeedsCondition(String name);

  /// No description provided for @formulaErrorBranchTypesDiffer.
  ///
  /// In en, this message translates to:
  /// **'{name} needs \"then\" and \"else\" of the same type ({left} vs {right})'**
  String formulaErrorBranchTypesDiffer(String name, String left, String right);

  /// No description provided for @formulaErrorUnclosedBracket.
  ///
  /// In en, this message translates to:
  /// **'Close the bracket with )'**
  String get formulaErrorUnclosedBracket;

  /// No description provided for @formulaErrorEndsEarly.
  ///
  /// In en, this message translates to:
  /// **'The formula ends too early'**
  String get formulaErrorEndsEarly;

  /// No description provided for @formulaErrorNegateNeedsNumber.
  ///
  /// In en, this message translates to:
  /// **'\"-\" needs a number'**
  String get formulaErrorNegateNeedsNumber;

  /// No description provided for @formulaErrorJoinWithAmpersand.
  ///
  /// In en, this message translates to:
  /// **'Use & to join text'**
  String get formulaErrorJoinWithAmpersand;

  /// No description provided for @formulaErrorCannotCombine.
  ///
  /// In en, this message translates to:
  /// **'\"{op}\" can\'t combine {left} and {right}'**
  String formulaErrorCannotCombine(String op, String left, String right);

  /// No description provided for @capabilitySchemaReadTitle.
  ///
  /// In en, this message translates to:
  /// **'See your collections and fields'**
  String get capabilitySchemaReadTitle;

  /// No description provided for @capabilitySchemaReadExplanation.
  ///
  /// In en, this message translates to:
  /// **'Reads collection and field names and types.'**
  String get capabilitySchemaReadExplanation;

  /// No description provided for @capabilityDataReadTitle.
  ///
  /// In en, this message translates to:
  /// **'Read cards'**
  String get capabilityDataReadTitle;

  /// No description provided for @capabilityDataReadExplanation.
  ///
  /// In en, this message translates to:
  /// **'Reads card values in the allowed collections.'**
  String get capabilityDataReadExplanation;

  /// No description provided for @capabilityDataWriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Create and change cards'**
  String get capabilityDataWriteTitle;

  /// No description provided for @capabilityDataWriteExplanation.
  ///
  /// In en, this message translates to:
  /// **'Proposes new cards and edits.'**
  String get capabilityDataWriteExplanation;

  /// No description provided for @capabilityDataDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete cards'**
  String get capabilityDataDeleteTitle;

  /// No description provided for @capabilityDataDeleteExplanation.
  ///
  /// In en, this message translates to:
  /// **'Proposes deleting cards. Never applied automatically.'**
  String get capabilityDataDeleteExplanation;

  /// No description provided for @capabilitySchemaWriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Change collections and fields'**
  String get capabilitySchemaWriteTitle;

  /// No description provided for @capabilitySchemaWriteExplanation.
  ///
  /// In en, this message translates to:
  /// **'Proposes new fields or field changes. Never applied automatically.'**
  String get capabilitySchemaWriteExplanation;

  /// No description provided for @capabilitySchemaDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete fields and collections'**
  String get capabilitySchemaDeleteTitle;

  /// No description provided for @capabilitySchemaDeleteExplanation.
  ///
  /// In en, this message translates to:
  /// **'Proposes deleting fields or collections. Never applied automatically.'**
  String get capabilitySchemaDeleteExplanation;

  /// No description provided for @capabilityViewsWriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Change views'**
  String get capabilityViewsWriteTitle;

  /// No description provided for @capabilityViewsWriteExplanation.
  ///
  /// In en, this message translates to:
  /// **'Proposes view changes — filters, sort, columns. Never applied automatically.'**
  String get capabilityViewsWriteExplanation;

  /// No description provided for @capabilityUiNavigateTitle.
  ///
  /// In en, this message translates to:
  /// **'Link to cards'**
  String get capabilityUiNavigateTitle;

  /// No description provided for @capabilityUiNavigateExplanation.
  ///
  /// In en, this message translates to:
  /// **'Shows links that open a card or view when you tap them.'**
  String get capabilityUiNavigateExplanation;

  /// No description provided for @coreSchemaCollectionNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Collection name is required'**
  String get coreSchemaCollectionNameRequired;

  /// No description provided for @coreSchemaFieldNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Field name is required'**
  String get coreSchemaFieldNameRequired;

  /// No description provided for @coreSchemaDuplicateFieldName.
  ///
  /// In en, this message translates to:
  /// **'Duplicate field name \"{name}\"'**
  String coreSchemaDuplicateFieldName(String name);

  /// No description provided for @coreSchemaTypeLocked.
  ///
  /// In en, this message translates to:
  /// **'The type of \"{name}\" is locked after save; add a new field instead'**
  String coreSchemaTypeLocked(String name);

  /// No description provided for @templatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Start from a template'**
  String get templatesTitle;

  /// No description provided for @templatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ready-made collections you can change like any other.'**
  String get templatesSubtitle;

  /// No description provided for @templatesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the templates.'**
  String get templatesLoadFailed;

  /// No description provided for @templatesSampleHint.
  ///
  /// In en, this message translates to:
  /// **'Sample cards come along so you can see it working — delete them anytime.'**
  String get templatesSampleHint;

  /// No description provided for @templatesContents.
  ///
  /// In en, this message translates to:
  /// **'{collections, plural, =1{1 collection} other{{collections} collections}} · {cards, plural, =1{1 sample card} other{{cards} sample cards}}'**
  String templatesContents(int collections, int cards);

  /// No description provided for @templatesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to workspace'**
  String get templatesAdd;

  /// No description provided for @templatesAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add {name}. Check your connection.'**
  String templatesAddFailed(String name);

  /// No description provided for @coreTrelloBoard.
  ///
  /// In en, this message translates to:
  /// **'Trello board'**
  String get coreTrelloBoard;

  /// No description provided for @coreTrelloUntitledCard.
  ///
  /// In en, this message translates to:
  /// **'Untitled card'**
  String get coreTrelloUntitledCard;

  /// No description provided for @coreTrelloUntitledList.
  ///
  /// In en, this message translates to:
  /// **'Untitled list'**
  String get coreTrelloUntitledList;

  /// No description provided for @coreTrelloUntitledField.
  ///
  /// In en, this message translates to:
  /// **'Untitled field'**
  String get coreTrelloUntitledField;

  /// No description provided for @coreTrelloUntitledOption.
  ///
  /// In en, this message translates to:
  /// **'Untitled option'**
  String get coreTrelloUntitledOption;

  /// No description provided for @coreTrelloUntitledItem.
  ///
  /// In en, this message translates to:
  /// **'Untitled item'**
  String get coreTrelloUntitledItem;

  /// No description provided for @coreTrelloNoList.
  ///
  /// In en, this message translates to:
  /// **'No list'**
  String get coreTrelloNoList;

  /// No description provided for @coreTrelloLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get coreTrelloLabel;

  /// No description provided for @coreTrelloMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get coreTrelloMember;

  /// No description provided for @coreTrelloName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get coreTrelloName;

  /// No description provided for @coreTrelloDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get coreTrelloDescription;

  /// No description provided for @coreTrelloList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get coreTrelloList;

  /// No description provided for @coreTrelloLabels.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get coreTrelloLabels;

  /// No description provided for @coreTrelloMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get coreTrelloMembers;

  /// No description provided for @coreTrelloStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get coreTrelloStart;

  /// No description provided for @coreTrelloDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get coreTrelloDue;

  /// No description provided for @coreTrelloDueDone.
  ///
  /// In en, this message translates to:
  /// **'Due done'**
  String get coreTrelloDueDone;

  /// No description provided for @coreTrelloAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get coreTrelloAttachments;

  /// No description provided for @coreTrelloLink.
  ///
  /// In en, this message translates to:
  /// **'Trello link'**
  String get coreTrelloLink;

  /// No description provided for @coreTrelloArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get coreTrelloArchived;

  /// No description provided for @coreTrelloBoardView.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get coreTrelloBoardView;

  /// No description provided for @coreTrelloItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get coreTrelloItem;

  /// No description provided for @coreTrelloDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get coreTrelloDone;

  /// No description provided for @coreTrelloChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get coreTrelloChecklist;

  /// No description provided for @coreTrelloCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get coreTrelloCard;

  /// No description provided for @coreTrelloComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get coreTrelloComment;

  /// No description provided for @coreTrelloAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get coreTrelloAuthor;

  /// No description provided for @coreTrelloDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get coreTrelloDate;

  /// No description provided for @coreTrelloChecklistItems.
  ///
  /// In en, this message translates to:
  /// **'{board} · Checklist items'**
  String coreTrelloChecklistItems(String board);

  /// No description provided for @coreTrelloComments.
  ///
  /// In en, this message translates to:
  /// **'{board} · Comments'**
  String coreTrelloComments(String board);

  /// No description provided for @coreTrelloFieldRenamed.
  ///
  /// In en, this message translates to:
  /// **'{field} (Trello field)'**
  String coreTrelloFieldRenamed(String field);

  /// No description provided for @coreTrelloFieldRenamedNumbered.
  ///
  /// In en, this message translates to:
  /// **'{field} (Trello field {number})'**
  String coreTrelloFieldRenamedNumbered(String field, int number);

  /// No description provided for @coreTrelloColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get coreTrelloColorGreen;

  /// No description provided for @coreTrelloColorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get coreTrelloColorYellow;

  /// No description provided for @coreTrelloColorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get coreTrelloColorOrange;

  /// No description provided for @coreTrelloColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get coreTrelloColorRed;

  /// No description provided for @coreTrelloColorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get coreTrelloColorPurple;

  /// No description provided for @coreTrelloColorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get coreTrelloColorBlue;

  /// No description provided for @coreTrelloColorSky.
  ///
  /// In en, this message translates to:
  /// **'Sky'**
  String get coreTrelloColorSky;

  /// No description provided for @coreTrelloColorLime.
  ///
  /// In en, this message translates to:
  /// **'Lime'**
  String get coreTrelloColorLime;

  /// No description provided for @coreTrelloColorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get coreTrelloColorPink;

  /// No description provided for @coreTrelloColorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get coreTrelloColorBlack;

  /// No description provided for @coreTrelloColorShade.
  ///
  /// In en, this message translates to:
  /// **'{shade, select, light{{color} light} dark{{color} dark} other{{color} {shade}}}'**
  String coreTrelloColorShade(String color, String shade);

  /// No description provided for @validationRequired.
  ///
  /// In en, this message translates to:
  /// **'{name} is required'**
  String validationRequired(String name);

  /// No description provided for @validationDateMin.
  ///
  /// In en, this message translates to:
  /// **'{name} must be on or after {date}'**
  String validationDateMin(String name, String date);

  /// No description provided for @validationDateMax.
  ///
  /// In en, this message translates to:
  /// **'{name} must be on or before {date}'**
  String validationDateMax(String name, String date);

  /// No description provided for @validationNumberMin.
  ///
  /// In en, this message translates to:
  /// **'{name} must be at least {min}'**
  String validationNumberMin(String name, String min);

  /// No description provided for @validationNumberMax.
  ///
  /// In en, this message translates to:
  /// **'{name} must be at most {max}'**
  String validationNumberMax(String name, String max);

  /// No description provided for @validationTooLong.
  ///
  /// In en, this message translates to:
  /// **'{name} must be at most {max} characters'**
  String validationTooLong(String name, int max);

  /// No description provided for @validationOneFile.
  ///
  /// In en, this message translates to:
  /// **'{name} allows only one file'**
  String validationOneFile(String name);

  /// No description provided for @validationFileType.
  ///
  /// In en, this message translates to:
  /// **'{file} has an unsupported type for {name}'**
  String validationFileType(String file, String name);

  /// No description provided for @validationNoOption.
  ///
  /// In en, this message translates to:
  /// **'{name} has no option \"{option}\"'**
  String validationNoOption(String name, String option);

  /// No description provided for @validationInvalidOption.
  ///
  /// In en, this message translates to:
  /// **'\"{option}\" is not a valid option for {name}'**
  String validationInvalidOption(String option, String name);

  /// No description provided for @validationBlankReference.
  ///
  /// In en, this message translates to:
  /// **'{name} contains a blank reference'**
  String validationBlankReference(String name);

  /// No description provided for @validationOneReference.
  ///
  /// In en, this message translates to:
  /// **'{name} may reference at most one object'**
  String validationOneReference(String name);

  /// No description provided for @objectsNewItem.
  ///
  /// In en, this message translates to:
  /// **'New {item}'**
  String objectsNewItem(String item);

  /// No description provided for @objectsCloseEditor.
  ///
  /// In en, this message translates to:
  /// **'Close editor'**
  String get objectsCloseEditor;

  /// No description provided for @objectsDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get objectsDiscardTitle;

  /// No description provided for @objectsDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'Your changes to this {item} haven\'t been saved.'**
  String objectsDiscardMessage(String item);

  /// No description provided for @objectsDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get objectsDiscard;

  /// No description provided for @objectsKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get objectsKeepEditing;

  /// No description provided for @objectsAnotherCard.
  ///
  /// In en, this message translates to:
  /// **'another card'**
  String get objectsAnotherCard;

  /// No description provided for @objectsRunReverted.
  ///
  /// In en, this message translates to:
  /// **'{run} · Reverted'**
  String objectsRunReverted(String run);

  /// No description provided for @objectsRunRevertedOnCard.
  ///
  /// In en, this message translates to:
  /// **'{run} on {card} · Reverted'**
  String objectsRunRevertedOnCard(String run, String card);

  /// No description provided for @objectsDeleteItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {item}?'**
  String objectsDeleteItemTitle(String item);

  /// No description provided for @objectsDeleteItemMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be deleted.'**
  String objectsDeleteItemMessage(String title);

  /// No description provided for @objectsDeleteItem.
  ///
  /// In en, this message translates to:
  /// **'Delete {item}'**
  String objectsDeleteItem(String item);

  /// No description provided for @objectsUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get objectsUploading;

  /// No description provided for @objectsSaveAsNew.
  ///
  /// In en, this message translates to:
  /// **'Save as new'**
  String get objectsSaveAsNew;

  /// No description provided for @objectsHeaderMeta.
  ///
  /// In en, this message translates to:
  /// **'{item} · created {created} · edited {edited}'**
  String objectsHeaderMeta(String item, String created, String edited);

  /// No description provided for @objectsJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get objectsJustNow;

  /// No description provided for @objectsMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String objectsMinutesAgo(int count);

  /// No description provided for @objectsHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String objectsHoursAgo(int count);

  /// No description provided for @objectsFixFields.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Fix 1 field to save} other{Fix {count} fields to save}}'**
  String objectsFixFields(int count);

  /// No description provided for @objectsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save — check your connection'**
  String get objectsSaveFailed;

  /// No description provided for @objectsDeletedElsewhere.
  ///
  /// In en, this message translates to:
  /// **'This {item} was deleted elsewhere.'**
  String objectsDeletedElsewhere(String item);

  /// No description provided for @objectsSaveAsNewToRestore.
  ///
  /// In en, this message translates to:
  /// **'Save as new to restore it.'**
  String get objectsSaveAsNewToRestore;

  /// No description provided for @objectsChangedElsewhere.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{names} was changed elsewhere.} other{{names} were changed elsewhere.}}'**
  String objectsChangedElsewhere(int count, String names);

  /// No description provided for @objectsNamesAnd.
  ///
  /// In en, this message translates to:
  /// **'{names} and {last}'**
  String objectsNamesAnd(String names, String last);

  /// No description provided for @objectsOverwriteNote.
  ///
  /// In en, this message translates to:
  /// **'Saving will overwrite it with your value.'**
  String get objectsOverwriteNote;

  /// No description provided for @objectsNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Needs a connection'**
  String get objectsNeedsConnection;

  /// No description provided for @objectsDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get objectsDismiss;

  /// No description provided for @objectsChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed'**
  String get objectsChanged;

  /// No description provided for @objectsCouldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open {name}'**
  String objectsCouldNotOpen(String name);

  /// No description provided for @objectsUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload {name}'**
  String objectsUploadFailed(String name);

  /// No description provided for @objectsUploadTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload {name}: files must be under 25 MB'**
  String objectsUploadTooLarge(String name);

  /// No description provided for @objectsAssignedOnSave.
  ///
  /// In en, this message translates to:
  /// **'Assigned on save'**
  String get objectsAssignedOnSave;

  /// No description provided for @objectsSetAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Set automatically'**
  String get objectsSetAutomatically;

  /// No description provided for @objectsNothingToCalculate.
  ///
  /// In en, this message translates to:
  /// **'Nothing to calculate yet'**
  String get objectsNothingToCalculate;

  /// No description provided for @objectsCalculated.
  ///
  /// In en, this message translates to:
  /// **'Calculated'**
  String get objectsCalculated;

  /// No description provided for @objectsCantEditType.
  ///
  /// In en, this message translates to:
  /// **'Can\'t edit {type} here'**
  String objectsCantEditType(String type);

  /// No description provided for @objectsReplaceFile.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get objectsReplaceFile;

  /// No description provided for @objectsUploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload file'**
  String get objectsUploadFile;

  /// No description provided for @objectsFileSizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{size} B'**
  String objectsFileSizeBytes(String size);

  /// No description provided for @objectsFileSizeKb.
  ///
  /// In en, this message translates to:
  /// **'{size} KB'**
  String objectsFileSizeKb(String size);

  /// No description provided for @objectsFileSizeMb.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String objectsFileSizeMb(String size);

  /// No description provided for @objectsFileBadge.
  ///
  /// In en, this message translates to:
  /// **'FILE'**
  String get objectsFileBadge;

  /// No description provided for @objectsRemoveNamed.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String objectsRemoveNamed(String name);

  /// No description provided for @objectsUploadingNamed.
  ///
  /// In en, this message translates to:
  /// **'Uploading {name}'**
  String objectsUploadingNamed(String name);

  /// No description provided for @objectsCancelUpload.
  ///
  /// In en, this message translates to:
  /// **'Cancel upload'**
  String get objectsCancelUpload;

  /// No description provided for @objectsUnknownItem.
  ///
  /// In en, this message translates to:
  /// **'Unknown {item}'**
  String objectsUnknownItem(String item);

  /// No description provided for @objectsUnlinkNamed.
  ///
  /// In en, this message translates to:
  /// **'Unlink {name}'**
  String objectsUnlinkNamed(String name);

  /// No description provided for @objectsLinkItem.
  ///
  /// In en, this message translates to:
  /// **'Link {item}'**
  String objectsLinkItem(String item);

  /// No description provided for @objectsEnterNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get objectsEnterNumber;

  /// No description provided for @objectsNoOptions.
  ///
  /// In en, this message translates to:
  /// **'No options yet'**
  String get objectsNoOptions;

  /// No description provided for @objectsChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose…'**
  String get objectsChoose;

  /// No description provided for @objectsPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get objectsPickDate;

  /// No description provided for @objectsPickDateTime.
  ///
  /// In en, this message translates to:
  /// **'Pick date and time'**
  String get objectsPickDateTime;

  /// No description provided for @objectsClearNamed.
  ///
  /// In en, this message translates to:
  /// **'Clear {name}'**
  String objectsClearNamed(String name);

  /// No description provided for @objectsLinkedToThis.
  ///
  /// In en, this message translates to:
  /// **'Linked to this {item}'**
  String objectsLinkedToThis(String item);

  /// No description provided for @objectsCouldNotDeleteItem.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the {item}'**
  String objectsCouldNotDeleteItem(String item);

  /// No description provided for @objectsCouldNotUpdate.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update {name}'**
  String objectsCouldNotUpdate(String name);

  /// No description provided for @objectsCheckedOf.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} {check}'**
  String objectsCheckedOf(int done, int total, String check);

  /// No description provided for @objectsAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add {item}'**
  String objectsAddItem(String item);

  /// No description provided for @objectsLinkingVia.
  ///
  /// In en, this message translates to:
  /// **'Linking here via {field}'**
  String objectsLinkingVia(String field);

  /// No description provided for @objectsNoItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No {items} yet'**
  String objectsNoItemsYet(String items);

  /// No description provided for @objectsLinkItems.
  ///
  /// In en, this message translates to:
  /// **'Link {items}'**
  String objectsLinkItems(String items);

  /// No description provided for @objectsFromCollection.
  ///
  /// In en, this message translates to:
  /// **'from {collection}'**
  String objectsFromCollection(String collection);

  /// No description provided for @objectsSearchItems.
  ///
  /// In en, this message translates to:
  /// **'Search {items}'**
  String objectsSearchItems(String items);

  /// No description provided for @objectsShownOf.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total}'**
  String objectsShownOf(int shown, int total);

  /// No description provided for @objectsCollectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'{collection} has no items yet'**
  String objectsCollectionEmpty(String collection);

  /// No description provided for @objectsThisCollectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'This collection has no items yet'**
  String get objectsThisCollectionEmpty;

  /// No description provided for @objectsNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No {items} match “{query}”'**
  String objectsNoMatch(String items, String query);

  /// No description provided for @objectsTryAnotherName.
  ///
  /// In en, this message translates to:
  /// **'Try another name'**
  String get objectsTryAnotherName;

  /// No description provided for @objectsUnlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get objectsUnlink;

  /// No description provided for @objectsLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get objectsLinked;

  /// No description provided for @authErrorSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed.'**
  String get authErrorSignInFailed;

  /// No description provided for @authErrorNoUser.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in returned no user.'**
  String get authErrorNoUser;

  /// No description provided for @authErrorUnsupportedPlatform.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is not supported on this platform.'**
  String get authErrorUnsupportedPlatform;

  /// No description provided for @authErrorNoIdToken.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in did not return an ID token.'**
  String get authErrorNoIdToken;

  /// No description provided for @authErrorSignOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-out failed.'**
  String get authErrorSignOutFailed;

  /// No description provided for @trelloImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from Trello'**
  String get trelloImportTitle;

  /// No description provided for @trelloImportFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get trelloImportFiles;

  /// No description provided for @trelloImportPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get trelloImportPaste;

  /// No description provided for @trelloImportProblemNotABoard.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a Trello board export. Use Export as JSON on the board.'**
  String get trelloImportProblemNotABoard;

  /// No description provided for @trelloImportProblemAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Already added'**
  String get trelloImportProblemAlreadyAdded;

  /// No description provided for @trelloImportProblemUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the chosen files. Choose them again, or paste one.'**
  String get trelloImportProblemUnreadable;

  /// No description provided for @trelloImportDropHint.
  ///
  /// In en, this message translates to:
  /// **'Trello board exports (.json)'**
  String get trelloImportDropHint;

  /// No description provided for @trelloImportChooseFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose files'**
  String get trelloImportChooseFiles;

  /// No description provided for @trelloImportBoardJson.
  ///
  /// In en, this message translates to:
  /// **'Board JSON'**
  String get trelloImportBoardJson;

  /// No description provided for @trelloImportPasteHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a board\'s whole export'**
  String get trelloImportPasteHint;

  /// No description provided for @trelloImportPasteHelp.
  ///
  /// In en, this message translates to:
  /// **'Paste one board\'s whole export, then add it. Repeat for more boards.'**
  String get trelloImportPasteHelp;

  /// No description provided for @trelloImportAddBoard.
  ///
  /// In en, this message translates to:
  /// **'Add board'**
  String get trelloImportAddBoard;

  /// No description provided for @trelloImportStep1.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 2 · Add boards'**
  String get trelloImportStep1;

  /// No description provided for @trelloImportBoardsToImport.
  ///
  /// In en, this message translates to:
  /// **'Boards to import'**
  String get trelloImportBoardsToImport;

  /// No description provided for @trelloImportAddAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Add at least one board'**
  String get trelloImportAddAtLeastOne;

  /// No description provided for @trelloImportHowToTitle.
  ///
  /// In en, this message translates to:
  /// **'Export each board from Trello'**
  String get trelloImportHowToTitle;

  /// No description provided for @trelloImportHowToOpen.
  ///
  /// In en, this message translates to:
  /// **'Open the board → '**
  String get trelloImportHowToOpen;

  /// No description provided for @trelloImportHowToMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get trelloImportHowToMenu;

  /// No description provided for @trelloImportHowToShare.
  ///
  /// In en, this message translates to:
  /// **'Print, export, and share'**
  String get trelloImportHowToShare;

  /// No description provided for @trelloImportHowToExport.
  ///
  /// In en, this message translates to:
  /// **'Export as JSON'**
  String get trelloImportHowToExport;

  /// No description provided for @trelloImportHowToRest.
  ///
  /// In en, this message translates to:
  /// **'. If Trello opens it in a new tab, save the page as a .json file (Ctrl+S), or copy all of it and use Paste. Nothing is imported until you choose.'**
  String get trelloImportHowToRest;

  /// No description provided for @trelloImportNoBoards.
  ///
  /// In en, this message translates to:
  /// **'No boards yet'**
  String get trelloImportNoBoards;

  /// No description provided for @trelloImportNoBoardsBody.
  ///
  /// In en, this message translates to:
  /// **'Boards you add show up here with their lists and cards.'**
  String get trelloImportNoBoardsBody;

  /// No description provided for @trelloImportListCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} list} other{{n} lists}}'**
  String trelloImportListCount(int count, String n);

  /// No description provided for @trelloImportCardCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} card} other{{n} cards}}'**
  String trelloImportCardCount(int count, String n);

  /// No description provided for @trelloImportChecklistItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} checklist item} other{{n} checklist items}}'**
  String trelloImportChecklistItemCount(int count, String n);

  /// No description provided for @trelloImportCommentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} comment} other{{n} comments}}'**
  String trelloImportCommentCount(int count, String n);

  /// No description provided for @trelloImportItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} item} other{{n} items}}'**
  String trelloImportItemCount(int count, String n);

  /// No description provided for @trelloImportCollectionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} collection} other{{n} collections}}'**
  String trelloImportCollectionCount(int count, String n);

  /// No description provided for @trelloImportCollectionsButton.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Import {n} collection} other{Import {n} collections}}'**
  String trelloImportCollectionsButton(int count, String n);

  /// No description provided for @trelloImportArchivedCards.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} archived card. They get an Archived checkbox and stay off the board view.} other{{n} archived cards. They get an Archived checkbox and stay off the board view.}}'**
  String trelloImportArchivedCards(int count, String n);

  /// No description provided for @trelloImportMoreFields.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+{n} more field} other{+{n} more fields}}'**
  String trelloImportMoreFields(int count, String n);

  /// No description provided for @trelloImportBoardViewByList.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} card · board view by List} other{{n} cards · board view by List}}'**
  String trelloImportBoardViewByList(int count, String n);

  /// No description provided for @trelloImportRemoveNamed.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String trelloImportRemoveNamed(String name);

  /// No description provided for @trelloImportDismissNamed.
  ///
  /// In en, this message translates to:
  /// **'Dismiss {name}'**
  String trelloImportDismissNamed(String name);

  /// No description provided for @trelloImportStep2.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 2 · Choose what to import'**
  String get trelloImportStep2;

  /// No description provided for @trelloImportNoAutomationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Automations can\'t come along.'**
  String get trelloImportNoAutomationsTitle;

  /// No description provided for @trelloImportNoAutomationsBody.
  ///
  /// In en, this message translates to:
  /// **'Trello leaves Butler rules and buttons out of board exports — set them up again in Automations once your boards are in.'**
  String get trelloImportNoAutomationsBody;

  /// No description provided for @trelloImportIncludeArchived.
  ///
  /// In en, this message translates to:
  /// **'Include archived cards and lists'**
  String get trelloImportIncludeArchived;

  /// No description provided for @trelloImportNoArchived.
  ///
  /// In en, this message translates to:
  /// **'No archived cards.'**
  String get trelloImportNoArchived;

  /// No description provided for @trelloImportCollectionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Each board becomes a collection with a board view grouped by list. Checklist items and comments show as lists on each card.'**
  String get trelloImportCollectionsHelp;

  /// No description provided for @trelloImportNothingChosen.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one collection'**
  String get trelloImportNothingChosen;

  /// No description provided for @trelloImportOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline — connect to import'**
  String get trelloImportOffline;

  /// No description provided for @trelloImportNeedsBoard.
  ///
  /// In en, this message translates to:
  /// **'needs the board'**
  String get trelloImportNeedsBoard;

  /// No description provided for @trelloImportChecklistItems.
  ///
  /// In en, this message translates to:
  /// **'Checklist items'**
  String get trelloImportChecklistItems;

  /// No description provided for @trelloImportComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get trelloImportComments;

  /// No description provided for @trelloImportCapped.
  ///
  /// In en, this message translates to:
  /// **'Trello exports keep only the newest 1,000 activities, so older comments may be missing.'**
  String get trelloImportCapped;

  /// No description provided for @trelloImportWritingCardsAndItems.
  ///
  /// In en, this message translates to:
  /// **'Writing cards and items'**
  String get trelloImportWritingCardsAndItems;

  /// No description provided for @trelloImportWritingCards.
  ///
  /// In en, this message translates to:
  /// **'Writing cards'**
  String get trelloImportWritingCards;

  /// No description provided for @trelloImportImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing from Trello'**
  String get trelloImportImporting;

  /// No description provided for @trelloImportKeepOpen.
  ///
  /// In en, this message translates to:
  /// **'Keep this open until it finishes.'**
  String get trelloImportKeepOpen;

  /// No description provided for @trelloImportPaused.
  ///
  /// In en, this message translates to:
  /// **'Import paused.'**
  String get trelloImportPaused;

  /// No description provided for @trelloImportStalled.
  ///
  /// In en, this message translates to:
  /// **'Morkva couldn\'t reach the server for 30 seconds. Check your connection, then retry — cards already written won\'t be added twice. Closing keeps what\'s already imported.'**
  String get trelloImportStalled;

  /// No description provided for @trelloImportRefused.
  ///
  /// In en, this message translates to:
  /// **'Morkva couldn\'t save some cards. Check your connection, then retry — cards already written won\'t be added twice. Closing keeps what\'s already imported.'**
  String get trelloImportRefused;

  /// No description provided for @trelloImportWrittenOf.
  ///
  /// In en, this message translates to:
  /// **'{written} of {total}'**
  String trelloImportWrittenOf(String written, String total);

  /// No description provided for @trelloImportNoAutomationsStart.
  ///
  /// In en, this message translates to:
  /// **'Imported cards don\'t start automations.'**
  String get trelloImportNoAutomationsStart;

  /// No description provided for @trelloImportWritingKeepOpen.
  ///
  /// In en, this message translates to:
  /// **'Writing — keep this open'**
  String get trelloImportWritingKeepOpen;

  /// No description provided for @trelloImportRowPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get trelloImportRowPaused;

  /// No description provided for @trelloImportRowWriting.
  ///
  /// In en, this message translates to:
  /// **'Writing'**
  String get trelloImportRowWriting;

  /// No description provided for @trelloImportRowWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get trelloImportRowWaiting;

  /// No description provided for @trelloImportDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Your boards are in'**
  String get trelloImportDoneTitle;

  /// No description provided for @trelloImportButlerHint.
  ///
  /// In en, this message translates to:
  /// **'Used Butler in Trello? Set up the same steps as Morkva automations.'**
  String get trelloImportButlerHint;

  /// No description provided for @settingsWorkspaceSection.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get settingsWorkspaceSection;

  /// No description provided for @settingsAutomationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Modules, buttons and runs'**
  String get settingsAutomationsSubtitle;

  /// No description provided for @settingsAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountSection;

  /// No description provided for @settingsImportSection.
  ///
  /// In en, this message translates to:
  /// **'Import from other apps'**
  String get settingsImportSection;

  /// No description provided for @settingsTrelloSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Boards become collections — lists, cards, labels, checklists and comments'**
  String get settingsTrelloSubtitle;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsAppearanceSection.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceSection;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device'**
  String get settingsThemeSubtitle;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @viewsGroupBy.
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get viewsGroupBy;

  /// No description provided for @viewsAddField.
  ///
  /// In en, this message translates to:
  /// **'Add field'**
  String get viewsAddField;

  /// No description provided for @viewsSetupCard.
  ///
  /// In en, this message translates to:
  /// **'Setup card'**
  String get viewsSetupCard;

  /// No description provided for @viewsModeTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get viewsModeTable;

  /// No description provided for @viewsModeTableDescription.
  ///
  /// In en, this message translates to:
  /// **'Rows and columns, sortable by any field.'**
  String get viewsModeTableDescription;

  /// No description provided for @viewsColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get viewsColumns;

  /// No description provided for @viewsModeBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get viewsModeBoard;

  /// No description provided for @viewsModeBoardDescription.
  ///
  /// In en, this message translates to:
  /// **'Cards in columns by a choice or reference field.'**
  String get viewsModeBoardDescription;

  /// No description provided for @viewsModeList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get viewsModeList;

  /// No description provided for @viewsModeListDescription.
  ///
  /// In en, this message translates to:
  /// **'Compact rows, optionally in sections.'**
  String get viewsModeListDescription;

  /// No description provided for @viewsModeCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get viewsModeCalendar;

  /// No description provided for @viewsModeCalendarDescription.
  ///
  /// In en, this message translates to:
  /// **'Items on the days of a date field.'**
  String get viewsModeCalendarDescription;

  /// No description provided for @viewsModeSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get viewsModeSummary;

  /// No description provided for @viewsModeSummaryDescription.
  ///
  /// In en, this message translates to:
  /// **'Big numbers per item, like a dashboard.'**
  String get viewsModeSummaryDescription;

  /// No description provided for @viewsSetupTiles.
  ///
  /// In en, this message translates to:
  /// **'Setup tiles'**
  String get viewsSetupTiles;

  /// No description provided for @viewsDateField.
  ///
  /// In en, this message translates to:
  /// **'Date field'**
  String get viewsDateField;

  /// No description provided for @viewsAddDateField.
  ///
  /// In en, this message translates to:
  /// **'Add date field'**
  String get viewsAddDateField;

  /// No description provided for @viewsNeedsChoiceOrReference.
  ///
  /// In en, this message translates to:
  /// **'Needs a choice or reference field'**
  String get viewsNeedsChoiceOrReference;

  /// No description provided for @viewsNeedsDateField.
  ///
  /// In en, this message translates to:
  /// **'Needs a date field'**
  String get viewsNeedsDateField;

  /// No description provided for @viewsNewItem.
  ///
  /// In en, this message translates to:
  /// **'New {item}'**
  String viewsNewItem(String item);

  /// No description provided for @viewsShownOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total}'**
  String viewsShownOfTotal(int shown, int total);

  /// No description provided for @viewsTotalCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {noun}'**
  String viewsTotalCount(int count, String noun);

  /// No description provided for @viewsSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by {field}'**
  String viewsSortBy(String field);

  /// No description provided for @viewsSortAscending.
  ///
  /// In en, this message translates to:
  /// **'ascending'**
  String get viewsSortAscending;

  /// No description provided for @viewsSortDescending.
  ///
  /// In en, this message translates to:
  /// **'descending'**
  String get viewsSortDescending;

  /// No description provided for @viewsChangeFields.
  ///
  /// In en, this message translates to:
  /// **'Change fields'**
  String get viewsChangeFields;

  /// No description provided for @viewsEnteredByHand.
  ///
  /// In en, this message translates to:
  /// **'Entered by hand'**
  String get viewsEnteredByHand;

  /// No description provided for @viewsEditValues.
  ///
  /// In en, this message translates to:
  /// **'Edit values'**
  String get viewsEditValues;

  /// No description provided for @viewsPickTilesHint.
  ///
  /// In en, this message translates to:
  /// **'Pick fields to show with “Setup tiles”.'**
  String get viewsPickTilesHint;

  /// No description provided for @viewsTileEmpty.
  ///
  /// In en, this message translates to:
  /// **'{label}: empty'**
  String viewsTileEmpty(String label);

  /// No description provided for @viewsGroupChip.
  ///
  /// In en, this message translates to:
  /// **'Group: {name}'**
  String viewsGroupChip(String name);

  /// No description provided for @viewsGroupChipNone.
  ///
  /// In en, this message translates to:
  /// **'Group: None'**
  String get viewsGroupChipNone;

  /// No description provided for @viewsReorderedIn.
  ///
  /// In en, this message translates to:
  /// **'Reordered in {group}'**
  String viewsReorderedIn(String group);

  /// No description provided for @viewsReorderedInSortOff.
  ///
  /// In en, this message translates to:
  /// **'Reordered in {group} — sort turned off'**
  String viewsReorderedInSortOff(String group);

  /// No description provided for @viewsMovedTo.
  ///
  /// In en, this message translates to:
  /// **'Moved to {group}'**
  String viewsMovedTo(String group);

  /// No description provided for @viewsMovedToHidden.
  ///
  /// In en, this message translates to:
  /// **'Moved to {group} — hidden by filter'**
  String viewsMovedToHidden(String group);

  /// No description provided for @viewsItemsFallback.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get viewsItemsFallback;

  /// No description provided for @viewsColumnOf.
  ///
  /// In en, this message translates to:
  /// **'Column {index} of {count}'**
  String viewsColumnOf(int index, int count);

  /// No description provided for @viewsJumpToColumn.
  ///
  /// In en, this message translates to:
  /// **'Jump to column'**
  String get viewsJumpToColumn;

  /// No description provided for @viewsBoardNeedsField.
  ///
  /// In en, this message translates to:
  /// **'Board needs a choice or reference field'**
  String get viewsBoardNeedsField;

  /// No description provided for @viewsBoardNeedsFieldMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a choice or reference field, and each of its values becomes a column you can drag {items} between.'**
  String viewsBoardNeedsFieldMessage(String items);

  /// No description provided for @viewsBoardChooseGroup.
  ///
  /// In en, this message translates to:
  /// **'Choose how to group this board'**
  String get viewsBoardChooseGroup;

  /// No description provided for @viewsBoardChooseGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'Each value of the field becomes a column.'**
  String get viewsBoardChooseGroupMessage;

  /// No description provided for @viewsGroupByAction.
  ///
  /// In en, this message translates to:
  /// **'Group by…'**
  String get viewsGroupByAction;

  /// No description provided for @viewsDateChip.
  ///
  /// In en, this message translates to:
  /// **'Date: {name}'**
  String viewsDateChip(String name);

  /// No description provided for @viewsDateChipEmpty.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get viewsDateChipEmpty;

  /// No description provided for @viewsCalendarNeedsDate.
  ///
  /// In en, this message translates to:
  /// **'Calendar needs a date field'**
  String get viewsCalendarNeedsDate;

  /// No description provided for @viewsCalendarNeedsDateMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a date field to place each {item} on a day.'**
  String viewsCalendarNeedsDateMessage(String item);

  /// No description provided for @viewsCalendarChooseDate.
  ///
  /// In en, this message translates to:
  /// **'Choose a date field'**
  String get viewsCalendarChooseDate;

  /// No description provided for @viewsCalendarChooseDateMessage.
  ///
  /// In en, this message translates to:
  /// **'Pick the date that places each {item} on a day.'**
  String viewsCalendarChooseDateMessage(String item);

  /// No description provided for @viewsOrderChanged.
  ///
  /// In en, this message translates to:
  /// **'Order changed'**
  String get viewsOrderChanged;

  /// No description provided for @viewsDragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get viewsDragToReorder;

  /// No description provided for @viewsLinkCardGone.
  ///
  /// In en, this message translates to:
  /// **'This link\'s {item} is gone'**
  String viewsLinkCardGone(String item);

  /// No description provided for @viewsAddFirstItem.
  ///
  /// In en, this message translates to:
  /// **'Add your first {item}'**
  String viewsAddFirstItem(String item);

  /// No description provided for @viewsAddFilter.
  ///
  /// In en, this message translates to:
  /// **'Add filter'**
  String get viewsAddFilter;

  /// No description provided for @viewsEditFilter.
  ///
  /// In en, this message translates to:
  /// **'Edit filter'**
  String get viewsEditFilter;

  /// No description provided for @viewsSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get viewsSort;

  /// No description provided for @viewsTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get viewsTitleFallback;

  /// No description provided for @viewsAddedHidden.
  ///
  /// In en, this message translates to:
  /// **'Added — hidden by the filters'**
  String get viewsAddedHidden;

  /// No description provided for @viewsSavedHidden.
  ///
  /// In en, this message translates to:
  /// **'Saved — hidden by the filters'**
  String get viewsSavedHidden;

  /// No description provided for @viewsFilledFromColumn.
  ///
  /// In en, this message translates to:
  /// **'Filled from the {group} column'**
  String viewsFilledFromColumn(String group);

  /// No description provided for @viewsFilledFromGroup.
  ///
  /// In en, this message translates to:
  /// **'Filled from the {group} group'**
  String viewsFilledFromGroup(String group);

  /// No description provided for @viewsFilledFromDay.
  ///
  /// In en, this message translates to:
  /// **'Filled from {date}'**
  String viewsFilledFromDay(String date);

  /// No description provided for @viewsDeletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{title}\"'**
  String viewsDeletedTitle(String title);

  /// No description provided for @viewsDeleteViewTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete view?'**
  String get viewsDeleteViewTitle;

  /// No description provided for @viewsDeleteViewMessage.
  ///
  /// In en, this message translates to:
  /// **'This deletes the view \"{name}\" and its filters and sort. Your data stays as it is.'**
  String viewsDeleteViewMessage(String name);

  /// No description provided for @viewsCustomize.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get viewsCustomize;

  /// No description provided for @viewsViewSettings.
  ///
  /// In en, this message translates to:
  /// **'View settings'**
  String get viewsViewSettings;

  /// No description provided for @viewsCustomizeCollection.
  ///
  /// In en, this message translates to:
  /// **'Customize collection'**
  String get viewsCustomizeCollection;

  /// No description provided for @viewsNoFieldsTitle.
  ///
  /// In en, this message translates to:
  /// **'This collection has no fields yet'**
  String get viewsNoFieldsTitle;

  /// No description provided for @viewsNoFieldsMessage.
  ///
  /// In en, this message translates to:
  /// **'Add the fields you track for each {item}, then come back to work with them here.'**
  String viewsNoFieldsMessage(String item);

  /// No description provided for @viewsSaveAsView.
  ///
  /// In en, this message translates to:
  /// **'Save as view'**
  String get viewsSaveAsView;

  /// No description provided for @viewsNoMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches these filters'**
  String get viewsNoMatchesTitle;

  /// No description provided for @viewsNoMatchesMessage.
  ///
  /// In en, this message translates to:
  /// **'None of your {count} {items} pass the filters above.'**
  String viewsNoMatchesMessage(int count, String items);

  /// No description provided for @viewsClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get viewsClearFilters;

  /// No description provided for @viewsAssistantFiltersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filters from Ask Morkva, not saved: {filters}'**
  String viewsAssistantFiltersTooltip(String filters);

  /// No description provided for @viewsFromAssistant.
  ///
  /// In en, this message translates to:
  /// **'From assistant · {filters}'**
  String viewsFromAssistant(String filters);

  /// No description provided for @viewsClearAssistantFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear assistant filters'**
  String get viewsClearAssistantFilters;

  /// No description provided for @viewsUnknownMode.
  ///
  /// In en, this message translates to:
  /// **'This view uses the \"{mode}\" mode, which this version doesn\'t have yet. Showing it as a {fallback}.'**
  String viewsUnknownMode(String mode, String fallback);

  /// No description provided for @viewsNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Collection not found'**
  String get viewsNotFoundTitle;

  /// No description provided for @viewsNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This collection may have been deleted, or the link is wrong. Head back home to pick another.'**
  String get viewsNotFoundMessage;

  /// No description provided for @viewsBackToCollections.
  ///
  /// In en, this message translates to:
  /// **'Back to collections'**
  String get viewsBackToCollections;

  /// No description provided for @viewsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this view'**
  String get viewsLoadError;

  /// No description provided for @viewsLoadErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get viewsLoadErrorMessage;

  /// No description provided for @viewsLoadTargetFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load {name}'**
  String viewsLoadTargetFailed(String name);

  /// No description provided for @viewsLinkFilterInvalid.
  ///
  /// In en, this message translates to:
  /// **'This link\'s filter isn\'t valid'**
  String get viewsLinkFilterInvalid;

  /// No description provided for @viewsSaveViewFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the view'**
  String get viewsSaveViewFailed;

  /// No description provided for @viewsSaveChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the change'**
  String get viewsSaveChangeFailed;

  /// No description provided for @viewsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete it'**
  String get viewsDeleteFailed;

  /// No description provided for @viewsUntitledView.
  ///
  /// In en, this message translates to:
  /// **'Untitled view'**
  String get viewsUntitledView;

  /// No description provided for @viewsCopyName.
  ///
  /// In en, this message translates to:
  /// **'{name} copy'**
  String viewsCopyName(String name);

  /// No description provided for @viewsFilteredName.
  ///
  /// In en, this message translates to:
  /// **'{name} · filtered'**
  String viewsFilteredName(String name);

  /// No description provided for @viewWidgetsPopover.
  ///
  /// In en, this message translates to:
  /// **'Popover'**
  String get viewWidgetsPopover;

  /// No description provided for @viewWidgetsLastViewCantDelete.
  ///
  /// In en, this message translates to:
  /// **'The last view can\'t be deleted'**
  String get viewWidgetsLastViewCantDelete;

  /// No description provided for @viewWidgetsNewView.
  ///
  /// In en, this message translates to:
  /// **'New view'**
  String get viewWidgetsNewView;

  /// No description provided for @viewWidgetsViewOptions.
  ///
  /// In en, this message translates to:
  /// **'View options'**
  String get viewWidgetsViewOptions;

  /// No description provided for @viewWidgetsSortCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get viewWidgetsSortCreated;

  /// No description provided for @viewWidgetsSortUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get viewWidgetsSortUpdated;

  /// No description provided for @viewWidgetsPickLookupReference.
  ///
  /// In en, this message translates to:
  /// **'Pick a reference to look up'**
  String get viewWidgetsPickLookupReference;

  /// No description provided for @viewWidgetsPickLookupField.
  ///
  /// In en, this message translates to:
  /// **'Pick a field to show'**
  String get viewWidgetsPickLookupField;

  /// No description provided for @viewWidgetsLookupSummary.
  ///
  /// In en, this message translates to:
  /// **'{field} of the linked {item} ({reference})'**
  String viewWidgetsLookupSummary(String field, String item, String reference);

  /// No description provided for @viewWidgetsNoFormulaYet.
  ///
  /// In en, this message translates to:
  /// **'No formula yet'**
  String get viewWidgetsNoFormulaYet;

  /// No description provided for @viewWidgetsPickAggregateSource.
  ///
  /// In en, this message translates to:
  /// **'Pick what to summarize'**
  String get viewWidgetsPickAggregateSource;

  /// No description provided for @viewWidgetsAggregateOfLinkingHere.
  ///
  /// In en, this message translates to:
  /// **'{op} of {field} of {source} linking here via {reference}'**
  String viewWidgetsAggregateOfLinkingHere(
    String op,
    String field,
    String source,
    String reference,
  );

  /// No description provided for @viewWidgetsAggregateOfLinked.
  ///
  /// In en, this message translates to:
  /// **'{op} of {field} of linked {source} ({reference})'**
  String viewWidgetsAggregateOfLinked(
    String op,
    String field,
    String source,
    String reference,
  );

  /// No description provided for @viewWidgetsAggregateOfAll.
  ///
  /// In en, this message translates to:
  /// **'{op} of {field} of all {source}'**
  String viewWidgetsAggregateOfAll(String op, String field, String source);

  /// No description provided for @viewWidgetsCountLinkingHere.
  ///
  /// In en, this message translates to:
  /// **'Count of {source} linking here via {reference}'**
  String viewWidgetsCountLinkingHere(String source, String reference);

  /// No description provided for @viewWidgetsCountLinked.
  ///
  /// In en, this message translates to:
  /// **'Count of linked {source} ({reference})'**
  String viewWidgetsCountLinked(String source, String reference);

  /// No description provided for @viewWidgetsCountAll.
  ///
  /// In en, this message translates to:
  /// **'Count of all {source}'**
  String viewWidgetsCountAll(String source);

  /// No description provided for @viewWidgetsSummaryWhere.
  ///
  /// In en, this message translates to:
  /// **'{summary} where {conditions}'**
  String viewWidgetsSummaryWhere(String summary, String conditions);

  /// No description provided for @viewWidgetsConditionSeparator.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get viewWidgetsConditionSeparator;

  /// No description provided for @viewWidgetsUnknownField.
  ///
  /// In en, this message translates to:
  /// **'Unknown field'**
  String get viewWidgetsUnknownField;

  /// No description provided for @viewWidgetsUnknownItem.
  ///
  /// In en, this message translates to:
  /// **'Unknown item'**
  String get viewWidgetsUnknownItem;

  /// No description provided for @viewWidgetsFilterChip.
  ///
  /// In en, this message translates to:
  /// **'{field} {condition}'**
  String viewWidgetsFilterChip(String field, String condition);

  /// No description provided for @viewWidgetsOpIs.
  ///
  /// In en, this message translates to:
  /// **'is'**
  String get viewWidgetsOpIs;

  /// No description provided for @viewWidgetsOpIsNot.
  ///
  /// In en, this message translates to:
  /// **'is not'**
  String get viewWidgetsOpIsNot;

  /// No description provided for @viewWidgetsOpHas.
  ///
  /// In en, this message translates to:
  /// **'has'**
  String get viewWidgetsOpHas;

  /// No description provided for @viewWidgetsOpHasNo.
  ///
  /// In en, this message translates to:
  /// **'has no'**
  String get viewWidgetsOpHasNo;

  /// No description provided for @viewWidgetsOpIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'is empty'**
  String get viewWidgetsOpIsEmpty;

  /// No description provided for @viewWidgetsOpIsNotEmpty.
  ///
  /// In en, this message translates to:
  /// **'is not empty'**
  String get viewWidgetsOpIsNotEmpty;

  /// No description provided for @viewWidgetsOpEquals.
  ///
  /// In en, this message translates to:
  /// **'is'**
  String get viewWidgetsOpEquals;

  /// No description provided for @viewWidgetsOpContains.
  ///
  /// In en, this message translates to:
  /// **'contains'**
  String get viewWidgetsOpContains;

  /// No description provided for @viewWidgetsOpNotContains.
  ///
  /// In en, this message translates to:
  /// **'does not contain'**
  String get viewWidgetsOpNotContains;

  /// No description provided for @viewWidgetsOpBefore.
  ///
  /// In en, this message translates to:
  /// **'is before'**
  String get viewWidgetsOpBefore;

  /// No description provided for @viewWidgetsOpAfter.
  ///
  /// In en, this message translates to:
  /// **'is after'**
  String get viewWidgetsOpAfter;

  /// No description provided for @viewWidgetsOpOnDay.
  ///
  /// In en, this message translates to:
  /// **'is on'**
  String get viewWidgetsOpOnDay;

  /// No description provided for @viewWidgetsOpHasAnyOf.
  ///
  /// In en, this message translates to:
  /// **'has any of'**
  String get viewWidgetsOpHasAnyOf;

  /// No description provided for @viewWidgetsOpIsAnyOf.
  ///
  /// In en, this message translates to:
  /// **'is any of'**
  String get viewWidgetsOpIsAnyOf;

  /// No description provided for @viewWidgetsOpHasNoneOf.
  ///
  /// In en, this message translates to:
  /// **'has none of'**
  String get viewWidgetsOpHasNoneOf;

  /// No description provided for @viewWidgetsOpIsNoneOf.
  ///
  /// In en, this message translates to:
  /// **'is none of'**
  String get viewWidgetsOpIsNoneOf;

  /// No description provided for @viewWidgetsOpIsChecked.
  ///
  /// In en, this message translates to:
  /// **'is checked'**
  String get viewWidgetsOpIsChecked;

  /// No description provided for @viewWidgetsOpIsNotChecked.
  ///
  /// In en, this message translates to:
  /// **'is not checked'**
  String get viewWidgetsOpIsNotChecked;

  /// No description provided for @viewWidgetsSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get viewWidgetsSort;

  /// No description provided for @viewWidgetsRemoveFilter.
  ///
  /// In en, this message translates to:
  /// **'Remove filter'**
  String get viewWidgetsRemoveFilter;

  /// No description provided for @viewWidgetsAddFilter.
  ///
  /// In en, this message translates to:
  /// **'Add filter'**
  String get viewWidgetsAddFilter;

  /// No description provided for @viewWidgetsFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get viewWidgetsFilter;

  /// No description provided for @viewWidgetsFieldsIntroTiles.
  ///
  /// In en, this message translates to:
  /// **'Choose which fields show as tiles in “{view}” and drag to set their order.'**
  String viewWidgetsFieldsIntroTiles(String view);

  /// No description provided for @viewWidgetsFieldsIntroCard.
  ///
  /// In en, this message translates to:
  /// **'Choose which fields show on each card in “{view}” and drag to set their order.'**
  String viewWidgetsFieldsIntroCard(String view);

  /// No description provided for @viewWidgetsPreviewHeading.
  ///
  /// In en, this message translates to:
  /// **'PREVIEW'**
  String get viewWidgetsPreviewHeading;

  /// No description provided for @viewWidgetsPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get viewWidgetsPreview;

  /// No description provided for @viewWidgetsEmptyFieldsSkipped.
  ///
  /// In en, this message translates to:
  /// **'Empty fields are skipped on the card.'**
  String get viewWidgetsEmptyFieldsSkipped;

  /// No description provided for @viewWidgetsShowColumn.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get viewWidgetsShowColumn;

  /// No description provided for @viewWidgetsLayoutBoard.
  ///
  /// In en, this message translates to:
  /// **'{field} is shown as the columns'**
  String viewWidgetsLayoutBoard(String field);

  /// No description provided for @viewWidgetsLayoutCalendar.
  ///
  /// In en, this message translates to:
  /// **'{field} places each card on its day'**
  String viewWidgetsLayoutCalendar(String field);

  /// No description provided for @viewWidgetsLayoutSeparate.
  ///
  /// In en, this message translates to:
  /// **'{field} is shown separately'**
  String viewWidgetsLayoutSeparate(String field);

  /// No description provided for @viewWidgetsTitleColumn.
  ///
  /// In en, this message translates to:
  /// **'Title column'**
  String get viewWidgetsTitleColumn;

  /// No description provided for @viewWidgetsCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Card title'**
  String get viewWidgetsCardTitle;

  /// No description provided for @viewWidgetsChangeTitleColumn.
  ///
  /// In en, this message translates to:
  /// **'Change title column'**
  String get viewWidgetsChangeTitleColumn;

  /// No description provided for @viewWidgetsChangeCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Change card title'**
  String get viewWidgetsChangeCardTitle;

  /// No description provided for @viewWidgetsReorderField.
  ///
  /// In en, this message translates to:
  /// **'Reorder {field}'**
  String viewWidgetsReorderField(String field);

  /// No description provided for @viewWidgetsMoveField.
  ///
  /// In en, this message translates to:
  /// **'Move {field}'**
  String viewWidgetsMoveField(String field);

  /// No description provided for @viewWidgetsMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get viewWidgetsMoveUp;

  /// No description provided for @viewWidgetsMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get viewWidgetsMoveDown;

  /// No description provided for @viewWidgetsSortManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get viewWidgetsSortManual;

  /// No description provided for @viewWidgetsSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get viewWidgetsSortBy;

  /// No description provided for @viewWidgetsSortAsc.
  ///
  /// In en, this message translates to:
  /// **'Asc'**
  String get viewWidgetsSortAsc;

  /// No description provided for @viewWidgetsSortAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get viewWidgetsSortAscending;

  /// No description provided for @viewWidgetsSortDesc.
  ///
  /// In en, this message translates to:
  /// **'Desc'**
  String get viewWidgetsSortDesc;

  /// No description provided for @viewWidgetsSortDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get viewWidgetsSortDescending;

  /// No description provided for @viewWidgetsModeGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get viewWidgetsModeGallery;

  /// No description provided for @viewWidgetsModeGalleryDescription.
  ///
  /// In en, this message translates to:
  /// **'Cards with pictures'**
  String get viewWidgetsModeGalleryDescription;

  /// No description provided for @viewWidgetsModeGalleryReason.
  ///
  /// In en, this message translates to:
  /// **'Needs image files'**
  String get viewWidgetsModeGalleryReason;

  /// No description provided for @viewWidgetsName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get viewWidgetsName;

  /// No description provided for @viewWidgetsNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Pipeline'**
  String get viewWidgetsNameHint;

  /// No description provided for @viewWidgetsCreateView.
  ///
  /// In en, this message translates to:
  /// **'Create view'**
  String get viewWidgetsCreateView;

  /// No description provided for @viewWidgetsNewItem.
  ///
  /// In en, this message translates to:
  /// **'New {item}'**
  String viewWidgetsNewItem(String item);

  /// No description provided for @viewWidgetsAddDetails.
  ///
  /// In en, this message translates to:
  /// **'Add details'**
  String get viewWidgetsAddDetails;

  /// No description provided for @viewWidgetsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get viewWidgetsLoading;

  /// No description provided for @viewWidgetsNothingMatchesFilters.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches these filters'**
  String get viewWidgetsNothingMatchesFilters;

  /// No description provided for @viewWidgetsClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get viewWidgetsClearFilters;

  /// No description provided for @viewWidgetsNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get viewWidgetsNoDate;

  /// No description provided for @viewWidgetsShowNoDate.
  ///
  /// In en, this message translates to:
  /// **'Show No date ({count})'**
  String viewWidgetsShowNoDate(int count);

  /// No description provided for @viewWidgetsHideNoDate.
  ///
  /// In en, this message translates to:
  /// **'Hide No date'**
  String get viewWidgetsHideNoDate;

  /// No description provided for @viewWidgetsDropToClearDate.
  ///
  /// In en, this message translates to:
  /// **'Drop to clear the date'**
  String get viewWidgetsDropToClearDate;

  /// No description provided for @viewWidgetsEveryItemHasDate.
  ///
  /// In en, this message translates to:
  /// **'Every {item} has a date. Drop one here to clear it.'**
  String viewWidgetsEveryItemHasDate(String item);

  /// No description provided for @viewWidgetsNothingScheduled.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled yet'**
  String get viewWidgetsNothingScheduled;

  /// No description provided for @viewWidgetsCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get viewWidgetsCollapse;

  /// No description provided for @viewWidgetsExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get viewWidgetsExpand;

  /// No description provided for @viewWidgetsDayToday.
  ///
  /// In en, this message translates to:
  /// **'{day} · Today'**
  String viewWidgetsDayToday(String day);

  /// No description provided for @viewWidgetsMoveToDate.
  ///
  /// In en, this message translates to:
  /// **'Move to date'**
  String get viewWidgetsMoveToDate;

  /// No description provided for @viewWidgetsClearedDate.
  ///
  /// In en, this message translates to:
  /// **'Cleared the date of \"{title}\"'**
  String viewWidgetsClearedDate(String title);

  /// No description provided for @viewWidgetsMovedToDay.
  ///
  /// In en, this message translates to:
  /// **'Moved \"{title}\" to {day}'**
  String viewWidgetsMovedToDay(String title, String day);

  /// No description provided for @viewWidgetsPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get viewWidgetsPreviousMonth;

  /// No description provided for @viewWidgetsNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get viewWidgetsNextMonth;

  /// No description provided for @viewWidgetsClickDayToAdd.
  ///
  /// In en, this message translates to:
  /// **'Click a day to add a {item}'**
  String viewWidgetsClickDayToAdd(String item);

  /// No description provided for @viewWidgetsNewItemOnDay.
  ///
  /// In en, this message translates to:
  /// **'New {item} on {day}'**
  String viewWidgetsNewItemOnDay(String item, String day);

  /// No description provided for @viewWidgetsShowAllMore.
  ///
  /// In en, this message translates to:
  /// **'Show all, {count} more'**
  String viewWidgetsShowAllMore(int count);

  /// No description provided for @viewWidgetsMoreCount.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String viewWidgetsMoreCount(int count);

  /// No description provided for @viewWidgetsJumpToColumn.
  ///
  /// In en, this message translates to:
  /// **'{column}, {count}. Jump to column'**
  String viewWidgetsJumpToColumn(String column, int count);

  /// No description provided for @viewWidgetsNewItemInColumn.
  ///
  /// In en, this message translates to:
  /// **'New {item} in {column}'**
  String viewWidgetsNewItemInColumn(String item, String column);

  /// No description provided for @viewWidgetsCollapseColumn.
  ///
  /// In en, this message translates to:
  /// **'Collapse {column}'**
  String viewWidgetsCollapseColumn(String column);

  /// No description provided for @viewWidgetsDropToClearField.
  ///
  /// In en, this message translates to:
  /// **'Drop here to clear {field}'**
  String viewWidgetsDropToClearField(String field);

  /// No description provided for @viewWidgetsNoItems.
  ///
  /// In en, this message translates to:
  /// **'No {items}'**
  String viewWidgetsNoItems(String items);

  /// No description provided for @viewWidgetsExpandColumn.
  ///
  /// In en, this message translates to:
  /// **'Expand {column}, {count, plural, =0{No {items}} =1{1 {item}} other{{count} {items}}}'**
  String viewWidgetsExpandColumn(
    String column,
    int count,
    String item,
    String items,
  );

  /// No description provided for @viewWidgetsViewSettings.
  ///
  /// In en, this message translates to:
  /// **'View settings'**
  String get viewWidgetsViewSettings;

  /// No description provided for @viewWidgetsMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get viewWidgetsMode;

  /// No description provided for @viewWidgetsManualOrder.
  ///
  /// In en, this message translates to:
  /// **'Manual order'**
  String get viewWidgetsManualOrder;

  /// No description provided for @viewWidgetsColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get viewWidgetsColumns;

  /// No description provided for @viewWidgetsCardFields.
  ///
  /// In en, this message translates to:
  /// **'Card fields'**
  String get viewWidgetsCardFields;

  /// No description provided for @viewWidgetsShownCount.
  ///
  /// In en, this message translates to:
  /// **'{count} shown'**
  String viewWidgetsShownCount(int count);

  /// No description provided for @viewWidgetsFilterBy.
  ///
  /// In en, this message translates to:
  /// **'Filter by'**
  String get viewWidgetsFilterBy;

  /// No description provided for @viewWidgetsUpdateFilter.
  ///
  /// In en, this message translates to:
  /// **'Update filter'**
  String get viewWidgetsUpdateFilter;

  /// No description provided for @viewWidgetsSearchFields.
  ///
  /// In en, this message translates to:
  /// **'Search fields'**
  String get viewWidgetsSearchFields;

  /// No description provided for @viewWidgetsNoFieldsMatch.
  ///
  /// In en, this message translates to:
  /// **'No fields match'**
  String get viewWidgetsNoFieldsMatch;

  /// No description provided for @viewWidgetsNoOptionsYet.
  ///
  /// In en, this message translates to:
  /// **'This field has no options yet'**
  String get viewWidgetsNoOptionsYet;

  /// No description provided for @viewWidgetsMissingItem.
  ///
  /// In en, this message translates to:
  /// **'Missing item'**
  String get viewWidgetsMissingItem;

  /// No description provided for @viewWidgetsNothingToLink.
  ///
  /// In en, this message translates to:
  /// **'Nothing to link to yet'**
  String get viewWidgetsNothingToLink;

  /// No description provided for @viewWidgetsNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get viewWidgetsNumberHint;

  /// No description provided for @viewWidgetsTextHint.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get viewWidgetsTextHint;

  /// No description provided for @viewWidgetsEnterNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get viewWidgetsEnterNumber;

  /// No description provided for @viewWidgetsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get viewWidgetsNoMatches;

  /// No description provided for @viewWidgetsLoadingItems.
  ///
  /// In en, this message translates to:
  /// **'Loading items'**
  String get viewWidgetsLoadingItems;

  /// No description provided for @viewWidgetsLoadingItemsEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Loading items…'**
  String get viewWidgetsLoadingItemsEllipsis;

  /// No description provided for @inboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get inboxTitle;

  /// No description provided for @inboxSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save — {error}'**
  String inboxSaveFailed(String error);

  /// No description provided for @inboxDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get inboxDone;

  /// No description provided for @inboxMovedToToday.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Moved 1 task to today} other{Moved {count} tasks to today}}'**
  String inboxMovedToToday(int count);

  /// No description provided for @inboxEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Inbox is empty'**
  String get inboxEmptyTitle;

  /// No description provided for @inboxEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Jot down notes, plan tasks and get reminded. Link anything to a card.'**
  String get inboxEmptyMessage;

  /// No description provided for @inboxLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your Inbox.'**
  String get inboxLoadFailed;

  /// No description provided for @inboxAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add a note…'**
  String get inboxAddNote;

  /// No description provided for @inboxAddTask.
  ///
  /// In en, this message translates to:
  /// **'Add a task…'**
  String get inboxAddTask;

  /// No description provided for @inboxAddTaskToday.
  ///
  /// In en, this message translates to:
  /// **'Add a task for today…'**
  String get inboxAddTaskToday;

  /// No description provided for @inboxAddTaskFor.
  ///
  /// In en, this message translates to:
  /// **'Add a task for {day}…'**
  String inboxAddTaskFor(String day);

  /// No description provided for @inboxTaskSwitchToNote.
  ///
  /// In en, this message translates to:
  /// **'Task — switch to note'**
  String get inboxTaskSwitchToNote;

  /// No description provided for @inboxNoteSwitchToTask.
  ///
  /// In en, this message translates to:
  /// **'Note — switch to task'**
  String get inboxNoteSwitchToTask;

  /// No description provided for @inboxTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get inboxTask;

  /// No description provided for @inboxNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get inboxNote;

  /// No description provided for @inboxTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get inboxTitleHint;

  /// No description provided for @inboxDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get inboxDetailsHint;

  /// No description provided for @inboxDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get inboxDate;

  /// No description provided for @inboxNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get inboxNoDate;

  /// No description provided for @inboxClearDate.
  ///
  /// In en, this message translates to:
  /// **'Clear date'**
  String get inboxClearDate;

  /// No description provided for @inboxTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get inboxTomorrow;

  /// No description provided for @inboxNextMonday.
  ///
  /// In en, this message translates to:
  /// **'Next Monday'**
  String get inboxNextMonday;

  /// No description provided for @inboxNextMon.
  ///
  /// In en, this message translates to:
  /// **'Next Mon'**
  String get inboxNextMon;

  /// No description provided for @inboxPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick…'**
  String get inboxPickDate;

  /// No description provided for @inboxTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get inboxTime;

  /// No description provided for @inboxAddTime.
  ///
  /// In en, this message translates to:
  /// **'Add a time'**
  String get inboxAddTime;

  /// No description provided for @inboxClearTime.
  ///
  /// In en, this message translates to:
  /// **'Clear time'**
  String get inboxClearTime;

  /// No description provided for @inboxSetDateForTime.
  ///
  /// In en, this message translates to:
  /// **'Set a date to add a time'**
  String get inboxSetDateForTime;

  /// No description provided for @inboxReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get inboxReminder;

  /// No description provided for @inboxReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get inboxReminders;

  /// No description provided for @inboxNoReminders.
  ///
  /// In en, this message translates to:
  /// **'No reminders'**
  String get inboxNoReminders;

  /// No description provided for @inboxAddReminder.
  ///
  /// In en, this message translates to:
  /// **'Add a reminder'**
  String get inboxAddReminder;

  /// No description provided for @inboxRemoveReminder.
  ///
  /// In en, this message translates to:
  /// **'Remove reminder'**
  String get inboxRemoveReminder;

  /// No description provided for @inboxSetDateForReminder.
  ///
  /// In en, this message translates to:
  /// **'Set a date to add a reminder'**
  String get inboxSetDateForReminder;

  /// No description provided for @inboxSetDateForReminders.
  ///
  /// In en, this message translates to:
  /// **'Set a date to add reminders'**
  String get inboxSetDateForReminders;

  /// No description provided for @inboxReminderAtTime.
  ///
  /// In en, this message translates to:
  /// **'At time'**
  String get inboxReminderAtTime;

  /// No description provided for @inboxReminder15MinBefore.
  ///
  /// In en, this message translates to:
  /// **'15 min before'**
  String get inboxReminder15MinBefore;

  /// No description provided for @inboxReminder15Min.
  ///
  /// In en, this message translates to:
  /// **'15 min'**
  String get inboxReminder15Min;

  /// No description provided for @inboxReminder1HourBefore.
  ///
  /// In en, this message translates to:
  /// **'1 h before'**
  String get inboxReminder1HourBefore;

  /// No description provided for @inboxReminder1Hour.
  ///
  /// In en, this message translates to:
  /// **'1 h'**
  String get inboxReminder1Hour;

  /// No description provided for @inboxReminder1DayBefore.
  ///
  /// In en, this message translates to:
  /// **'1 day before'**
  String get inboxReminder1DayBefore;

  /// No description provided for @inboxReminder1Day.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get inboxReminder1Day;

  /// No description provided for @inboxReminderMorningOf.
  ///
  /// In en, this message translates to:
  /// **'Morning of'**
  String get inboxReminderMorningOf;

  /// No description provided for @inboxReminderDayBefore.
  ///
  /// In en, this message translates to:
  /// **'Day before'**
  String get inboxReminderDayBefore;

  /// No description provided for @inboxReminderMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String inboxReminderMinutes(int minutes);

  /// No description provided for @inboxNotificationsDefault.
  ///
  /// In en, this message translates to:
  /// **'Reminders pop up while Morkva is open. {link} to see them in other tabs too.'**
  String inboxNotificationsDefault(String link);

  /// No description provided for @inboxTurnOnNotifications.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications'**
  String get inboxTurnOnNotifications;

  /// No description provided for @inboxNotificationsGranted.
  ///
  /// In en, this message translates to:
  /// **'Reminders pop up while Morkva is open in a tab.'**
  String get inboxNotificationsGranted;

  /// No description provided for @inboxNotificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked for this site — reminders show only inside Morkva.'**
  String get inboxNotificationsDenied;

  /// No description provided for @inboxLinkCard.
  ///
  /// In en, this message translates to:
  /// **'Link a card'**
  String get inboxLinkCard;

  /// No description provided for @inboxRemoveLink.
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get inboxRemoveLink;

  /// No description provided for @inboxOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Open {label}'**
  String inboxOpenLink(String label);

  /// No description provided for @inboxCardDeleted.
  ///
  /// In en, this message translates to:
  /// **'Card deleted'**
  String get inboxCardDeleted;

  /// No description provided for @inboxCollectionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Collection deleted'**
  String get inboxCollectionDeleted;

  /// No description provided for @inboxDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get inboxDeleted;

  /// No description provided for @inboxDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'Your changes to this item haven\'t been saved.'**
  String get inboxDiscardMessage;

  /// No description provided for @inboxOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get inboxOverdue;

  /// No description provided for @inboxCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get inboxCompleted;

  /// No description provided for @inboxMoveAllToToday.
  ///
  /// In en, this message translates to:
  /// **'Move all to today'**
  String get inboxMoveAllToToday;

  /// No description provided for @inboxNothingForToday.
  ///
  /// In en, this message translates to:
  /// **'Nothing for today'**
  String get inboxNothingForToday;

  /// No description provided for @inboxNothingFor.
  ///
  /// In en, this message translates to:
  /// **'Nothing for {day}'**
  String inboxNothingFor(String day);

  /// No description provided for @inboxDaysLate.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 d late} other{{days} d late}}'**
  String inboxDaysLate(int days);

  /// No description provided for @inboxMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Mark done'**
  String get inboxMarkDone;

  /// No description provided for @inboxMarkNotDone.
  ///
  /// In en, this message translates to:
  /// **'Mark not done'**
  String get inboxMarkNotDone;

  /// No description provided for @inboxPickDateIn.
  ///
  /// In en, this message translates to:
  /// **'{month}, pick a date'**
  String inboxPickDateIn(String month);

  /// No description provided for @inboxPreviousWeek.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get inboxPreviousWeek;

  /// No description provided for @inboxNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get inboxNextWeek;

  /// No description provided for @inboxStripDay.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{{day}} =1{{day}, 1 open} other{{day}, {count} open}}'**
  String inboxStripDay(String day, int count);

  /// No description provided for @inboxStripDayToday.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{{day}, today} =1{{day}, today, 1 open} other{{day}, today, {count} open}}'**
  String inboxStripDayToday(String day, int count);

  /// No description provided for @inboxCardsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the cards'**
  String get inboxCardsLoadFailed;

  /// No description provided for @inboxCollectionsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the collections'**
  String get inboxCollectionsLoadFailed;

  /// No description provided for @inboxSearchCollections.
  ///
  /// In en, this message translates to:
  /// **'Search collections'**
  String get inboxSearchCollections;

  /// No description provided for @inboxNoCollections.
  ///
  /// In en, this message translates to:
  /// **'No collections yet'**
  String get inboxNoCollections;

  /// No description provided for @inboxNoCollectionsMatch.
  ///
  /// In en, this message translates to:
  /// **'No collections match “{query}”'**
  String inboxNoCollectionsMatch(String query);

  /// No description provided for @inboxSearchIn.
  ///
  /// In en, this message translates to:
  /// **'Search {name}'**
  String inboxSearchIn(String name);

  /// No description provided for @inboxShownOf.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total}'**
  String inboxShownOf(int shown, int total);

  /// No description provided for @inboxCollectionNoCards.
  ///
  /// In en, this message translates to:
  /// **'{name} has no cards yet'**
  String inboxCollectionNoCards(String name);

  /// No description provided for @inboxNoCardsMatch.
  ///
  /// In en, this message translates to:
  /// **'No cards match “{query}”'**
  String inboxNoCardsMatch(String query);

  /// No description provided for @inboxBackToCollections.
  ///
  /// In en, this message translates to:
  /// **'Back to collections'**
  String get inboxBackToCollections;

  /// No description provided for @inboxLinkStepCollection.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 2 · Choose a collection'**
  String get inboxLinkStepCollection;

  /// No description provided for @inboxLinkStepCard.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 2 · Choose a card'**
  String get inboxLinkStepCard;

  /// No description provided for @inboxAddToInbox.
  ///
  /// In en, this message translates to:
  /// **'Add to Inbox'**
  String get inboxAddToInbox;

  /// No description provided for @inboxAddToInboxMenu.
  ///
  /// In en, this message translates to:
  /// **'Add to Inbox…'**
  String get inboxAddToInboxMenu;

  /// No description provided for @inboxCardOpenCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Inbox · 1 open} other{Inbox · {count} open}}'**
  String inboxCardOpenCount(int count);

  /// No description provided for @inboxDueCount.
  ///
  /// In en, this message translates to:
  /// **'{count} due'**
  String inboxDueCount(int count);

  /// No description provided for @inboxDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get inboxDismiss;

  /// No description provided for @inboxDismissAll.
  ///
  /// In en, this message translates to:
  /// **'Dismiss all'**
  String get inboxDismissAll;

  /// No description provided for @inboxReminderFor.
  ///
  /// In en, this message translates to:
  /// **'Reminder: {title}'**
  String inboxReminderFor(String title);

  /// No description provided for @inboxRemindersAway.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reminder while you were away} other{{count} reminders while you were away}}'**
  String inboxRemindersAway(int count);

  /// No description provided for @inboxMoreCount.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String inboxMoreCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
