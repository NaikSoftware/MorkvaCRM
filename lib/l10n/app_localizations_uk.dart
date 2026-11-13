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
  String get shellSyncSynced => 'Синхронізовано';

  @override
  String get shellSyncSyncing => 'Синхронізація…';

  @override
  String get shellSyncOffline => 'Офлайн';

  @override
  String get shellSyncConflict => 'Конфлікт';

  @override
  String get shellSyncError => 'Збій синхронізації';

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
    return 'Я можу читати вашу колекцію «$name», рахувати показники та вносити зміни — ви підтверджуєте кожну зміну, перш ніж вона станеться.';
  }

  @override
  String assistantIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Я можу читати всі $count ваших колекцій, рахувати показники та вносити зміни — ви підтверджуєте кожну зміну, перш ніж вона станеться.',
      many:
          'Я можу читати всі $count ваших колекцій, рахувати показники та вносити зміни — ви підтверджуєте кожну зміну, перш ніж вона станеться.',
      few:
          'Я можу читати всі $count ваші колекції, рахувати показники та вносити зміни — ви підтверджуєте кожну зміну, перш ніж вона станеться.',
      one:
          'Я можу читати всі ваші колекції ($count), рахувати показники та вносити зміни — ви підтверджуєте кожну зміну, перш ніж вона станеться.',
      zero:
          'Я допоможу створити колекції, порахувати показники та внести зміни — ви підтверджуєте кожну зміну, перш ніж вона станеться.',
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
      'Створи колекцію «Клієнти» з полями ім’я, телефон і місто';

  @override
  String get assistantSuggestSetUpOrders =>
      'Налаштуй колекцію «Замовлення», пов’язану з «Клієнти»';

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
  String get assistantJumpToLatest => 'До останніх';

  @override
  String get assistantThinking => 'Думаю…';

  @override
  String assistantWaitLarge(int seconds) {
    return 'Розмова велика; чекаємо $seconds с.';
  }

  @override
  String get assistantBusyRetryingNow => 'Gemini перевантажений. Повторюємо…';

  @override
  String assistantBusyRetryingIn(int seconds) {
    return 'Gemini перевантажений. Повтор через $seconds с.';
  }

  @override
  String get assistantWaitLargeSpoken =>
      'Розмова велика; чекаємо, перш ніж продовжити.';

  @override
  String get assistantBusyRetryingShortly =>
      'Gemini перевантажений. Незабаром повторимо.';

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
    return 'Розмову «$title» і її повідомлення буде видалено. Зміни, які вона внесла у ваші дані, залишаться.';
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
  String get assistantUndoNone => 'Це незворотно.';

  @override
  String assistantUndoPartialFor(int minutes) {
    return 'Частину змін можна буде повернути протягом $minutes хв.';
  }

  @override
  String get assistantUndoPartialLater => 'Частину змін можна буде повернути.';

  @override
  String assistantUndoFor(int minutes) {
    return 'Повернути все можна протягом $minutes хв.';
  }

  @override
  String get assistantUndoLater => 'Потім зміни можна буде повернути.';

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
  String get assistantInstallModule => 'Установити модуль';

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
  String get assistantRebuild => 'Оновити перегляд';

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
  String get assistantErrorBusy => 'Gemini зараз перевантажений.';

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
    return 'за запитом $query';
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
      'Один охайний дім для ваших колекцій і карток — надійно синхронізований на всіх пристроях, де ви входите.';

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
    return 'Поле «$name» не можна використати у формулі — щоб підсумувати пов’язані картки, виберіть агрегацію';
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
  String get templatesAdd => 'Додати в робочий простір';

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
  String get settingsWorkspaceSection => 'Робочий простір';

  @override
  String get settingsAutomationsSubtitle => 'Модулі, кнопки й запуски';

  @override
  String get settingsImportSection => 'Імпорт з інших застосунків';

  @override
  String get settingsTrelloSubtitle =>
      'Дошки стають колекціями — списки, картки, мітки, чеклісти й коментарі';

  @override
  String get settingsSignOut => 'Вийти';
}
