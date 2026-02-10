// PdfExportService — Ledger-aware PDF (Debit/Credit + Net Balance)
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/group_model.dart';
import '../models/expense_model.dart';

// ---- Top-level function for compute() isolate ----
Future<Uint8List> _generatePdfBytes(Map<String, dynamic> args) async {
  final logoBytes = args['logoBytes'] as Uint8List;
  final groupName = args['groupName'] as String;
  final expenses = (args['expenses'] as List).cast<ExpenseModel>();
  final from = args['from'] as DateTime;
  final to = args['to'] as DateTime;

  final pdf = pw.Document();

  // ---- Filter by date range ----
  final filtered = expenses.where((e) {
    return !e.date.isBefore(from) && !e.date.isAfter(to);
  }).toList();

  // ---- Totals ----
  double totalDebit = 0;
  double totalCredit = 0;

  for (final e in filtered) {
    if (e.type == 'credit') {
      totalCredit += e.amount;
    } else {
      totalDebit += e.amount;
    }
  }

  final netBalance = totalCredit - totalDebit;

  // ---- Member totals (ledger-aware) ----
  final Map<String, double> memberTotals = {};

  for (final e in filtered) {
    final share = e.amount / e.categories.length;
    for (final m in e.categories) {
      final signedShare = e.type == 'credit' ? share : -share;
      memberTotals[m] = (memberTotals[m] ?? 0) + signedShare;
    }
  }

  // ---- Sort expenses by date ----
  filtered.sort((a, b) => a.date.compareTo(b.date));

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
        ),
        buildBackground: (context) => pw.Center(
          child: pw.Opacity(
            opacity: 0.08,
            child: pw.Image(
              pw.MemoryImage(logoBytes),
              width: 320,
            ),
          ),
        ),
      ),
      build: (context) => [
        PdfExportService._header(
          groupName,
          from,
          to,
          totalDebit,
          totalCredit,
          netBalance,
        ),
        pw.SizedBox(height: 18),

        ...PdfExportService._memberSummaryTable(memberTotals),
        pw.SizedBox(height: 22),

        ...PdfExportService._expensesTable(filtered),
      ],
    ),
  );

  return pdf.save();
}

class PdfExportService {
  static Future<File> exportGroupReport({
    required GroupModel group,
    required List<ExpenseModel> expenses,
    required DateTime from,
    required DateTime to,
  }) async {
    // ---- Load watermark logo (main thread — needs Flutter engine) ----
    final Uint8List logoBytes =
        (await rootBundle.load('assets/images/eleghart_logo.png'))
            .buffer
            .asUint8List();

    // ---- Generate PDF bytes in background isolate ----
    final Uint8List pdfBytes = await compute(_generatePdfBytes, {
      'logoBytes': logoBytes,
      'groupName': group.name,
      'expenses': expenses,
      'from': from,
      'to': to,
    });

    // ---- Save file (Android + iOS safe) ----
    Directory dir;
    if (Platform.isAndroid) {
      dir = (await getExternalStorageDirectory())!;
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    final file = File(
      '${dir.path}/Eleghart_${group.name}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );

    await file.writeAsBytes(pdfBytes);

    return file;
  }

  // ---------------- HEADER ----------------

  static pw.Widget _header(
    String groupName,
    DateTime from,
    DateTime to,
    double totalDebit,
    double totalCredit,
    double netBalance,
  ) {
    final netIsPositive = netBalance >= 0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(14),

        // Eleghart reddish gradient
        gradient: const pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: [
            PdfColor.fromInt(0xFF8B0000), // deep red
            PdfColor.fromInt(0xFFB11226), // eleghart red
          ],
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Eleghart Ledger Report',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            groupName,
            style: const pw.TextStyle(
              fontSize: 14,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'From ${DateFormat('dd MMM yyyy').format(from)}  to  ${DateFormat('dd MMM yyyy').format(to)}',
            style: const pw.TextStyle(
              fontSize: 11,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 12),

          // ---- Totals ----
          pw.Row(children: [
            pw.Text('Total Debit: ',
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.Text('Rs. ${totalDebit.toStringAsFixed(0)}',
                style: const pw.TextStyle(
                    fontSize: 12, color: PdfColors.white)),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Text('Total Credit: ',
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.Text('Rs. ${totalCredit.toStringAsFixed(0)}',
                style: const pw.TextStyle(
                    fontSize: 12, color: PdfColors.white)),
          ]),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Text('Net Balance: ',
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.Text(
              '${netIsPositive ? '+' : '-'} Rs. ${netBalance.abs().toStringAsFixed(0)}',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: netIsPositive ? PdfColors.green200 : PdfColors.red200,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ---------------- MEMBER TABLE ----------------

  static List<pw.Widget> _memberSummaryTable(Map<String, double> totals) {
    return [
      pw.Text(
        'Member Summary (Net)',
        style: pw.TextStyle(
          fontSize: 15,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(0xFF8B0000),
        ),
      ),
      pw.SizedBox(height: 10),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        children: [
          _tableRow(['Member', 'Net Amount'], isHeader: true),
          ...totals.entries.map((e) {
            final isPositive = e.value >= 0;
            final sign = isPositive ? '+' : '-';
            return _tableRow([
              e.key,
              '$sign Rs. ${e.value.abs().toStringAsFixed(0)}',
            ]);
          }),
        ],
      ),
    ];
  }

  // ---------------- EXPENSE TABLE ----------------

  static List<pw.Widget> _expensesTable(List<ExpenseModel> expenses) {
    return [
      pw.Text(
        'Transactions',
        style: pw.TextStyle(
          fontSize: 15,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(0xFF8B0000),
        ),
      ),
      pw.SizedBox(height: 10),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.2),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(2.5),
          3: const pw.FlexColumnWidth(2.5),
          4: const pw.FlexColumnWidth(1.4),
        },
        children: [
          _tableRow(
            ['Date', 'Type', 'Description', 'Members', 'Amount'],
            isHeader: true,
          ),
          ...expenses.map((e) {
            final isCredit = e.type == 'credit';
            final sign = isCredit ? '+' : '-';

            return _tableRow([
              DateFormat('dd MMM yyyy').format(e.date),
              e.type.toUpperCase(),
              e.description.isEmpty ? 'Expense' : e.description,
              e.categories.join(', '),
              '$sign Rs. ${e.amount.toStringAsFixed(0)}',
            ]);
          }),
        ],
      ),
    ];
  }

  // ---------------- TABLE ROW ----------------

  static pw.TableRow _tableRow(
    List<String> cells, {
    bool isHeader = false,
  }) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: isHeader ? PdfColors.grey200 : null,
      ),
      children: cells
          .map(
            (c) => pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                c,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight:
                      isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
