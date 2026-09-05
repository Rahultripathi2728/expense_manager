import '../../features/expenses/domain/expense_model.dart';
import 'export_models.dart';

/// Stub for platforms that don't have dart:io or dart:html
Future<void> exportToCSV(List<Expense> expenses) async {
  throw UnsupportedError('Export not supported on this platform');
}

Future<void> exportToPDF(
  List<Expense> expenses, {
  String? title,
  DateTime? startDate,
  DateTime? endDate,
  double totalSpent = 0.0,
  double totalReceived = 0.0,
  double netBalance = 0.0,
  String? userName,
}) async {
  throw UnsupportedError('Export not supported on this platform');
}

Future<void> exportStatementToCSV(StatementExportData data) async {
  throw UnsupportedError('Export not supported on this platform');
}

Future<void> exportStatementToPDF(StatementExportData data) async {
  throw UnsupportedError('Export not supported on this platform');
}
