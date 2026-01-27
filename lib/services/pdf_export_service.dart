import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/group_model.dart';
import '../models/expense_model.dart';

class PdfExportService {
  static Future<File> exportGroupReport({
    required GroupModel group,
    required List<ExpenseModel> expenses,
    required DateTime from,
    required DateTime to,
  }) async {
    final pdf = pw.Document();

    // ---- Load watermark logo ----
    final Uint8List logoBytes =
        (await rootBundle.load('assets/images/eleghart_logo.png'))
            .buffer
            .asUint8List();

    // ---- Filter by date range ----
    final filtered = expenses.where((e) {
      return !e.date.isBefore(from) && !e.date.isAfter(to);
    }).toList();

    // ---- Member totals ----
    final Map<String, double> memberTotals = {};

    for (final e in filtered) {
      final share = e.amount / e.categories.length;
      for (final m in e.categories) {
        memberTotals[m] = (memberTotals[m] ?? 0) + share;
      }
    }

    final totalSpent =
        filtered.fold<double>(0, (sum, e) => sum + e.amount);

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
          _header(group.name, from, to, totalSpent),
          pw.SizedBox(height: 18),

          _memberSummaryTable(memberTotals),
          pw.SizedBox(height: 22),

          _expensesTable(filtered),
        ],
      ),
    );

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

    await file.writeAsBytes(await pdf.save());

    return file;
  }

  // ---------------- HEADER ----------------

  static pw.Widget _header(
    String groupName,
    DateTime from,
    DateTime to,
    double totalSpent,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(14),

        // 👇 Eleghart reddish gradient
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
            'Eleghart Expense Report',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            groupName,
            style: pw.TextStyle(
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
          pw.SizedBox(height: 10),
          pw.Text(
            'Total Spent: Rs. ${totalSpent.toStringAsFixed(0)}',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- MEMBER TABLE ----------------

  static pw.Widget _memberSummaryTable(Map<String, double> totals) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Member Summary',
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
            _tableRow(['Member', 'Amount'], isHeader: true),
            ...totals.entries.map(
              (e) => _tableRow(
                [e.key, 'Rs. ${e.value.toStringAsFixed(0)}'],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------- EXPENSE TABLE ----------------

  static pw.Widget _expensesTable(List<ExpenseModel> expenses) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Expenses',
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
            _tableRow(
              ['Date', 'Description', 'Members', 'Amount'],
              isHeader: true,
            ),
            ...expenses.map(
              (e) => _tableRow([
                DateFormat('dd MMM yyyy').format(e.date),
                e.description.isEmpty ? 'Expense' : e.description,
                e.categories.join(', '),
                'Rs. ${e.amount.toStringAsFixed(0)}',
              ]),
            ),
          ],
        ),
      ],
    );
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
