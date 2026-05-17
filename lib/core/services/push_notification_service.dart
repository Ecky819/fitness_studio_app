import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../api_service.dart';

// Top-level handler required by FCM for background/terminated messages.
// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // FCM displays the notification automatically when the app is in background
  // or terminated — no manual action needed here.
}

class PushNotificationService {
  PushNotificationService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  // Android channel — must match the channelId sent by the backend.
  static const _androidChannel = AndroidNotificationChannel(
    'gym_alerts',
    'Gym Alerts',
    description: 'Wichtige Benachrichtigungen von deinem Fitnessstudio',
    importance: Importance.high,
  );

  // ── Initialization (call once in main()) ──────────────────────────────────

  static Future<void> initialize() async {
    // Web / desktop: skip — FCM push is mobile-only
    if (kIsWeb) return;

    await _requestPermission();
    await _setupLocalNotifications();
    await _createAndroidChannel();

    // Register the top-level background handler
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // Show a local notification when the app is in the foreground
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  // ── Token registration (call after every successful login) ────────────────

  static Future<void> registerToken() async {
    if (kIsWeb) return;
    try {
      final token = await _messaging.getToken();
      if (token != null) await ApiService.registerFcmToken(token);

      // Keep the backend in sync when the FCM token is rotated
      _messaging.onTokenRefresh.listen(ApiService.registerFcmToken);
    } catch (e) {
      // Best-effort: push token failure must not block login
      debugPrint('[Push] Token registration failed: $e');
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[Push] Permission: ${settings.authorizationStatus}');
  }

  static Future<void> _setupLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false, // already requested via FCM
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  static Future<void> _createAndroidChannel() async {
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(sound: 'default'),
      ),
    );
  }
}
