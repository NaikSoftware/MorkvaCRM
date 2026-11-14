// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get shellAllCollections => 'Усі колекції';

  @override
  String get shellNavAll => 'Усі';

  @override
  String get shellCollapseSidebar => 'Згорнути бічну панель';

  @override
  String get shellExpandSidebar => 'Розгорнути бічну панель';

  @override
  String get shellPinnedHeader => 'ЗАКРІПЛЕНІ';

  @override
  String get shellPinnedEmpty =>
      'Закріплюйте колекції, якими користуєтеся найчастіше: натисніть значок шпильки біля будь-якої колекції в розділі «Усі колекції».';

  @override
  String get shellUnpin => 'Відкріпити';

  @override
  String get shellDragToReorder => 'Перетягніть, щоб змінити порядок';

  @override
  String get shellJumpTo => 'Перейти до…';

  @override
  String shellJumpToShortcut(String shortcut) {
    return 'Перейти до… ($shortcut)';
  }

  @override
  String get shellJumpHint => 'Перейти до колекції';

  @override
  String shellJumpNoMatch(String query) {
    return 'Не знайдено колекцій за запитом «$query»';
  }

  @override
  String get shellAskMorkva => 'Запитати Моркву';

  @override
  String shellAskMorkvaShortcut(String shortcut) {
    return 'Запитати Моркву · $shortcut';
  }

  @override
  String get shellAccountAndSettings => 'Обліковий запис і налаштування';

  @override
  String get shellSyncSynced => 'Збережено';

  @override
  String get shellSyncSyncing => 'Синхронізація…';

  @override
  String get shellSyncOffline => 'Офлайн';

  @override
  String get shellSyncConflict => 'Конфлікт';

  @override
  String get shellSyncError => 'Помилка синхронізації';

  @override
  String shellSyncStatus(String status) {
    return 'Стан синхронізації: $status';
  }

  @override
  String shellSyncStatusDismiss(String status) {
    return 'Стан синхронізації: $status. Торкніться, щоб закрити.';
  }

  @override
  String designTypeToConfirm(String text) {
    return 'Введіть «$text», щоб підтвердити';
  }

  @override
  String get designChangeIcon => 'Змінити значок';

  @override
  String get designChooseIcon => 'Виберіть значок';

  @override
  String get designIconNone => 'Без значка';

  @override
  String get designIconCards => 'Картки';

  @override
  String get designIconGrid => 'Сітка';

  @override
  String get designIconInventory => 'Склад';

  @override
  String get designIconShipping => 'Доставка';

  @override
  String get designIconOrders => 'Замовлення';

  @override
  String get designIconProducts => 'Товари';

  @override
  String get designIconPricing => 'Ціни';

  @override
  String get designIconPeople => 'Люди';

  @override
  String get designIconContact => 'Контакт';

  @override
  String get designIconCompany => 'Компанія';

  @override
  String get designIconStore => 'Магазин';

  @override
  String get designIconFinance => 'Фінанси';

  @override
  String get designIconInvoices => 'Рахунки';

  @override
  String get designIconSchedule => 'Розклад';

  @override
  String get designIconTasks => 'Завдання';

  @override
  String get designIconDocuments => 'Документи';

  @override
  String get designIconNotes => 'Нотатки';

  @override
  String get designIconFavorites => 'Вибране';

  @override
  String get designIconPriorities => 'Пріоритети';

  @override
  String get designIconProperties => 'Нерухомість';

  @override
  String get designIconVehicles => 'Транспорт';

  @override
  String get designIconServices => 'Послуги';

  @override
  String get designIconPets => 'Тварини';

  @override
  String get designIconMenu => 'Меню';

  @override
  String get assistantAskMorkva => 'Запитати Моркву';

  @override
  String get assistantConversationHistory => 'Історія розмов';

  @override
  String get assistantNewConversation => 'Нова розмова';

  @override
  String get assistantCloseAssistant => 'Закрити помічника';

  @override
  String get assistantBackToConversation => 'Назад до розмови';

  @override
  String get assistantConversations => 'Розмови';

  @override
  String get assistantGreeting => 'Вітаю! Що подивимося?';

  @override
  String assistantGreetingNamed(String name) {
    return 'Вітаю, $name! Що подивимося?';
  }

  @override
  String assistantIntroOne(String name) {
    return 'Я можу читати вашу колекцію «$name», рахувати показники та вносити зміни — кожну зміну ви підтверджуєте заздалегідь.';
  }

  @override
  String assistantIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Я можу читати всі $count ваших колекцій, рахувати показники та вносити зміни — кожну зміну ви підтверджуєте заздалегідь.',
      many:
          'Я можу читати всі $count ваших колекцій, рахувати показники та вносити зміни — кожну зміну ви підтверджуєте заздалегідь.',
      few:
          'Я можу читати всі $count ваші колекції, рахувати показники та вносити зміни — кожну зміну ви підтверджуєте заздалегідь.',
      one:
          'Я можу читати всі ваші колекції ($count), рахувати показники та вносити зміни — кожну зміну ви підтверджуєте заздалегідь.',
      zero:
          'Я допоможу створити колекції, порахувати показники та внести зміни — кожну зміну ви підтверджуєте заздалегідь.',
    );
    return '$_temp0';
  }

  @override
  String get assistantSuggestAsk => 'Запитати';

  @override
  String get assistantSuggestAnalyze => 'Аналізувати';

  @override
  String get assistantSuggestAct => 'Діяти';

  @override
  String get assistantSuggestHelp => 'З чим ти можеш допомогти?';

  @override
  String get assistantSuggestCreateClients =>
      'Створи колекцію «Клієнти» з полями: ім’я, телефон, місто';

  @override
  String get assistantSuggestSetUpOrders =>
      'Налаштуй колекцію «Замовлення», пов’язану з колекцією «Клієнти»';

  @override
  String assistantSuggestHowMany(String name) {
    return 'Скільки карток додано до «$name» цього місяця?';
  }

  @override
  String assistantSuggestNewest(String name) {
    return 'Покажи 5 найновіших карток у «$name»';
  }

  @override
  String assistantSuggestByMonth(String name) {
    return '«$name» за місяцями цього року';
  }

  @override
  String assistantSuggestCompare(String name) {
    return 'Порівняй «$name» за цей і минулий місяць';
  }

  @override
  String assistantSuggestLinked(String name) {
    return 'Додай нову колекцію, пов’язану з «$name»';
  }

  @override
  String assistantSuggestNotes(String name) {
    return 'Додай поле «Нотатки» до «$name»';
  }

  @override
  String get assistantConsentTitle => 'Перш ніж почати';

  @override
  String get assistantConsentData =>
      'Щоб відповісти, Морква надсилає ваше запитання й потрібні дані до Gemini від Google.';

  @override
  String get assistantConsentFreeTier =>
      'На безкоштовному тарифі Google може використовувати запити й відповіді для покращення своїх продуктів, тож не додавайте до запитань конфіденційних даних.';

  @override
  String get assistantDisclaimer =>
      'Відповіді можуть бути помилковими — перевіряйте важливі числа.';

  @override
  String get assistantEnable => 'Увімкнути Моркву';

  @override
  String get assistantOffTitle => 'Моркву вимкнено';

  @override
  String get assistantOffBody =>
      'Моркву не ввімкнено для вашого облікового запису.';

  @override
  String get assistantNotSetUpTitle => 'Ще не налаштовано';

  @override
  String get assistantNotSetUpBody =>
      'Моркву ще не налаштовано для цього проєкту.';

  @override
  String get assistantUnavailableTitle => 'Морква недоступна';

  @override
  String get assistantTryLater => 'Спробуйте пізніше.';

  @override
  String assistantOpenObject(String label) {
    return 'Відкрити: $label';
  }

  @override
  String get assistantRemoveContext => 'Прибрати контекст';

  @override
  String assistantLookingAt(String target) {
    return 'Відкрито: $target';
  }

  @override
  String assistantShownCount(int count) {
    return 'показано $count';
  }

  @override
  String get assistantJumpToLatest => 'До останніх повідомлень';

  @override
  String get assistantThinking => 'Думаю…';

  @override
  String assistantWaitLarge(int seconds) {
    return 'Розмова велика, тож чекаємо $seconds с.';
  }

  @override
  String get assistantBusyRetryingNow =>
      'Gemini зараз перевантажено. Повторюємо…';

  @override
  String assistantBusyRetryingIn(int seconds) {
    return 'Gemini перевантажено. Повтор через $seconds с.';
  }

  @override
  String get assistantWaitLargeSpoken =>
      'Розмова велика, тож трохи зачекаємо, перш ніж продовжити.';

  @override
  String get assistantBusyRetryingShortly =>
      'Gemini перевантажено. Незабаром повторимо.';

  @override
  String assistantDailyLimit(String time) {
    return 'Безкоштовний ліміт ШІ на сьогодні вичерпано. Він оновиться о $time.';
  }

  @override
  String get assistantRetryNow => 'Повторити зараз';

  @override
  String get assistantDeleteThreadTitle => 'Видалити цю розмову?';

  @override
  String assistantDeleteThreadBody(String title) {
    return 'Розмову «$title» та її повідомлення буде видалено. Зміни, які вона внесла у ваші дані, залишаться.';
  }

  @override
  String assistantDeleteThreadTooltip(String title) {
    return 'Видалити «$title»';
  }

  @override
  String get assistantNoThreads => 'Розмов ще немає';

  @override
  String get assistantNoThreadsBody => 'Поставте запитання, щоб почати.';

  @override
  String get assistantNothingFound => 'Нічого не знайдено';

  @override
  String assistantNoThreadsMatch(String query) {
    return 'Немає розмов за запитом «$query».';
  }

  @override
  String get assistantApplyingSwitchLater =>
      'Застосовуємо зміни… Перейти до іншої розмови можна буде після завершення.';

  @override
  String get assistantSearchThreads => 'Пошук розмов';

  @override
  String get assistantComposerHint =>
      'Запитайте про дані або скажіть, що змінити…';

  @override
  String get assistantComposerFollowUp => 'Запитайте ще щось…';

  @override
  String get assistantMessageField => 'Повідомлення для Моркви';

  @override
  String get assistantOffline => 'Ви офлайн — Моркві потрібне з’єднання.';

  @override
  String assistantPausedUntil(String time) {
    return 'Морква на паузі до $time.';
  }

  @override
  String get assistantApplyingChanges => 'Застосовуємо зміни…';

  @override
  String assistantApproveOrKeep(String noun) {
    return 'Підтвердьте видалення або залиште $noun як є — чи надішліть нове повідомлення, щоб пропустити.';
  }

  @override
  String get assistantApproveOrKeepItems =>
      'Підтвердьте видалення вище або залиште все як є — чи надішліть нове повідомлення, щоб пропустити.';

  @override
  String get assistantApproveOrReject =>
      'Підтвердьте або відхиліть зміни вище — чи надішліть нове повідомлення, щоб їх пропустити.';

  @override
  String get assistantStopGenerating => 'Зупинити';

  @override
  String get assistantSend => 'Надіслати';

  @override
  String assistantStepsShow(String headline) {
    return 'Кроки: $headline. Показати кожен крок';
  }

  @override
  String get assistantSteps => 'Кроки';

  @override
  String get assistantHideSteps => 'Сховати кроки';

  @override
  String get assistantStepFailed => 'не вдалося';

  @override
  String get assistantNoChartData => 'Немає даних для діаграми';

  @override
  String get assistantShowAsChart => 'Показати діаграмою';

  @override
  String get assistantShowAsTable => 'Показати таблицею';

  @override
  String assistantSaveAsView(String name) {
    return 'Зберегти як подання в «$name»';
  }

  @override
  String assistantSaveAsViewPrompt(String title, String name) {
    return 'Збережи «$title» як подання в «$name»';
  }

  @override
  String get assistantSoFar => 'поки що';

  @override
  String assistantPointSoFar(String label) {
    return '$label (поки що)';
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
      'bar': 'Стовпчикова діаграма',
      'other': 'Лінійна діаграма',
    });
    return '$_temp0: $metric, від $first до $last$details';
  }

  @override
  String assistantChartPeak(String label, String value) {
    return ', пік — $label: $value';
  }

  @override
  String assistantShowingRows(int shown, int total) {
    return 'Показано $shown з $total';
  }

  @override
  String get assistantOpenAsFilteredView => 'Відкрити як подання з фільтром';

  @override
  String get assistantCopyTable => 'Копіювати таблицю';

  @override
  String get assistantTableCopied => 'Таблицю скопійовано';

  @override
  String assistantOpenCell(String column, String value) {
    return 'Відкрити: $column $value';
  }

  @override
  String get assistantRetryFailed => 'Повторити невдалі';

  @override
  String get assistantAppliedSchemaChange => 'Зміну структури застосовано';

  @override
  String get assistantAppliedChanges => 'Зміни застосовано';

  @override
  String assistantStaleLeft(int count) {
    return 'Змінено деінде після попереднього перегляду, залишено як є: $count';
  }

  @override
  String assistantStartedRuns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Розпочато $count запуску автоматизацій ·',
      many: 'Розпочато $count запусків автоматизацій ·',
      few: 'Розпочато $count запуски автоматизацій ·',
      one: 'Розпочато $count запуск автоматизації ·',
    );
    return '$_temp0';
  }

  @override
  String get assistantView => 'Переглянути';

  @override
  String get assistantReverted => 'Скасовано — тепер нічого не змінено';

  @override
  String get assistantUndoFailed => 'Не вдалося скасувати ці зміни';

  @override
  String assistantUpdatedSomeFailed(int done, int failed) {
    return 'Оновлено: $done, з помилкою: $failed';
  }

  @override
  String assistantApprovedOf(int done, int total) {
    return 'Ви підтвердили $done з $total';
  }

  @override
  String get assistantApplied => 'Застосовано';

  @override
  String assistantQueued(int count) {
    return 'Очікують з’єднання: $count';
  }

  @override
  String assistantAppliedNote(String note) {
    return 'Застосовано · $note';
  }

  @override
  String get assistantUndoExpired => 'Час на скасування минув';

  @override
  String get assistantUndoUntilClose =>
      'скасувати можна, доки ви не закриєте застосунок';

  @override
  String assistantUndoForMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'скасувати можна ще $minutes хвилини',
      many: 'скасувати можна ще $minutes хвилин',
      few: 'скасувати можна ще $minutes хвилини',
      one: 'скасувати можна ще $minutes хвилину',
    );
    return '$_temp0';
  }

  @override
  String get assistantStopped => 'Зупинено';

  @override
  String get assistantCutShort => 'Відповідь обірвано — попросіть продовжити';

  @override
  String get assistantProposedDeletion => 'Запропоноване видалення';

  @override
  String get assistantProposedChanges => 'Запропоновані зміни';

  @override
  String assistantMoreNotShown(int count) {
    return 'Ще не показано: $count';
  }

  @override
  String assistantShowMore(int count) {
    return 'Показати ще $count';
  }

  @override
  String assistantAllSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Вибрано всі $count',
      many: 'Вибрано всі $count',
      few: 'Вибрано всі $count',
      one: 'Вибрано всі $count',
    );
    return '$_temp0';
  }

  @override
  String get assistantNoneSelected => 'Нічого не вибрано';

  @override
  String assistantSomeSelected(int picked, int total) {
    return 'Вибрано $picked з $total';
  }

  @override
  String assistantDeleteCollectionTitle(String name) {
    return 'Видалити колекцію «$name»?';
  }

  @override
  String assistantDeleteCollectionBody(String name, String undo) {
    return 'Усі картки з «$name» буде видалено разом із нею. $undo';
  }

  @override
  String get assistantDeleteCollection => 'Видалити колекцію';

  @override
  String get assistantAppliesWithoutAsking =>
      'Застосовує зміни без підтвердження';

  @override
  String assistantPlanKind(String kind, String fallback) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'createCard': 'Створити картку',
      'updateCard': 'Змінити картку',
      'deleteCard': 'Видалити картку',
      'createCollection': 'Створити колекцію',
      'updateCollection': 'Змінити колекцію',
      'deleteCollection': 'Видалити колекцію',
      'addField': 'Додати поле',
      'updateField': 'Змінити поле',
      'deleteField': 'Видалити поле',
      'createView': 'Створити подання',
      'updateView': 'Змінити подання',
      'deleteView': 'Видалити подання',
      'saveModule': 'Зберегти модуль',
      'saveAutomation': 'Зберегти автоматизацію',
      'deleteAutomation': 'Видалити автоматизацію',
      'other': '$fallback',
    });
    return '$_temp0';
  }

  @override
  String get assistantUndoNone => 'Цю дію не можна скасувати.';

  @override
  String assistantUndoPartialFor(int minutes) {
    return 'Частину змін можна буде скасувати протягом $minutes хв.';
  }

  @override
  String get assistantUndoPartialLater =>
      'Частину змін можна буде скасувати пізніше.';

  @override
  String assistantUndoFor(int minutes) {
    return 'Скасувати зміни можна протягом $minutes хв.';
  }

  @override
  String get assistantUndoLater => 'Зміни можна буде скасувати пізніше.';

  @override
  String assistantNothingChangesUntilApproved(String undo) {
    return 'Нічого не зміниться, доки ви не підтвердите. $undo';
  }

  @override
  String assistantModuleSource(String name, String id) {
    return 'Модуль · $name ($id)';
  }

  @override
  String get assistantDiffFromEmpty => 'з порожнього';

  @override
  String get assistantDiffEmpty => 'порожньо';

  @override
  String assistantDiffFrom(String value) {
    return 'з $value';
  }

  @override
  String assistantDiffTo(String value) {
    return 'на $value';
  }

  @override
  String get assistantViewCode => 'Переглянути код';

  @override
  String get assistantApplyingChangesLabel => 'Застосовуємо зміни';

  @override
  String get assistantUpdateModule => 'Оновити модуль';

  @override
  String get assistantInstallModule => 'Встановити модуль';

  @override
  String assistantDeleteSomeOf(int count, int total) {
    return 'Видалити $count з $total';
  }

  @override
  String assistantApproveChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Підтвердити $count зміни',
      many: 'Підтвердити $count змін',
      few: 'Підтвердити $count зміни',
      one: 'Підтвердити $count зміну',
    );
    return '$_temp0';
  }

  @override
  String get assistantKeepIt => 'Залишити';

  @override
  String get assistantKeepThem => 'Залишити';

  @override
  String get assistantReject => 'Відхилити';

  @override
  String get assistantApplying => 'Застосовуємо…';

  @override
  String assistantUpdatingProgress(int done, int total) {
    return 'Оновлюємо $done з $total…';
  }

  @override
  String get assistantRejectedNothingChanged => 'Відхилено — нічого не змінено';

  @override
  String get assistantSkippedNothingChanged => 'Пропущено — нічого не змінено';

  @override
  String assistantNothingChangedAfter(String message) {
    return '$message — нічого не змінено';
  }

  @override
  String get assistantChangedElsewhere =>
      'Змінено деінде після попереднього перегляду';

  @override
  String get assistantPreviewExpired =>
      'Попередній перегляд застарів — нічого не змінено';

  @override
  String get assistantInterrupted =>
      'Перервано під час застосування — зміни могли застосуватися частково, перевірте дані';

  @override
  String get assistantCouldNotApply => 'Не вдалося застосувати зміни';

  @override
  String get assistantRebuild => 'Оновити';

  @override
  String get assistantErrorLoadPartial =>
      'Не вдалося завантажити всю розмову, тому повідомлення не надіслано. Спробуйте ще раз за мить.';

  @override
  String get assistantErrorOpen => 'Не вдалося відкрити цю розмову.';

  @override
  String get assistantNothingWasChanged => 'Нічого не змінено.';

  @override
  String get assistantApprovedWereApplied =>
      'Підтверджені вами зміни застосовано.';

  @override
  String assistantErrorWithOutcome(String message, String outcome) {
    return '$message $outcome';
  }

  @override
  String get assistantBlocked => 'Із цим запитом я не можу допомогти.';

  @override
  String get assistantErrorDailyLimit => 'Ліміт ШІ на сьогодні вичерпано.';

  @override
  String get assistantErrorBusy => 'Gemini зараз перевантажено.';

  @override
  String get assistantErrorDropped =>
      'Я не змогла завершити — з’єднання обірвалося.';

  @override
  String get assistantErrorUnknown =>
      'Щось пішло не так, і я не змогла завершити.';

  @override
  String assistantCouldNotReadResult(String message) {
    return 'Не вдалося прочитати результат ($message)';
  }

  @override
  String assistantCouldNotRetry(String message) {
    return 'Не вдалося повторити ($message)';
  }

  @override
  String get assistantNeedsConnection => 'Потрібне з’єднання';

  @override
  String get assistantNeedsConnectionToUndo =>
      'Для скасування потрібне з’єднання';

  @override
  String get assistantSnippetChart => 'діаграма';

  @override
  String get assistantSnippetTable => 'таблиця';

  @override
  String assistantStepsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Не виконано кроків: $count',
      many: 'Не виконано кроків: $count',
      few: 'Не виконано кроків: $count',
      one: 'Не виконано кроків: $count',
    );
    return '$_temp0';
  }

  @override
  String assistantResultShown(String name, int count) {
    return '$name · показано $count';
  }

  @override
  String assistantResultCards(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name · $count картки',
      many: '$name · $count карток',
      few: '$name · $count картки',
      one: '$name · $count картка',
    );
    return '$_temp0';
  }

  @override
  String assistantResultBy(String name, String group) {
    return '$name за $group';
  }

  @override
  String assistantResultWhere(String clauses) {
    return 'де $clauses';
  }

  @override
  String assistantResultMatching(String query) {
    return 'за запитом «$query»';
  }

  @override
  String assistantStepLookedAt(String name) {
    return 'Переглянуто $name';
  }

  @override
  String assistantStepFilteredTo(int count) {
    return 'відфільтровано до $count';
  }

  @override
  String assistantStepFiltered(int from, int to) {
    return 'відфільтровано $from → $to';
  }

  @override
  String assistantStepGroupedBy(String group) {
    return 'згруповано за $group';
  }

  @override
  String get assistantTableTotal => 'Разом';

  @override
  String get assistantTableAll => 'Усі';

  @override
  String assistantResultBucket(String field, String bucket) {
    return '$field ($bucket)';
  }

  @override
  String get assistantBucketDay => 'день';

  @override
  String get assistantBucketWeek => 'тиждень';

  @override
  String get assistantBucketMonth => 'місяць';

  @override
  String get assistantBucketQuarter => 'квартал';

  @override
  String get assistantBucketYear => 'рік';

  @override
  String get assistantOpCount => 'кількість';

  @override
  String get assistantOpSum => 'сума';

  @override
  String get assistantOpAverage => 'середнє';

  @override
  String get assistantOpMin => 'мінімум';

  @override
  String get assistantOpMax => 'максимум';

  @override
  String assistantMetricOf(String op, String field) {
    return '$op: $field';
  }

  @override
  String assistantMetricSummed(String field) {
    return 'сума: $field';
  }

  @override
  String assistantMetricAveraged(String field) {
    return 'середнє: $field';
  }

  @override
  String assistantMetricLowest(String field) {
    return 'мінімум: $field';
  }

  @override
  String assistantMetricHighest(String field) {
    return 'максимум: $field';
  }

  @override
  String get assistantMetricCounted => 'пораховано';

  @override
  String get authWelcomeTitle => 'Вітаємо у вашому робочому просторі';

  @override
  String get authWelcomeBody =>
      'Усі ваші колекції й картки в одному охайному місці — надійно синхронізовані на всіх пристроях, де ви ввійшли.';

  @override
  String get authPrivacyNote =>
      'Ми використовуємо ваш обліковий запис Google лише для входу. Ваші дані належать вам.';

  @override
  String get authContinueWithGoogle => 'Продовжити з Google';

  @override
  String get syncConflictSemantics => 'Попередження про конфлікт синхронізації';

  @override
  String syncConflictTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Новіші версії $count елемента збережено деінде',
      many: 'Новіші версії $count елементів збережено деінде',
      few: 'Новіші версії $count елементів збережено деінде',
      one: 'Новішу версію $count елемента збережено деінде',
    );
    return '$_temp0';
  }

  @override
  String get syncConflictBody =>
      'Ми зберегли ваші останні зміни й замінили іншу копію. Якщо та версія була важливою, внесіть ці зміни знову.';

  @override
  String get syncConflictDismiss => 'Закрити попередження про конфлікт';

  @override
  String get automationJustNow => 'щойно';

  @override
  String automationMinutesAgo(int count) {
    return '$count хв тому';
  }

  @override
  String automationHoursAgo(int count) {
    return '$count год тому';
  }

  @override
  String automationSizeBytes(int bytes) {
    return '$bytes Б';
  }

  @override
  String automationSizeKb(String kb) {
    return '$kb КБ';
  }

  @override
  String automationDurationMs(int ms) {
    return '$ms мс';
  }

  @override
  String automationDurationS(int s) {
    return '$s с';
  }

  @override
  String get automationScopeAll => 'В усіх колекціях';

  @override
  String automationScopeIn(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'У колекціях: $names',
      many: 'У колекціях: $names',
      few: 'У колекціях: $names',
      one: 'У колекції: $names',
    );
    return '$_temp0';
  }

  @override
  String get automationRemovedCollectionInline => 'видалена колекція';

  @override
  String automationWillAskFor(String titles) {
    return 'Попросить дозволи: $titles';
  }

  @override
  String get automationWhenButtonCard => 'Кнопка на картці';

  @override
  String get automationWhenButtonCollection => 'Кнопка в колекції';

  @override
  String automationWhenButtonOn(String collection) {
    return 'Кнопка в колекції «$collection»';
  }

  @override
  String get automationWhenCreated => 'Коли створено картку';

  @override
  String get automationWhenUpdated => 'Коли змінено картку';

  @override
  String get automationWhenDeleted => 'Коли видалено картку';

  @override
  String get automationListAnd => ' і ';

  @override
  String get automationListOr => ' або ';

  @override
  String automationWhenFieldsChange(String fields) {
    return 'коли змінено $fields';
  }

  @override
  String automationStartsMatchingField(String field, String condition) {
    return '$field починає відповідати «$condition»';
  }

  @override
  String automationStartsMatching(String condition) {
    return 'починає відповідати «$condition»';
  }

  @override
  String automationDoLine(String module, String action) {
    return 'Виконати: $module › $action';
  }

  @override
  String get automationRemovedModuleInline => 'видалений модуль';

  @override
  String get automationSourceImported => 'Імпортовано';

  @override
  String get automationSourceAssistant => 'Створено Морквою';

  @override
  String automationInstalledSnack(String name) {
    return 'Модуль «$name» встановлено';
  }

  @override
  String get automationAskMorkva => 'Запитати Моркву';

  @override
  String get automationAskMorkvaToWrite => 'Попросити Моркву написати';

  @override
  String get automationAskPrefill => 'Напиши модуль, який ';

  @override
  String get automationImportModule => 'Імпортувати модуль';

  @override
  String get automationEngineDownTitle =>
      'Наразі автоматизації не можуть працювати на цьому пристрої.';

  @override
  String get automationEngineDownBody =>
      'Запуски не виконуються, але записуються в журнал.';

  @override
  String get automationPageSubtitle =>
      'Модулі додають дії. Автоматизації розміщують їх на кнопках або запускають, коли змінюються картки.';

  @override
  String get automationNewAutomation => 'Нова автоматизація';

  @override
  String get automationInstallModuleFirst => 'Спершу встановіть модуль';

  @override
  String get automationTabModules => 'Модулі';

  @override
  String get automationTabRuns => 'Запуски';

  @override
  String get automationLoadErrorMessage =>
      'Перевірте з’єднання й спробуйте ще раз.';

  @override
  String get automationLoadModulesFailed => 'Не вдалося завантажити модулі';

  @override
  String get automationLoadAutomationsFailed =>
      'Не вдалося завантажити автоматизації';

  @override
  String get automationLoadRunsFailed => 'Не вдалося завантажити запуски';

  @override
  String get automationNoModulesTitle => 'Модулів ще немає';

  @override
  String get automationNoModulesMessage =>
      'Модулі додають у застосунок дії — наприклад, ставлять дату чи позначають малий залишок. Попросіть Моркву написати модуль або імпортуйте файл .morkva.json.';

  @override
  String automationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count автоматизації',
      many: '$count автоматизацій',
      few: '$count автоматизації',
      one: '$count автоматизація',
    );
    return '$_temp0';
  }

  @override
  String get automationThisCollection => 'Ця колекція';

  @override
  String get automationNoAutomationsTitle => 'Автоматизацій ще немає';

  @override
  String get automationNoAutomationsMessage =>
      'Розмістіть дію модуля на кнопці або запускайте її, коли картки створюються, змінюються чи видаляються.';

  @override
  String get automationRemovedCollection => 'Видалена колекція';

  @override
  String automationEnabledSemantics(String name) {
    return '$name: увімкнено';
  }

  @override
  String automationClearFilter(String label) {
    return 'Прибрати фільтр «$label»';
  }

  @override
  String get automationThisCard => 'Ця картка';

  @override
  String get automationThisModule => 'Цей модуль';

  @override
  String get automationFilterAll => 'Усі';

  @override
  String get automationFilterNeedsReview => 'Чекають перевірки';

  @override
  String get automationFilterFailed => 'Невдалі';

  @override
  String get automationFilterByAutomation => 'Фільтрувати за автоматизацією';

  @override
  String get automationAnyAutomation => 'Будь-яка автоматизація';

  @override
  String get automationRunningNow => 'Виконуються зараз';

  @override
  String get automationNoRunsTitle => 'Запусків ще немає';

  @override
  String get automationNoRunsMessage =>
      'Коли автоматизація запуститься, тут з’явиться її журнал — що її запустило, що вона прочитала і що змінила.';

  @override
  String automationSkippedGroup(int count, String reason) {
    return 'Не запущено: $count · $reason';
  }

  @override
  String get automationShow => 'Показати';

  @override
  String get automationQueued => 'У черзі';

  @override
  String automationQueuedAhead(int count) {
    return 'У черзі · попереду $count';
  }

  @override
  String get automationApplyingEllipsis => 'Застосування…';

  @override
  String get automationRunning => 'Виконується';

  @override
  String get automationStop => 'Зупинити';

  @override
  String automationSkippedTimes(int count, String reason) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Не запущено $count разу · $reason',
      many: 'Не запущено $count разів · $reason',
      few: 'Не запущено $count рази · $reason',
      one: 'Не запущено $count раз · $reason',
    );
    return '$_temp0';
  }

  @override
  String get automationUndone => 'Скасовано';

  @override
  String automationChangedOffline(String changed, String ran) {
    return 'Змінено офлайн о $changed · запущено о $ran';
  }

  @override
  String get automationReview => 'Переглянути';

  @override
  String get automationRunAgain => 'Запустити знову';

  @override
  String automationRunAgainOn(String card) {
    return 'Запустити знову для $card';
  }

  @override
  String get automationReviewPermissions => 'Переглянути дозволи';

  @override
  String get automationEditAutomation => 'Редагувати автоматизацію';

  @override
  String get automationEditAction => 'Редагувати';

  @override
  String automationChangeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count зміни',
      many: '$count змін',
      few: '$count зміни',
      one: '$count зміна',
    );
    return '$_temp0';
  }

  @override
  String get automationNeedsConnection => 'Потрібне з’єднання';

  @override
  String get automationImportUnreadable =>
      'Не вдалося прочитати цей файл. Виберіть його ще раз або вставте вміст.';

  @override
  String get automationImportChooseFileHint => 'Виберіть файл .morkva.json';

  @override
  String get automationImportChooseFile => 'Вибрати файл';

  @override
  String get automationImportPasteHint => 'Вставте файл модуля (JSON)';

  @override
  String get automationImportSourceFile => 'Файл';

  @override
  String get automationImportSourcePaste => 'Вставити';

  @override
  String automationImportSameVersion(String version) {
    return 'Цю версію (v$version) уже встановлено.';
  }

  @override
  String automationImportReplacingTitle(String version) {
    return 'Модуль із таким id уже встановлено (v$version).';
  }

  @override
  String automationImportReplacingBody(int count, String version) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Якщо дозволити, його буде замінено на v$version для $count автоматизації.',
      many:
          'Якщо дозволити, його буде замінено на v$version для $count автоматизацій.',
      few:
          'Якщо дозволити, його буде замінено на v$version для $count автоматизацій.',
      one:
          'Якщо дозволити, його буде замінено на v$version для $count автоматизації.',
    );
    return '$_temp0';
  }

  @override
  String get automationScopeTagCard => 'На картці';

  @override
  String get automationScopeTagCollection => 'У колекції';

  @override
  String get automationScopeTagAny => 'Картка або колекція';

  @override
  String automationConsentCodeChanged(
    String fromVersion,
    String toVersion,
    String fromSize,
    String toSize,
  ) {
    return 'Код змінено: v$fromVersion → v$toVersion · $fromSize → $toSize';
  }

  @override
  String get automationConsentSameVersion => 'Цю версію вже встановлено.';

  @override
  String get automationConsentAutoApplyOffNew =>
      'Для нової версії автозастосування вимкнеться. Знову ввімкнути його можна на сторінці модуля.';

  @override
  String get automationConsentAutoApplyOffAgain =>
      'Після повторного встановлення автозастосування вимкнеться. Знову ввімкнути його можна на сторінці модуля.';

  @override
  String get automationConsentItCan => 'Модуль може:';

  @override
  String get automationConsentCapNew => 'Нове';

  @override
  String get automationConsentCapRemoved => 'Прибрано';

  @override
  String get automationConsentActions => 'Дії:';

  @override
  String get automationViewCode => 'Переглянути код';

  @override
  String get automationConsentWhere => 'Де';

  @override
  String get automationConsentAllCollections => 'Усі колекції';

  @override
  String get automationConsentAllCollectionsHint =>
      'Кожна колекція, зокрема нові.';

  @override
  String get automationOnlyThese => 'Лише вибрані';

  @override
  String get automationConsentOnlyTheseHint =>
      'Виберіть колекції, які модуль може читати й змінювати.';

  @override
  String get automationConsentSandboxNote =>
      'Модулі не мають доступу до інтернету, вашого облікового запису чи інших застосунків. Змінити або відкликати доступ можна пізніше на сторінці модуля.';

  @override
  String get automationConsentAllowAndInstall => 'Дозволити та встановити';

  @override
  String get automationConsentAllow => 'Дозволити';

  @override
  String automationConsentChangeAccessTitle(String name) {
    return 'Змінити доступ для «$name»';
  }

  @override
  String automationConsentAllowTitle(String name) {
    return 'Дозволити «$name»?';
  }

  @override
  String get automationConsentPickWhere => 'Виберіть, де модуль може працювати';

  @override
  String get automationLoadModuleFailed => 'Не вдалося завантажити модуль';

  @override
  String get automationModuleNotInstalledTitle => 'Цей модуль не встановлено';

  @override
  String get automationModuleNotInstalledMessage =>
      'Його видалили або посилання застаріло.';

  @override
  String get automationModuleAllowTitle => 'Дозвольте цьому модулю працювати.';

  @override
  String get automationModuleAllowBody =>
      'Перегляньте, що він може робити, — після цього його дії зможуть запускатися.';

  @override
  String automationModuleChangedTitle(String fromVersion, String toVersion) {
    return 'Модуль змінився (v$fromVersion → v$toVersion).';
  }

  @override
  String get automationModuleChangedBody =>
      'Його автоматизації призупинено, доки ви не дозволите нову версію.';

  @override
  String get automationReviewChanges => 'Переглянути зміни';

  @override
  String get automationModuleBrokenTitle =>
      'Файл цього модуля більше не дійсний.';

  @override
  String get automationModuleBrokenBody => 'Імпортуйте його ще раз.';

  @override
  String automationExportedSnack(String fileName) {
    return 'Файл $fileName експортовано';
  }

  @override
  String automationUninstallTitle(String name) {
    return 'Видалити модуль «$name»?';
  }

  @override
  String get automationUninstallMessageNone =>
      'Незавершені перевірки модуля буде скасовано, а його дозволи — відкликано. Історія запусків залишиться.';

  @override
  String get automationUninstallMessageOne =>
      'Автоматизацію модуля та її кнопку буде видалено, незавершені перевірки — скасовано, а дозволи — відкликано. Історія запусків залишиться.';

  @override
  String automationUninstallMessageMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Буде видалено $count автоматизації модуля та їхні кнопки, незавершені перевірки — скасовано, а дозволи — відкликано. Історія запусків залишиться.',
      many:
          'Буде видалено $count автоматизацій модуля та їхні кнопки, незавершені перевірки — скасовано, а дозволи — відкликано. Історія запусків залишиться.',
      few:
          'Буде видалено $count автоматизації модуля та їхні кнопки, незавершені перевірки — скасовано, а дозволи — відкликано. Історія запусків залишиться.',
      one:
          'Буде видалено $count автоматизацію модуля та її кнопку, незавершені перевірки — скасовано, а дозволи — відкликано. Історія запусків залишиться.',
    );
    return '$_temp0';
  }

  @override
  String get automationUninstall => 'Видалити модуль';

  @override
  String automationUninstalledSnack(String name) {
    return 'Модуль «$name» видалено';
  }

  @override
  String automationModuleAuthor(String author) {
    return 'Автор: $author (з файлу)';
  }

  @override
  String get automationExport => 'Експортувати';

  @override
  String get automationModuleAbout => 'Про модуль';

  @override
  String automationRevokeTitle(String name) {
    return 'Відкликати доступ для «$name»?';
  }

  @override
  String get automationRevokeMessage =>
      'Його автоматизації перестануть запускатися, а незавершені перевірки буде скасовано, доки ви знову не дозволите модуль.';

  @override
  String get automationRevoke => 'Відкликати';

  @override
  String get automationWhatItCanDo => 'Що може модуль';

  @override
  String get automationChangeAccess => 'Змінити доступ';

  @override
  String get automationModuleSandboxNote =>
      'Модулі не мають доступу до інтернету, вашого облікового запису чи інших застосунків. Кожна зміна спершу показується в попередньому перегляді, якщо нижче не ввімкнено автозастосування.';

  @override
  String get automationWillAskForLabel => 'Попросить дозволи:';

  @override
  String get automationAutoApplyTitle => 'Застосовувати зміни автоматично';

  @override
  String get automationAutoApplyNotOffered =>
      'Цей модуль може видаляти дані або змінювати структуру, тому його зміни завжди чекають на вашу перевірку.';

  @override
  String get automationAllowModuleFirst => 'Спершу дозвольте цей модуль';

  @override
  String get automationAutoApplyExplanation =>
      'Невеликі зміни від цього модуля — створення й редагування до 20 карток без очищення значень — застосовуються без запиту. Більші зміни, видалення та зміни структури завжди чекають на вас. Застосований запуск можна скасувати, доки ви не перезавантажите застосунок.';

  @override
  String get automationInputField => 'вибір поля';

  @override
  String get automationInputCollection => 'вибір колекції';

  @override
  String get automationInputChoice => 'вибір варіанта';

  @override
  String get automationInputOnOff => 'увімк. або вимк.';

  @override
  String get automationInputNumber => 'число';

  @override
  String get automationInputText => 'текст';

  @override
  String get automationActions => 'Дії';

  @override
  String get automationTestRun => 'Тестовий запуск';

  @override
  String get automationAddToButton => 'Додати на кнопку';

  @override
  String get automationUsingIt => 'Автоматизації з цим модулем';

  @override
  String get automationUsingItNone =>
      'Його ще не використовує жодна автоматизація.';

  @override
  String get automationCode => 'Код';

  @override
  String get automationRecentRuns => 'Останні запуски';

  @override
  String get automationAllRuns => 'Усі запуски';

  @override
  String get automationNoRunsShort => 'Запусків ще немає.';

  @override
  String get automationNoChanges => 'Без змін';

  @override
  String get automationLoadRunFailed => 'Не вдалося завантажити запуск';

  @override
  String get automationRunNotInLogTitle => 'Цього запуску немає в журналі';

  @override
  String get automationRunNotInLogMessage =>
      'Можливо, його видалено разом зі старішими запусками.';

  @override
  String get automationStatusApplying => 'Застосовується';

  @override
  String get automationStatusNeedsReview => 'Чекає перевірки';

  @override
  String get automationStatusSucceeded => 'Успішно';

  @override
  String get automationStatusFailed => 'Не вдалося';

  @override
  String get automationStatusTimedOut => 'Час вичерпано';

  @override
  String get automationStatusSkipped => 'Не запущено';

  @override
  String get automationStatusRejected => 'Відхилено';

  @override
  String get automationStatusExpired => 'Термін минув';

  @override
  String automationAhead(int count) {
    return 'попереду $count';
  }

  @override
  String get automationApplyAuto => 'Авто';

  @override
  String get automationApplyAskFirst => 'Спершу питати';

  @override
  String automationOnDevice(String device) {
    return 'на $device';
  }

  @override
  String automationUndoWithTime(String timeLeft) {
    return 'Скасувати · $timeLeft';
  }

  @override
  String automationMinutesLeft(int count) {
    return 'залишилося $count хв';
  }

  @override
  String automationSecondsLeft(int count) {
    return 'залишилося $count с';
  }

  @override
  String get automationOpenCard => 'Відкрити картку';

  @override
  String get automationCopiedRunLog => 'Журнал запуску скопійовано';

  @override
  String get automationCopyLog => 'Копіювати журнал';

  @override
  String get automationStepTrigger => 'Тригер';

  @override
  String get automationAnAutomation => 'Автоматизація';

  @override
  String automationThisRun(String name) {
    return '$name (цей запуск)';
  }

  @override
  String get automationPreviousRun => 'Попередній запуск';

  @override
  String get automationStepInputs => 'Вхідні дані';

  @override
  String get automationStepCalls => 'Виклики';

  @override
  String get automationNoCalls => 'Викликів немає';

  @override
  String automationCallsDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ще $count виклику не записано',
      many: 'Ще $count викликів не записано',
      few: 'Ще $count виклики не записано',
      one: 'Ще $count виклик не записано',
    );
    return '$_temp0';
  }

  @override
  String get automationStepConsole => 'Консоль';

  @override
  String automationLinesDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ще $count рядка не записано',
      many: 'Ще $count рядків не записано',
      few: 'Ще $count рядки не записано',
      one: 'Ще $count рядок не записано',
    );
    return '$_temp0';
  }

  @override
  String get automationStepPlan => 'План';

  @override
  String automationApprovedAt(String time) {
    return 'ви підтвердили о $time';
  }

  @override
  String get automationStepLinks => 'Посилання';

  @override
  String automationOpenLink(String label) {
    return 'Відкрити: $label';
  }

  @override
  String get automationStepOutcome => 'Результат';

  @override
  String get automationRetryFailed => 'Повторити невдалі';

  @override
  String get automationReviewElsewhere => 'Перевірка в іншому вікні';

  @override
  String automationTriggerButtonCollection(int count, String collection) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Натиснуто кнопку в колекції «$collection» · $count картки',
      many: 'Натиснуто кнопку в колекції «$collection» · $count карток',
      few: 'Натиснуто кнопку в колекції «$collection» · $count картки',
      one: 'Натиснуто кнопку в колекції «$collection» · $count картка',
    );
    return '$_temp0';
  }

  @override
  String automationTriggerButtonSomeCollection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Натиснуто кнопку в колекції · $count картки',
      many: 'Натиснуто кнопку в колекції · $count карток',
      few: 'Натиснуто кнопку в колекції · $count картки',
      one: 'Натиснуто кнопку в колекції · $count картка',
    );
    return '$_temp0';
  }

  @override
  String automationTriggerButtonCard(String card) {
    return 'Натиснуто кнопку на картці $card';
  }

  @override
  String get automationTriggerButtonSomeCard => 'Натиснуто кнопку на картці';

  @override
  String automationTriggerCreated(String card) {
    return 'Створено картку $card';
  }

  @override
  String get automationTriggerCreatedSomeCard => 'Створено картку';

  @override
  String automationTriggerDeleted(String card) {
    return 'Видалено картку $card';
  }

  @override
  String get automationTriggerDeletedSomeCard => 'Видалено картку';

  @override
  String automationTriggerUpdated(String card) {
    return 'Змінено картку $card';
  }

  @override
  String get automationTriggerUpdatedSomeCard => 'Змінено картку';

  @override
  String automationTriggerFieldsChanged(String fields, String card) {
    return 'Змінено $fields у картці $card';
  }

  @override
  String automationTriggerFieldsChangedSomeCard(String fields) {
    return 'Змінено $fields у картці';
  }

  @override
  String automationUpdatedFailed(int applied, int failed) {
    return 'Оновлено: $applied, не вдалося: $failed';
  }

  @override
  String automationAppliedChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Застосовано $count зміни',
      many: 'Застосовано $count змін',
      few: 'Застосовано $count зміни',
      one: 'Застосовано $count зміну',
    );
    return '$_temp0';
  }

  @override
  String get automationUndoExpired => 'Час на скасування минув';

  @override
  String get automationUndoAfterReload =>
      'Після перезавантаження скасування недоступне';

  @override
  String automationReverted(String time) {
    return 'Скасовано · $time';
  }

  @override
  String automationAskFixPrefill(String name, String problem) {
    return 'Виправ модуль «$name»: $problem';
  }

  @override
  String get automationDecideLater => 'Вирішити пізніше';

  @override
  String get automationSavedForReview => 'Збережено для перевірки';

  @override
  String get automationButtonPressed => 'Натиснуто кнопку';

  @override
  String automationBecauseCreated(String card) {
    return 'Бо створено картку $card';
  }

  @override
  String get automationBecauseCreatedSomeCard => 'Бо створено картку';

  @override
  String automationBecauseDeleted(String card) {
    return 'Бо видалено картку $card';
  }

  @override
  String get automationBecauseDeletedSomeCard => 'Бо видалено картку';

  @override
  String automationBecauseUpdated(String card) {
    return 'Бо змінено картку $card';
  }

  @override
  String get automationBecauseUpdatedSomeCard => 'Бо змінено картку';

  @override
  String get automationReviewExpiredTitle => 'Час на перевірку минув.';

  @override
  String get automationReviewExpiredBody =>
      'Попередній перегляд зберігається, лише поки застосунок відкритий. Запустіть ще раз, щоб отримати новий попередній перегляд для поточних даних.';

  @override
  String get automationUndoneSentence => 'Скасовано.';

  @override
  String get automationDoneSentence => 'Готово.';

  @override
  String automationNextReview(int count) {
    return 'Наступна перевірка (залишилося $count)';
  }

  @override
  String get automationTestRunNote =>
      'Тестові запуски ніколи не змінюють дані — ви побачите, що змінилося б.';

  @override
  String get automationTestRunCollection => 'Колекція';

  @override
  String get automationTestRunCard => 'Картка';

  @override
  String get automationTestRunCardOptional => 'Картка (необов’язково)';

  @override
  String get automationSearchCards => 'Шукати картки';

  @override
  String get automationLoadCardsFailed => 'Не вдалося завантажити картки';

  @override
  String automationTestRunTitle(String action) {
    return 'Тест: «$action»';
  }

  @override
  String get automationTestRunNeedsAllow =>
      'Щоб протестувати, дозвольте модуль';

  @override
  String get automationRunTest => 'Запустити тест';

  @override
  String automationWouldChangeCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Змінилося б $count картки',
      many: 'Змінилося б $count карток',
      few: 'Змінилися б $count картки',
      one: 'Змінилася б $count картка',
    );
    return '$_temp0';
  }

  @override
  String automationTestRunFailed(String reason) {
    return 'Не вдалося: $reason';
  }

  @override
  String automationCallsCount(int count) {
    return 'Виклики ($count)';
  }

  @override
  String automationConsoleCount(int count) {
    return 'Консоль ($count)';
  }

  @override
  String get automationCloseEditor => 'Закрити редактор';

  @override
  String automationDeleteTitle(String name) {
    return 'Видалити «$name»?';
  }

  @override
  String get automationDeleteMessage =>
      'Її кнопка зникне. Історія запусків залишиться.';

  @override
  String get automationEditorName => 'Назва';

  @override
  String get automationEditorNameHint => 'Позначити дату відправлення';

  @override
  String get automationEditorWhen => 'Коли';

  @override
  String get automationEditorIn => 'Колекція';

  @override
  String get automationEditorDo => 'Виконати';

  @override
  String get automationEditorButton => 'Кнопка';

  @override
  String get automationEditorApply => 'Застосування';

  @override
  String get automationEditorEnabled => 'Увімкнено';

  @override
  String get automationPausedBroken => 'Цю автоматизацію призупинено.';

  @override
  String get automationPausedLoopTitle =>
      'Призупинено: вона запускалася надто часто протягом хвилини,';

  @override
  String get automationPausedLoopMessage =>
      'що схоже на цикл (можливо, вона змінює картки, за якими стежить).';

  @override
  String get automationPausedCrashedTitle =>
      'Призупинено: застосунок зупинився під час запуску';

  @override
  String get automationPausedCrashedMessage =>
      '(імовірно, через нестачу пам’яті).';

  @override
  String get automationResume => 'Продовжити';

  @override
  String get automationKindCardButtonHint => 'З’являється в заголовку картки.';

  @override
  String get automationKindCollectionButtonHint =>
      'З’являється в меню «Дії» колекції.';

  @override
  String get automationPickCollection => 'Виберіть колекцію';

  @override
  String get automationNotAllowedNote => 'Недоступна для цього модуля';

  @override
  String automationNotAllowedForModule(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Модулю недоступні: $names.',
      many: 'Модулю недоступні: $names.',
      few: 'Модулю недоступні: $names.',
      one: 'Модулю недоступні: $names.',
    );
    return '$_temp0';
  }

  @override
  String get automationAddCondition => 'Додати умову';

  @override
  String get automationEditCondition => 'Змінити умову';

  @override
  String get automationEditorIf => 'Якщо';

  @override
  String get automationCondition => 'Умова';

  @override
  String get automationRunOnAnyChange => 'Запускати за будь-якої зміни';

  @override
  String get automationOnlyWhenFieldsChange => 'Лише коли змінюються ці поля';

  @override
  String get automationLeaveEmptyAnyChange =>
      'Залиште порожнім, щоб реагувати на будь-яку зміну.';

  @override
  String get automationEditorRun => 'Запуск';

  @override
  String get automationModeEnters =>
      'Один раз, коли картка починає відповідати';

  @override
  String get automationModeEntersHint =>
      'Не запускатиметься знову, доки картка й далі відповідає.';

  @override
  String get automationModeMatches =>
      'Щоразу, коли картку змінено й вона відповідає';

  @override
  String get automationEventHelp =>
      'Запускається на пристрої, де внесено зміну, поки там відкритий застосунок. Офлайн-зміни запускають її після синхронізації. Обчислювані значення самі по собі її не запускають.';

  @override
  String get automationLastChecked => 'Остання перевірка';

  @override
  String get automationFieldFallback => 'Поле';

  @override
  String automationRemoveCondition(String label) {
    return 'Прибрати «$label»';
  }

  @override
  String get automationPickModule => 'Виберіть модуль';

  @override
  String get automationPickAction => 'Виберіть дію';

  @override
  String automationActionRunsOnCollection(String action) {
    return '$action · Запускається для колекції';
  }

  @override
  String automationActionRunsOnCard(String action) {
    return '$action · Запускається для картки';
  }

  @override
  String get automationModule => 'Модуль';

  @override
  String get automationAction => 'Дія';

  @override
  String automationFieldsOf(String collection) {
    return 'Поля колекції «$collection».';
  }

  @override
  String get automationButtonLabel => 'Підпис';

  @override
  String get automationButtonIcon => 'Значок';

  @override
  String get automationButtonColor => 'Колір';

  @override
  String get automationButtonPreview => 'Попередній перегляд';

  @override
  String get automationAskFirstButtonHint =>
      'Ви перевіряєте кожну зміну в попередньому перегляді.';

  @override
  String get automationAskFirstEventHint =>
      'Кожна картка чекає у списку «Чекають перевірки».';

  @override
  String get automationApplyAutomatically => 'Застосовувати автоматично';

  @override
  String get automationApplyAutomaticallyHint =>
      'Невеликі створення й редагування карток застосовуються без запиту. Більші зміни, видалення та зміни структури все одно чекають.';

  @override
  String get automationAlwaysAsks =>
      'Цей модуль може видаляти дані або змінювати структуру, тому завжди питає.';

  @override
  String get automationTurnOnAutoApplyFirst =>
      'Спершу ввімкніть автозастосування для цього модуля.';

  @override
  String get automationModuleDetails => 'Сторінка модуля';

  @override
  String get automationScopeSameAsModuleSummary =>
      'Доступні колекції: як у модуля';

  @override
  String automationScopeCountSummary(int count) {
    return 'Доступні колекції: $count';
  }

  @override
  String get automationAdvanced => 'Додатково';

  @override
  String get automationScopeSameAsModule => 'Як у модуля';

  @override
  String get automationCallDone => 'Готово';

  @override
  String get automationCallNoChange => 'Уже актуально';

  @override
  String get automationErrorCrashed =>
      'Застосунок зупинився під час запуску — імовірно, через нестачу пам’яті';

  @override
  String get automationErrorInterrupted =>
      'Перервано — зміни могли застосуватися частково, перевірте картки.';

  @override
  String get automationTintCarrot => 'морквяний';

  @override
  String get automationTintLeaf => 'зелений';

  @override
  String get automationTintSky => 'блакитний';

  @override
  String get automationTintPlum => 'сливовий';

  @override
  String get automationTintSand => 'пісочний';

  @override
  String get automationTintRose => 'рожевий';

  @override
  String get automationTintSlate => 'графітовий';

  @override
  String get automationTintTeal => 'бірюзовий';

  @override
  String get automationWidgetsFixReviewPermissions => 'Переглянути дозволи';

  @override
  String get automationWidgetsFixEditAutomation => 'Редагувати автоматизацію';

  @override
  String get automationWidgetsFixResume => 'Продовжити';

  @override
  String get automationWidgetsFixRunAgain => 'Запустити знову';

  @override
  String get automationWidgetsFixChangeAccess => 'Змінити доступ';

  @override
  String get automationWidgetsFixAskMorkva => 'Попросити Моркву виправити';

  @override
  String get automationWidgetsRunQueued => 'У черзі';

  @override
  String get automationWidgetsRunQueuedDetail => 'Чекає своєї черги.';

  @override
  String get automationWidgetsRunRunning => 'Виконується…';

  @override
  String get automationWidgetsRunRunningDetail => 'Дія виконується.';

  @override
  String get automationWidgetsRunApplying => 'Застосування…';

  @override
  String get automationWidgetsRunApplyingDetail => 'Зміни застосовуються.';

  @override
  String get automationWidgetsRunAwaitingReview => 'Чекає вашої перевірки';

  @override
  String get automationWidgetsRunAwaitingReviewDetail =>
      'Зміни чекають на вас у попередньому перегляді.';

  @override
  String get automationWidgetsRunDoneDetail => 'Дію завершено.';

  @override
  String automationWidgetsRunTimedOut(int seconds) {
    return 'Час вичерпано: $seconds с';
  }

  @override
  String automationWidgetsRunTimedOutDetail(int seconds) {
    return 'Дія тривала довше за $seconds с, тому її зупинено. Нічого не змінено.';
  }

  @override
  String get automationWidgetsRunRejected => 'Відхилено';

  @override
  String get automationWidgetsRunRejectedDetail => 'Ви відхилили зміни.';

  @override
  String get automationWidgetsRunExpired => 'Термін минув';

  @override
  String get automationWidgetsRunExpiredDetail =>
      'Попередній перегляд зберігався, лише доки застосунок був відкритий.';

  @override
  String get automationWidgetsRunSkipped => 'Не запущено';

  @override
  String get automationWidgetsRunSkippedDetail =>
      'Застосунок не запустив цю дію.';

  @override
  String get automationWidgetsRunFailed => 'Не вдалося';

  @override
  String get automationWidgetsRunFailedDetail => 'Запуск завершився помилкою.';

  @override
  String get automationWidgetsNeedsConsent => 'Потрібна згода';

  @override
  String get automationWidgetsReasonNeedsConsentDetail =>
      'Модуль змінився або ще не має дозволу.';

  @override
  String get automationWidgetsReasonBroken => 'Автоматизація не працює';

  @override
  String get automationWidgetsReasonBrokenDetail =>
      'Її умова, дія чи колекція більше не підходять.';

  @override
  String get automationWidgetsStoppedAfterCrash => 'Зупинено після збою';

  @override
  String get automationWidgetsReasonCrashedDetail =>
      'Застосунок зупинився під час запуску — імовірно, через нестачу пам’яті.';

  @override
  String get automationWidgetsReasonCrashedAdvice =>
      'Натисніть «Продовжити» на сторінці автоматизації';

  @override
  String get automationWidgetsPaused => 'Призупинено';

  @override
  String get automationWidgetsReasonPausedDetail =>
      'Її призупинено — вами або через підозру на цикл.';

  @override
  String get automationWidgetsReasonEngineUnavailable => 'Тут не запускається';

  @override
  String get automationWidgetsReasonEngineUnavailableDetail =>
      'Захищене середовище не може запуститися на цьому пристрої.';

  @override
  String get automationWidgetsReasonEngineUnavailableAdvice =>
      'Запустіть з іншого пристрою чи браузера';

  @override
  String get automationWidgetsReasonNotSettled => 'Картка не оновилася вчасно';

  @override
  String get automationWidgetsReasonNotSettledDetail =>
      'Зміна не дійшла до застосунку за 5 с, тому її не перевірено.';

  @override
  String get automationWidgetsReasonNotPermitted => 'Не дозволено';

  @override
  String get automationWidgetsReasonNotPermittedDetail =>
      'Зміна зачепила колекцію, до якої цей модуль не має доступу.';

  @override
  String get automationWidgetsReasonLoop => 'Утворився б цикл';

  @override
  String get automationWidgetsReasonLoopDetail =>
      'Ця автоматизація вже запускалася в цьому ланцюжку.';

  @override
  String get automationWidgetsReasonLoopAdvice => 'Змініть її умови';

  @override
  String get automationWidgetsReasonDepthLimit => 'Задовгий ланцюжок';

  @override
  String get automationWidgetsReasonDepthLimitDetail =>
      'Автоматизації запускали одна одну на 3 рівні вглиб — застосунок зупинив ланцюжок тут.';

  @override
  String get automationWidgetsReasonDepthLimitAdvice =>
      'Змініть умови автоматизацій';

  @override
  String get automationWidgetsReasonFanOut => 'Забагато карток одразу';

  @override
  String get automationWidgetsReasonFanOutDetail =>
      'З однієї зміни обробляються лише перші 100 карток.';

  @override
  String get automationWidgetsReasonFanOutAdvice =>
      'Розбийте зміну на менші частини';

  @override
  String get automationWidgetsReasonQueueFull => 'Перевантажено';

  @override
  String get automationWidgetsReasonQueueFullDetail =>
      'У черзі було забагато запусків.';

  @override
  String get automationWidgetsReasonQueueFullAdvice => 'Запустіть пізніше';

  @override
  String get automationWidgetsReasonReviewBacklog =>
      'Забагато перевірок у черзі';

  @override
  String get automationWidgetsReasonReviewBacklogDetail =>
      'Уже чекають 50 перевірок.';

  @override
  String get automationWidgetsReasonReviewBacklogAdvice =>
      'Перегляньте або відхиліть ті, що чекають';

  @override
  String get automationWidgetsReasonCardGone => 'Картку видалено';

  @override
  String get automationWidgetsReasonCardGoneDetail => 'Картки більше не існує.';

  @override
  String get automationWidgetsStopped => 'Зупинено';

  @override
  String get automationWidgetsReasonCancelledDetail =>
      'Ви зупинили запуск. Нічого не змінено.';

  @override
  String get automationWidgetsReasonDuplicate => 'Уже виконується';

  @override
  String get automationWidgetsReasonDuplicateDetail =>
      'Ця автоматизація вже виконувалася для цієї картки.';

  @override
  String get automationWidgetsReasonLoadError => 'Модуль не запустився';

  @override
  String get automationWidgetsReasonLoadErrorDetail =>
      'Код модуля містить помилку або завантажувався задовго.';

  @override
  String get automationWidgetsReasonLoadErrorAdvice =>
      'Попросіть Моркву виправити або імпортуйте виправлений файл';

  @override
  String get automationWidgetsReasonModuleError => 'Збій модуля';

  @override
  String get automationWidgetsReasonModuleErrorDetail =>
      'Модуль завершився з помилкою.';

  @override
  String automationWidgetsReasonModuleErrorMessage(String message) {
    return 'Модуль завершився з помилкою: $message';
  }

  @override
  String get automationWidgetsReasonPlanRefused => 'Зміну відхилено';

  @override
  String get automationWidgetsReasonPlanRefusedDetail =>
      'Зміна, яку запитав модуль, не дозволена — див. «Виклики».';

  @override
  String get automationWidgetsReasonPlanRefusedAdvice =>
      'Перевірте «Виклики»; за потреби змініть доступ';

  @override
  String get automationWidgetsReasonLimitExceeded => 'Забагато роботи';

  @override
  String get automationWidgetsReasonLimitExceededDetail =>
      'Модуль запросив більше, ніж дозволено одному запуску (виклики, дані чи час).';

  @override
  String get automationWidgetsReasonLimitExceededAdvice =>
      'Запустіть на меншій кількості карток';

  @override
  String get automationWidgetsReasonAbuseDetail =>
      'Модуль надіслав забагато або завеликі повідомлення.';

  @override
  String get automationWidgetsReasonOffline => 'Офлайн';

  @override
  String get automationWidgetsReasonOfflineDetail =>
      'Не вдалося застосувати без з’єднання.';

  @override
  String get automationWidgetsReasonOfflineAdvice =>
      'Запустіть знову, коли з’явиться з’єднання';

  @override
  String get automationWidgetsReasonNotApplied => 'Нічого не застосовано';

  @override
  String get automationWidgetsReasonNotAppliedDetail =>
      'Жодну зі змін не вдалося застосувати — див. план.';

  @override
  String get automationWidgetsOutcomeUnknown => 'Результат невідомий';

  @override
  String get automationWidgetsReasonInterruptedDetail =>
      'Застосунок закрили під час застосування змін — їх могло бути застосовано частково.';

  @override
  String get automationWidgetsReasonInterruptedAdvice => 'Перевірте картку';

  @override
  String get automationWidgetsReasonInternalDetail =>
      'У застосунку сталася неочікувана помилка.';

  @override
  String get automationWidgetsReasonInternalAdvice =>
      'Запустіть знову; якщо повториться, скопіюйте журнал';

  @override
  String get automationWidgetsReasonCodeChangedDetail =>
      'Код модуля змінився до того, як ви переглянули зміни.';

  @override
  String get automationWidgetsReasonUninstalledDetail =>
      'Модуль видалили до того, як ви переглянули зміни.';

  @override
  String get automationWidgetsReasonSupersededDetail =>
      'Цей попередній перегляд замінив новий запуск.';

  @override
  String get automationWidgetsOutcomeUnknownDetail =>
      'Зміни застосовувалися в іншому вікні — перевірте картки.';

  @override
  String get automationWidgetsOutcomeUnknownAdvice => 'Перевірте картки';

  @override
  String get automationWidgetsReviewNotHere => 'Перевірка тут недоступна';

  @override
  String get automationWidgetsReviewNotHereDetail =>
      'Її відкрили в іншому вікні або до перезапуску застосунку.';

  @override
  String automationWidgetsAskedFirst(String policy) {
    return 'Спершу запитано: $policy.';
  }

  @override
  String get automationWidgetsChipInstalled => 'Встановлено';

  @override
  String get automationWidgetsChipBroken => 'Не працює';

  @override
  String get automationWidgetsChipLoopSuspected => 'Підозра на цикл';

  @override
  String get automationWidgetsChipAskFirst => 'Спершу питати';

  @override
  String get automationWidgetsChipAuto => 'Авто';

  @override
  String get automationWidgetsChipAutoOff => 'Авто · вимкнено для модуля';

  @override
  String automationWidgetsQueuedAhead(int count) {
    return 'У черзі · попереду $count';
  }

  @override
  String automationWidgetsRunOnCard(String label, String card) {
    return '$label · $card';
  }

  @override
  String automationWidgetsNoticeNeedsReview(String label) {
    return '$label: чекає вашої перевірки';
  }

  @override
  String get automationWidgetsNoChanges => 'Без змін';

  @override
  String automationWidgetsNoticeTimedOut(String label) {
    return '$label: час вичерпано (20 с)';
  }

  @override
  String automationWidgetsNoticeStopped(String label) {
    return '$label: зупинено. Нічого не змінено.';
  }

  @override
  String get automationWidgetsNoticeOffline =>
      'Не вдалося застосувати — ви офлайн';

  @override
  String automationWidgetsNoticeOfflineOn(String label) {
    return 'Не вдалося застосувати «$label» — ви офлайн';
  }

  @override
  String automationWidgetsNoticeFailed(String label) {
    return '$label: помилка';
  }

  @override
  String automationWidgetsNoticeFailedMessage(String label, String message) {
    return '$label: помилка — $message';
  }

  @override
  String get automationWidgetsCantRunOnDevice =>
      'Автоматизації не можуть працювати на цьому пристрої';

  @override
  String get automationWidgetsViewRun => 'Переглянути запуск';

  @override
  String get automationWidgetsReview => 'Переглянути';

  @override
  String get automationWidgetsStateSavesFirst => 'спершу буде збережено';

  @override
  String get automationWidgetsStateNeedsConsent => 'потрібна згода';

  @override
  String get automationWidgetsStateQueued => 'у черзі';

  @override
  String get automationWidgetsStateRunning => 'виконується';

  @override
  String get automationWidgetsStateWaitingForReview => 'чекає перевірки';

  @override
  String get automationWidgetsStateLastRunFailed => 'останній запуск не вдався';

  @override
  String get automationWidgetsStop => 'Зупинити';

  @override
  String automationWidgetsStopLabel(String label) {
    return 'Зупинити «$label»';
  }

  @override
  String get automationWidgetsSaveAndRun => 'Зберегти й запустити';

  @override
  String get automationWidgetsWorksOnSavedCard =>
      'Дія працює зі збереженою карткою.';

  @override
  String get automationWidgetsMoreActions => 'Інші дії';

  @override
  String automationWidgetsMoreActionsState(String label, String state) {
    return 'Інші дії, $label: $state';
  }

  @override
  String get automationWidgetsActions => 'Дії';

  @override
  String automationWidgetsActionsLive(String label, String state) {
    return 'Дії, $label: $state';
  }

  @override
  String get automationWidgetsNoButtons => 'Кнопок ще немає.';

  @override
  String get automationWidgetsNeedsReview => 'Чекає перевірки';

  @override
  String get automationWidgetsLastRunFailed => 'Останній запуск не вдався';

  @override
  String automationWidgetsRunsOnShown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Для $count показаної картки',
      many: 'Для $count показаних карток',
      few: 'Для $count показаних карток',
      one: 'Для $count показаної картки',
    );
    return '$_temp0';
  }

  @override
  String automationWidgetsRunsOnAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Для всіх карток ($count)',
      many: 'Для всіх карток ($count)',
      few: 'Для всіх карток ($count)',
      one: 'Для всіх карток ($count)',
    );
    return '$_temp0';
  }

  @override
  String automationWidgetsAutomationsFor(String collection) {
    return 'Автоматизації для «$collection»…';
  }

  @override
  String get automationWidgetsNewAutomation => 'Нова автоматизація…';

  @override
  String automationWidgetsRunningLabel(String label) {
    return 'Виконується «$label»';
  }

  @override
  String automationWidgetsRunningLabelEllipsis(String label) {
    return 'Виконується «$label»…';
  }

  @override
  String get automationWidgetsLongPressToStop => 'Утримуйте, щоб зупинити';

  @override
  String get automationWidgetsRunAction => 'Запустити дію…';

  @override
  String get automationWidgetsAutomationsEllipsis => 'Автоматизації…';

  @override
  String automationWidgetsPillRunning(int count) {
    return 'Виконується · $count';
  }

  @override
  String automationWidgetsNeedReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count чекають перевірки',
      many: '$count чекають перевірки',
      few: '$count чекають перевірки',
      one: '$count чекає перевірки',
    );
    return '$_temp0';
  }

  @override
  String automationWidgetsPillFailed(int count) {
    return 'З помилкою: $count';
  }

  @override
  String automationWidgetsPillDidntRun(int count) {
    return 'Не запущено: $count';
  }

  @override
  String automationWidgetsSentenceRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Виконується $count автоматизації',
      many: 'Виконується $count автоматизацій',
      few: 'Виконуються $count автоматизації',
      one: 'Виконується $count автоматизація',
    );
    return '$_temp0';
  }

  @override
  String automationWidgetsSentenceAlsoNeedReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count чекають перевірки',
      many: '$count чекають перевірки',
      few: '$count чекають перевірки',
      one: '$count чекає перевірки',
    );
    return '$_temp0';
  }

  @override
  String automationWidgetsSentenceNeedsReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count автоматизації чекають перевірки',
      many: '$count автоматизацій чекають перевірки',
      few: '$count автоматизації чекають перевірки',
      one: '$count автоматизація чекає перевірки',
    );
    return '$_temp0';
  }

  @override
  String automationWidgetsSentenceFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count завершилися з помилкою',
      many: '$count завершилися з помилкою',
      few: '$count завершилися з помилкою',
      one: '$count завершилася з помилкою',
    );
    return '$_temp0';
  }

  @override
  String automationWidgetsSentenceDidntRun(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count автоматизації не запустилися',
      many: '$count автоматизацій не запустилися',
      few: '$count автоматизації не запустилися',
      one: '$count автоматизація не запустилася',
    );
    return '$_temp0';
  }

  @override
  String automationWidgetsSentenceReviewsExpired(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count перевірки застаріли · Переглянути',
      many: '$count перевірок застаріло · Переглянути',
      few: '$count перевірки застаріли · Переглянути',
      one: '$count перевірка застаріла · Переглянути',
    );
    return '$_temp0';
  }

  @override
  String automationWidgetsAutoApplyPaused(String status) {
    return '$status · Автозастосування призупинено на 10 хв';
  }

  @override
  String automationWidgetsDefaultName(String action, String collection) {
    return '$action — $collection';
  }

  @override
  String get automationWidgetsProblemName => 'Вкажіть назву';

  @override
  String get automationWidgetsProblemCollection => 'Виберіть колекцію';

  @override
  String automationWidgetsProblemCollectionNotAllowed(String collection) {
    return 'Модуль не має доступу до колекції «$collection»';
  }

  @override
  String get automationWidgetsProblemAction => 'Виберіть дію';

  @override
  String get automationWidgetsProblemCardAction =>
      'Ця дія працює з карткою — використайте кнопку картки або подію';

  @override
  String get automationWidgetsProblemCollectionAction =>
      'Ця дія працює з колекцією — використайте кнопку колекції';

  @override
  String automationWidgetsProblemFillIn(String field) {
    return 'Заповніть поле «$field»';
  }

  @override
  String get automationWidgetsProblemWhere =>
      'Додайте хоча б одну умову або виберіть поля для відстеження';

  @override
  String get automationWidgetsProblemAlwaysAsks =>
      'Цей модуль може видаляти дані або змінювати структуру, тому завжди питає.';

  @override
  String get automationWidgetsProblemTurnOnAutoFirst =>
      'Спершу ввімкніть автозастосування для цього модуля';

  @override
  String get automationWidgetsAutoApplyOnTitle =>
      'Застосовувати зміни цього модуля автоматично?';

  @override
  String get automationWidgetsTurnOn => 'Увімкнути';

  @override
  String get automationWidgetsAutoApplyOffTitle => 'Вимкнути автозастосування?';

  @override
  String automationWidgetsAutoApplyOffBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count автоматизації спершу питатимуть.',
      many: '$count автоматизацій спершу питатимуть.',
      few: '$count автоматизації спершу питатимуть.',
      one: '$count автоматизація спершу питатиме.',
    );
    return '$_temp0';
  }

  @override
  String get automationWidgetsTurnOff => 'Вимкнути';

  @override
  String automationWidgetsProvenance(String name, String id) {
    return 'Модуль · $name ($id)';
  }

  @override
  String get collectionsTypeText => 'Текст';

  @override
  String get collectionsTypeTextDescription =>
      'Довільний текст в один чи кілька рядків.';

  @override
  String get collectionsTypeNumber => 'Число';

  @override
  String get collectionsTypeNumberDescription =>
      'Числове значення, за потреби в заданих межах.';

  @override
  String get collectionsTypeBoolean => 'Так / Ні';

  @override
  String get collectionsTypeBooleanDescription =>
      'Простий перемикач «так / ні».';

  @override
  String get collectionsTypeDate => 'Дата';

  @override
  String get collectionsTypeDateDescription =>
      'Календарна дата, за потреби з часом.';

  @override
  String get collectionsTypeSingleSelect => 'Вибір';

  @override
  String get collectionsTypeSingleSelectDescription =>
      'Один варіант із заданого списку.';

  @override
  String get collectionsTypeMultiSelect => 'Множинний вибір';

  @override
  String get collectionsTypeMultiSelectDescription =>
      'Будь-яка кількість варіантів (теги).';

  @override
  String get collectionsTypeReference => 'Посилання';

  @override
  String get collectionsTypeReferenceDescription =>
      'Зв’язок із картками іншої колекції.';

  @override
  String get collectionsTypeFile => 'Файл';

  @override
  String get collectionsTypeFileDescription => 'Одне чи кілька вкладень.';

  @override
  String get collectionsTypeAutoNumber => 'Автонумерація';

  @override
  String get collectionsTypeAutoNumberDescription =>
      'Порядковий номер, що присвоюється автоматично.';

  @override
  String get collectionsTypeCalculated => 'Обчислюване';

  @override
  String get collectionsTypeCalculatedDescription =>
      'Формула, підсумок за пов’язаними картками або поле пов’язаної картки.';

  @override
  String get collectionsMultiline => 'Кілька рядків';

  @override
  String get collectionsMultilineHint =>
      'Дозволити переноси рядків у значенні.';

  @override
  String get collectionsMaxLength => 'Макс. довжина';

  @override
  String get collectionsNoLimit => 'Без обмежень';

  @override
  String get collectionsSummaryMultiline => 'кілька рядків';

  @override
  String collectionsSummaryMax(int max) {
    return 'макс. $max';
  }

  @override
  String get collectionsDecimalPlaces => 'Знаків після коми';

  @override
  String get collectionsWholeNumber => 'Ціле число';

  @override
  String get collectionsUnitLabel => 'Одиниця виміру';

  @override
  String get collectionsUnitLabelHint => 'напр. кг, ₴';

  @override
  String get collectionsMinimum => 'Мінімум';

  @override
  String get collectionsNoMinimum => 'Без мінімуму';

  @override
  String get collectionsMaximum => 'Максимум';

  @override
  String get collectionsNoMaximum => 'Без максимуму';

  @override
  String collectionsSummaryDecimals(int count) {
    return '$count зн. після коми';
  }

  @override
  String get collectionsIncludeTime => 'З часом';

  @override
  String get collectionsIncludeTimeHint => 'Зберігати час разом із датою.';

  @override
  String get collectionsEarliest => 'Не раніше';

  @override
  String get collectionsLatest => 'Не пізніше';

  @override
  String get collectionsAnyDate => 'Будь-яка';

  @override
  String get collectionsSummaryDate => 'дата';

  @override
  String get collectionsSummaryDateTime => 'дата й час';

  @override
  String collectionsOptionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count варіанта',
      many: '$count варіантів',
      few: '$count варіанти',
      one: '$count варіант',
    );
    return '$_temp0';
  }

  @override
  String collectionsOptionDefault(int number) {
    return 'Варіант $number';
  }

  @override
  String get collectionsNoOptions => 'Варіантів ще немає — додайте перший.';

  @override
  String get collectionsAddOption => 'Додати варіант';

  @override
  String get collectionsDragToReorder => 'Перетягніть, щоб змінити порядок';

  @override
  String get collectionsOptionLabel => 'Назва варіанта';

  @override
  String get collectionsRemoveOption => 'Прибрати варіант';

  @override
  String collectionsColorSwatch(String hex) {
    return 'Колір $hex';
  }

  @override
  String get collectionsNoColor => 'Без кольору';

  @override
  String get collectionsBooleanNoSettings =>
      'Поле «Так / Ні» не має додаткових налаштувань.';

  @override
  String get collectionsTargetCollection => 'Цільова колекція';

  @override
  String get collectionsChooseCollection => 'Виберіть колекцію';

  @override
  String collectionsThisCollection(String name) {
    return '$name (ця колекція)';
  }

  @override
  String get collectionsPickTargetWarning =>
      'Виберіть цільову колекцію — доти посилання нікуди не веде.';

  @override
  String get collectionsAllowMultiple => 'Кілька значень';

  @override
  String get collectionsReferenceMultipleHint => 'Посилатися на кілька карток.';

  @override
  String get collectionsSummaryNoTarget => '(без цілі)';

  @override
  String get collectionsSummaryUnknownTarget => '(невідомо)';

  @override
  String collectionsSummaryReferenceMany(String name) {
    return '→ $name (кілька)';
  }

  @override
  String get collectionsFileMultipleHint => 'Прикріплювати кілька файлів.';

  @override
  String get collectionsAllowedExtensions => 'Дозволені розширення';

  @override
  String get collectionsAllowedExtensionsHint =>
      'напр. png, jpg, pdf — через кому; порожньо — будь-які';

  @override
  String get collectionsSummaryMultiple => 'кілька';

  @override
  String get collectionsNoFile => 'Немає файлу';

  @override
  String get collectionsStartAt => 'Почати з';

  @override
  String get collectionsPrefix => 'Префікс';

  @override
  String get collectionsPrefixHint => 'напр. ЗАМ-';

  @override
  String get collectionsDigits => 'Кількість цифр';

  @override
  String get collectionsDigitsHint => 'напр. 4 → 0042';

  @override
  String get collectionsFirstNumber => 'Перший номер';

  @override
  String get collectionsAutoNumberNote =>
      'Нові картки отримують наступний номер під час збереження. Наявні картки лишаються без номера.';

  @override
  String collectionsSummaryDigits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count цифри',
      many: '$count цифр',
      few: '$count цифри',
      one: '$count цифра',
    );
    return '$_temp0';
  }

  @override
  String collectionsSummaryFrom(int start) {
    return 'від $start';
  }

  @override
  String get collectionsSummaryAuto => 'авто';

  @override
  String collectionsSummaryFormula(String type) {
    return 'Формула → $type';
  }

  @override
  String get collectionsModeFormula => 'Формула';

  @override
  String get collectionsModeAggregate => 'Агрегація';

  @override
  String get collectionsModeLookup => 'Підстановка';

  @override
  String get collectionsModeFormulaHint => 'Обчислює з полів цієї картки.';

  @override
  String get collectionsModeAggregateHint =>
      'Підсумовує значення інших карток — як SUMIF в електронних таблицях.';

  @override
  String get collectionsModeLookupHint =>
      'Показує поле пов’язаної картки — як VLOOKUP.';

  @override
  String get collectionsDecimals => 'Знаки після коми';

  @override
  String get collectionsDecimalsAuto => 'авто';

  @override
  String get collectionsUnit => 'Одиниця';

  @override
  String get collectionsUnitHint => 'напр. ₴, кг';

  @override
  String collectionsFormulaCircular(String chain) {
    return 'Циклічне посилання: $chain';
  }

  @override
  String collectionsFormulaExample(String open, String close) {
    return 'напр. $openЦіна$close * $openКількість$close';
  }

  @override
  String collectionsFormulaResult(String type) {
    return 'Результат: $type';
  }

  @override
  String get collectionsInsertField => 'Вставити поле';

  @override
  String get collectionsFunctions => 'Функції';

  @override
  String get collectionsJoinChip => '& об’єднати';

  @override
  String collectionsJoinTooltip(String open, String close) {
    return 'Об’єднує текст: $openІм’я$close & \" \" & $openПрізвище$close';
  }

  @override
  String get collectionsAllFunctions => 'Усі функції';

  @override
  String get collectionsAllFunctionsTooltip =>
      'Усі функції з поясненням, як ними користуватися';

  @override
  String get collectionsSummarize => 'Підсумувати';

  @override
  String get collectionsPickSource => 'Виберіть, що підсумувати';

  @override
  String get collectionsNoSources =>
      'Додайте поле «Посилання», щоб пов’язати картки, або підсумуйте всю колекцію.';

  @override
  String get collectionsCalculate => 'Обчислити';

  @override
  String get collectionsAggregateOf => 'З поля';

  @override
  String get collectionsPickSourceFirst => 'Спершу виберіть, що підсумувати.';

  @override
  String collectionsNoNumberFields(String name) {
    return 'У колекції «$name» немає числових полів.';
  }

  @override
  String collectionsNoNumberOrDateFields(String name) {
    return 'У колекції «$name» немає полів із числом чи датою.';
  }

  @override
  String get collectionsOnlyWhere => 'Лише якщо';

  @override
  String get collectionsAddCondition => 'Додати умову';

  @override
  String get collectionsEditCondition => 'Змінити умову';

  @override
  String get collectionsRemoveCondition => 'Прибрати умову';

  @override
  String get collectionsAndCondition => 'І…';

  @override
  String collectionsSourceLinkingToThis(String name) {
    return '$name, що посилаються на цю картку';
  }

  @override
  String collectionsSourceLinkingHere(String name) {
    return '$name, що посилаються сюди';
  }

  @override
  String collectionsSourceVia(String field) {
    return 'через $field';
  }

  @override
  String collectionsSourceLinked(String name) {
    return 'Пов’язані: $name';
  }

  @override
  String collectionsSourceIn(String field) {
    return 'поле $field';
  }

  @override
  String collectionsSourceAll(String name) {
    return 'Усі: $name';
  }

  @override
  String get collectionsSourceEveryItem => 'кожна картка';

  @override
  String get collectionsThrough => 'Через';

  @override
  String get collectionsNoLookupReferences =>
      'Додайте поле «Посилання» (одна пов’язана картка), щоб підставляти її поля.';

  @override
  String get collectionsPickReference => 'Виберіть посилання';

  @override
  String collectionsLinksTo(String name) {
    return 'посилається на $name';
  }

  @override
  String get collectionsShow => 'Показати';

  @override
  String collectionsNoFieldsToShow(String name) {
    return 'У колекції «$name» немає полів для показу.';
  }

  @override
  String get collectionsThatCollectionNoFields =>
      'У тій колекції немає полів для показу.';

  @override
  String get collectionsPickField => 'Виберіть поле';

  @override
  String get collectionsLookupKeepsType =>
      'Тип зберігається: вибір лишається вибором, тож фільтри й підсумки можуть використовувати його варіанти.';

  @override
  String get collectionsInWords => 'СЛОВАМИ';

  @override
  String get collectionsAddFieldTitle => 'Додати поле';

  @override
  String get collectionsAddFieldSubtitle =>
      'Виберіть тип — налаштувати й перейменувати поле можна далі.';

  @override
  String get collectionsAutomatic => 'Автоматично';

  @override
  String collectionsAddFieldOfType(String type) {
    return 'Додати поле: $type';
  }

  @override
  String get collectionsRequired => 'Обов’язкове';

  @override
  String get collectionsRequiredHint =>
      'Картка дійсна, лише коли це поле заповнено.';

  @override
  String get collectionsOptions => 'Параметри';

  @override
  String get collectionsFieldName => 'Назва поля';

  @override
  String get collectionsFieldNameHint => 'Назва, Статус, Термін…';

  @override
  String get collectionsHelpText => 'Підказка';

  @override
  String get collectionsHelpTextHint =>
      'Необов’язково — пояснення, що показується біля поля';

  @override
  String get collectionsTypeLocked =>
      'Після першого збереження тип змінити не можна. Щоб змінити його, видаліть це поле й додайте нове.';

  @override
  String get collectionsGroup => 'Група';

  @override
  String get collectionsGroupName => 'Назва групи';

  @override
  String get collectionsGroupNameHint =>
      'Залиште порожнім для розділу без групи';

  @override
  String get collectionsCollapsedByDefault => 'Згорнуто за замовчуванням';

  @override
  String get collectionsCollapsedByDefaultHint =>
      'Група буде згорнута, коли ви відкриєте картку.';

  @override
  String get collectionsDeleteGroup => 'Видалити групу';

  @override
  String get collectionsDeleteGroupTitle => 'Видалити групу?';

  @override
  String get collectionsDeleteGroupMessage =>
      'Групу буде прибрано з макета. Її поля не видаляються — їх буде перенесено до основного розділу.';

  @override
  String get collectionsUntitledCollection => 'Колекція без назви';

  @override
  String get collectionsNewGroup => 'Нова група';

  @override
  String get collectionsAddGroup => 'Додати групу';

  @override
  String get collectionsDropFieldHere => 'Перетягніть поле сюди';

  @override
  String get collectionsAddField => 'Додати поле';

  @override
  String get collectionsUntitledSection => 'Розділ без назви';

  @override
  String get collectionsUntitledField => 'Поле без назви';

  @override
  String get collectionsFields => 'Поля';

  @override
  String collectionsFirstRunQuestion(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {
      'other': 'Що ви відстежуєте для кожної картки?',
    });
    return '$_temp0';
  }

  @override
  String get collectionsFirstRunHint =>
      'Натисніть, щоб додати, — будь-яке поле можна потім перейменувати чи змінити.';

  @override
  String get collectionsCustomField => 'Інше поле';

  @override
  String get collectionsSuggestStatus => 'Статус';

  @override
  String get collectionsSuggestStatusHint => 'вибір';

  @override
  String get collectionsSuggestToDo => 'До виконання';

  @override
  String get collectionsSuggestInProgress => 'У роботі';

  @override
  String get collectionsSuggestDone => 'Готово';

  @override
  String get collectionsSuggestDueDate => 'Термін';

  @override
  String get collectionsSuggestDueDateHint => 'дата';

  @override
  String get collectionsSuggestAmount => 'Сума';

  @override
  String get collectionsSuggestAmountHint => 'число';

  @override
  String get collectionsSuggestCustomer => 'Клієнт';

  @override
  String get collectionsSuggestCustomerHint => 'посилання';

  @override
  String get collectionsSuggestNotes => 'Нотатки';

  @override
  String get collectionsSuggestNotesHint => 'текст';

  @override
  String collectionsSaveFailed(String error) {
    return 'Не вдалося зберегти: $error';
  }

  @override
  String get collectionsNotFoundTitle => 'Колекцію не знайдено';

  @override
  String get collectionsNotFoundMessage =>
      'Можливо, цю колекцію видалено або посилання неправильне. Поверніться на головну й виберіть іншу.';

  @override
  String get collectionsBackToCollections => 'До колекцій';

  @override
  String get collectionsDescriptionTitle => 'Опис колекції';

  @override
  String get collectionsDescriptionHint => 'Що зберігається в цій колекції';

  @override
  String get collectionsChooseIcon => 'Вибрати значок';

  @override
  String get collectionsCustomizing => 'Налаштування';

  @override
  String get collectionsNameHint => 'Назва колекції';

  @override
  String get collectionsAddDescription => 'Додати опис';

  @override
  String get collectionsSaved => 'Збережено';

  @override
  String get collectionsSaving => 'Збереження…';

  @override
  String get collectionsUnsavedChanges => 'Незбережені зміни';

  @override
  String get collectionsObjectForm => 'Форма картки';

  @override
  String get collectionsObjectFormHint => 'Як виглядає відкрита картка';

  @override
  String get collectionsConfigureField => 'Налаштування поля';

  @override
  String get collectionsSelectToEdit =>
      'Виберіть поле чи групу, щоб змінити їх.';

  @override
  String get collectionsLeaveTitle => 'Зберегти зміни?';

  @override
  String get collectionsLeaveMessage =>
      'У цій колекції є незбережені зміни. Збережіть їх перед виходом або відхиліть.';

  @override
  String get collectionsDiscard => 'Відхилити';

  @override
  String get collectionsLoading => 'Завантаження колекцій…';

  @override
  String get collectionsTitleFieldName => 'Назва';

  @override
  String collectionsTemplateAdded(String name) {
    return 'Додано: $name';
  }

  @override
  String collectionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count колекції',
      many: '$count колекцій',
      few: '$count колекції',
      one: '$count колекція',
    );
    return '$_temp0';
  }

  @override
  String collectionsCountWithPinnedShort(int count, int pinned) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count колекції',
      many: '$count колекцій',
      few: '$count колекції',
      one: '$count колекція',
    );
    return '$_temp0 · закріплено: $pinned';
  }

  @override
  String collectionsCountWithPinned(int count, int pinned) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count колекції',
      many: '$count колекцій',
      few: '$count колекції',
      one: '$count колекція',
    );
    return '$_temp0 · закріплено на бічній панелі: $pinned';
  }

  @override
  String get collectionsFromTemplate => 'Із шаблону';

  @override
  String get collectionsNewCollection => 'Нова колекція';

  @override
  String get collectionsHeaderAll => 'КОЛЕКЦІЇ';

  @override
  String get collectionsHeaderOthers => 'УСІ ІНШІ';

  @override
  String get collectionsDeleteTitle => 'Видалити колекцію?';

  @override
  String collectionsDeleteMessage(String name) {
    return 'Колекцію «$name» та її структуру буде видалено назавжди. Картки в ній стануть недоступними. Цю дію не можна скасувати.';
  }

  @override
  String get collectionsEmptyTitle => 'Колекцій ще немає';

  @override
  String get collectionsEmptyMessage =>
      'Колекції містять ваші картки — замовлення, клієнтів, склад, будь-що. Створіть першу, щоб упорядкувати свою роботу.';

  @override
  String get collectionsStartFromTemplate => 'Почати з шаблону';

  @override
  String get collectionsLoadErrorTitle => 'Не вдалося завантажити колекції';

  @override
  String collectionsLoadFailed(String error) {
    return 'Не вдалося завантажити колекції: $error';
  }

  @override
  String get collectionsRenameCollection => 'Перейменувати колекцію';

  @override
  String get collectionsNameRequired => 'Дайте колекції назву';

  @override
  String get collectionsNameLabel => 'Назва';

  @override
  String get collectionsNameExamples => 'Замовлення, Клієнти, Склад…';

  @override
  String get collectionsDescriptionLabel => 'Опис';

  @override
  String get collectionsDescriptionOptionalHint =>
      'Необов’язково — що зберігається в цій колекції';

  @override
  String collectionsOpenCollection(String name) {
    return 'Відкрити «$name»';
  }

  @override
  String get collectionsPinToSidebar => 'Закріпити на бічній панелі';

  @override
  String get collectionsUnpinFromSidebar => 'Відкріпити від бічної панелі';

  @override
  String get collectionsNoFieldsYet => 'Полів ще немає';

  @override
  String get collectionsMoreActions => 'Інші дії';

  @override
  String get collectionsCustomize => 'Налаштувати';

  @override
  String get appTitle => 'Morkva CRM';

  @override
  String get commonCancel => 'Скасувати';

  @override
  String get commonSave => 'Зберегти';

  @override
  String get commonDelete => 'Видалити';

  @override
  String get commonRemove => 'Прибрати';

  @override
  String get commonClose => 'Закрити';

  @override
  String get commonDone => 'Готово';

  @override
  String get commonRetry => 'Повторити';

  @override
  String get commonTryAgain => 'Спробувати ще раз';

  @override
  String get commonAdd => 'Додати';

  @override
  String get commonCreate => 'Створити';

  @override
  String get commonEdit => 'Редагувати';

  @override
  String get commonRename => 'Перейменувати';

  @override
  String get commonDuplicate => 'Дублювати';

  @override
  String get commonUndo => 'Скасувати';

  @override
  String get commonOk => 'Гаразд';

  @override
  String get commonGotIt => 'Зрозуміло';

  @override
  String get commonBack => 'Назад';

  @override
  String get commonNext => 'Далі';

  @override
  String get commonContinue => 'Продовжити';

  @override
  String get commonApply => 'Застосувати';

  @override
  String get commonOpen => 'Відкрити';

  @override
  String get commonSearch => 'Пошук';

  @override
  String get commonCopy => 'Копіювати';

  @override
  String get commonCopied => 'Скопійовано';

  @override
  String get commonMore => 'Більше';

  @override
  String get commonMoreOptions => 'Інші дії';

  @override
  String get commonClear => 'Очистити';

  @override
  String get commonNone => 'Немає';

  @override
  String get commonUntitled => 'Без назви';

  @override
  String get commonLoading => 'Завантаження…';

  @override
  String get commonSomethingWentWrong => 'Щось пішло не так';

  @override
  String get commonToday => 'Сьогодні';

  @override
  String get commonYesterday => 'Учора';

  @override
  String get commonSettings => 'Налаштування';

  @override
  String get commonCollections => 'Колекції';

  @override
  String get commonAutomations => 'Автоматизації';

  @override
  String commonCardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count картки',
      many: '$count карток',
      few: '$count картки',
      one: '$count картка',
    );
    return '$_temp0';
  }

  @override
  String commonFieldCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count поля',
      many: '$count полів',
      few: '$count поля',
      one: '$count поле',
    );
    return '$_temp0';
  }

  @override
  String get coreYes => 'Так';

  @override
  String get coreNo => 'Ні';

  @override
  String coreLinkedCount(int count) {
    return 'пов’язаних: $count';
  }

  @override
  String coreNoValueGroup(String field) {
    return '$field: не вказано';
  }

  @override
  String coreWeekOf(String day) {
    return 'Тиждень з $day';
  }

  @override
  String get coreDefaultViewName => 'Усі';

  @override
  String get coreFormulaTypeNumber => 'Число';

  @override
  String get coreFormulaTypeText => 'Текст';

  @override
  String get coreFormulaTypeBoolean => 'Так / Ні';

  @override
  String get coreFormulaTypeDate => 'Дата';

  @override
  String get coreAggregateOpCount => 'Кількість';

  @override
  String get coreAggregateOpSum => 'Сума';

  @override
  String get coreAggregateOpAverage => 'Середнє';

  @override
  String get coreAggregateOpMin => 'Мін.';

  @override
  String get coreAggregateOpMax => 'Макс.';

  @override
  String formulaFunctionUsage(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'IF': 'IF(умова, тоді, інакше)',
      'AND': 'AND(a, b, …)',
      'OR': 'OR(a, b, …)',
      'NOT': 'NOT(умова)',
      'ROUND': 'ROUND(число, знаки)',
      'FLOOR': 'FLOOR(число)',
      'CEIL': 'CEIL(число)',
      'ABS': 'ABS(число)',
      'MIN': 'MIN(a, b, …)',
      'MAX': 'MAX(a, b, …)',
      'CONCAT': 'CONCAT(a, b, …)',
      'LEN': 'LEN(текст)',
      'UPPER': 'UPPER(текст)',
      'LOWER': 'LOWER(текст)',
      'TODAY': 'TODAY()',
      'YEAR': 'YEAR(дата)',
      'MONTH': 'MONTH(дата)',
      'DAY': 'DAY(дата)',
      'ISBLANK': 'ISBLANK(значення)',
      'other': '$name',
    });
    return '$_temp0';
  }

  @override
  String formulaFunctionSummary(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'IF': 'Вибирає значення за умовою «Так / Ні».',
      'AND': '«Так», коли всі умови — «Так».',
      'OR': '«Так», коли хоч одна умова — «Так».',
      'NOT': 'Змінює «Так» на «Ні» й навпаки.',
      'ROUND':
          'Округлює до заданої кількості знаків після коми (за замовчуванням 0).',
      'FLOOR': 'Округлює вниз до цілого.',
      'CEIL': 'Округлює вгору до цілого.',
      'ABS': 'Число без знака.',
      'MIN': 'Найменше число.',
      'MAX': 'Найбільше число.',
      'CONCAT': 'Об’єднує значення в один текст.',
      'LEN': 'Кількість символів у тексті.',
      'UPPER': 'Текст великими літерами.',
      'LOWER': 'Текст малими літерами.',
      'TODAY': 'Сьогоднішня дата.',
      'YEAR': 'Рік дати.',
      'MONTH': 'Місяць дати (1–12).',
      'DAY': 'День місяця дати.',
      'ISBLANK': '«Так», коли значення порожнє.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get formulaErrorEmpty => 'Введіть формулу';

  @override
  String formulaErrorNotANumber(String text) {
    return '«$text» — не число';
  }

  @override
  String get formulaErrorUnclosedText => 'Закрийте текст лапками \"';

  @override
  String formulaErrorUnclosedField(String brace) {
    return 'Закрийте поле дужкою $brace';
  }

  @override
  String formulaErrorUnexpected(String text) {
    return 'Тут не очікувалося «$text»';
  }

  @override
  String formulaErrorNoSuchField(String name) {
    return 'Немає поля «$name»';
  }

  @override
  String get formulaErrorOwnField =>
      'Формула не може використовувати власне поле';

  @override
  String formulaErrorFieldNotUsable(String name) {
    return 'Поле «$name» не можна використати у формулі — щоб підсумувати пов’язані картки, скористайтеся режимом «Агрегація»';
  }

  @override
  String formulaErrorFieldWithoutBraces(String token) {
    return 'Беріть назви полів у фігурні дужки: $token';
  }

  @override
  String formulaErrorUnknownFunction(String name) {
    return 'Невідома функція «$name»';
  }

  @override
  String formulaErrorWrongArguments(String usage) {
    return 'Пишіть так: $usage';
  }

  @override
  String formulaErrorUnclosedCall(String name) {
    return 'Закрийте $name( дужкою )';
  }

  @override
  String formulaErrorExpectsNumbers(String name) {
    return '$name приймає лише числа';
  }

  @override
  String formulaErrorExpectsBooleans(String name) {
    return '$name приймає лише значення «Так / Ні»';
  }

  @override
  String formulaErrorExpectsText(String name) {
    return '$name приймає лише текст';
  }

  @override
  String formulaErrorExpectsDate(String name) {
    return '$name приймає лише дату';
  }

  @override
  String formulaErrorNeedsCondition(String name) {
    return '$name потребує умови «Так / Ні»';
  }

  @override
  String formulaErrorBranchTypesDiffer(String name, String left, String right) {
    return 'У $name «тоді» й «інакше» мають бути одного типу ($left і $right)';
  }

  @override
  String get formulaErrorUnclosedBracket => 'Закрийте дужку )';

  @override
  String get formulaErrorEndsEarly => 'Формула обривається зарано';

  @override
  String get formulaErrorNegateNeedsNumber => '«-» потребує числа';

  @override
  String get formulaErrorJoinWithAmpersand =>
      'Щоб об’єднати текст, використовуйте &';

  @override
  String formulaErrorCannotCombine(String op, String left, String right) {
    return '«$op» не поєднує $left і $right';
  }

  @override
  String get capabilitySchemaReadTitle => 'Бачити ваші колекції й поля';

  @override
  String get capabilitySchemaReadExplanation =>
      'Читає назви й типи колекцій і полів.';

  @override
  String get capabilityDataReadTitle => 'Читати картки';

  @override
  String get capabilityDataReadExplanation =>
      'Читає значення карток у дозволених колекціях.';

  @override
  String get capabilityDataWriteTitle => 'Створювати й змінювати картки';

  @override
  String get capabilityDataWriteExplanation => 'Пропонує нові картки та зміни.';

  @override
  String get capabilityDataDeleteTitle => 'Видаляти картки';

  @override
  String get capabilityDataDeleteExplanation =>
      'Пропонує видалити картки. Ніколи не застосовується автоматично.';

  @override
  String get capabilitySchemaWriteTitle => 'Змінювати колекції й поля';

  @override
  String get capabilitySchemaWriteExplanation =>
      'Пропонує нові поля або зміни полів. Ніколи не застосовується автоматично.';

  @override
  String get capabilitySchemaDeleteTitle => 'Видаляти поля й колекції';

  @override
  String get capabilitySchemaDeleteExplanation =>
      'Пропонує видалити поля або колекції. Ніколи не застосовується автоматично.';

  @override
  String get capabilityViewsWriteTitle => 'Змінювати подання';

  @override
  String get capabilityViewsWriteExplanation =>
      'Пропонує зміни подань — фільтри, сортування, стовпці. Ніколи не застосовується автоматично.';

  @override
  String get capabilityUiNavigateTitle => 'Посилатися на картки';

  @override
  String get capabilityUiNavigateExplanation =>
      'Показує посилання, що відкривають картку чи подання, коли ви їх торкаєтеся.';

  @override
  String get coreSchemaCollectionNameRequired => 'Вкажіть назву колекції';

  @override
  String get coreSchemaFieldNameRequired => 'Вкажіть назву поля';

  @override
  String coreSchemaDuplicateFieldName(String name) {
    return 'Поле з назвою «$name» уже є';
  }

  @override
  String coreSchemaTypeLocked(String name) {
    return 'Тип поля «$name» не можна змінити після збереження — додайте нове поле';
  }

  @override
  String get templatesTitle => 'Почати з шаблону';

  @override
  String get templatesSubtitle =>
      'Готові колекції, які можна змінювати, як і будь-які інші.';

  @override
  String get templatesLoadFailed => 'Не вдалося завантажити шаблони.';

  @override
  String get templatesSampleHint =>
      'Разом із шаблоном додаються зразки карток, щоб ви побачили, як усе працює, — їх можна будь-коли видалити.';

  @override
  String templatesContents(int collections, int cards) {
    String _temp0 = intl.Intl.pluralLogic(
      collections,
      locale: localeName,
      other: '$collections колекції',
      many: '$collections колекцій',
      few: '$collections колекції',
      one: '$collections колекція',
    );
    String _temp1 = intl.Intl.pluralLogic(
      cards,
      locale: localeName,
      other: '$cards зразка картки',
      many: '$cards зразків карток',
      few: '$cards зразки карток',
      one: '$cards зразок картки',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get templatesAdd => 'Додати до робочого простору';

  @override
  String templatesAddFailed(String name) {
    return 'Не вдалося додати «$name». Перевірте з’єднання.';
  }

  @override
  String get coreTrelloBoard => 'Дошка Trello';

  @override
  String get coreTrelloUntitledCard => 'Картка без назви';

  @override
  String get coreTrelloUntitledList => 'Список без назви';

  @override
  String get coreTrelloUntitledField => 'Поле без назви';

  @override
  String get coreTrelloUntitledOption => 'Варіант без назви';

  @override
  String get coreTrelloUntitledItem => 'Пункт без назви';

  @override
  String get coreTrelloNoList => 'Без списку';

  @override
  String get coreTrelloLabel => 'Мітка';

  @override
  String get coreTrelloMember => 'Учасник';

  @override
  String get coreTrelloName => 'Назва';

  @override
  String get coreTrelloDescription => 'Опис';

  @override
  String get coreTrelloList => 'Список';

  @override
  String get coreTrelloLabels => 'Мітки';

  @override
  String get coreTrelloMembers => 'Учасники';

  @override
  String get coreTrelloStart => 'Початок';

  @override
  String get coreTrelloDue => 'Термін';

  @override
  String get coreTrelloDueDone => 'Термін виконано';

  @override
  String get coreTrelloAttachments => 'Вкладення';

  @override
  String get coreTrelloLink => 'Посилання на Trello';

  @override
  String get coreTrelloArchived => 'В архіві';

  @override
  String get coreTrelloBoardView => 'Дошка';

  @override
  String get coreTrelloItem => 'Пункт';

  @override
  String get coreTrelloDone => 'Виконано';

  @override
  String get coreTrelloChecklist => 'Чекліст';

  @override
  String get coreTrelloCard => 'Картка';

  @override
  String get coreTrelloComment => 'Коментар';

  @override
  String get coreTrelloAuthor => 'Автор';

  @override
  String get coreTrelloDate => 'Дата';

  @override
  String coreTrelloChecklistItems(String board) {
    return '$board · Пункти чеклістів';
  }

  @override
  String coreTrelloComments(String board) {
    return '$board · Коментарі';
  }

  @override
  String coreTrelloFieldRenamed(String field) {
    return '$field (поле Trello)';
  }

  @override
  String coreTrelloFieldRenamedNumbered(String field, int number) {
    return '$field (поле Trello $number)';
  }

  @override
  String get coreTrelloColorGreen => 'Зелений';

  @override
  String get coreTrelloColorYellow => 'Жовтий';

  @override
  String get coreTrelloColorOrange => 'Помаранчевий';

  @override
  String get coreTrelloColorRed => 'Червоний';

  @override
  String get coreTrelloColorPurple => 'Фіолетовий';

  @override
  String get coreTrelloColorBlue => 'Синій';

  @override
  String get coreTrelloColorSky => 'Блакитний';

  @override
  String get coreTrelloColorLime => 'Лаймовий';

  @override
  String get coreTrelloColorPink => 'Рожевий';

  @override
  String get coreTrelloColorBlack => 'Чорний';

  @override
  String coreTrelloColorShade(String color, String shade) {
    String _temp0 = intl.Intl.selectLogic(shade, {
      'light': '$color (світлий)',
      'dark': '$color (темний)',
      'other': '$color $shade',
    });
    return '$_temp0';
  }

  @override
  String validationRequired(String name) {
    return 'Поле «$name» обов’язкове';
  }

  @override
  String validationDateMin(String name, String date) {
    return '«$name»: дата має бути не раніше $date';
  }

  @override
  String validationDateMax(String name, String date) {
    return '«$name»: дата має бути не пізніше $date';
  }

  @override
  String validationNumberMin(String name, String min) {
    return '«$name»: щонайменше $min';
  }

  @override
  String validationNumberMax(String name, String max) {
    return '«$name»: щонайбільше $max';
  }

  @override
  String validationTooLong(String name, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '«$name»: щонайбільше $max символу',
      many: '«$name»: щонайбільше $max символів',
      few: '«$name»: щонайбільше $max символи',
      one: '«$name»: щонайбільше $max символ',
    );
    return '$_temp0';
  }

  @override
  String validationOneFile(String name) {
    return '«$name»: можна додати лише один файл';
  }

  @override
  String validationFileType(String file, String name) {
    return 'Тип файлу «$file» не підтримується в полі «$name»';
  }

  @override
  String validationNoOption(String name, String option) {
    return 'У полі «$name» немає варіанта «$option»';
  }

  @override
  String validationInvalidOption(String option, String name) {
    return '«$option» — недійсний варіант для поля «$name»';
  }

  @override
  String validationBlankReference(String name) {
    return '«$name» містить порожнє посилання';
  }

  @override
  String validationOneReference(String name) {
    return '«$name»: можна вибрати лише одну картку';
  }

  @override
  String objectsNewItem(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {'other': 'Нова картка'});
    return '$_temp0';
  }

  @override
  String get objectsCloseEditor => 'Закрити редактор';

  @override
  String get objectsDiscardTitle => 'Відхилити зміни?';

  @override
  String objectsDiscardMessage(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {
      'other': 'Зміни в цій картці не збережено.',
    });
    return '$_temp0';
  }

  @override
  String get objectsDiscard => 'Відхилити';

  @override
  String get objectsKeepEditing => 'Продовжити редагування';

  @override
  String get objectsAnotherCard => 'інша картка';

  @override
  String objectsRunReverted(String run) {
    return '$run · Скасовано';
  }

  @override
  String objectsRunRevertedOnCard(String run, String card) {
    return '$run · $card · Скасовано';
  }

  @override
  String objectsDeleteItemTitle(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {'other': 'Видалити картку?'});
    return '$_temp0';
  }

  @override
  String objectsDeleteItemMessage(String title) {
    return '«$title» буде видалено.';
  }

  @override
  String objectsDeleteItem(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {'other': 'Видалити картку'});
    return '$_temp0';
  }

  @override
  String get objectsUploading => 'Завантаження…';

  @override
  String get objectsSaveAsNew => 'Зберегти як нову';

  @override
  String objectsHeaderMeta(String item, String created, String edited) {
    String _temp0 = intl.Intl.selectLogic(item, {'other': 'Картка'});
    return '$_temp0 · створено $created · змінено $edited';
  }

  @override
  String get objectsJustNow => 'щойно';

  @override
  String objectsMinutesAgo(int count) {
    return '$count хв тому';
  }

  @override
  String objectsHoursAgo(int count) {
    return '$count год тому';
  }

  @override
  String objectsFixFields(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Виправте $count поля, щоб зберегти',
      many: 'Виправте $count полів, щоб зберегти',
      few: 'Виправте $count поля, щоб зберегти',
      one: 'Виправте $count поле, щоб зберегти',
    );
    return '$_temp0';
  }

  @override
  String get objectsSaveFailed => 'Не вдалося зберегти — перевірте з’єднання';

  @override
  String objectsDeletedElsewhere(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {
      'other': 'Цю картку видалено деінде.',
    });
    return '$_temp0';
  }

  @override
  String get objectsSaveAsNewToRestore =>
      'Щоб відновити її, збережіть як нову.';

  @override
  String objectsChangedElsewhere(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Поля змінено деінде: $names.',
      many: 'Поля змінено деінде: $names.',
      few: 'Поля змінено деінде: $names.',
      one: 'Поле змінено деінде: $names.',
    );
    return '$_temp0';
  }

  @override
  String objectsNamesAnd(String names, String last) {
    return '$names і $last';
  }

  @override
  String get objectsOverwriteNote =>
      'Якщо зберегти, буде записано ваше значення.';

  @override
  String get objectsNeedsConnection => 'Потрібне з’єднання';

  @override
  String get objectsDismiss => 'Закрити';

  @override
  String get objectsChanged => 'Змінено';

  @override
  String objectsCouldNotOpen(String name) {
    return 'Не вдалося відкрити «$name»';
  }

  @override
  String objectsUploadFailed(String name) {
    return 'Не вдалося завантажити «$name»';
  }

  @override
  String objectsUploadTooLarge(String name) {
    return 'Не вдалося завантажити «$name»: файл має бути менший за 25 МБ';
  }

  @override
  String get objectsAssignedOnSave => 'Призначається під час збереження';

  @override
  String get objectsSetAutomatically => 'Заповнюється автоматично';

  @override
  String get objectsNothingToCalculate => 'Поки нічого обчислювати';

  @override
  String get objectsCalculated => 'Обчислюване поле';

  @override
  String objectsCantEditType(String type) {
    return 'Поле типу «$type» тут не редагується';
  }

  @override
  String get objectsReplaceFile => 'Замінити';

  @override
  String get objectsUploadFile => 'Завантажити файл';

  @override
  String objectsFileSizeBytes(String size) {
    return '$size Б';
  }

  @override
  String objectsFileSizeKb(String size) {
    return '$size КБ';
  }

  @override
  String objectsFileSizeMb(String size) {
    return '$size МБ';
  }

  @override
  String get objectsFileBadge => 'ФАЙЛ';

  @override
  String objectsRemoveNamed(String name) {
    return 'Прибрати «$name»';
  }

  @override
  String objectsUploadingNamed(String name) {
    return 'Завантаження «$name»';
  }

  @override
  String get objectsCancelUpload => 'Скасувати завантаження';

  @override
  String objectsUnknownItem(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {'other': 'Невідома картка'});
    return '$_temp0';
  }

  @override
  String objectsUnlinkNamed(String name) {
    return 'Відв’язати «$name»';
  }

  @override
  String objectsLinkItem(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {'other': 'Пов’язати картку'});
    return '$_temp0';
  }

  @override
  String get objectsEnterNumber => 'Введіть число';

  @override
  String get objectsNoOptions => 'Ще немає варіантів';

  @override
  String get objectsChoose => 'Виберіть…';

  @override
  String get objectsPickDate => 'Виберіть дату';

  @override
  String get objectsPickDateTime => 'Виберіть дату й час';

  @override
  String objectsClearNamed(String name) {
    return 'Очистити «$name»';
  }

  @override
  String objectsLinkedToThis(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {
      'other': 'Пов’язано з цією карткою',
    });
    return '$_temp0';
  }

  @override
  String objectsCouldNotDeleteItem(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {
      'other': 'Не вдалося видалити картку',
    });
    return '$_temp0';
  }

  @override
  String objectsCouldNotUpdate(String name) {
    return 'Не вдалося оновити «$name»';
  }

  @override
  String objectsCheckedOf(int done, int total, String check) {
    return '$done з $total $check';
  }

  @override
  String objectsAddItem(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {'other': 'Додати картку'});
    return '$_temp0';
  }

  @override
  String objectsLinkingVia(String field) {
    return 'Пов’язано через поле «$field»';
  }

  @override
  String objectsNoItemsYet(String items) {
    String _temp0 = intl.Intl.selectLogic(items, {'other': 'Ще немає карток'});
    return '$_temp0';
  }

  @override
  String objectsLinkItems(String items) {
    String _temp0 = intl.Intl.selectLogic(items, {'other': 'Пов’язати картки'});
    return '$_temp0';
  }

  @override
  String objectsFromCollection(String collection) {
    return 'з колекції «$collection»';
  }

  @override
  String objectsSearchItems(String items) {
    String _temp0 = intl.Intl.selectLogic(items, {'other': 'Шукати картки'});
    return '$_temp0';
  }

  @override
  String objectsShownOf(int shown, int total) {
    return '$shown з $total';
  }

  @override
  String objectsCollectionEmpty(String collection) {
    return 'У колекції «$collection» ще немає карток';
  }

  @override
  String get objectsThisCollectionEmpty => 'У цій колекції ще немає карток';

  @override
  String objectsNoMatch(String items, String query) {
    String _temp0 = intl.Intl.selectLogic(items, {
      'other': 'Немає карток за запитом «$query»',
    });
    return '$_temp0';
  }

  @override
  String get objectsTryAnotherName => 'Спробуйте іншу назву';

  @override
  String get objectsUnlink => 'Відв’язати';

  @override
  String get objectsLinked => 'Пов’язано';

  @override
  String get authErrorSignInFailed => 'Не вдалося увійти через Google.';

  @override
  String get authErrorNoUser => 'Вхід через Google не повернув користувача.';

  @override
  String get authErrorUnsupportedPlatform =>
      'Вхід через Google не підтримується на цій платформі.';

  @override
  String get authErrorNoIdToken => 'Вхід через Google не повернув ID-токен.';

  @override
  String get authErrorSignOutFailed => 'Не вдалося вийти.';

  @override
  String get trelloImportTitle => 'Імпорт з Trello';

  @override
  String get trelloImportFiles => 'Файли';

  @override
  String get trelloImportPaste => 'Вставити';

  @override
  String get trelloImportProblemNotABoard =>
      'Це не експорт дошки Trello. На дошці скористайтеся пунктом «Export as JSON».';

  @override
  String get trelloImportProblemAlreadyAdded => 'Уже додано';

  @override
  String get trelloImportProblemUnreadable =>
      'Не вдалося прочитати вибрані файли. Виберіть їх ще раз або вставте вміст.';

  @override
  String get trelloImportDropHint => 'Експорти дошок Trello (.json)';

  @override
  String get trelloImportChooseFiles => 'Вибрати файли';

  @override
  String get trelloImportBoardJson => 'JSON дошки';

  @override
  String get trelloImportPasteHint => 'Вставте весь експорт дошки';

  @override
  String get trelloImportPasteHelp =>
      'Вставте весь експорт однієї дошки й додайте її. Повторіть для інших дошок.';

  @override
  String get trelloImportAddBoard => 'Додати дошку';

  @override
  String get trelloImportStep1 => 'Крок 1 з 2 · Додайте дошки';

  @override
  String get trelloImportBoardsToImport => 'Дошки для імпорту';

  @override
  String get trelloImportAddAtLeastOne => 'Додайте хоча б одну дошку';

  @override
  String get trelloImportHowToTitle => 'Експортуйте кожну дошку з Trello';

  @override
  String get trelloImportHowToOpen => 'Відкрийте дошку → ';

  @override
  String get trelloImportHowToMenu => 'Menu';

  @override
  String get trelloImportHowToShare => 'Print, export, and share';

  @override
  String get trelloImportHowToExport => 'Export as JSON';

  @override
  String get trelloImportHowToRest =>
      '. Якщо Trello відкриє експорт у новій вкладці, збережіть сторінку як файл .json (Ctrl+S) або скопіюйте весь вміст і скористайтеся вкладкою «Вставити». Нічого не імпортується, доки ви не підтвердите вибір.';

  @override
  String get trelloImportNoBoards => 'Ще немає дошок';

  @override
  String get trelloImportNoBoardsBody =>
      'Додані дошки з’являться тут разом зі списками й картками.';

  @override
  String trelloImportListCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n списку',
      many: '$n списків',
      few: '$n списки',
      one: '$n список',
    );
    return '$_temp0';
  }

  @override
  String trelloImportCardCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n картки',
      many: '$n карток',
      few: '$n картки',
      one: '$n картка',
    );
    return '$_temp0';
  }

  @override
  String trelloImportChecklistItemCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n пункту чеклістів',
      many: '$n пунктів чеклістів',
      few: '$n пункти чеклістів',
      one: '$n пункт чекліста',
    );
    return '$_temp0';
  }

  @override
  String trelloImportCommentCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n коментаря',
      many: '$n коментарів',
      few: '$n коментарі',
      one: '$n коментар',
    );
    return '$_temp0';
  }

  @override
  String trelloImportItemCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n пункту',
      many: '$n пунктів',
      few: '$n пункти',
      one: '$n пункт',
    );
    return '$_temp0';
  }

  @override
  String trelloImportCollectionCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n колекції',
      many: '$n колекцій',
      few: '$n колекції',
      one: '$n колекція',
    );
    return '$_temp0';
  }

  @override
  String trelloImportCollectionsButton(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Імпортувати $n колекції',
      many: 'Імпортувати $n колекцій',
      few: 'Імпортувати $n колекції',
      one: 'Імпортувати $n колекцію',
    );
    return '$_temp0';
  }

  @override
  String trelloImportArchivedCards(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$n архівної картки. Такі картки отримають прапорець «В архіві» й не показуватимуться на дошці.',
      many:
          '$n архівних карток. Такі картки отримають прапорець «В архіві» й не показуватимуться на дошці.',
      few:
          '$n архівні картки. Такі картки отримають прапорець «В архіві» й не показуватимуться на дошці.',
      one:
          '$n архівна картка. Такі картки отримають прапорець «В архіві» й не показуватимуться на дошці.',
    );
    return '$_temp0';
  }

  @override
  String trelloImportMoreFields(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$n поля',
      many: '+$n полів',
      few: '+$n поля',
      one: '+$n поле',
    );
    return '$_temp0';
  }

  @override
  String trelloImportBoardViewByList(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n картки · дошка за списками',
      many: '$n карток · дошка за списками',
      few: '$n картки · дошка за списками',
      one: '$n картка · дошка за списками',
    );
    return '$_temp0';
  }

  @override
  String trelloImportRemoveNamed(String name) {
    return 'Прибрати «$name»';
  }

  @override
  String trelloImportDismissNamed(String name) {
    return 'Приховати «$name»';
  }

  @override
  String get trelloImportStep2 => 'Крок 2 з 2 · Виберіть, що імпортувати';

  @override
  String get trelloImportNoAutomationsTitle => 'Автоматизації не перенесуться.';

  @override
  String get trelloImportNoAutomationsBody =>
      'Trello не додає правила й кнопки Butler до експорту дошок — налаштуйте їх знову в розділі «Автоматизації», коли дошки буде імпортовано.';

  @override
  String get trelloImportIncludeArchived =>
      'Імпортувати архівні картки й списки';

  @override
  String get trelloImportNoArchived => 'Архівних карток немає.';

  @override
  String get trelloImportCollectionsHelp =>
      'Кожна дошка стане колекцією з поданням-дошкою, згрупованим за списками. Пункти чеклістів і коментарі показуються списками в кожній картці.';

  @override
  String get trelloImportNothingChosen => 'Виберіть хоча б одну колекцію';

  @override
  String get trelloImportOffline =>
      'Ви офлайн — під’єднайтеся, щоб імпортувати';

  @override
  String get trelloImportNeedsBoard => 'потрібна дошка';

  @override
  String get trelloImportChecklistItems => 'Пункти чеклістів';

  @override
  String get trelloImportComments => 'Коментарі';

  @override
  String get trelloImportCapped =>
      'Експорт Trello зберігає лише 1000 найновіших дій, тож старіших коментарів може бракувати.';

  @override
  String get trelloImportWritingCardsAndItems => 'Записуємо картки й пункти';

  @override
  String get trelloImportWritingCards => 'Записуємо картки';

  @override
  String get trelloImportImporting => 'Імпортуємо з Trello';

  @override
  String get trelloImportKeepOpen => 'Не закривайте вікно до завершення.';

  @override
  String get trelloImportPaused => 'Імпорт призупинено.';

  @override
  String get trelloImportStalled =>
      'Застосунку не вдалося зв’язатися з сервером протягом 30 секунд. Перевірте з’єднання й повторіть спробу — уже записані картки не додадуться вдруге. Якщо закрити вікно, уже імпортоване залишиться.';

  @override
  String get trelloImportRefused =>
      'Застосунку не вдалося зберегти деякі картки. Перевірте з’єднання й повторіть спробу — уже записані картки не додадуться вдруге. Якщо закрити вікно, уже імпортоване залишиться.';

  @override
  String trelloImportWrittenOf(String written, String total) {
    return '$written з $total';
  }

  @override
  String get trelloImportNoAutomationsStart =>
      'Імпортовані картки не запускають автоматизації.';

  @override
  String get trelloImportWritingKeepOpen => 'Запис — не закривайте вікно';

  @override
  String get trelloImportRowPaused => 'Призупинено';

  @override
  String get trelloImportRowWriting => 'Запис';

  @override
  String get trelloImportRowWaiting => 'Очікування';

  @override
  String get trelloImportDoneTitle => 'Дошки імпортовано';

  @override
  String get trelloImportButlerHint =>
      'Користувалися Butler у Trello? Відтворіть ті самі кроки за допомогою автоматизацій.';

  @override
  String get settingsWorkspaceSection => 'Робочий простір';

  @override
  String get settingsAutomationsSubtitle => 'Модулі, кнопки й запуски';

  @override
  String get settingsAccountSection => 'Обліковий запис';

  @override
  String get settingsImportSection => 'Імпорт з інших застосунків';

  @override
  String get settingsTrelloSubtitle =>
      'Дошки стають колекціями — списки, картки, мітки, чеклісти й коментарі';

  @override
  String get settingsSignOut => 'Вийти';

  @override
  String get settingsAppearanceSection => 'Вигляд';

  @override
  String get settingsTheme => 'Тема';

  @override
  String get settingsThemeSubtitle => 'Зберігається на цьому пристрої';

  @override
  String get settingsThemeLight => 'Світла';

  @override
  String get settingsThemeDark => 'Темна';

  @override
  String get settingsThemeSystem => 'Системна';

  @override
  String get viewsGroupBy => 'Групувати за';

  @override
  String get viewsAddField => 'Додати поле';

  @override
  String get viewsSetupCard => 'Налаштувати картку';

  @override
  String get viewsModeTable => 'Таблиця';

  @override
  String get viewsModeTableDescription =>
      'Рядки й стовпці з сортуванням за будь-яким полем.';

  @override
  String get viewsColumns => 'Стовпці';

  @override
  String get viewsModeBoard => 'Дошка';

  @override
  String get viewsModeBoardDescription =>
      'Картки в стовпцях за полем вибору чи посилання.';

  @override
  String get viewsModeList => 'Список';

  @override
  String get viewsModeListDescription =>
      'Компактні рядки, за потреби — у розділах.';

  @override
  String get viewsModeCalendar => 'Календар';

  @override
  String get viewsModeCalendarDescription => 'Картки по днях за полем дати.';

  @override
  String get viewsModeSummary => 'Зведення';

  @override
  String get viewsModeSummaryDescription =>
      'Великі числа для кожної картки, як на інформаційній панелі.';

  @override
  String get viewsSetupTiles => 'Налаштувати плитки';

  @override
  String get viewsDateField => 'Поле дати';

  @override
  String get viewsAddDateField => 'Додати поле дати';

  @override
  String get viewsNeedsChoiceOrReference => 'Потрібне поле вибору чи посилання';

  @override
  String get viewsNeedsDateField => 'Потрібне поле дати';

  @override
  String viewsNewItem(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {'other': 'Нова картка'});
    return '$_temp0';
  }

  @override
  String viewsShownOfTotal(int shown, int total) {
    return '$shown з $total';
  }

  @override
  String viewsTotalCount(int count, String noun) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count картки',
      many: '$count карток',
      few: '$count картки',
      one: '$count картка',
    );
    String _temp1 = intl.Intl.selectLogic(noun, {'other': '$_temp0'});
    return '$_temp1';
  }

  @override
  String viewsSortBy(String field) {
    return 'Сортувати за полем «$field»';
  }

  @override
  String get viewsSortAscending => 'за зростанням';

  @override
  String get viewsSortDescending => 'за спаданням';

  @override
  String get viewsChangeFields => 'Змінити поля';

  @override
  String get viewsEnteredByHand => 'Введено вручну';

  @override
  String get viewsEditValues => 'Змінити значення';

  @override
  String get viewsPickTilesHint =>
      'Виберіть поля для показу кнопкою «Налаштувати плитки».';

  @override
  String viewsTileEmpty(String label) {
    return '$label: порожньо';
  }

  @override
  String viewsGroupChip(String name) {
    return 'Група: $name';
  }

  @override
  String get viewsGroupChipNone => 'Група: немає';

  @override
  String viewsReorderedIn(String group) {
    return 'Порядок змінено в «$group»';
  }

  @override
  String viewsReorderedInSortOff(String group) {
    return 'Порядок змінено в «$group» — сортування вимкнено';
  }

  @override
  String viewsMovedTo(String group) {
    return 'Переміщено в «$group»';
  }

  @override
  String viewsMovedToHidden(String group) {
    return 'Переміщено в «$group» — приховано фільтром';
  }

  @override
  String get viewsItemsFallback => 'картки';

  @override
  String viewsColumnOf(int index, int count) {
    return 'Стовпець $index з $count';
  }

  @override
  String get viewsJumpToColumn => 'Перейти до стовпця';

  @override
  String get viewsBoardNeedsField =>
      'Для дошки потрібне поле вибору чи посилання';

  @override
  String viewsBoardNeedsFieldMessage(String items) {
    String _temp0 = intl.Intl.selectLogic(items, {
      'other':
          'Додайте поле вибору чи посилання — кожне його значення стане стовпцем, і картки можна буде перетягувати між ними.',
    });
    return '$_temp0';
  }

  @override
  String get viewsBoardChooseGroup => 'Виберіть, як групувати дошку';

  @override
  String get viewsBoardChooseGroupMessage =>
      'Кожне значення поля стане стовпцем.';

  @override
  String get viewsGroupByAction => 'Групувати за…';

  @override
  String viewsDateChip(String name) {
    return 'Дата: $name';
  }

  @override
  String get viewsDateChipEmpty => 'Дата';

  @override
  String get viewsCalendarNeedsDate => 'Для календаря потрібне поле дати';

  @override
  String viewsCalendarNeedsDateMessage(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {
      'other': 'Додайте поле дати, щоб розподілити картки по днях.',
    });
    return '$_temp0';
  }

  @override
  String get viewsCalendarChooseDate => 'Виберіть поле дати';

  @override
  String viewsCalendarChooseDateMessage(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {
      'other': 'Виберіть дату, за якою картки розподіляться по днях.',
    });
    return '$_temp0';
  }

  @override
  String get viewsOrderChanged => 'Порядок змінено';

  @override
  String get viewsDragToReorder => 'Перетягніть, щоб змінити порядок';

  @override
  String viewsLinkCardGone(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {
      'other': 'Картки за цим посиланням уже немає',
    });
    return '$_temp0';
  }

  @override
  String viewsAddFirstItem(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {
      'other': 'Додайте першу картку',
    });
    return '$_temp0';
  }

  @override
  String get viewsAddFilter => 'Додати фільтр';

  @override
  String get viewsEditFilter => 'Змінити фільтр';

  @override
  String get viewsSort => 'Сортування';

  @override
  String get viewsTitleFallback => 'Назва';

  @override
  String get viewsAddedHidden => 'Додано — приховано фільтрами';

  @override
  String get viewsSavedHidden => 'Збережено — приховано фільтрами';

  @override
  String viewsFilledFromColumn(String group) {
    return 'Заповнено зі стовпця «$group»';
  }

  @override
  String viewsFilledFromGroup(String group) {
    return 'Заповнено з групи «$group»';
  }

  @override
  String viewsFilledFromDay(String date) {
    return 'Заповнено датою $date';
  }

  @override
  String viewsDeletedTitle(String title) {
    return 'Видалено «$title»';
  }

  @override
  String get viewsDeleteViewTitle => 'Видалити подання?';

  @override
  String viewsDeleteViewMessage(String name) {
    return 'Подання «$name» буде видалено разом із його фільтрами й сортуванням. Ваші дані залишаться без змін.';
  }

  @override
  String get viewsCustomize => 'Налаштувати';

  @override
  String get viewsViewSettings => 'Налаштування подання';

  @override
  String get viewsCustomizeCollection => 'Налаштувати колекцію';

  @override
  String get viewsNoFieldsTitle => 'У цій колекції ще немає полів';

  @override
  String viewsNoFieldsMessage(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {
      'other':
          'Додайте поля, які хочете відстежувати для кожної картки, і поверніться сюди, щоб працювати з ними.',
    });
    return '$_temp0';
  }

  @override
  String get viewsSaveAsView => 'Зберегти як подання';

  @override
  String get viewsNoMatchesTitle => 'Нічого не відповідає цим фільтрам';

  @override
  String viewsNoMatchesMessage(int count, String items) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count картки',
      many: '$count карток',
      few: '$count карток',
      one: '$count картки',
    );
    String _temp1 = intl.Intl.selectLogic(items, {
      'other': 'Жодна з $_temp0 не відповідає фільтрам вище.',
    });
    return '$_temp1';
  }

  @override
  String get viewsClearFilters => 'Скинути фільтри';

  @override
  String viewsAssistantFiltersTooltip(String filters) {
    return 'Фільтри від Моркви (не збережено): $filters';
  }

  @override
  String viewsFromAssistant(String filters) {
    return 'Від Моркви · $filters';
  }

  @override
  String get viewsClearAssistantFilters => 'Прибрати фільтри Моркви';

  @override
  String viewsUnknownMode(String mode, String fallback) {
    return 'Це подання використовує режим «$mode», якого в цій версії ще немає. Показуємо його як: $fallback.';
  }

  @override
  String get viewsNotFoundTitle => 'Колекцію не знайдено';

  @override
  String get viewsNotFoundMessage =>
      'Можливо, цю колекцію видалено або посилання неправильне. Поверніться на головну й виберіть іншу.';

  @override
  String get viewsBackToCollections => 'До колекцій';

  @override
  String get viewsLoadError => 'Не вдалося завантажити подання';

  @override
  String get viewsLoadErrorMessage => 'Перевірте з’єднання й спробуйте ще раз.';

  @override
  String viewsLoadTargetFailed(String name) {
    return 'Не вдалося завантажити «$name»';
  }

  @override
  String get viewsLinkFilterInvalid => 'Фільтр у цьому посиланні недійсний';

  @override
  String get viewsSaveViewFailed => 'Не вдалося зберегти подання';

  @override
  String get viewsSaveChangeFailed => 'Не вдалося зберегти зміну';

  @override
  String get viewsDeleteFailed => 'Не вдалося видалити';

  @override
  String get viewsUntitledView => 'Подання без назви';

  @override
  String viewsCopyName(String name) {
    return '$name (копія)';
  }

  @override
  String viewsFilteredName(String name) {
    return '$name · з фільтром';
  }

  @override
  String get viewWidgetsPopover => 'Спливне вікно';

  @override
  String get viewWidgetsLastViewCantDelete =>
      'Останнє подання не можна видалити';

  @override
  String get viewWidgetsNewView => 'Нове подання';

  @override
  String get viewWidgetsViewOptions => 'Параметри подання';

  @override
  String get viewWidgetsSortCreated => 'Створено';

  @override
  String get viewWidgetsSortUpdated => 'Оновлено';

  @override
  String get viewWidgetsPickLookupReference =>
      'Виберіть посилання для підстановки';

  @override
  String get viewWidgetsPickLookupField => 'Виберіть поле для показу';

  @override
  String viewWidgetsLookupSummary(String field, String item, String reference) {
    String _temp0 = intl.Intl.selectLogic(item, {
      'other': '$field з пов’язаної картки ($reference)',
    });
    return '$_temp0';
  }

  @override
  String get viewWidgetsNoFormulaYet => 'Формули ще немає';

  @override
  String get viewWidgetsPickAggregateSource => 'Виберіть, що підсумувати';

  @override
  String viewWidgetsAggregateOfLinkingHere(
    String op,
    String field,
    String source,
    String reference,
  ) {
    return '$op «$field» з карток «$source», що посилаються сюди через «$reference»';
  }

  @override
  String viewWidgetsAggregateOfLinked(
    String op,
    String field,
    String source,
    String reference,
  ) {
    return '$op «$field» з пов’язаних карток «$source» ($reference)';
  }

  @override
  String viewWidgetsAggregateOfAll(String op, String field, String source) {
    return '$op «$field» з усіх карток «$source»';
  }

  @override
  String viewWidgetsCountLinkingHere(String source, String reference) {
    return 'Кількість карток «$source», що посилаються сюди через «$reference»';
  }

  @override
  String viewWidgetsCountLinked(String source, String reference) {
    return 'Кількість пов’язаних карток «$source» ($reference)';
  }

  @override
  String viewWidgetsCountAll(String source) {
    return 'Кількість усіх карток «$source»';
  }

  @override
  String viewWidgetsSummaryWhere(String summary, String conditions) {
    return '$summary, де $conditions';
  }

  @override
  String get viewWidgetsConditionSeparator => ' і ';

  @override
  String get viewWidgetsUnknownField => 'Невідоме поле';

  @override
  String get viewWidgetsUnknownItem => 'Невідома картка';

  @override
  String viewWidgetsFilterChip(String field, String condition) {
    return '$field: $condition';
  }

  @override
  String get viewWidgetsOpIs => '';

  @override
  String get viewWidgetsOpIsNot => 'не';

  @override
  String get viewWidgetsOpHas => 'містить';

  @override
  String get viewWidgetsOpHasNo => 'не містить';

  @override
  String get viewWidgetsOpIsEmpty => 'не заповнено';

  @override
  String get viewWidgetsOpIsNotEmpty => 'заповнено';

  @override
  String get viewWidgetsOpEquals => 'дорівнює';

  @override
  String get viewWidgetsOpContains => 'містить';

  @override
  String get viewWidgetsOpNotContains => 'не містить';

  @override
  String get viewWidgetsOpBefore => 'раніше за';

  @override
  String get viewWidgetsOpAfter => 'пізніше за';

  @override
  String get viewWidgetsOpOnDay => 'припадає на';

  @override
  String get viewWidgetsOpHasAnyOf => 'містить одне з';

  @override
  String get viewWidgetsOpIsAnyOf => 'одне з';

  @override
  String get viewWidgetsOpHasNoneOf => 'не містить жодного з';

  @override
  String get viewWidgetsOpIsNoneOf => 'жодне з';

  @override
  String get viewWidgetsOpIsChecked => 'позначено';

  @override
  String get viewWidgetsOpIsNotChecked => 'не позначено';

  @override
  String get viewWidgetsSort => 'Сортування';

  @override
  String get viewWidgetsRemoveFilter => 'Прибрати фільтр';

  @override
  String get viewWidgetsAddFilter => 'Додати фільтр';

  @override
  String get viewWidgetsFilter => 'Фільтр';

  @override
  String viewWidgetsFieldsIntroTiles(String view) {
    return 'Виберіть поля, які показувати плитками в «$view», і перетягніть їх, щоб задати порядок.';
  }

  @override
  String viewWidgetsFieldsIntroCard(String view) {
    return 'Виберіть поля, які показувати на кожній картці в «$view», і перетягніть їх, щоб задати порядок.';
  }

  @override
  String get viewWidgetsPreviewHeading => 'ПОПЕРЕДНІЙ ПЕРЕГЛЯД';

  @override
  String get viewWidgetsPreview => 'Попередній перегляд';

  @override
  String get viewWidgetsEmptyFieldsSkipped =>
      'Порожні поля на картці не показуються.';

  @override
  String get viewWidgetsShowColumn => 'Показ';

  @override
  String viewWidgetsLayoutBoard(String field) {
    return '«$field» показано як стовпці';
  }

  @override
  String viewWidgetsLayoutCalendar(String field) {
    return '«$field» визначає день кожної картки';
  }

  @override
  String viewWidgetsLayoutSeparate(String field) {
    return '«$field» показано окремо';
  }

  @override
  String get viewWidgetsTitleColumn => 'Стовпець назви';

  @override
  String get viewWidgetsCardTitle => 'Назва картки';

  @override
  String get viewWidgetsChangeTitleColumn => 'Змінити стовпець назви';

  @override
  String get viewWidgetsChangeCardTitle => 'Змінити назву картки';

  @override
  String viewWidgetsReorderField(String field) {
    return 'Змінити порядок: $field';
  }

  @override
  String viewWidgetsMoveField(String field) {
    return 'Перемістити «$field»';
  }

  @override
  String get viewWidgetsMoveUp => 'Перемістити вгору';

  @override
  String get viewWidgetsMoveDown => 'Перемістити вниз';

  @override
  String get viewWidgetsSortManual => 'Вручну';

  @override
  String get viewWidgetsSortBy => 'Сортувати за';

  @override
  String get viewWidgetsSortAsc => 'За зрост.';

  @override
  String get viewWidgetsSortAscending => 'За зростанням';

  @override
  String get viewWidgetsSortDesc => 'За спад.';

  @override
  String get viewWidgetsSortDescending => 'За спаданням';

  @override
  String get viewWidgetsModeGallery => 'Галерея';

  @override
  String get viewWidgetsModeGalleryDescription => 'Картки із зображеннями';

  @override
  String get viewWidgetsModeGalleryReason => 'Потрібні файли зображень';

  @override
  String get viewWidgetsName => 'Назва';

  @override
  String get viewWidgetsNameHint => 'напр. Воронка';

  @override
  String get viewWidgetsCreateView => 'Створити подання';

  @override
  String viewWidgetsNewItem(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {'other': 'Нова картка'});
    return '$_temp0';
  }

  @override
  String get viewWidgetsAddDetails => 'Додати деталі';

  @override
  String get viewWidgetsLoading => 'Завантаження';

  @override
  String get viewWidgetsNothingMatchesFilters =>
      'Нічого не відповідає цим фільтрам';

  @override
  String get viewWidgetsClearFilters => 'Скинути фільтри';

  @override
  String get viewWidgetsNoDate => 'Без дати';

  @override
  String viewWidgetsShowNoDate(int count) {
    return 'Показати «Без дати» ($count)';
  }

  @override
  String get viewWidgetsHideNoDate => 'Сховати «Без дати»';

  @override
  String get viewWidgetsDropToClearDate => 'Відпустіть, щоб прибрати дату';

  @override
  String viewWidgetsEveryItemHasDate(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {
      'other':
          'У всіх карток є дата. Перетягніть картку сюди, щоб прибрати її дату.',
    });
    return '$_temp0';
  }

  @override
  String get viewWidgetsNothingScheduled => 'Ще нічого не заплановано';

  @override
  String get viewWidgetsCollapse => 'Згорнути';

  @override
  String get viewWidgetsExpand => 'Розгорнути';

  @override
  String viewWidgetsDayToday(String day) {
    return '$day · Сьогодні';
  }

  @override
  String get viewWidgetsMoveToDate => 'Перенести на дату';

  @override
  String viewWidgetsClearedDate(String title) {
    return 'Дату картки «$title» прибрано';
  }

  @override
  String viewWidgetsMovedToDay(String title, String day) {
    return 'Картку «$title» перенесено на $day';
  }

  @override
  String get viewWidgetsPreviousMonth => 'Попередній місяць';

  @override
  String get viewWidgetsNextMonth => 'Наступний місяць';

  @override
  String viewWidgetsClickDayToAdd(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {
      'other': 'Натисніть на день, щоб додати картку',
    });
    return '$_temp0';
  }

  @override
  String viewWidgetsNewItemOnDay(String item, String day) {
    String _temp0 = intl.Intl.selectLogic(item, {
      'other': 'Нова картка на $day',
    });
    return '$_temp0';
  }

  @override
  String viewWidgetsShowAllMore(int count) {
    return 'Показати всі, ще $count';
  }

  @override
  String viewWidgetsMoreCount(int count) {
    return 'Ще $count';
  }

  @override
  String viewWidgetsJumpToColumn(String column, int count) {
    return '$column, $count. Перейти до стовпця';
  }

  @override
  String viewWidgetsNewItemInColumn(String item, String column) {
    String _temp0 = intl.Intl.selectLogic(item, {
      'other': 'Нова картка у стовпці «$column»',
    });
    return '$_temp0';
  }

  @override
  String viewWidgetsCollapseColumn(String column) {
    return 'Згорнути «$column»';
  }

  @override
  String viewWidgetsDropToClearField(String field) {
    return 'Перетягніть сюди, щоб очистити «$field»';
  }

  @override
  String viewWidgetsNoItems(String items) {
    String _temp0 = intl.Intl.selectLogic(items, {'other': 'Немає карток'});
    return '$_temp0';
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
      other: '$count картки',
      many: '$count карток',
      few: '$count картки',
      one: '$count картка',
      zero: 'немає карток',
    );
    String _temp1 = intl.Intl.selectLogic(items, {
      'other': 'Розгорнути «$column», $_temp0',
    });
    String _temp2 = intl.Intl.selectLogic(item, {'other': '$_temp1'});
    return '$_temp2';
  }

  @override
  String get viewWidgetsViewSettings => 'Налаштування подання';

  @override
  String get viewWidgetsMode => 'Режим';

  @override
  String get viewWidgetsManualOrder => 'Ручний порядок';

  @override
  String get viewWidgetsColumns => 'Стовпці';

  @override
  String get viewWidgetsCardFields => 'Поля картки';

  @override
  String viewWidgetsShownCount(int count) {
    return 'Показано: $count';
  }

  @override
  String get viewWidgetsFilterBy => 'Фільтрувати за';

  @override
  String get viewWidgetsUpdateFilter => 'Оновити фільтр';

  @override
  String get viewWidgetsSearchFields => 'Пошук полів';

  @override
  String get viewWidgetsNoFieldsMatch => 'Немає відповідних полів';

  @override
  String get viewWidgetsNoOptionsYet => 'У цього поля ще немає варіантів';

  @override
  String get viewWidgetsMissingItem => 'Відсутня картка';

  @override
  String get viewWidgetsNothingToLink => 'Ще немає з чим пов’язати';

  @override
  String get viewWidgetsNumberHint => 'Число';

  @override
  String get viewWidgetsTextHint => 'Текст';

  @override
  String get viewWidgetsEnterNumber => 'Введіть число';

  @override
  String get viewWidgetsNoMatches => 'Немає збігів';

  @override
  String get viewWidgetsLoadingItems => 'Завантаження карток';

  @override
  String get viewWidgetsLoadingItemsEllipsis => 'Завантаження карток…';

  @override
  String get inboxTitle => 'Вхідні';

  @override
  String inboxSaveFailed(String error) {
    return 'Не вдалося зберегти — $error';
  }

  @override
  String get inboxDone => 'Виконано';

  @override
  String inboxMovedToToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count завдання перенесено на сьогодні',
      many: '$count завдань перенесено на сьогодні',
      few: '$count завдання перенесено на сьогодні',
      one: '$count завдання перенесено на сьогодні',
    );
    return '$_temp0';
  }

  @override
  String get inboxEmptyTitle => 'Вхідні порожні';

  @override
  String get inboxEmptyMessage =>
      'Записуйте нотатки, плануйте завдання й отримуйте нагадування. Пов’язуйте будь-що з карткою.';

  @override
  String get inboxLoadFailed => 'Не вдалося завантажити вхідні.';

  @override
  String get inboxAddNote => 'Додати нотатку…';

  @override
  String get inboxAddTask => 'Додати завдання…';

  @override
  String get inboxAddTaskToday => 'Додати завдання на сьогодні…';

  @override
  String inboxAddTaskFor(String day) {
    return 'Додати завдання на $day…';
  }

  @override
  String get inboxTaskSwitchToNote => 'Завдання — перемкнути на нотатку';

  @override
  String get inboxNoteSwitchToTask => 'Нотатка — перемкнути на завдання';

  @override
  String get inboxTask => 'Завдання';

  @override
  String get inboxNote => 'Нотатка';

  @override
  String get inboxTitleHint => 'Назва';

  @override
  String get inboxDetailsHint => 'Подробиці (необов’язково)';

  @override
  String get inboxDate => 'Дата';

  @override
  String get inboxNoDate => 'Без дати';

  @override
  String get inboxClearDate => 'Прибрати дату';

  @override
  String get inboxTomorrow => 'Завтра';

  @override
  String get inboxNextMonday => 'Наступного понеділка';

  @override
  String get inboxNextMon => 'Наступний пн';

  @override
  String get inboxPickDate => 'Вибрати…';

  @override
  String get inboxTime => 'Час';

  @override
  String get inboxAddTime => 'Додати час';

  @override
  String get inboxClearTime => 'Прибрати час';

  @override
  String get inboxSetDateForTime => 'Укажіть дату, щоб додати час';

  @override
  String get inboxReminder => 'Нагадування';

  @override
  String get inboxReminders => 'Нагадування';

  @override
  String get inboxNoReminders => 'Без нагадувань';

  @override
  String get inboxAddReminder => 'Додати нагадування';

  @override
  String get inboxRemoveReminder => 'Прибрати нагадування';

  @override
  String get inboxSetDateForReminder => 'Укажіть дату, щоб додати нагадування';

  @override
  String get inboxSetDateForReminders =>
      'Укажіть дату, щоб додавати нагадування';

  @override
  String get inboxReminderAtTime => 'Під час події';

  @override
  String get inboxReminder15MinBefore => 'За 15 хв';

  @override
  String get inboxReminder15Min => '15 хв';

  @override
  String get inboxReminder1HourBefore => 'За 1 год';

  @override
  String get inboxReminder1Hour => '1 год';

  @override
  String get inboxReminder1DayBefore => 'За 1 день';

  @override
  String get inboxReminder1Day => '1 день';

  @override
  String get inboxReminderMorningOf => 'Зранку того дня';

  @override
  String get inboxReminderDayBefore => 'Напередодні';

  @override
  String inboxReminderMinutes(int minutes) {
    return '$minutes хв';
  }

  @override
  String inboxNotificationsDefault(String link) {
    return 'Нагадування з’являються, поки застосунок відкритий. $link, щоб бачити їх і в інших вкладках.';
  }

  @override
  String get inboxTurnOnNotifications => 'Увімкніть сповіщення';

  @override
  String get inboxNotificationsGranted =>
      'Нагадування з’являються, поки застосунок відкритий у вкладці.';

  @override
  String get inboxNotificationsDenied =>
      'Сповіщення для цього сайту заблоковано — нагадування показуються лише в застосунку.';

  @override
  String get inboxLinkCard => 'Пов’язати картку';

  @override
  String get inboxRemoveLink => 'Прибрати посилання';

  @override
  String inboxOpenLink(String label) {
    return 'Відкрити $label';
  }

  @override
  String get inboxCardDeleted => 'Картку видалено';

  @override
  String get inboxCollectionDeleted => 'Колекцію видалено';

  @override
  String get inboxDeleted => 'Видалено';

  @override
  String get inboxDiscardMessage => 'Зміни в цьому записі не збережено.';

  @override
  String get inboxOverdue => 'Прострочені';

  @override
  String get inboxCompleted => 'Виконані';

  @override
  String get inboxMoveAllToToday => 'Перенести всі на сьогодні';

  @override
  String get inboxNothingForToday => 'На сьогодні нічого';

  @override
  String inboxNothingFor(String day) {
    return 'Нічого на $day';
  }

  @override
  String inboxDaysLate(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дн. прострочено',
      many: '$days дн. прострочено',
      few: '$days дн. прострочено',
      one: '$days дн. прострочено',
    );
    return '$_temp0';
  }

  @override
  String get inboxMarkDone => 'Позначити виконаним';

  @override
  String get inboxMarkNotDone => 'Позначити невиконаним';

  @override
  String inboxPickDateIn(String month) {
    return '$month, вибрати дату';
  }

  @override
  String get inboxPreviousWeek => 'Попередній тиждень';

  @override
  String get inboxNextWeek => 'Наступний тиждень';

  @override
  String inboxStripDay(String day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$day, $count невиконаних',
      many: '$day, $count невиконаних',
      few: '$day, $count невиконані',
      one: '$day, $count невиконане',
      zero: '$day',
    );
    return '$_temp0';
  }

  @override
  String inboxStripDayToday(String day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$day, сьогодні, $count невиконаних',
      many: '$day, сьогодні, $count невиконаних',
      few: '$day, сьогодні, $count невиконані',
      one: '$day, сьогодні, $count невиконане',
      zero: '$day, сьогодні',
    );
    return '$_temp0';
  }

  @override
  String get inboxCardsLoadFailed => 'Не вдалося завантажити картки';

  @override
  String get inboxSearchCollections => 'Шукати колекції';

  @override
  String get inboxNoCollections => 'Колекцій ще немає';

  @override
  String inboxNoCollectionsMatch(String query) {
    return 'Жодна колекція не відповідає «$query»';
  }

  @override
  String inboxSearchIn(String name) {
    return 'Пошук: $name';
  }

  @override
  String inboxShownOf(int shown, int total) {
    return '$shown з $total';
  }

  @override
  String inboxCollectionNoCards(String name) {
    return 'У «$name» ще немає карток';
  }

  @override
  String inboxNoCardsMatch(String query) {
    return 'Жодна картка не відповідає «$query»';
  }

  @override
  String get inboxBackToCollections => 'Назад до колекцій';

  @override
  String get inboxLinkStepCollection => 'Крок 1 з 2 · Виберіть колекцію';

  @override
  String get inboxLinkStepCard => 'Крок 2 з 2 · Виберіть картку';

  @override
  String get inboxAddToInbox => 'Додати у вхідні';

  @override
  String get inboxAddToInboxMenu => 'Додати у вхідні…';

  @override
  String inboxCardOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Вхідні · $count невиконаних',
      many: 'Вхідні · $count невиконаних',
      few: 'Вхідні · $count невиконані',
      one: 'Вхідні · $count невиконане',
    );
    return '$_temp0';
  }

  @override
  String inboxDueCount(int count) {
    return '$count до виконання';
  }

  @override
  String get inboxDismiss => 'Закрити';

  @override
  String get inboxDismissAll => 'Закрити всі';

  @override
  String inboxReminderFor(String title) {
    return 'Нагадування: $title';
  }

  @override
  String inboxRemindersAway(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Поки вас не було: $count нагадування',
      many: 'Поки вас не було: $count нагадувань',
      few: 'Поки вас не було: $count нагадування',
      one: 'Поки вас не було: $count нагадування',
    );
    return '$_temp0';
  }

  @override
  String inboxMoreCount(int count) {
    return 'Ще $count';
  }
}
