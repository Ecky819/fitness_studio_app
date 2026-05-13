import 'package:flutter/material.dart';
import 'api_service.dart';

enum AppState { loading, unauthenticated, noMembership, activeMembership }

/// Central app state controller.
///
/// Uses [ApiService] for all backend calls and [flutter_secure_storage]
/// (via ApiService) for token persistence across restarts.
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
      final hasToken = await ApiService.isAuthenticated();
      if (!hasToken) {
        _currentState = AppState.unauthenticated;
        _notify();
        return;
      }

      // Token exists — verify it's still valid and check membership.
      final hasMembership = await _fetchMembershipActive();
      _currentState =
          hasMembership ? AppState.activeMembership : AppState.noMembership;
    } on ApiException catch (e) {
      // 401 → token expired and refresh failed → force re-login.
      if (e.isUnauthorized) {
        await ApiService.clearTokens();
        _currentState = AppState.unauthenticated;
      } else {
        // Network error etc. — keep last known state or go unauthenticated.
        _currentState = AppState.unauthenticated;
      }
    } catch (_) {
      _currentState = AppState.unauthenticated;
    } finally {
      _notify();
    }
  }

  Future<void> onLoginSuccess() async {
    _currentState = AppState.loading;
    _notify();

    try {
      final hasMembership = await _fetchMembershipActive();
      _currentState =
          hasMembership ? AppState.activeMembership : AppState.noMembership;
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
