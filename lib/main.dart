import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_provider.dart';
import 'app/router/app_router.dart';
import 'core/services/cache_service.dart';
import 'core/services/realtime_service.dart';
import 'core/services/push_notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint('Background message handled: ${message.messageId}');
  } catch (e) {
    debugPrint('Background message initialization failed: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
    }
  }

  // Catch Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: \${details.exception}');
  };

  // Catch asynchronous errors
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Async Error: \$error\\n\$stack');
    return true;
  };

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const ExpenseManagerApp(),
    ),
  );
}

class ExpenseManagerApp extends ConsumerWidget {
  const ExpenseManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);
    ref.watch(realtimeInitProvider); // Keep realtime connection alive
    ref.watch(pushNotificationInitProvider); // Keep push notifications alive

    return MaterialApp.router(
      title: 'Expense Manager',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.theme,
      darkTheme: AppTheme.theme, // AppTheme returns dynamic colors based on isDark
      routerConfig: router,
      builder: (context, child) {
        return StreamBuilder<List<ConnectivityResult>>(
          stream: Connectivity().onConnectivityChanged,
          builder: (context, snapshot) {
            final isOffline = snapshot.data != null && snapshot.data!.contains(ConnectivityResult.none);
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                children: [
                  if (child != null) child,
                  // Non-blocking animated offline banner
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOutCubic,
                    top: isOffline ? MediaQuery.of(context).padding.top : -(MediaQuery.of(context).padding.top + 36),
                    left: 0,
                    right: 0,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 4,
                          bottom: 6,
                          left: 16,
                          right: 16,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF2D2D2D), Color(0xFF1A1A1A)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off_rounded, color: Color(0xFFEF4444), size: 16),
                            SizedBox(width: 8),
                            Text(
                              'You are offline — showing cached data',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
