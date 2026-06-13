import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import '../appwrite_client.dart';

/// Push Notification Service using Appwrite Messaging / Functions
class PushNotificationService {
  final Functions _functions;

  PushNotificationService(this._functions);

  /// Registers the device FCM token with Appwrite.
  Future<void> registerDeviceToken(String userId, String token) async {
    // Typically this would call an Appwrite Function or write to push_subscriptions table
    try {
      await _functions.createExecution(
        functionId: 'register-device-token',
        body: jsonEncode({
          'userId': userId,
          'token': token,
          'platform': 'android',
        }),
      );
    } catch (e) {
      // Ignore if function not deployed yet
    }
  }

  /// Request permission (would use firebase_messaging or similar in production).
  Future<bool> requestPermission() async {
    // Mocking permission granted
    return true;
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return PushNotificationService(ref.watch(appwriteFunctionsProvider));
});
