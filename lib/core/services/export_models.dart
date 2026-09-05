class GroupSummaryInfo {
  final String id;
  final String name;
  final int memberCount;

  const GroupSummaryInfo({
    required this.id,
    required this.name,
    required this.memberCount,
  });
}

class StatementTransactionItem {
  final String id;
  final DateTime dateTime;
  final String title;
  final String groupName;
  final String payerName;
  final String category;
  final double amount;
  final bool isOutflow;
  final bool isSettlement;
  final String? subtitle;

  const StatementTransactionItem({
    required this.id,
    required this.dateTime,
    required this.title,
    required this.groupName,
    required this.payerName,
    required this.category,
    required this.amount,
    required this.isOutflow,
    this.isSettlement = false,
    this.subtitle,
  });
}

class StatementExportData {
  final String userName;
  final String userEmail;
  final String? userUpiId;
  final List<GroupSummaryInfo> groups;
  final String scope; // 'all' | 'expenses' | 'settlements'
  final String expenseFilter; // 'all' | 'personal' | 'group'
  final DateTime startDate;
  final DateTime endDate;
  final List<StatementTransactionItem> items;
  final double totalSpent;
  final double totalReceived;
  final double netBalance;
  final Map<String, double> categoryBreakdown;

  const StatementExportData({
    required this.userName,
    required this.userEmail,
    this.userUpiId,
    required this.groups,
    required this.scope,
    this.expenseFilter = 'all',
    required this.startDate,
    required this.endDate,
    required this.items,
    required this.totalSpent,
    required this.totalReceived,
    required this.netBalance,
    required this.categoryBreakdown,
  });
}
