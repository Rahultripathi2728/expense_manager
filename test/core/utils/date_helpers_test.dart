import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/core/utils/date_helpers.dart';

void main() {
  group('DateHelpers Tests', () {
    test('isSameDay should return true for same dates', () {
      final date1 = DateTime(2026, 6, 16, 10, 30);
      final date2 = DateTime(2026, 6, 16, 15, 45);
      final date3 = DateTime(2026, 6, 17, 10, 30);

      expect(DateHelpers.isSameDay(date1, date2), isTrue);
      expect(DateHelpers.isSameDay(date1, date3), isFalse);
    });

    test('startOfMonth and endOfMonth calculations', () {
      final date = DateTime(2026, 6, 16);
      
      final start = DateHelpers.startOfMonth(date);
      expect(start.day, 1);
      expect(start.month, 6);
      expect(start.year, 2026);

      final end = DateHelpers.endOfMonth(date);
      expect(end.day, 30); // June has 30 days
      expect(end.month, 6);
      expect(end.year, 2026);
    });

    test('formatCurrency should format INR correctly', () {
      expect(DateHelpers.formatCurrency(1500.0), '₹1,500');
      expect(DateHelpers.formatCurrency(1500.50), '₹1,500.50');
    });
  });
}
