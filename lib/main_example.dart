// Example usage of the AccessScreen
// This would typically be in your main.dart or navigation setup

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/access/access_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Fitness Studio App',
        theme: ThemeData.dark(), // Dark theme for low-light environments
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fitness Studio')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Navigate to access screen - BLE scan starts automatically
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AccessScreen(doorId: 'main_door'),
              ),
            );
          },
          child: const Text('Enter Studio'),
        ),
      ),
    );
  }
}

/*
Required dependencies in pubspec.yaml:

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.0
  qr_flutter: ^4.1.0
  http: ^1.2.0

For production BLE support, also add:
  flutter_blue_plus: ^1.32.0

Permissions in AndroidManifest.xml:
  <uses-permission android:name="android.permission.BLUETOOTH" />
  <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

Permissions in Info.plist (iOS):
  <key>NSBluetoothAlwaysUsageDescription</key>
  <string>This app needs Bluetooth access for door access</string>
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>This app needs location access for Bluetooth scanning</string>
*/
