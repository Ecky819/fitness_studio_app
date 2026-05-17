// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Fitness Studio';

  @override
  String get adminTitle => 'Admin-Dashboard';

  @override
  String get memberPortal => 'Mitgliederportal';

  @override
  String get signOut => 'Abmelden';

  @override
  String get signOutConfirmTitle => 'Abmelden?';

  @override
  String get signOutConfirmBody =>
      'Du wirst zum Anmeldebildschirm zurückgeleitet.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get loading => 'Lädt…';

  @override
  String get membership => 'Mitgliedschaft';

  @override
  String get membershipActive => 'Aktiv';

  @override
  String get membershipCanceled => 'Gekündigt';

  @override
  String get membershipPastDue => 'Überfällig';

  @override
  String get membershipExpired => 'Abgelaufen';

  @override
  String get membershipPlan => 'Tarif';

  @override
  String get membershipValidUntil => 'Gültig bis';

  @override
  String get renewMembership => 'Mitgliedschaft verlängern';

  @override
  String get invoices => 'Rechnungen';

  @override
  String get noInvoices => 'Noch keine Rechnungen vorhanden.';

  @override
  String get downloadPdf => 'PDF herunterladen';

  @override
  String get errorGeneric =>
      'Ein Fehler ist aufgetreten. Bitte versuche es erneut.';

  @override
  String get errorUnauthorized =>
      'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.';

  @override
  String get errorPaymentFailed =>
      'Zahlung fehlgeschlagen. Bitte aktualisiere deine Zahlungsmethode.';

  @override
  String get errorAccessDenied =>
      'Zugriff verweigert. Bitte überprüfe deinen Mitgliedschaftsstatus.';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navAnalytics => 'Analysen';

  @override
  String get navInsights => 'KI-Einblicke';

  @override
  String get navUsers => 'Benutzer';

  @override
  String get navDevices => 'Geräte';

  @override
  String get navLogs => 'Protokolle';

  @override
  String get navPricing => 'Preise';
}
