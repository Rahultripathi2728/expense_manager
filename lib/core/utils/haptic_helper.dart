import 'package:flutter/services.dart';

/// Centralized haptic feedback helper.
/// Provides subtle tactile cues for key user actions.
class HapticHelper {
  HapticHelper._();

  /// Light tap — for minor selections (calendar date, category pick, tab switch).
  static void lightTap() => HapticFeedback.lightImpact();

  /// Medium tap — for confirmations (add expense, settle, save profile).
  static void mediumTap() => HapticFeedback.mediumImpact();

  /// Heavy tap — for destructive or critical actions (delete expense, sign out).
  static void heavyTap() => HapticFeedback.heavyImpact();

  /// Selection click — for toggles and option selections.
  static void selectionClick() => HapticFeedback.selectionClick();
}
