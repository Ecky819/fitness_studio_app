// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fitness Studio';

  @override
  String get adminTitle => 'Admin Dashboard';

  @override
  String get memberPortal => 'Member Portal';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signOutConfirmTitle => 'Sign Out?';

  @override
  String get signOutConfirmBody => 'You will be returned to the login screen.';

  @override
  String get cancel => 'Cancel';

  @override
  String get loading => 'Loading…';

  @override
  String get membership => 'Membership';

  @override
  String get membershipActive => 'Active';

  @override
  String get membershipCanceled => 'Canceled';

  @override
  String get membershipPastDue => 'Past Due';

  @override
  String get membershipExpired => 'Expired';

  @override
  String get membershipPlan => 'Plan';

  @override
  String get membershipValidUntil => 'Valid until';

  @override
  String get renewMembership => 'Renew Membership';

  @override
  String get invoices => 'Invoices';

  @override
  String get noInvoices => 'No invoices yet.';

  @override
  String get downloadPdf => 'Download PDF';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorUnauthorized => 'Your session expired. Please log in again.';

  @override
  String get errorPaymentFailed =>
      'Payment failed. Please update your payment method.';

  @override
  String get errorAccessDenied =>
      'Access denied. Please check your membership status.';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navAnalytics => 'Analytics';

  @override
  String get navInsights => 'AI Insights';

  @override
  String get navUsers => 'Users';

  @override
  String get navDevices => 'Devices';

  @override
  String get navLogs => 'Logs';

  @override
  String get navPricing => 'Pricing';
}
