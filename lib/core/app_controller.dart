import 'package:flutter/material.dart';

/// Global app state for the fitness access app
enum AppState {
  /// App is initializing/loading
  loading,

  /// User is not authenticated
  unauthenticated,

  /// User is authenticated but has no active membership
  noMembership,

  /// User has active membership and can access the gym
  activeMembership,
}

/// App controller that manages global app state and navigation
class AppController {
  AppState _currentState = AppState.loading;

  AppState get currentState => _currentState;

  /// Initialize the app - check authentication and membership status
  Future<void> initialize() async {
    _currentState = AppState.loading;
    notifyListeners();

    try {
      // Check if user is authenticated
      final isAuthenticated = await _checkAuthentication();

      if (!isAuthenticated) {
        _currentState = AppState.unauthenticated;
        notifyListeners();
        return;
      }

      // Check membership status
      final hasMembership = await _checkMembership();

      if (!hasMembership) {
        _currentState = AppState.noMembership;
      } else {
        _currentState = AppState.activeMembership;
      }

      notifyListeners();
    } catch (e) {
      // On error, default to unauthenticated
      _currentState = AppState.unauthenticated;
      notifyListeners();
    }
  }

  /// Handle successful login
  Future<void> onLoginSuccess() async {
    _currentState = AppState.loading;
    notifyListeners();

    // Check membership after login
    final hasMembership = await _checkMembership();

    if (!hasMembership) {
      _currentState = AppState.noMembership;
    } else {
      _currentState = AppState.activeMembership;
    }

    notifyListeners();
  }

  /// Handle successful payment/membership activation
  Future<void> onPaymentSuccess() async {
    _currentState = AppState.activeMembership;
    notifyListeners();
  }

  /// Handle logout
  void logout() {
    _currentState = AppState.unauthenticated;
    notifyListeners();
  }

  /// Check authentication status
  Future<bool> _checkAuthentication() async {
    try {
      // In real app, check for stored JWT token
      // For demo, always return false to show login flow
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check membership status
  Future<bool> _checkMembership() async {
    try {
      // In real app, call GET /me API
      // For demo, always return false to show membership flow
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Listeners for state changes
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
}
