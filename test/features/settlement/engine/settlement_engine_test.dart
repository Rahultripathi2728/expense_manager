import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/features/expenses/domain/expense_model.dart';
import 'package:expense_manager/features/expenses/domain/expense_split_model.dart';
import 'package:expense_manager/features/settlement/domain/settlement_model.dart';
import 'package:expense_manager/features/settlement/engine/settlement_engine.dart';
import 'package:expense_manager/features/settlement/engine/models/simplified_debt.dart';

void main() {
  group('SettlementEngine Core Tests', () {
    test('User Scenario: Aman pays 300, Rahul pays 200 - Rahul bill is NOT locked', () {
      const amanId = 'user_aman';
      const rahulId = 'user_rahul';
      final members = [amanId, rahulId];

      final bill1 = Expense(
        id: 'bill_aman_300',
        userId: amanId,
        groupId: 'flat_group',
        amount: 300.0,
        category: 'Food',
        description: 'Groceries by Aman',
        expenseDate: DateTime.now(),
        expenseType: 'group',
        createdAt: DateTime.now(),
        splitType: 'equal',
        isSettled: false,
      );

      final bill2 = Expense(
        id: 'bill_rahul_200',
        userId: rahulId,
        groupId: 'flat_group',
        amount: 200.0,
        category: 'Supplies',
        description: 'Supplies by Rahul',
        expenseDate: DateTime.now(),
        expenseType: 'group',
        createdAt: DateTime.now(),
        splitType: 'equal',
        isSettled: false,
      );

      final splits = [
        // Bill 1 splits (150 each)
        const ExpenseSplit(id: 's1', expenseId: 'bill_aman_300', userId: amanId, amountOwed: 150.0, isIncluded: true),
        const ExpenseSplit(id: 's2', expenseId: 'bill_aman_300', userId: rahulId, amountOwed: 150.0, isIncluded: true),
        // Bill 2 splits (100 each)
        const ExpenseSplit(id: 's3', expenseId: 'bill_rahul_200', userId: rahulId, amountOwed: 100.0, isIncluded: true),
        const ExpenseSplit(id: 's4', expenseId: 'bill_rahul_200', userId: amanId, amountOwed: 100.0, isIncluded: true),
      ];

      final ledger = SettlementEngine.computeLedger(
        memberUserIds: members,
        expenses: [bill1, bill2],
        allSplits: splits,
        settlements: [],
      );

      // Ledger Totals
      expect(ledger.billsPaidByMember[amanId], 300.0);
      expect(ledger.billShareByMember[amanId], 250.0);
      expect(ledger.getMemberNet(amanId), 50.0); // Aman gets back 50

      expect(ledger.billsPaidByMember[rahulId], 200.0);
      expect(ledger.billShareByMember[rahulId], 250.0);
      expect(ledger.getMemberNet(rahulId), -50.0); // Rahul owes 50

      // Simplified Debts
      expect(ledger.transactions.length, 1);
      expect(
        ledger.transactions.first,
        const SimplifiedDebt(fromUserId: rahulId, toUserId: amanId, amount: 50.0),
      );

      // CRITICAL VERIFICATION: Neither bill is locked!
      // Rahul CAN edit/delete his 200 bill!
      expect(ledger.isExpenseLocked(bill2), isFalse, reason: 'Rahul bill must NOT be locked');
      expect(ledger.isExpenseLocked(bill1), isFalse, reason: 'Aman bill must NOT be locked');
    });

    test('Recorded Settlement locks only the referenced expense', () {
      const amanId = 'user_aman';
      const rahulId = 'user_rahul';
      final members = [amanId, rahulId];

      final bill1 = Expense(
        id: 'bill_1',
        userId: amanId,
        groupId: 'g1',
        amount: 100.0,
        category: 'Food',
        description: 'Snacks',
        expenseDate: DateTime.now(),
        expenseType: 'group',
        createdAt: DateTime.now(),
        splitType: 'equal',
        isSettled: false,
      );

      final bill2 = Expense(
        id: 'bill_2',
        userId: rahulId,
        groupId: 'g1',
        amount: 80.0,
        category: 'Food',
        description: 'Drinks',
        expenseDate: DateTime.now(),
        expenseType: 'group',
        createdAt: DateTime.now(),
        splitType: 'equal',
        isSettled: false,
      );

      final settlement = Settlement(
        id: 'set_1',
        groupId: 'g1',
        fromUserId: rahulId,
        toUserId: amanId,
        amount: 50.0,
        createdAt: DateTime.now(),
        settledExpenseIds: ['bill_1'],
      );

      final ledger = SettlementEngine.computeLedger(
        memberUserIds: members,
        expenses: [bill1, bill2],
        allSplits: [
          const ExpenseSplit(id: 's1', expenseId: 'bill_1', userId: amanId, amountOwed: 50.0, isIncluded: true),
          const ExpenseSplit(id: 's2', expenseId: 'bill_1', userId: rahulId, amountOwed: 50.0, isIncluded: true),
          const ExpenseSplit(id: 's3', expenseId: 'bill_2', userId: rahulId, amountOwed: 40.0, isIncluded: true),
          const ExpenseSplit(id: 's4', expenseId: 'bill_2', userId: amanId, amountOwed: 40.0, isIncluded: true),
        ],
        settlements: [settlement],
      );

      // Bill 1 is referenced in settlement, so it is locked
      expect(ledger.isExpenseLocked(bill1), isTrue);
      // Bill 2 is NOT referenced, so it remains editable
      expect(ledger.isExpenseLocked(bill2), isFalse);
    });

    test('Mathematical Invariant: Sum of net balances is always zero', () {
      final members = ['u1', 'u2', 'u3'];
      final bill = Expense(
        id: 'exp_1',
        userId: 'u1',
        groupId: 'g1',
        amount: 600.0,
        category: 'Travel',
        description: 'Cab',
        expenseDate: DateTime.now(),
        expenseType: 'group',
        createdAt: DateTime.now(),
        splitType: 'equal',
        isSettled: false,
      );

      final splits = [
        const ExpenseSplit(id: 's1', expenseId: 'exp_1', userId: 'u1', amountOwed: 200.0, isIncluded: true),
        const ExpenseSplit(id: 's2', expenseId: 'exp_1', userId: 'u2', amountOwed: 200.0, isIncluded: true),
        const ExpenseSplit(id: 's3', expenseId: 'exp_1', userId: 'u3', amountOwed: 200.0, isIncluded: true),
      ];

      final ledger = SettlementEngine.computeLedger(
        memberUserIds: members,
        expenses: [bill],
        allSplits: splits,
        settlements: [],
      );

      final totalNet = ledger.netBalances.values.fold<double>(0.0, (sum, val) => sum + val);
      expect(totalNet.abs(), lessThan(0.01));
      expect(ledger.getMemberNet('u1'), 400.0);
      expect(ledger.getMemberNet('u2'), -200.0);
      expect(ledger.getMemberNet('u3'), -200.0);
    });

    test('User Scenario 2: 3 members (Kumar pays 300, Demo settles 100, Rahul pending) -> partiallySettled', () {
      const kumarId = 'user_kumar';
      const demoId = 'user_demo';
      const rahulId = 'user_rahul';
      final members = [kumarId, demoId, rahulId];

      final bill = Expense(
        id: 'bill_kumar_300',
        userId: kumarId,
        groupId: 'room',
        amount: 300.0,
        category: 'Food',
        description: 'Dinner by Kumar',
        expenseDate: DateTime.now(),
        expenseType: 'group',
        createdAt: DateTime.now(),
        splitType: 'equal',
        isSettled: false,
      );

      final splits = [
        const ExpenseSplit(id: 's1', expenseId: 'bill_kumar_300', userId: kumarId, amountOwed: 100.0, isIncluded: true),
        const ExpenseSplit(id: 's2', expenseId: 'bill_kumar_300', userId: demoId, amountOwed: 100.0, isIncluded: true),
        const ExpenseSplit(id: 's3', expenseId: 'bill_kumar_300', userId: rahulId, amountOwed: 100.0, isIncluded: true),
      ];

      // Phase 1: Only Demo settles with Kumar
      final demoSettlement = Settlement(
        id: 'set_demo',
        groupId: 'room',
        fromUserId: demoId,
        toUserId: kumarId,
        amount: 100.0,
        createdAt: DateTime.now(),
        settledExpenseIds: ['bill_kumar_300'],
      );

      final ledgerPhase1 = SettlementEngine.computeLedger(
        memberUserIds: members,
        expenses: [bill],
        allSplits: splits,
        settlements: [demoSettlement],
      );

      // Phase 1 checks:
      expect(ledgerPhase1.isExpensePartiallySettled(bill), isTrue, reason: 'Demo paid, but Rahul is pending -> partially settled');
      expect(ledgerPhase1.isExpenseFullySettled(bill), isFalse, reason: 'Rahul has NOT paid -> NOT fully settled');
      expect(ledgerPhase1.isExpenseLocked(bill), isTrue, reason: 'Demo already paid -> cannot edit or delete');
      expect(ledgerPhase1.getSettledDebtorsCount(bill), 1);
      expect(ledgerPhase1.getTotalDebtorsCount(bill), 2);

      // Phase 2: Rahul also settles with Kumar
      final rahulSettlement = Settlement(
        id: 'set_rahul',
        groupId: 'room',
        fromUserId: rahulId,
        toUserId: kumarId,
        amount: 100.0,
        createdAt: DateTime.now(),
        settledExpenseIds: ['bill_kumar_300'],
      );

      final ledgerPhase2 = SettlementEngine.computeLedger(
        memberUserIds: members,
        expenses: [bill],
        allSplits: splits,
        settlements: [demoSettlement, rahulSettlement],
      );

      // Phase 2 checks:
      expect(ledgerPhase2.isExpenseFullySettled(bill), isTrue, reason: 'Both Demo and Rahul paid -> fully settled');
      expect(ledgerPhase2.isExpensePartiallySettled(bill), isFalse);
      expect(ledgerPhase2.isExpenseLocked(bill), isTrue);
      expect(ledgerPhase2.getSettledDebtorsCount(bill), 2);
      expect(ledgerPhase2.getTotalDebtorsCount(bill), 2);
    });
  });
}
