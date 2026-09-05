import 'package:flutter/material.dart';

/// Centralized color tokens for the Split Pro app.
/// Modern Fintech UI/UX palette with Primary Blue, Accent Gold, and Dark Navy.
class AppColors {
  AppColors._();

  static bool isDark = false;

  // ── Core Brand Colors ──
  static const Color primaryBlue = Color(0xFF2481E9);
  static const Color accentGold = Color(0xFFF6C336);
  static const Color darkNavy = Color(0xFF07152E);
  static const Color pureWhite = Color(0xFFFFFFFF);
  
  // Gradients
  static const Color gradientStart = Color(0xFF3095F0);
  static const Color gradientEnd = Color(0xFF41A5FF);

  static const Color mutedRed = Color(0xFFE11D48);
  static const Color mutedGreen = Color(0xFF10B981);

  // ── Backgrounds & Surfaces ──
  static Color get background =>
      isDark ? darkNavy : const Color(0xFFF8FAFC); // Very light slate for light mode
  static Color get surface =>
      isDark ? const Color(0xFF0F2040) : pureWhite;
  static Color get surfaceVariant =>
      isDark ? const Color(0xFF152A50) : const Color(0xFFF1F5F9);
  static Color get surfaceElevated =>
      isDark ? const Color(0xFF1A3560) : pureWhite;
  static Color get surfaceHover =>
      isDark ? const Color(0xFF1E3A6A) : const Color(0xFFE2E8F0);

  // ── Text ──
  static Color get textPrimary =>
      isDark ? pureWhite : darkNavy;
  static Color get textSecondary =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color get textTertiary =>
      isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  static Color get textDisabled =>
      isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

  // ── Borders & Dividers ──
  static Color get border =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  static Color get borderLight =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
  static Color get divider =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

  // ── Primary Actions ──
  static Color get primary => primaryBlue;
  static Color get onPrimary => pureWhite;
  static Color get primaryMuted =>
      isDark ? const Color(0xFF1D4ED8) : const Color(0xFF60A5FA);

  // ── Semantic Colors ──
  static Color get success => mutedGreen;
  static Color get successMuted =>
      isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
  static Color get warning => accentGold;
  static Color get warningMuted =>
      isDark ? const Color(0xFF78350F) : const Color(0xFFFEF08A);
  static Color get error => mutedRed;
  static Color get errorMuted =>
      isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFFE4E6);
  static Color get info => primaryBlue;
  static Color get infoMuted =>
      isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);

  // ── Budget Progress Zones ──
  static Color get budgetSafe => mutedGreen;
  static Color get budgetWarning => accentGold;
  static Color get budgetDanger => mutedRed;

  // ── Category Colors (Vibrant & Modern Fintech) ──
  static const Color categoryFood = Color(0xFFFF5722); // Vibrant Coral Orange
  static const Color categoryGroceries = Color(0xFFF59E0B); // Amber
  static const Color categoryTransport = Color(0xFF2481E9); // Vivid Blue
  static const Color categoryStays = Color(0xFF6366F1); // Indigo
  static const Color categoryBills = Color(0xFFEAB308); // Gold
  static const Color categorySubscription = Color(0xFF8B5CF6); // Purple
  static const Color categoryShopping = Color(0xFFEC4899); // Pink
  static const Color categoryGifts = Color(0xFFD946EF); // Fuchsia
  static const Color categoryDrinks = Color(0xFFEF4444); // Crimson
  static const Color categoryFuel = Color(0xFFF97316); // Bright Orange
  static const Color categoryUdhaar = Color(0xFF10B981); // Emerald
  static const Color categoryHealth = Color(0xFF14B8A6); // Mint Teal
  static const Color categoryEntertainment = Color(0xFF06B6D4); // Cyan
  static const Color categoryEducation = Color(0xFF3B82F6); // Royal Blue
  static const Color categoryOther = Color(0xFF64748B); // Slate Blue

  // ── Overlay ──
  static Color get scrim => const Color(0x66000000);
  static Color get shimmerBase =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  static Color get shimmerHighlight =>
      isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC);

  /// Returns the budget zone color for a given percentage.
  static Color budgetColor(double percentage) {
    if (percentage >= 90) return budgetDanger;
    if (percentage >= 60) return budgetWarning;
    return budgetSafe;
  }

  /// Returns vibrant color for a given expense category.
  static Color categoryColor(String category) {
    switch (category.toLowerCase().trim()) {
      case 'food':
        return categoryFood;
      case 'groceries':
        return categoryGroceries;
      case 'transport':
      case 'cab':
      case 'taxi':
        return categoryTransport;
      case 'stays':
      case 'rent':
      case 'hotel':
        return categoryStays;
      case 'bills':
      case 'utilities':
      case 'electricity':
      case 'wifi':
        return categoryBills;
      case 'subscription':
      case 'ott':
        return categorySubscription;
      case 'shopping':
      case 'clothes':
        return categoryShopping;
      case 'gifts':
        return categoryGifts;
      case 'drinks':
      case 'party':
        return categoryDrinks;
      case 'fuel':
      case 'petrol':
      case 'diesel':
        return categoryFuel;
      case 'udhaar':
      case 'loan':
      case 'transfer':
        return categoryUdhaar;
      case 'health':
      case 'medical':
      case 'doctor':
      case 'medicine':
        return categoryHealth;
      case 'entertainment':
      case 'movies':
      case 'games':
        return categoryEntertainment;
      case 'education':
      case 'books':
      case 'course':
        return categoryEducation;
      default:
        return categoryOther;
    }
  }
}
