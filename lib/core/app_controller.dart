import 'package:flutter/material.dart';
import 'api_service.dart';

enum AppState {
  loading,
  onboarding,
  unauthenticated,
  noMembership,
  activeMembership,
  adminAccess,
}

class AppController {
  AppState _currentState = AppState.loading;
  AppState get currentState => _currentState;

  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
  void _notify() {
    for (final l in _listeners) {
      l();
    }
  }

  Future<void> initialize() async {
    _currentState = AppState.loading;
    _notify();

    try {
      // Restore tenant slug from storage so requests work after a restart.
      await ApiService.restoreTenantSlug();

      // First-time users see onboarding before anything else.
      final onboarded = await ApiService.hasCompletedOnboarding();
      if (!onboarded) {
        _currentState = AppState.onboarding;
        _notify();
        return;
      }

      // Without a gym code the backend cannot resolve the tenant — send the
      // user back to login so they can enter it (login form now has the field).
      if (!ApiService.hasTenantSlug) {
        _currentState = AppState.unauthenticated;
        _notify();
        return;
      }

      final hasToken = await ApiService.isAuthenticated();
      if (!hasToken) {
        _currentState = AppState.unauthenticated;
        _notify();
        return;
      }

      _currentState = await _resolveAuthenticatedState();
    } on ApiException catch (e) {
      if (e.isUnauthorized) await ApiService.clearTokens();
      _currentState = AppState.unauthenticated;
    } catch (_) {
      _currentState = AppState.unauthenticated;
    } finally {
      _notify();
    }
  }

  Future<void> completeOnboarding() async {
    await ApiService.markOnboardingComplete();
    _currentState = AppState.unauthenticated;
    _notify();
  }

  Future<void> onLoginSuccess() async {
    _currentState = AppState.loading;
    _notify();

    try {
      _currentState = await _resolveAuthenticatedState();
    } catch (_) {
      _currentState = AppState.noMembership;
    } finally {
      _notify();
    }
  }

  Future<void> onPaymentSuccess() async {
    _currentState = AppState.activeMembership;
    _notify();
  }

  Future<void> logout() async {
    await ApiService.logout();
    _currentState = AppState.unauthenticated;
    _notify();
  }

  // ── Private ──────────────────────────────────────────────────────────────

  Future<AppState> _resolveAuthenticatedState() async {
    try {
      final profile = await ApiService.getProfile();
      final role = profile['role'] as String? ?? 'USER';

      if (role == 'ADMIN' || role == 'TRAINER' || role == 'SUPER_ADMIN') {
        return AppState.adminAccess;
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) rethrow;
      // Role check failed (network) — fall through to membership check.
    }

    final hasMembership = await _fetchMembershipActive();
    return hasMembership ? AppState.activeMembership : AppState.noMembership;
  }

  Future<bool> _fetchMembershipActive() async {
    try {
      final status = await ApiService.getMembershipStatus();
      return status['status'] == 'active';
    } on ApiException catch (e) {
      if (e.isUnauthorized) rethrow;
      return false;
    }
  }
}
