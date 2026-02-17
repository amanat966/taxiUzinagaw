import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_kk.dart';
import 'app_localizations_ru.dart';

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
    Locale('kk'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'Tulpar'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get login;

  /// No description provided for @phone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get phone;

  /// No description provided for @password.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get password;

  /// No description provided for @driver.
  ///
  /// In ru, this message translates to:
  /// **'Водитель'**
  String get driver;

  /// No description provided for @dispatcher.
  ///
  /// In ru, this message translates to:
  /// **'Диспетчер'**
  String get dispatcher;

  /// No description provided for @status.
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get status;

  /// No description provided for @free.
  ///
  /// In ru, this message translates to:
  /// **'Свободен'**
  String get free;

  /// No description provided for @busy.
  ///
  /// In ru, this message translates to:
  /// **'Занят'**
  String get busy;

  /// No description provided for @offline.
  ///
  /// In ru, this message translates to:
  /// **'Не в сети'**
  String get offline;

  /// No description provided for @order.
  ///
  /// In ru, this message translates to:
  /// **'Заказ'**
  String get order;

  /// No description provided for @from.
  ///
  /// In ru, this message translates to:
  /// **'Откуда'**
  String get from;

  /// No description provided for @to.
  ///
  /// In ru, this message translates to:
  /// **'Куда'**
  String get to;

  /// No description provided for @inProgress.
  ///
  /// In ru, this message translates to:
  /// **'В пути'**
  String get inProgress;

  /// No description provided for @createOrder.
  ///
  /// In ru, this message translates to:
  /// **'Создать заказ'**
  String get createOrder;

  /// No description provided for @addDriver.
  ///
  /// In ru, this message translates to:
  /// **'Добавить водителя'**
  String get addDriver;

  /// No description provided for @name.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get name;

  /// No description provided for @drivers.
  ///
  /// In ru, this message translates to:
  /// **'Водители'**
  String get drivers;

  /// No description provided for @activeOrders.
  ///
  /// In ru, this message translates to:
  /// **'Активные заказы'**
  String get activeOrders;

  /// No description provided for @controlPanel.
  ///
  /// In ru, this message translates to:
  /// **'Панель управления'**
  String get controlPanel;

  /// No description provided for @logout.
  ///
  /// In ru, this message translates to:
  /// **'Выход'**
  String get logout;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @comment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий'**
  String get comment;

  /// No description provided for @assignDriver.
  ///
  /// In ru, this message translates to:
  /// **'Назначить водителя (опционально)'**
  String get assignDriver;

  /// No description provided for @none.
  ///
  /// In ru, this message translates to:
  /// **'Не назначен'**
  String get none;

  /// No description provided for @orderCreated.
  ///
  /// In ru, this message translates to:
  /// **'Заказ создан'**
  String get orderCreated;

  /// No description provided for @orderCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Заказ отменён'**
  String get orderCancelled;

  /// No description provided for @currentOrder.
  ///
  /// In ru, this message translates to:
  /// **'Текущий заказ'**
  String get currentOrder;

  /// No description provided for @startTrip.
  ///
  /// In ru, this message translates to:
  /// **'Начать поездку'**
  String get startTrip;

  /// No description provided for @finishTrip.
  ///
  /// In ru, this message translates to:
  /// **'Завершить'**
  String get finishTrip;

  /// No description provided for @accept.
  ///
  /// In ru, this message translates to:
  /// **'Принять'**
  String get accept;

  /// No description provided for @noOrders.
  ///
  /// In ru, this message translates to:
  /// **'Заказов пока нет, отдохните'**
  String get noOrders;

  /// No description provided for @noActiveOrder.
  ///
  /// In ru, this message translates to:
  /// **'Нет активного заказа. Ожидание назначений...'**
  String get noActiveOrder;

  /// No description provided for @newOrders.
  ///
  /// In ru, this message translates to:
  /// **'Новые заказы'**
  String get newOrders;

  /// No description provided for @noNewOrders.
  ///
  /// In ru, this message translates to:
  /// **'Новых заказов нет. Ожидание...'**
  String get noNewOrders;

  /// No description provided for @home.
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get home;

  /// No description provided for @history.
  ///
  /// In ru, this message translates to:
  /// **'История'**
  String get history;

  /// No description provided for @profile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settings;

  /// No description provided for @changePassword.
  ///
  /// In ru, this message translates to:
  /// **'Смена пароля'**
  String get changePassword;

  /// No description provided for @oldPassword.
  ///
  /// In ru, this message translates to:
  /// **'Текущий пароль'**
  String get oldPassword;

  /// No description provided for @newPassword.
  ///
  /// In ru, this message translates to:
  /// **'Новый пароль'**
  String get newPassword;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @passwordChanged.
  ///
  /// In ru, this message translates to:
  /// **'Пароль изменён'**
  String get passwordChanged;

  /// No description provided for @loginFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка входа'**
  String get loginFailed;

  /// No description provided for @addDriverFormTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавить водителя'**
  String get addDriverFormTitle;

  /// No description provided for @driverCreated.
  ///
  /// In ru, this message translates to:
  /// **'Водитель добавлен'**
  String get driverCreated;

  /// No description provided for @requiredField.
  ///
  /// In ru, this message translates to:
  /// **'Обязательное поле'**
  String get requiredField;

  /// No description provided for @minPasswordLength.
  ///
  /// In ru, this message translates to:
  /// **'Минимум 6 символов'**
  String get minPasswordLength;

  /// No description provided for @statusNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый'**
  String get statusNew;

  /// No description provided for @statusAssigned.
  ///
  /// In ru, this message translates to:
  /// **'Назначен'**
  String get statusAssigned;

  /// No description provided for @statusAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Принят'**
  String get statusAccepted;

  /// No description provided for @statusInProgress.
  ///
  /// In ru, this message translates to:
  /// **'В пути'**
  String get statusInProgress;

  /// No description provided for @statusDone.
  ///
  /// In ru, this message translates to:
  /// **'Выполнен'**
  String get statusDone;

  /// No description provided for @statusCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменён'**
  String get statusCancelled;

  /// No description provided for @assignDriverToOrder.
  ///
  /// In ru, this message translates to:
  /// **'Назначить водителя'**
  String get assignDriverToOrder;

  /// No description provided for @driverAssigned.
  ///
  /// In ru, this message translates to:
  /// **'Водитель назначен'**
  String get driverAssigned;

  /// No description provided for @ordersCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Заказов выполнено'**
  String get ordersCompleted;

  /// No description provided for @ordersInProgress.
  ///
  /// In ru, this message translates to:
  /// **'В процессе'**
  String get ordersInProgress;

  /// No description provided for @driverProfile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль водителя'**
  String get driverProfile;

  /// No description provided for @openIn2GIS.
  ///
  /// In ru, this message translates to:
  /// **'Открыть в 2ГИС'**
  String get openIn2GIS;

  /// No description provided for @callClient.
  ///
  /// In ru, this message translates to:
  /// **'Позвонить'**
  String get callClient;

  /// No description provided for @price.
  ///
  /// In ru, this message translates to:
  /// **'Цена'**
  String get price;

  /// No description provided for @currencyKzt.
  ///
  /// In ru, this message translates to:
  /// **'тг'**
  String get currencyKzt;

  /// No description provided for @clientName.
  ///
  /// In ru, this message translates to:
  /// **'Имя клиента'**
  String get clientName;

  /// No description provided for @clientPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон клиента'**
  String get clientPhone;

  /// No description provided for @historyComingSoon.
  ///
  /// In ru, this message translates to:
  /// **'История поездок скоро появится.'**
  String get historyComingSoon;

  /// No description provided for @earnings.
  ///
  /// In ru, this message translates to:
  /// **'Заработок'**
  String get earnings;

  /// No description provided for @last7Days.
  ///
  /// In ru, this message translates to:
  /// **'7 дней'**
  String get last7Days;

  /// No description provided for @last30Days.
  ///
  /// In ru, this message translates to:
  /// **'30 дней'**
  String get last30Days;

  /// No description provided for @completedTrips.
  ///
  /// In ru, this message translates to:
  /// **'Завершённые поездки'**
  String get completedTrips;

  /// No description provided for @editProfile.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать профиль'**
  String get editProfile;

  /// No description provided for @changePhoto.
  ///
  /// In ru, this message translates to:
  /// **'Сменить фото'**
  String get changePhoto;

  /// No description provided for @noCompletedTrips.
  ///
  /// In ru, this message translates to:
  /// **'У вас пока нет завершенных поездок'**
  String get noCompletedTrips;

  /// No description provided for @arrived.
  ///
  /// In ru, this message translates to:
  /// **'На месте'**
  String get arrived;

  /// No description provided for @assignedOrder.
  ///
  /// In ru, this message translates to:
  /// **'Вам назначен заказ'**
  String get assignedOrder;
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
      <String>['en', 'kk', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'kk':
      return AppLocalizationsKk();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
