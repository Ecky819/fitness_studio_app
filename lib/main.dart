import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_providers.dart';
import 'core/app_controller.dart';
import 'features/admin/admin_shell.dart';
import 'features/auth/login_screen.dart';
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

/// Root widget that switches screens based on app state
class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);

    // Show loading screen during initialization
    if (appState == AppState.loading) {
      return const LoadingScreen();
    }

    // Switch screens based on app state
    switch (appState) {
      case AppState.unauthenticated:
        return const LoginScreen();
      case AppState.noMembership:
        return const MembershipScreen();
      case AppState.activeMembership:
        return const AccessScreen(doorId: 'main_door');
      default:
        return const LoginScreen();
    }
  }
}

/// Loading screen shown during app initialization
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _spinAnimation = Tween<double>(begin: 0, end: 1).animate(_spinController);
  }

  @override
  void dispose() {
    _spinController.dispose();
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
            AnimatedBuilder(
              animation: _spinAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _spinAnimation.value * 2 * 3.14159,
                  child: const Icon(
                    Icons.fitness_center,
                    size: 80,
                    color: AppColors.primary,
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Loading...',
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}
