import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DraftService {
  static const _draftKeyPrefix = 'expense_draft_';

  Future<void> saveDraft(String formId, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_draftKeyPrefix$formId', jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getDraft(String formId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('$_draftKeyPrefix$formId');
    if (jsonStr != null) {
      try {
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> clearDraft(String formId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_draftKeyPrefix$formId');
  }
}

final draftServiceProvider = Provider<DraftService>((ref) {
  return DraftService();
});
