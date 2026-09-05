import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../features/expenses/domain/expense_model.dart';
import '../utils/date_helpers.dart';
import 'export_models.dart';

Future<void> exportToCSV(List<Expense> expenses) async {
  List<List<dynamic>> rows = [];
  rows.add(['Date', 'Description', 'Category', 'Type', 'Amount (INR)', 'Paid By']);
  for (var exp in expenses) {
    rows.add([
      DateHelpers.formatFullDate(exp.expenseDate),
      exp.description,
      exp.category,
      exp.expenseType,
      exp.amount.toStringAsFixed(2),
      exp.userId,
    ]);
  }
  String csvData = const ListToCsvConverter().convert(rows);
  final bytes = utf8.encode(csvData);
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', 'expenses_export.csv')
    ..click();
  html.Url.revokeObjectUrl(url);
}

Future<void> exportStatementToCSV(StatementExportData data) async {
  List<List<dynamic>> rows = [];
  rows.add(['SPLIT PRO FINANCIAL STATEMENT']);
  rows.add(['Account Holder', data.userName]);
  rows.add(['Email', data.userEmail]);
  if (data.userUpiId != null && data.userUpiId!.isNotEmpty) {
    rows.add(['UPI ID', data.userUpiId]);
  }
  rows.add(['Statement Period', '${DateHelpers.formatFullDate(data.startDate)} to ${DateHelpers.formatFullDate(data.endDate)}']);
  rows.add(['Statement Scope', data.scope.toUpperCase()]);
  rows.add([]);
  rows.add(['Date & Time', 'Title / Description', 'Group / Type', 'Payer', 'Category', 'Outflow / Inflow', 'Amount (INR)']);

  for (var item in data.items) {
    final dateStr = '${DateHelpers.formatFullDate(item.dateTime)} ${DateHelpers.formatTime(item.dateTime)}';
    final typeStr = item.isOutflow ? 'OUTFLOW' : 'INFLOW';
    final signStr = item.isOutflow ? '-' : '+';
    rows.add([
      dateStr,
      item.title,
      item.groupName,
      item.payerName,
      item.category.toUpperCase(),
      typeStr,
      '$signStr${item.amount.toStringAsFixed(2)}',
    ]);
  }

  rows.add([]);
  if (data.scope == 'expenses') {
    rows.add(['TOTAL EXPENSES', 'Rs. ${data.totalSpent.toStringAsFixed(2)}']);
  } else if (data.scope == 'settlements') {
    rows.add(['TOTAL PAID OUT', 'Rs. ${data.totalSpent.toStringAsFixed(2)}']);
    rows.add(['TOTAL RECEIVED', 'Rs. ${data.totalReceived.toStringAsFixed(2)}']);
    rows.add(['NET SETTLEMENT BALANCE', 'Rs. ${data.netBalance.toStringAsFixed(2)}']);
  } else {
    rows.add(['TOTAL OUTFLOW', 'Rs. ${data.totalSpent.toStringAsFixed(2)}']);
    rows.add(['TOTAL INFLOW', 'Rs. ${data.totalReceived.toStringAsFixed(2)}']);
    rows.add(['NET FINANCIAL POSITION', 'Rs. ${data.netBalance.toStringAsFixed(2)}']);
  }

  String csvData = const ListToCsvConverter().convert(rows);
  final bytes = utf8.encode(csvData);
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', 'split_pro_statement_${data.scope}.csv')
    ..click();
  html.Url.revokeObjectUrl(url);
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
  // Backwards-compatible legacy call wraps into StatementExportData
  final double calculatedSpent = totalSpent > 0
      ? totalSpent
      : expenses.fold(0.0, (sum, e) => sum + e.amount);
  final double calculatedNet = netBalance != 0.0
      ? netBalance
      : (totalReceived - calculatedSpent);

  final Map<String, double> catSums = {};
  for (final e in expenses) {
    final cat = e.category.trim().isEmpty ? 'MISC' : e.category.toUpperCase();
    catSums[cat] = (catSums[cat] ?? 0.0) + e.amount;
  }

  final data = StatementExportData(
    userName: userName ?? 'User',
    userEmail: '',
    groups: [],
    scope: 'expenses',
    startDate: startDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1),
    endDate: endDate ?? DateTime.now(),
    items: expenses.map((e) {
      return StatementTransactionItem(
        id: e.id,
        dateTime: e.expenseDate,
        title: e.description,
        groupName: e.groupId != null ? 'Group Expense' : 'Personal',
        payerName: 'You',
        category: e.category,
        amount: e.amount,
        isOutflow: true,
      );
    }).toList(),
    totalSpent: calculatedSpent,
    totalReceived: totalReceived,
    netBalance: calculatedNet,
    categoryBreakdown: catSums,
  );

  await exportStatementToPDF(data);
}

Future<void> exportStatementToPDF(StatementExportData data) async {
  final pdf = pw.Document();

  final periodText =
      '${DateHelpers.formatFullDate(data.startDate)} to ${DateHelpers.formatFullDate(data.endDate)}';

  String statementTitle = 'FINANCIAL ACTIVITY STATEMENT';
  if (data.scope == 'expenses') {
    statementTitle = 'EXPENSE STATEMENT (${data.expenseFilter.toUpperCase()})';
  } else if (data.scope == 'settlements') {
    statementTitle = 'SETTLEMENT & PAYMENT STATEMENT';
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        return [
          // Header Bar
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 14,
                        height: 14,
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.blue700,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text(
                        'SPLIT PRO',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    statementTitle,
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Period: $periodText',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Generated: ${DateHelpers.formatFullDate(DateTime.now())} ${DateHelpers.formatTime(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Records Count: ${data.items.length}',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(thickness: 1, color: PdfColors.grey300),
          pw.SizedBox(height: 10),

          // User Profile & Accounts Block
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          'ACCOUNT HOLDER: ',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          data.userName.isNotEmpty ? data.userName : 'Account User',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ],
                    ),
                    if (data.userEmail.isNotEmpty)
                      pw.Row(
                        children: [
                          pw.Text(
                            'EMAIL: ',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            data.userEmail,
                            style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800),
                          ),
                        ],
                      ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          'UPI ID: ',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          (data.userUpiId != null && data.userUpiId!.isNotEmpty)
                              ? data.userUpiId!
                              : 'Not configured',
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            color: (data.userUpiId != null && data.userUpiId!.isNotEmpty)
                                ? PdfColors.blue800
                                : PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                    if (data.groups.isNotEmpty)
                      pw.Text(
                        'GROUPS (${data.groups.length}): ' +
                            data.groups.map((g) => '${g.name} (${g.memberCount})').join(', '),
                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                      ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Scope-Tailored KPI Cards
          if (data.scope == 'expenses') ...[
            // Expenses Only KPI Card
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.red200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text(
                        'TOTAL EXPENSES SPENT',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Rs. ${data.totalSpent.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red900,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(height: 28, width: 1, color: PdfColors.red200),
                  pw.Column(
                    children: [
                      pw.Text(
                        'TOTAL ITEMS LOGGED',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${data.items.length}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey900,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(height: 28, width: 1, color: PdfColors.red200),
                  pw.Column(
                    children: [
                      pw.Text(
                        'EXPENSE SCOPE',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        data.expenseFilter.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else if (data.scope == 'settlements') ...[
            // Settlements Only KPI Card
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.blue200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text(
                        'SETTLEMENTS PAID OUT',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Rs. ${data.totalSpent.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red800,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(height: 28, width: 1, color: PdfColors.blue200),
                  pw.Column(
                    children: [
                      pw.Text(
                        'SETTLEMENTS RECEIVED',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Rs. ${data.totalReceived.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(height: 28, width: 1, color: PdfColors.blue200),
                  pw.Column(
                    children: [
                      pw.Text(
                        'NET SETTLEMENT POSITION',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${data.netBalance >= 0 ? '+' : '-'}Rs. ${data.netBalance.abs().toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: data.netBalance >= 0 ? PdfColors.green800 : PdfColors.red800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // All Activity KPI Card
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text(
                        'TOTAL OUTFLOW (SPENT)',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Rs. ${data.totalSpent.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red800,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(height: 28, width: 1, color: PdfColors.grey400),
                  pw.Column(
                    children: [
                      pw.Text(
                        'TOTAL INFLOW (RECEIVED)',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Rs. ${data.totalReceived.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(height: 28, width: 1, color: PdfColors.grey400),
                  pw.Column(
                    children: [
                      pw.Text(
                        'NET CASH FLOW',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${data.netBalance >= 0 ? '+' : '-'}Rs. ${data.netBalance.abs().toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: data.netBalance >= 0 ? PdfColors.green800 : PdfColors.red800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 14),

          // Category Breakdown (if any)
          if (data.categoryBreakdown.isNotEmpty && data.scope != 'settlements') ...[
            pw.Text(
              'EXPENSES BY CATEGORY',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 5),
            pw.Wrap(
              spacing: 6,
              runSpacing: 4,
              children: data.categoryBreakdown.entries.map((entry) {
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColors.blue200),
                  ),
                  child: pw.Text(
                    '${entry.key}: Rs. ${entry.value.toStringAsFixed(0)}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.blue900),
                  ),
                );
              }).toList(),
            ),
            pw.SizedBox(height: 14),
          ],

          // Detailed Transaction Table
          pw.Text(
            'TRANSACTION AUDIT DETAILS',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Date & Time', 'Description & Context', 'Payer', 'Category', 'Amount (INR)'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            headerHeight: 22,
            cellHeight: 22,
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerRight,
            },
            data: [
              ...data.items.map((item) {
                final dateFormatted =
                    '${DateHelpers.formatFullDate(item.dateTime)}\n${DateHelpers.formatTime(item.dateTime)}';
                final descFormatted = item.groupName.isNotEmpty
                    ? '${item.title}\n[${item.groupName}]'
                    : item.title;
                final sign = item.isOutflow ? '-' : '+';
                return [
                  dateFormatted,
                  descFormatted,
                  item.payerName,
                  item.category.toUpperCase(),
                  '$sign Rs. ${item.amount.toStringAsFixed(2)}',
                ];
              }),
              [
                'SUMMARY',
                '${data.items.length} total transactions',
                '',
                '',
                data.scope == 'expenses'
                    ? 'Rs. ${data.totalSpent.toStringAsFixed(2)}'
                    : (data.netBalance >= 0 ? '+' : '-') + 'Rs. ${data.netBalance.abs().toStringAsFixed(2)}',
              ],
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(thickness: 0.5, color: PdfColors.grey400),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Split Pro Expense Manager • Certified Financial Activity Export',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500),
              ),
              pw.Text(
                'Confidential Document',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500),
              ),
            ],
          ),
        ];
      },
    ),
  );

  final pdfBytes = await pdf.save();
  final blob = html.Blob([pdfBytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', 'split_pro_statement_${data.scope}.pdf')
    ..click();
  html.Url.revokeObjectUrl(url);
}
