import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_providers.dart';
import 'core/app_controller.dart';
import 'features/admin/admin_shell.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/billing/membership_screen.dart';
import 'features/access/access_screen.dart';
import 'design_system/design_system.dart';

void main() {
  runApp(const ProviderScope(child: FitnessStudioApp()));
}

class FitnessStudioApp extends ConsumerWidget {
  const FitnessStudioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: kIsWeb ? 'Admin Dashboard' : 'Fitness Studio Access',
      theme: AppTheme.dark,
      home: kIsWeb ? const AdminShell() : const AppRoot(),
      debugShowCheckedModeBanner: false,
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
