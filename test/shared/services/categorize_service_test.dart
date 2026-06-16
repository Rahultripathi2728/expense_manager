import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/shared/services/categorize_service.dart';

void main() {
  group('CategorizeService Tests', () {
    test('categorize correctly identifies food', () {
      expect(CategorizeService.categorize('Zomato delivery'), 'food');
      expect(CategorizeService.categorize('grocery shopping at Dmart'), 'food');
      expect(CategorizeService.categorize('McDonalds burger'), 'food');
    });

    test('categorize correctly identifies transport', () {
      expect(CategorizeService.categorize('Uber ride to office'), 'transport');
      expect(CategorizeService.categorize('Petrol for bike'), 'transport');
    });

    test('categorize defaults to other if no match', () {
      expect(CategorizeService.categorize('Unknown weird expense'), 'other');
      expect(CategorizeService.categorize('XYZ abc'), 'other');
    });

    test('categorize is case-insensitive', () {
      expect(CategorizeService.categorize('NETFLIX SUBSCRIPTION'), 'entertainment');
      expect(CategorizeService.categorize('amazon prime'), 'shopping'); // amazon is in shopping
    });

    test('displayName returns capitalized string', () {
      expect(CategorizeService.displayName('food'), 'Food');
      expect(CategorizeService.displayName('entertainment'), 'Entertainment');
    });

    test('iconForCategory returns correct emoji', () {
      expect(CategorizeService.iconForCategory('food'), '🍔');
      expect(CategorizeService.iconForCategory('transport'), '🚗');
      expect(CategorizeService.iconForCategory('unknown_category'), '📦');
    });
  });
}
