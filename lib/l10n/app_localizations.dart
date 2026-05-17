import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('de'),
    Locale('en')
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Fitness Studio'**
  String get appTitle;

  /// Web admin dashboard title
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminTitle;

  /// Member web portal title
  ///
  /// In en, this message translates to:
  /// **'Member Portal'**
  String get memberPortal;

  /// Sign out button label
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// Sign out confirm dialog title
  ///
  /// In en, this message translates to:
  /// **'Sign Out?'**
  String get signOutConfirmTitle;

  /// Sign out confirm dialog body
  ///
  /// In en, this message translates to:
  /// **'You will be returned to the login screen.'**
  String get signOutConfirmBody;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Generic loading text
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// Membership section title
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get membership;

  /// Active membership status
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get membershipActive;

  /// Canceled membership status
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get membershipCanceled;

  /// Past due membership status
  ///
  /// In en, this message translates to:
  /// **'Past Due'**
  String get membershipPastDue;

  /// Expired membership status
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get membershipExpired;

  /// Plan label
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get membershipPlan;

  /// Valid until label
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get membershipValidUntil;

  /// Renew membership button
  ///
  /// In en, this message translates to:
  /// **'Renew Membership'**
  String get renewMembership;

  /// Invoices section title
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoices;

  /// Empty invoice list message
  ///
  /// In en, this message translates to:
  /// **'No invoices yet.'**
  String get noInvoices;

  /// Download PDF tooltip
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get downloadPdf;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// Session expired error
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please log in again.'**
  String get errorUnauthorized;

  /// Payment failed notification
  ///
  /// In en, this message translates to:
  /// **'Payment failed. Please update your payment method.'**
  String get errorPaymentFailed;

  /// Access denied error
  ///
  /// In en, this message translates to:
  /// **'Access denied. Please check your membership status.'**
  String get errorAccessDenied;

  /// Navigation item: Dashboard
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// Navigation item: Analytics
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get navAnalytics;

  /// Navigation item: AI Insights
  ///
  /// In en, this message translates to:
  /// **'AI Insights'**
  String get navInsights;

  /// Navigation item: Users
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get navUsers;

  /// Navigation item: Devices
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get navDevices;

  /// Navigation item: Logs
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get navLogs;

  /// Navigation item: Pricing
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get navPricing;
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
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
