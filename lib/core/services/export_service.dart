import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../features/expenses/domain/expense_model.dart';
import '../utils/date_helpers.dart';

class ExportService {
  /// Exports expenses to CSV and opens the share dialog
  static Future<void> exportToCSV(List<Expense> expenses) async {
    List<List<dynamic>> rows = [];

    // Header row
    rows.add(['Date', 'Description', 'Category', 'Type', 'Amount', 'Paid By']);

    // Data rows
    for (var exp in expenses) {
      rows.add([
        DateHelpers.formatFullDate(exp.expenseDate),
        exp.description,
        exp.category,
        exp.expenseType,
        exp.amount,
        exp.userId,
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/expenses_export.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(path)], text: 'Expense Report (CSV)');
  }

  /// Exports expenses to PDF and opens the share dialog
  static Future<void> exportToPDF(List<Expense> expenses) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Expense Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Generated on: ${DateHelpers.formatFullDate(DateTime.now())}',
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Description', 'Category', 'Amount'],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              data: expenses.map((exp) {
                return [
                  DateHelpers.formatFullDate(exp.expenseDate),
                  exp.description,
                  exp.category,
                  exp.amount.toStringAsFixed(2),
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/expenses_report.pdf';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(path)], text: 'Expense Report (PDF)');
  }
}
