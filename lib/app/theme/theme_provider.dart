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

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      setTheme(ThemeMode.light);
    } else {
      setTheme(ThemeMode.dark);
    }
  }

  void _updateAppColors(ThemeMode mode) {
    if (mode == ThemeMode.dark) {
      AppColors.isDark = true;
    } else if (mode == ThemeMode.light) {
      AppColors.isDark = false;
    } else {
      AppColors.isDark = false;
    }
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});
