import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/auth/presentation/sign_up_page.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/otp_verification_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/auth/presentation/magic_login_page.dart';
import '../../features/calendar/presentation/calendar_page.dart';
import '../../features/expenses/presentation/my_expenses_page.dart';
import '../../features/expenses/presentation/view_all_expenses_page.dart';
import '../../features/expenses/presentation/expense_detail_page.dart';
import '../../features/expenses/presentation/personal_expenses_page.dart';
import '../../features/expenses/presentation/group_share_selection_page.dart';
import '../../features/expenses/presentation/cash_flow_ledger_page.dart';
import '../../features/expenses/presentation/export/statement_export_screen.dart';
import '../../features/settlement/presentation/settlement_history_page.dart';
import '../../features/settlement/presentation/settlement_history_detail_page.dart';
import '../../features/settlement/domain/settlement_model.dart';
import '../../features/settlement/presentation/bill_selection_page.dart';
import '../../features/settlement/presentation/payment_summary_page.dart';
import '../../features/expenses/domain/expense_model.dart';
import '../../features/groups/presentation/groups_page.dart';
import '../../features/groups/presentation/group_detail_page.dart';
import '../../features/groups/domain/group_model.dart';
import '../../features/items/presentation/items_page.dart';
import '../../features/items/presentation/add_item_screen.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../shared/widgets/app_shell.dart';
import '../../features/auth/domain/user_model.dart';

final splashDelayProvider = FutureProvider<void>((ref) async {
  await Future.delayed(const Duration(milliseconds: 2500));
});

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<int>(0);

  ref.listen<AsyncValue<UserModel?>>(
    authStateProvider,
    (_, __) => refreshNotifier.value++,
  );

  ref.listen<AsyncValue<void>>(
    splashDelayProvider,
    (_, __) => refreshNotifier.value++,
  );

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final splashDelay = ref.read(splashDelayProvider);

      final isAuthLoading = authState.isLoading;
      final isSplashDelayLoading = splashDelay.isLoading;
      final isLoading = isAuthLoading || isSplashDelayLoading;

      final user = authState.valueOrNull;
      final isAuthRoute =
          state.matchedLocation == '/sign-in' ||
          state.matchedLocation == '/sign-up' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/magic-login';

      // If auth is still loading or splash delay hasn't finished, stay on or redirect to splash
      if (isLoading) {
        if (state.matchedLocation != '/splash') return '/splash';
        return null;
      }

      // If we are on the splash screen and loading is done, proceed to the app
      if (state.matchedLocation == '/splash') {
        return user != null ? '/calendar' : '/sign-in';
      }

      // If user is null and not on an auth route, force them to sign-in
      if (user == null && !isAuthRoute) return '/sign-in';

      // If user is logged in and trying to access an auth route, redirect to app
      if (user != null && isAuthRoute) return '/calendar';

      return null;
    },
    routes: [
      // ── Splash Route ──
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
      // ── Auth Routes ──
      GoRoute(path: '/sign-in', builder: (_, __) => const SignInPage()),
      GoRoute(path: '/sign-up', builder: (_, __) => const SignUpPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/magic-login',
        builder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ?? '';
          final secret = state.uri.queryParameters['secret'] ?? '';
          return MagicLoginPage(userId: userId, secret: secret);
        },
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return OtpVerificationPage(
            userId: args['userId'] ?? '',
            email: args['email'] ?? '',
            name: args['name'] ?? '',
            username: args['username'] ?? '',
          );
        },
      ),

      // ── Main App Shell ──
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/calendar',
            pageBuilder: (_, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const CalendarPage(),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: '/expenses',
            pageBuilder: (_, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const MyExpensesPage(),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: '/groups',
            pageBuilder: (_, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const GroupsPage(),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: '/items',
            pageBuilder: (_, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const ItemsPage(),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: '/settlement',
            redirect: (_, __) => '/groups',
          ),
        ],
      ),

      // ── Detail Routes ──
      GoRoute(
        path: '/personal-expenses',
        builder: (_, state) {
          final month = state.extra as DateTime? ?? DateTime.now();
          return PersonalExpensesPage(month: month);
        },
      ),
      GoRoute(
        path: '/group-share-selection',
        builder: (_, state) {
          final month = state.extra as DateTime? ?? DateTime.now();
          return GroupShareSelectionPage(month: month);
        },
      ),
      GoRoute(
        path: '/cash-flow',
        builder: (_, state) {
          final month = state.extra as DateTime? ?? DateTime.now();
          return CashFlowLedgerPage(month: month);
        },
      ),
      GoRoute(
        path: '/group/:groupId',
        builder: (_, state) =>
            GroupDetailPage(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/expenses/view-all',
        builder: (_, __) => const ViewAllExpensesPage(),
      ),


      GoRoute(
        path: '/expense-detail',
        builder: (_, state) {
          final expense = state.extra;
          if (expense is! Expense) {
            // Redirect to a safe page if navigated without proper data
            return const Scaffold(
              body: Center(
                child: Text('Expense data not found. Please go back.'),
              ),
            );
          }
          return ExpenseDetailPage(expense: expense);
        },
      ),
      GoRoute(
        path: '/bill-selection',
        builder: (_, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return BillSelectionPage(
            groupId: args['groupId'] ?? '',
            unsettledExpenses: args['expenses'] as List<Expense>? ?? [],
          );
        },
      ),
      GoRoute(
        path: '/payment-summary',
        builder: (_, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return PaymentSummaryPage(
            groupId: args['groupId'] ?? '',
            selectedExpenses: args['expenses'] as List<Expense>? ?? [],
          );
        },
      ),
      GoRoute(
        path: '/settlement-history',
        builder: (_, state) {
          final groupId = state.extra as String? ?? '';
          return SettlementHistoryPage(groupId: groupId);
        },
      ),
      GoRoute(
        path: '/settlement-history-detail',
        builder: (_, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return SettlementHistoryDetailPage(
            settlement: args['settlement'] as Settlement,
            fromName: args['fromName'] as String? ?? '',
            toName: args['toName'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: '/add-item',
        builder: (_, state) {
          final group = state.extra as Group?;
          return AddItemScreen(group: group);
        },
      ),
      GoRoute(
        path: '/export-statement',
        builder: (_, state) {
          final args = state.extra as Map<String, dynamic>?;
          return StatementExportScreen(
            initialMonth: args?['month'] as DateTime?,
            initialDateRange: args?['dateRange'] as DateTimeRange?,
          );
        },
      ),
    ],
  );
});
