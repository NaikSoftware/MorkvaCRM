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

  /// No description provided for @assistantConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get assistantConsentTitle;

  /// No description provided for @assistantConsentData.
  ///
  /// In en, this message translates to:
  /// **'To answer, Ask Morkva sends your question and the parts of your data it needs to Google’s Gemini.'**
  String get assistantConsentData;

  /// No description provided for @assistantConsentFreeTier.
  ///
  /// In en, this message translates to:
  /// **'On the free tier Google may use prompts and answers to improve its products, so keep sensitive details out of your questions.'**
  String get assistantConsentFreeTier;

  /// No description provided for @assistantDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Answers can be wrong — check important numbers.'**
  String get assistantDisclaimer;

  /// No description provided for @assistantEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Ask Morkva'**
  String get assistantEnable;

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
  /// **'matching {query}'**
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
