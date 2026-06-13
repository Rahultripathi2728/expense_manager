import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/cache_service.dart';
import 'app_colors.dart';

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _themeKey = 'app_theme_mode';

  @override
  ThemeMode build() {
    _updateAppColors(ThemeMode.light);
    return ThemeMode.light;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_themeKey, mode.name);
    _updateAppColors(mode);
  }

  void _updateAppColors(ThemeMode mode) {
    if (mode == ThemeMode.dark) {
      AppColors.isDark = true;
    } else if (mode == ThemeMode.light) {
      AppColors.isDark = false;
    } else {
      // For system, we ideally need to check the system brightness.
      // But for static colors, we will rely on a basic check or just set it based on current binding if available.
      // A better way is updating it in the root widget with MediaQuery, but for now we set it to false and let the root widget override if needed.
      AppColors.isDark = false;
    }
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});
