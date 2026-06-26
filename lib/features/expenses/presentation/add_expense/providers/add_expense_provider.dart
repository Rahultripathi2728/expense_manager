import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/features/expenses/data/expense_repository.dart';
import 'package:expense_manager/features/auth/data/auth_repository.dart';
import 'package:expense_manager/features/expenses/presentation/add_expense/add_expense_screen.dart';
import 'package:expense_manager/features/profile/data/profile_repository.dart';
import 'package:expense_manager/features/profile/domain/profile_model.dart';
import 'package:expense_manager/shared/services/categorize_service.dart';
import 'package:expense_manager/features/expenses/domain/expense_model.dart';
import 'package:expense_manager/core/utils/error_formatter.dart';

class ItemSplitState {
  final String description;
  final int qty;
  final double price;
  final List<String> participantIds;

  ItemSplitState({
    required this.description,
    required this.qty,
    required this.price,
    required this.participantIds,
  });

  ItemSplitState copyWith({
    String? description,
    int? qty,
    double? price,
    List<String>? participantIds,
  }) {
    return ItemSplitState(
      description: description ?? this.description,
      qty: qty ?? this.qty,
      price: price ?? this.price,
      participantIds: participantIds ?? this.participantIds,
    );
  }
}

class SingleBillState {
  final String description;
  final double amount;
  final String category;
  final String splitType; // 'equal' | 'unequal' | 'itemwise'
  final List<String> selectedMemberIds; // for equal split
  final Map<String, double>
  unequalAmounts; // for unequal split (userId -> amount)
  final List<ItemSplitState> items; // for itemwise split

  SingleBillState({
    this.description = '',
    this.amount = 0.0,
    this.category = '',
    this.splitType = 'equal',
    this.selectedMemberIds = const [],
    this.unequalAmounts = const {},
    this.items = const [],
  });

  SingleBillState copyWith({
    String? description,
    double? amount,
    String? category,
    String? splitType,
    List<String>? selectedMemberIds,
    Map<String, double>? unequalAmounts,
    List<ItemSplitState>? items,
  }) {
    return SingleBillState(
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      splitType: splitType ?? this.splitType,
      selectedMemberIds: selectedMemberIds ?? this.selectedMemberIds,
      unequalAmounts: unequalAmounts ?? this.unequalAmounts,
      items: items ?? this.items,
    );
  }
}

class AddExpenseState {
  final List<SingleBillState> bills;
  final int activeBillIndex;
  final List<String> allMemberIds;
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  AddExpenseState({
    this.bills = const [],
    this.activeBillIndex = 0,
    this.allMemberIds = const [],
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  AddExpenseState copyWith({
    List<SingleBillState>? bills,
    int? activeBillIndex,
    List<String>? allMemberIds,
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return AddExpenseState(
      bills: bills ?? this.bills,
      activeBillIndex: activeBillIndex ?? this.activeBillIndex,
      allMemberIds: allMemberIds ?? this.allMemberIds,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

class AddExpenseNotifier extends StateNotifier<AddExpenseState> {
  final Ref _ref;
  final String? _groupId;

  Expense? _existingExpense;

  AddExpenseNotifier(this._ref, this._groupId) : super(AddExpenseState()) {
    _initMembers();
  }

  Future<void> initializeWithExpense(Expense expense) async {
    _existingExpense = expense;
    state = state.copyWith(isLoading: true);
    try {
      final repo = _ref.read(expenseRepositoryProvider);
      final splits = await repo.getExpenseSplits(expense.id);
      final items = await repo.getExpenseItems(expense.id);

      List<String> selectedMemberIds = [];
      Map<String, double> unequalAmounts = {};
      List<ItemSplitState> itemStates = [];

      if (expense.splitType == 'equal') {
        selectedMemberIds = splits.where((s) => s.isIncluded).map((s) => s.userId).toList();
      } else if (expense.splitType == 'unequal') {
        for (final s in splits) {
          unequalAmounts[s.userId] = s.amountOwed;
        }
      } else if (expense.splitType == 'itemwise') {
        itemStates = items.map((item) {
          return ItemSplitState(
            description: item.itemName,
            qty: 1, // qty is not natively stored in appwrite currently, so we default to 1
            price: item.itemAmount,
            participantIds: item.participants,
          );
        }).toList();
      }

      final initialBill = SingleBillState(
        description: expense.description,
        amount: expense.amount,
        category: expense.category,
        splitType: expense.splitType ?? 'equal',
        selectedMemberIds: selectedMemberIds,
        unequalAmounts: unequalAmounts,
        items: itemStates,
      );

      state = state.copyWith(
        bills: [initialBill],
        activeBillIndex: 0,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to load expense details: $e', isLoading: false);
    }
  }

  Future<void> _initMembers() async {
    try {
      if (_groupId == null) {
        final user = _ref.read(authStateProvider).valueOrNull;
        if (user != null) {
          if (state.bills.isEmpty) {
            final initialBill = SingleBillState(
              selectedMemberIds: [user.id],
              unequalAmounts: {user.id: 0.0},
            );
            state = state.copyWith(
              allMemberIds: [user.id],
              bills: [initialBill],
              activeBillIndex: 0,
            );
          } else {
             state = state.copyWith(allMemberIds: [user.id]);
          }
        }
      } else {
        // Fetch group members profiles using future
        final profiles = await _ref.read(
          groupProfilesProvider(_groupId).future,
        );
        final ids = profiles.map((p) => p.userId).toList();
        
        if (state.bills.isEmpty) {
          final initialBill = SingleBillState(
            selectedMemberIds: ids,
            unequalAmounts: {for (var id in ids) id: 0.0},
          );
          state = state.copyWith(
            allMemberIds: ids,
            bills: [initialBill],
            activeBillIndex: 0,
          );
        } else {
           state = state.copyWith(allMemberIds: ids);
        }
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to initialize members: $e');
    }
  }

  void addBill() {
    final list = List<SingleBillState>.from(state.bills);
    list.add(
      SingleBillState(
        selectedMemberIds: List<String>.from(state.allMemberIds),
        unequalAmounts: {for (var id in state.allMemberIds) id: 0.0},
      ),
    );
    state = state.copyWith(bills: list, activeBillIndex: list.length - 1);
  }

  void removeBill(int index) {
    final list = List<SingleBillState>.from(state.bills);
    if (list.length > 1) {
      list.removeAt(index);
      int newActive = state.activeBillIndex;
      if (newActive >= list.length) {
        newActive = list.length - 1;
      }
      state = state.copyWith(bills: list, activeBillIndex: newActive);
    }
  }

  void setActiveBillIndex(int index) {
    if (index >= 0 && index < state.bills.length) {
      state = state.copyWith(activeBillIndex: index);
    }
  }

  void updateActiveBill(SingleBillState Function(SingleBillState) updater) {
    final list = List<SingleBillState>.from(state.bills);
    if (list.isNotEmpty) {
      list[state.activeBillIndex] = updater(list[state.activeBillIndex]);
      state = state.copyWith(bills: list);
    }
  }

  void updateDescription(String value) {
    updateActiveBill(
      (b) => b.copyWith(
        description: value,
        category: CategorizeService.categorize(value),
      ),
    );
  }

  void updateCategory(String value) {
    updateActiveBill((b) => b.copyWith(category: value));
  }

  void updateAmount(double value) {
    updateActiveBill((b) => b.copyWith(amount: value));
  }

  void updateSplitType(String value) {
    updateActiveBill((b) {
      var updated = b.copyWith(splitType: value);
      if (value == 'itemwise' && updated.items.isEmpty) {
        updated = updated.copyWith(
          items: [
            ItemSplitState(
              description: '',
              qty: 1,
              price: 0.0,
              participantIds: List<String>.from(state.allMemberIds),
            ),
          ],
        );
      }
      return updated;
    });
    if (value == 'itemwise') {
      _recalculateItemwiseTotal();
    }
  }

  // Equally splitting
  void toggleMember(String userId) {
    updateActiveBill((b) {
      final list = List<String>.from(b.selectedMemberIds);
      if (list.contains(userId)) {
        if (list.length > 1) {
          list.remove(userId);
        }
      } else {
        list.add(userId);
      }
      return b.copyWith(selectedMemberIds: list);
    });
  }

  void selectAllMembers() {
    updateActiveBill((b) => b.copyWith(selectedMemberIds: state.allMemberIds));
  }

  // Unequally splitting
  void updateUnequalAmount(String userId, double amount) {
    updateActiveBill((b) {
      final map = Map<String, double>.from(b.unequalAmounts);
      map[userId] = amount;
      return b.copyWith(unequalAmounts: map);
    });
  }

  void splitUnequallyEqually() {
    if (state.allMemberIds.isEmpty) return;
    updateActiveBill((b) {
      final share = b.amount / state.allMemberIds.length;
      final map = {for (var id in state.allMemberIds) id: share};
      return b.copyWith(unequalAmounts: map);
    });
  }

  // Itemwise splitting
  void addItem() {
    updateActiveBill((b) {
      final items = List<ItemSplitState>.from(b.items);
      items.add(
        ItemSplitState(
          description: '',
          qty: 1,
          price: 0.0,
          participantIds: List<String>.from(state.allMemberIds),
        ),
      );
      return b.copyWith(items: items);
    });
    _recalculateItemwiseTotal();
  }

  void removeItem(int index) {
    updateActiveBill((b) {
      final items = List<ItemSplitState>.from(b.items);
      if (items.length > 1) {
        items.removeAt(index);
        return b.copyWith(items: items);
      }
      return b;
    });
    _recalculateItemwiseTotal();
  }

  void updateItemDescription(int index, String value) {
    updateActiveBill((b) {
      final items = List<ItemSplitState>.from(b.items);
      items[index] = items[index].copyWith(description: value);
      return b.copyWith(items: items);
    });
  }

  void updateItemQty(int index, int qty) {
    if (qty > 0) {
      updateActiveBill((b) {
        final items = List<ItemSplitState>.from(b.items);
        items[index] = items[index].copyWith(qty: qty);
        return b.copyWith(items: items);
      });
      _recalculateItemwiseTotal();
    }
  }

  void updateItemPrice(int index, double price) {
    updateActiveBill((b) {
      final items = List<ItemSplitState>.from(b.items);
      items[index] = items[index].copyWith(price: price);
      return b.copyWith(items: items);
    });
    _recalculateItemwiseTotal();
  }

  void toggleItemParticipant(int index, String userId) {
    updateActiveBill((b) {
      final items = List<ItemSplitState>.from(b.items);
      final participants = List<String>.from(items[index].participantIds);
      if (participants.contains(userId)) {
        if (participants.length > 1) {
          participants.remove(userId);
        }
      } else {
        participants.add(userId);
      }
      items[index] = items[index].copyWith(participantIds: participants);
      return b.copyWith(items: items);
    });
  }

  void _recalculateItemwiseTotal() {
    updateActiveBill((b) {
      double total = 0.0;
      for (final item in b.items) {
        total += item.qty * item.price;
      }
      return b.copyWith(amount: total);
    });
  }

  Future<void> submitExpense({required String? groupId, DateTime? date}) async {
    // Validate all bills
    for (int i = 0; i < state.bills.length; i++) {
      final bill = state.bills[i];
      if (bill.description.trim().isEmpty) {
        state = state.copyWith(
          errorMessage: 'Please enter a description for Bill ${i + 1}',
        );
        return;
      }
      if (bill.amount <= 0.0) {
        state = state.copyWith(
          errorMessage:
              'Please enter an amount greater than 0 for Bill ${i + 1}',
        );
        return;
      }
      if (groupId != null && bill.splitType == 'unequal') {
        double totalSplit = 0.0;
        for (final amt in bill.unequalAmounts.values) {
          totalSplit += amt;
        }
        if ((totalSplit - bill.amount).abs() > 0.01) {
          state = state.copyWith(
            isLoading: false,
            errorMessage:
                'Split values sum (₹$totalSplit) must equal total (₹${bill.amount}) for Bill ${i + 1}',
          );
          return;
        }
      }
      if (groupId != null && bill.splitType == 'itemwise') {
        for (final item in bill.items) {
          if (item.description.trim().isEmpty) {
            state = state.copyWith(
              isLoading: false,
              errorMessage:
                  'All items must have a description in Bill ${i + 1}',
            );
            return;
          }
          if (item.price <= 0.0) {
            state = state.copyWith(
              isLoading: false,
              errorMessage: 'All items must have a price > 0 in Bill ${i + 1}',
            );
            return;
          }
        }
      }
    }

    final user = _ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      state = state.copyWith(errorMessage: 'Authentication error');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final repo = _ref.read(expenseRepositoryProvider);
      for (final bill in state.bills) {
        if (groupId == null) {
          if (_existingExpense != null) {
            await repo.updatePersonalExpense(
              expenseId: _existingExpense!.id,
              description: bill.description,
              amount: bill.amount,
              category: bill.category,
              date: date ?? DateTime.now(),
            );
          } else {
            await repo.createPersonalExpense(
              userId: user.id,
              description: bill.description,
              amount: bill.amount,
              category: bill.category,
              date: date ?? DateTime.now(),
            );
          }
        } else {
          // Group Expense: Construct splits and items depending on split type
          List<Map<String, dynamic>> splitsPayload = [];
          List<Map<String, dynamic>>? itemsPayload;

          if (bill.splitType == 'equal') {
            final share = bill.amount / bill.selectedMemberIds.length;
            splitsPayload = bill.selectedMemberIds
                .map(
                  (userId) => {
                    'userId': userId,
                    'amountOwed': share,
                    'isIncluded': true,
                  },
                )
                .toList();
          } else if (bill.splitType == 'unequal') {
            splitsPayload = bill.unequalAmounts.entries
                .map(
                  (e) => {
                    'userId': e.key,
                    'amountOwed': e.value,
                    'isIncluded': e.value > 0.0,
                  },
                )
                .toList();
          } else if (bill.splitType == 'itemwise') {
            final Map<String, double> aggregatedAmounts = {
              for (var id in state.allMemberIds) id: 0.0,
            };

            itemsPayload = [];
            for (final item in bill.items) {
              final itemTotal = item.qty * item.price;
              final share = itemTotal / item.participantIds.length;
              for (final partId in item.participantIds) {
                aggregatedAmounts[partId] =
                    (aggregatedAmounts[partId] ?? 0.0) + share;
              }

              itemsPayload.add({
                'itemName': item.description,
                'itemAmount': itemTotal,
                'participants': item.participantIds,
              });
            }

            splitsPayload = aggregatedAmounts.entries
                .map(
                  (e) => {
                    'userId': e.key,
                    'amountOwed': e.value,
                    'isIncluded': e.value > 0.0,
                  },
                )
                .toList();
          }

          if (_existingExpense != null) {
            await repo.updateGroupExpense(
              expenseId: _existingExpense!.id,
              description: bill.description,
              amount: bill.amount,
              category: bill.category,
              splitType: bill.splitType,
              splits: splitsPayload,
              items: itemsPayload,
              date: date,
            );
          } else {
            await repo.createGroupExpense(
              groupId: groupId,
              userId: user.id,
              description: bill.description,
              amount: bill.amount,
              category: bill.category,
              splitType: bill.splitType,
              splits: splitsPayload,
              items: itemsPayload,
              date: date,
            );
          }
        }
      }

      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to add expense: ${ErrorFormatter.format(e)}',
      );
    }
  }

  void initializeMembers(List<String> memberIds) {
    if (memberIds.isEmpty) return;

    if (state.allMemberIds.length == memberIds.length &&
        state.allMemberIds.every((id) => memberIds.contains(id))) {
      if (state.bills.isNotEmpty) return;
    }

    final initialBill = SingleBillState(
      selectedMemberIds: List<String>.from(memberIds),
      unequalAmounts: {for (var id in memberIds) id: 0.0},
    );

    state = state.copyWith(
      allMemberIds: memberIds,
      bills: [initialBill],
      activeBillIndex: 0,
    );
  }
}

final addExpenseProvider = StateNotifierProvider.autoDispose
    .family<AddExpenseNotifier, AddExpenseState, String?>((ref, groupId) {
      final notifier = AddExpenseNotifier(ref, groupId);
      if (groupId == null) {
        ref.listen<AsyncValue<Profile?>>(currentProfileProvider, (prev, next) {
          final profile = next.valueOrNull;
          if (profile != null) {
            notifier.initializeMembers([profile.userId]);
          }
        }, fireImmediately: true);
      } else {
        ref.listen<AsyncValue<List<Profile>>>(groupProfilesProvider(groupId), (
          prev,
          next,
        ) {
          final profiles = next.valueOrNull;
          if (profiles != null) {
            notifier.initializeMembers(profiles.map((p) => p.userId).toList());
          }
        }, fireImmediately: true);
      }
      return notifier;
    });
