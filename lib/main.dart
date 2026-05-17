import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/app_providers.dart';
import 'core/app_controller.dart';
import 'core/services/push_notification_service.dart';
import 'features/admin/admin_shell.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/billing/membership_screen.dart';
import 'features/access/access_screen.dart';
import 'features/member/member_web_view.dart';
import 'design_system/design_system.dart';
import 'l10n/app_localizations.dart';

// Sentry DSN is injected at build time: --dart-define=SENTRY_DSN=https://...
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is only available on mobile — web dashboard skips push setup.
  if (!kIsWeb) {
    await Firebase.initializeApp();
    await PushNotificationService.initialize();
  }

  if (_sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.tracesSampleRate = 0.2;
        options.environment =
            const String.fromEnvironment('APP_ENV', defaultValue: 'production');
      },
      appRunner: () => runApp(const ProviderScope(child: FitnessStudioApp())),
    );
  } else {
    runApp(const ProviderScope(child: FitnessStudioApp()));
  }
}

class FitnessStudioApp extends ConsumerWidget {
  const FitnessStudioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: kIsWeb ? 'Fitness Studio' : 'Fitness Studio Access',
      theme: AppTheme.dark,
      home: kIsWeb ? const WebRoot() : const AppRoot(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

// ── Web root — routes admin vs. member on the web platform ───────────────────

class WebRoot extends ConsumerWidget {
  const WebRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (appState) {
        AppState.loading => const LoadingScreen(),
        AppState.onboarding || AppState.unauthenticated => const LoginScreen(),
        AppState.adminAccess => const AdminShell(),
        // Members get the web portal (membership status + invoices).
        AppState.activeMembership ||
        AppState.noMembership =>
          const MemberWebView(),
      },
    );
  }
}

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (appState) {
        AppState.loading => const LoadingScreen(),
        AppState.onboarding => const OnboardingScreen(),
        AppState.unauthenticated => const LoginScreen(),
        AppState.noMembership => const MembershipScreen(),
        AppState.activeMembership =>
          const AccessScreen(doorId: 'main_door'),
        // Admins/trainers on mobile get the full dashboard.
        AppState.adminAccess => const AdminShell(),
      },
    );
  }
}

// ── Loading screen ────────────────────────────────────────────────────────────

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RotationTransition(
              turns: _spin,
              child: const Icon(
                Icons.fitness_center,
                size: 80,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Loading…', style: AppTextStyles.body),
          ],
        ),
      ),
    );
  }
}
