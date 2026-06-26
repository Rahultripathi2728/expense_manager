import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../appwrite_client.dart';
import 'cache_service.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../app/router/app_router.dart';

/// Push Notification Service using Appwrite Messaging / Push Targets
class PushNotificationService {
  final Account _account;
  final SharedPreferences _prefs;
  final Ref _ref;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  PushNotificationService(this._account, this._prefs, this._ref);

  static const String _fcmProviderId = '6a329e92000244e586c8';
  static const String _pushTargetIdKey = 'push_target_id';
  static const String _pushDeviceTokenKey = 'push_device_token';

  /// Initialize permissions, local channels, and foreground message handlers.
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('Push notifications are skipped on Web.');
      return;
    }
    // 1. Request notification permission
    final notificationSettings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (notificationSettings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted push notification permission');
    } else {
      debugPrint('User declined or has not accepted push notification permission');
      return;
    }

    // 2. Initialize Local Notifications for Foreground display
    const androidInitSettings = AndroidInitializationSettings('launcher_icon');
    const initSettings = InitializationSettings(android: androidInitSettings);
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification clicked in foreground: ${response.payload}');
      },
    );

    // Create android notification channel
    const androidChannel = AndroidNotificationChannel(
      'expense_manager_channel',
      'Expense Manager Notifications',
      description: 'Used for expense and settlement updates.',
      importance: Importance.max,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(androidChannel);
      await androidPlugin.requestNotificationsPermission();
    }

    // 3. Listen to foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message received: ${message.messageId}');
      debugPrint('Payload data: ${message.data}');
      
      String? title = message.notification?.title;
      String? body = message.notification?.body;
      
      // Fallback if the payload has direct keys in message.data
      if (title == null || title.isEmpty) {
        title = message.data['title'] as String?;
      }
      if (body == null || body.isEmpty) {
        body = message.data['body'] as String?;
      }
      
      // Default fallback
      title ??= 'New Notification';

      _localNotifications.show(
        id: message.hashCode,
        title: title,
        body: body ?? '',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            androidChannel.id,
            androidChannel.name,
            channelDescription: androidChannel.description,
            icon: 'launcher_icon',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    });

    // 4. Handle notification clicks (app opened from notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification clicked to open app: ${message.data}');
      _handleNotificationClick(message.data);
    });

    // Also handle if app was terminated and opened by notification
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('App opened from terminated state by notification: ${message.data}');
        _handleNotificationClick(message.data);
      }
    });
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    try {
      _ref.read(routerProvider).go('/notifications');
    } catch (e) {
      debugPrint('Error navigating on notification click: $e');
    }
  }

  /// Registers the device FCM token with Appwrite.
  Future<void> registerDeviceToken(String userId) async {
    if (kIsWeb) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint('Failed to retrieve FCM Device Token');
        return;
      }
      debugPrint('Retrieved FCM Device Token: $token');

      final cachedToken = _prefs.getString(_pushDeviceTokenKey);
      final cachedTargetId = _prefs.getString(_pushTargetIdKey);

      // If already registered with this exact token, skip
      if (cachedToken == token && cachedTargetId != null) {
        debugPrint('Device token already registered with target ID: $cachedTargetId');
        return;
      }

      // If token changed but target exists, clean up the old one first
      if (cachedTargetId != null) {
        await unregisterDeviceToken();
      }

      // Register new target
      final targetId = ID.unique();
      await _account.createPushTarget(
        targetId: targetId,
        providerId: _fcmProviderId,
        identifier: token,
      );

      // Save to cache
      await _prefs.setString(_pushTargetIdKey, targetId);
      await _prefs.setString(_pushDeviceTokenKey, token);
      debugPrint('Successfully registered device token as Appwrite Push Target: $targetId');
    } catch (e) {
      debugPrint('Error registering device token to Appwrite: $e');
    }
  }

  /// Unregisters the device FCM token from Appwrite (on logout).
  Future<void> unregisterDeviceToken() async {
    if (kIsWeb) return;
    try {
      final cachedTargetId = _prefs.getString(_pushTargetIdKey);
      if (cachedTargetId != null) {
        await _account.deletePushTarget(targetId: cachedTargetId);
        await _prefs.remove(_pushTargetIdKey);
        await _prefs.remove(_pushDeviceTokenKey);
        debugPrint('Successfully deleted Appwrite Push Target: $cachedTargetId');
      }
    } catch (e) {
      debugPrint('Error unregistering device token from Appwrite: $e');
    }
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final account = ref.watch(appwriteAccountProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return PushNotificationService(account, prefs, ref);
});

final pushNotificationInitProvider = Provider<void>((ref) {
  final pushService = ref.watch(pushNotificationServiceProvider);

  // Initialize listeners
  pushService.initialize();

  // Check initial state
  final authState = ref.read(authStateProvider);
  authState.whenData((user) {
    if (user != null) {
      pushService.registerDeviceToken(user.id);
    }
  });

  // Listen for changes (login/logout)
  ref.listen(authStateProvider, (previous, next) {
    next.whenData((user) {
      if (user != null) {
        pushService.registerDeviceToken(user.id);
      } else {
        pushService.unregisterDeviceToken();
      }
    });
  });
});
