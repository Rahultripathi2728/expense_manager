import 'package:flutter/material.dart';

/// Centralized color tokens for the Expense Manager app.
/// Dark-first grayscale palette with solid black primary actions.
/// NEVER use hardcoded colors in widgets — always reference AppColors.
class AppColors {
  AppColors._();

  static bool isDark = false;

  // ── Primary Palette (Light-first, grayscale) ──
  static Color get background =>
      isDark ? const Color(0xFF111111) : const Color(0xFFF9F9F9);
  static Color get surface =>
      isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
  static Color get surfaceVariant =>
      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F3F3);
  static Color get surfaceElevated =>
      isDark ? const Color(0xFF242424) : const Color(0xFFFFFFFF);
  static Color get surfaceHover =>
      isDark ? const Color(0xFF2E2E2E) : const Color(0xFFEDEDED);

  // ── Text ──
  static Color get textPrimary =>
      isDark ? const Color(0xFFEEEEEE) : const Color(0xFF111111);
  static Color get textSecondary =>
      isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666);
  static Color get textTertiary =>
      isDark ? const Color(0xFF777777) : const Color(0xFF999999);
  static Color get textDisabled =>
      isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC);

  // ── Borders & Dividers ──
  static Color get border =>
      isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0);
  static Color get borderLight =>
      isDark ? const Color(0xFF222222) : const Color(0xFFEEEEEE);
  static Color get divider =>
      isDark ? const Color(0xFF222222) : const Color(0xFFEEEEEE);

  // ── Primary Actions (solid black/white) ──
  static Color get primary =>
      isDark ? const Color(0xFFEEEEEE) : const Color(0xFF111111);
  static Color get onPrimary =>
      isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF);
  static Color get primaryMuted =>
      isDark ? const Color(0xFF888888) : const Color(0xFF777777);

  // ── Semantic Colors ──
  static Color get success => const Color(0xFF22C55E);
  static Color get successMuted =>
      isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);
  static Color get warning => const Color(0xFFF59E0B);
  static Color get warningMuted =>
      isDark ? const Color(0xFF78350F) : const Color(0xFFFEF9C3);
  static Color get error => const Color(0xFFEF4444);
  static Color get errorMuted =>
      isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
  static Color get info => const Color(0xFF3B82F6);
  static Color get infoMuted =>
      isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);

  // ── Budget Progress Zones ──
  static Color get budgetSafe => const Color(0xFF22C55E);
  static Color get budgetWarning => const Color(0xFFF59E0B);
  static Color get budgetDanger => const Color(0xFFEF4444);

  // ── Category Colors ──
  static Color get categoryFood => const Color(0xFFEF4444);
  static Color get categoryTransport => const Color(0xFF3B82F6);
  static Color get categoryBills => const Color(0xFFF59E0B);
  static Color get categoryShopping => const Color(0xFF8B5CF6);
  static Color get categoryEntertainment => const Color(0xFFEC4899);
  static Color get categoryHealth => const Color(0xFF10B981);
  static Color get categoryEducation => const Color(0xFF06B6D4);
  static Color get categoryTravel => const Color(0xFFF97316);
  static Color get categoryOther => const Color(0xFF6B7280);

  // ── Overlay ──
  static Color get scrim => const Color(0x33000000);
  static Color get shimmerBase =>
      isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0);
  static Color get shimmerHighlight =>
      isDark ? const Color(0xFF444444) : const Color(0xFFF3F3F3);

  /// Returns the budget zone color for a given percentage.
  static Color budgetColor(double percentage) {
    if (percentage >= 90) return budgetDanger;
    if (percentage >= 60) return budgetWarning;
    return budgetSafe;
  }

  /// Returns color for a given expense category.
  static Color categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return categoryFood;
      case 'transport':
        return categoryTransport;
      case 'bills':
        return categoryBills;
      case 'shopping':
        return categoryShopping;
      case 'entertainment':
        return categoryEntertainment;
      case 'health':
        return categoryHealth;
      case 'education':
        return categoryEducation;
      case 'travel':
        return categoryTravel;
      default:
        return categoryOther;
    }
  }
}
