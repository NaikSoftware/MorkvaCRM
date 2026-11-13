// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

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
