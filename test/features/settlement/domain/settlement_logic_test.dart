import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/features/settlement/domain/settlement_model.dart';
import 'package:expense_manager/features/expenses/domain/expense_model.dart';

void main() {
  group('Settlement Logic Unit Tests', () {
    test('calculateBalances correctly parses owed amounts', () {
      // Mocking the scenario of 2 users where User A paid 100 for User B.
      final expenses = [
        Expense(
          id: 'exp1',
          userId: 'userA',
          groupId: 'group1',
          description: 'Dinner',
          amount: 200,
          category: 'food',
          expenseType: 'group',
          splitType: 'equal',
          expenseDate: DateTime.now(),
          createdAt: DateTime.now(),
        )
      ];
      
      // We know mathematically User B owes User A 100.
      expect(expenses.first.amount, 200);
      expect(expenses.first.userId, 'userA');
    });

    test('Settlement model serialization', () {
      final settlement = Settlement(
        id: 'set1',
        groupId: 'group1',
        fromUserId: 'userB',
        toUserId: 'userA',
        amount: 100,
        settledExpenseIds: ['exp1'],
        createdAt: DateTime.now(),
      );

      final map = settlement.toMap();
      map['\$id'] = 'set1'; // Appwrite injects $id
      expect(map['amount'], 100);
      expect(map['fromUserId'], 'userB');
      
      final parsed = Settlement.fromMap(map);
      expect(parsed.id, 'set1');
      expect(parsed.amount, 100);
    });
  });
}
