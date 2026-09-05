import 'export_service_stub.dart'
    if (dart.library.html) 'export_service_web.dart'
    if (dart.library.io) 'export_service_io.dart' as platform_export;

import '../../features/expenses/domain/expense_model.dart';
import 'export_models.dart';

class ExportService {
  /// Exports expenses to CSV and downloads on Web or opens the share dialog on mobile.
  static Future<void> exportToCSV(List<Expense> expenses) =>
      platform_export.exportToCSV(expenses);

  /// Exports comprehensive financial statement to PDF with calculations & summary.
  static Future<void> exportToPDF(
    List<Expense> expenses, {
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    double totalSpent = 0.0,
    double totalReceived = 0.0,
    double netBalance = 0.0,
    String? userName,
  }) =>
      platform_export.exportToPDF(
        expenses,
        title: title,
        startDate: startDate,
        endDate: endDate,
        totalSpent: totalSpent,
        totalReceived: totalReceived,
        netBalance: netBalance,
        userName: userName,
      );

  /// Exports fully configured bank-grade PDF statement.
  static Future<void> exportStatementToPDF(StatementExportData data) =>
      platform_export.exportStatementToPDF(data);

  /// Exports comprehensive CSV statement.
  static Future<void> exportStatementToCSV(StatementExportData data) =>
      platform_export.exportStatementToCSV(data);
}
