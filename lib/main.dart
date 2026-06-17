import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_provider.dart';
import 'app/router/app_router.dart';
import 'core/services/cache_service.dart';
import 'core/services/realtime_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
                    if (isOffline)
                      Positioned.fill(
                        child: Material(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 64),
                                SizedBox(height: 16),
                                Text(
                                  'You are offline',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Please connect to the internet to use Expense Manager.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
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
