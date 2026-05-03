import 'dart:convert';
import 'package:http/http.dart' as http;

/// Mock API service for the fitness studio app
class ApiService {
  static const String baseUrl = 'https://api.fitness-studio.mock';

  /// Mock login endpoint
  static Future<Map<String, dynamic>> login(String email) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock successful response
    return {
      'success': true,
      'token': 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}',
      'user': {
        'id': 'user_123',
        'email': email,
        'name': 'Fitness User',
      },
    };
  }

  /// Mock get current user endpoint
  static Future<Map<String, dynamic>> getCurrentUser() async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock user data
    return {
      'id': 'user_123',
      'email': 'user@fitness.com',
      'name': 'Fitness User',
      'subscription': {
        'status': 'active', // 'active', 'canceled', 'past_due', 'expired'
        'current_period_end':
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'plan': {
          'name': 'Premium Membership',
          'price': 29.99,
        },
      },
    };
  }

  /// Mock create checkout session endpoint
  static Future<Map<String, dynamic>> createCheckoutSession() async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Mock Stripe checkout session
    return {
      'id': 'cs_mock_${DateTime.now().millisecondsSinceEpoch}',
      'url': 'https://checkout.stripe.com/pay/cs_mock_session_123',
      'success_url': 'fitnessstudio://success',
      'cancel_url': 'fitnessstudio://cancel',
    };
  }

  /// Mock verify payment endpoint (called after Stripe redirect)
  static Future<Map<String, dynamic>> verifyPayment(String sessionId) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock successful payment verification
    return {
      'success': true,
      'subscription': {
        'status': 'active',
        'current_period_end':
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      },
    };
  }

  /// Generic HTTP GET request (for future real API integration)
  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer mock_token', // In real app, get from secure storage
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      // For demo purposes, return mock data on network errors
      return await _getMockData(endpoint);
    }
  }

  /// Generic HTTP POST request (for future real API integration)
  static Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer mock_token', // In real app, get from secure storage
        },
        body: json.encode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      // For demo purposes, return mock data on network errors
      return await _postMockData(endpoint, data);
    }
  }

  /// Mock data fallback for GET requests
  static Future<Map<String, dynamic>> _getMockData(String endpoint) async {
    await Future.delayed(const Duration(milliseconds: 300));

    switch (endpoint) {
      case '/me':
        return await getCurrentUser();
      default:
        throw Exception('Unknown endpoint: $endpoint');
    }
  }

  /// Mock data fallback for POST requests
  static Future<Map<String, dynamic>> _postMockData(
      String endpoint, Map<String, dynamic> data) async {
    await Future.delayed(const Duration(milliseconds: 300));

    switch (endpoint) {
      case '/login':
        return await login(data['email']);
      case '/checkout':
        return await createCheckoutSession();
      default:
        throw Exception('Unknown endpoint: $endpoint');
    }
  }
}
