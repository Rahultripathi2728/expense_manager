/// App-wide constants: collection IDs, database ID, etc.
class AppConstants {
  AppConstants._();

  // ── Appwrite Configuration ──
  static const String appwriteEndpoint = 'https://sgp.cloud.appwrite.io/v1';
  static const String appwriteProjectId = '6a200c97000d20071b44';

  // ── Database ──
  static const String databaseId = 'expense_manager_db';
  static const String localDbEncryptionKey = 'xM9q\$#vP2!aL8^kR5@wY7&nB4*tJ1%hC';

  // ── Collection IDs ──
  static const String profilesCollection = 'profiles';
  static const String groupsCollection = 'groups';
  static const String groupMembersCollection = 'group_members';
  static const String expensesCollection = 'expenses';
  static const String expenseSplitsCollection = 'expense_splits';
  static const String expenseItemsCollection = 'expense_items';
  static const String settlementsCollection = 'settlements';
  static const String listsCollection = 'lists';
  static const String notificationsCollection = 'notifications';
  static const String pushSubscriptionsCollection = 'push_subscriptions';

  // ── Function IDs ──
  static const String joinGroupFunction = 'join-group-by-code';
  static const String createGroupExpenseFunction = 'create-group-expense';
  static const String settleBalancesFunction = 'settle-balances';
  static const String deleteExpenseFunction = 'delete-expense';
  static const String sendPushFunction = 'send-push';

  // ── Currency ──
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';

  // ── Pagination ──
  static const int defaultPageSize = 25;
  static const int maxPageSize = 100;

  // ── Cache ──
  static const int cacheExpenseDays = 90;

  // ── Join Code ──
  static const int joinCodeLength = 6;

  // ── Validation ──
  static const int minPasswordLength = 6;
  static const double splitEpsilon = 0.01;
}
