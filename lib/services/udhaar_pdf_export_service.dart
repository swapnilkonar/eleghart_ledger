import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/ledger_transaction_model.dart';
import '../models/person_model.dart';

class UdhaarPdfExportService {
  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _nowFormat = DateFormat('dd MMM yyyy, hh:mm a');

  static Future<Uint8List> _logoBytes() async =>
      (await rootBundle.load('assets/images/eleghart_logo.png'))
          .buffer
          .asUint8List();

  // ─── Export person's full ledger ─────────────────────────────────────────

  static Future<File> exportPersonLedger({
    required PersonModel person,
    required List<LedgerTransactionModel> transactions,
    DateTime? from,
    DateTime? to,
  }) async {
    final logo = await _logoBytes();
    final pdf = pw.Document();
    final filtered = transactions.where((t) {
      if (from != null && t.transactionDate.isBefore(from)) return false;
      if (to != null && t.transactionDate.isAfter(to)) return false;
      return true;
    }).toList();
    final sorted = [...filtered]
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    final toCollect = filtered
        .where((t) => t.isCollection)
        .fold(0.0, (s, t) => s + t.amount);
    final toPay = filtered
        .where((t) => t.isPayment)
        .fold(0.0, (s, t) => s + t.amount);
    final net = toCollect - toPay;

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(base: pw.Font.helvetica()),
          buildBackground: (_) => pw.Center(
            child: pw.Opacity(
              opacity: 0.08,
              child: pw.Image(pw.MemoryImage(logo), width: 320),
            ),
          ),
        ),
        build: (_) => [
          _personHeader(person, toCollect, toPay, net),
          pw.SizedBox(height: 18),
          _sectionTitle('Transactions'),
          pw.SizedBox(height: 10),
          _transactionTable(sorted),
        ],
      ),
    );

    return _savePdf(pdf, 'udhaar_${person.name.replaceAll(' ', '_')}_ledger');
  }

  // ─── Export full Udhaar summary ───────────────────────────────────────────

  static Future<File> exportFullSummary({
    required List<PersonModel> persons,
    required List<LedgerTransactionModel> transactions,
    DateTime? from,
    DateTime? to,
  }) async {
    final logo = await _logoBytes();
    final pdf = pw.Document();

    final filtered = transactions.where((t) {
      if (from != null && t.transactionDate.isBefore(from)) return false;
      if (to != null && t.transactionDate.isAfter(to)) return false;
      return true;
    }).toList();

    double grandCollect = 0, grandPay = 0;
    final rows = persons.map((p) {
      final pTx = filtered.where((t) => t.personId == p.id).toList();
      final c = pTx
          .where((t) => t.isCollection)
          .fold(0.0, (s, t) => s + t.amount);
      final pay =
          pTx.where((t) => t.isPayment).fold(0.0, (s, t) => s + t.amount);
      grandCollect += c;
      grandPay += pay;
      return (p, c, pay, c - pay);
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(base: pw.Font.helvetica()),
          buildBackground: (_) => pw.Center(
            child: pw.Opacity(
              opacity: 0.08,
              child: pw.Image(pw.MemoryImage(logo), width: 320),
            ),
          ),
        ),
        build: (_) => [
          _fullSummaryHeader(grandCollect, grandPay, grandCollect - grandPay),
          pw.SizedBox(height: 18),
          _sectionTitle('Person Ledger Summary'),
          pw.SizedBox(height: 10),
          _personsTable(rows),
        ],
      ),
    );

    return _savePdf(pdf, 'udhaar_full_summary');
  }

  // ─── Header widgets ───────────────────────────────────────────────────────

  static pw.Widget _personHeader(
    PersonModel person,
    double toCollect,
    double toPay,
    double net,
  ) {
    final netPos = net >= 0;
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(14),
        gradient: const pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: [
            PdfColor.fromInt(0xFF8B0000),
            PdfColor.fromInt(0xFFB11226),
          ],
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(person.name,
              style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white)),
          pw.SizedBox(height: 2),
          pw.Text('Eleghart Ledger Report',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.white)),
          if (person.phone != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(person.phone!,
                style:
                    const pw.TextStyle(fontSize: 11, color: PdfColors.white)),
          ],
          pw.SizedBox(height: 6),
          pw.Text('Generated: ${_nowFormat.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
          pw.SizedBox(height: 12),
          pw.Row(children: [
            pw.Text('Collection: ',
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.Text('Rs. ${toCollect.toStringAsFixed(0)}',
                style:
                    const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
            pw.SizedBox(width: 16),
            pw.Text('Payment: ',
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.Text('Rs. ${toPay.toStringAsFixed(0)}',
                style:
                    const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Text('Net Position: ',
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.Text(
              '${netPos ? '+' : '-'} Rs. ${net.abs().toStringAsFixed(0)}',
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color:
                      netPos ? PdfColors.green200 : PdfColors.red200),
            ),
          ]),
        ],
      ),
    );
  }

  static pw.Widget _fullSummaryHeader(
      double grandCollect, double grandPay, double net) {
    final netPos = net >= 0;
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(14),
        gradient: const pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: [
            PdfColor.fromInt(0xFF8B0000),
            PdfColor.fromInt(0xFFB11226),
          ],
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Eleghart Ledger Report',
              style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white)),
          pw.SizedBox(height: 6),
          pw.Text('Udhaar - Full Summary',
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.white)),
          pw.SizedBox(height: 6),
          pw.Text('Generated: ${_nowFormat.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
          pw.SizedBox(height: 12),
          pw.Row(children: [
            pw.Text('Collection: ',
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.Text('Rs. ${grandCollect.toStringAsFixed(0)}',
                style:
                    const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
            pw.SizedBox(width: 16),
            pw.Text('Payment: ',
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.Text('Rs. ${grandPay.toStringAsFixed(0)}',
                style:
                    const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Text('Net Balance: ',
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.Text(
              '${netPos ? '+' : '-'} Rs. ${net.abs().toStringAsFixed(0)}',
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: netPos ? PdfColors.green200 : PdfColors.red200),
            ),
          ]),
        ],
      ),
    );
  }

  // ─── Section title (matches expense PDF style) ────────────────────────────

  static pw.Widget _sectionTitle(String title) => pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 15,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(0xFF8B0000),
        ),
      );

  // ─── Tables ───────────────────────────────────────────────────────────────

  static pw.Widget _transactionTable(List<LedgerTransactionModel> txs) {
    if (txs.isEmpty) {
      return pw.Text('No transactions recorded.',
          style: const pw.TextStyle(color: PdfColors.grey600));
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.3),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(2.5),
      },
      children: [
        _tableRow(['Date', 'Type', 'Amount', 'Description'], isHeader: true),
        ...txs.map((t) {
          final isCol = t.isCollection;
          return _tableRow([
            _dateFormat.format(t.transactionDate),
            isCol ? 'Collection' : 'Payment',
            '${isCol ? '+' : '-'} Rs. ${t.amount.toStringAsFixed(0)}',
            t.description,
          ]);
        }),
      ],
    );
  }

  static pw.Widget _personsTable(
      List<(PersonModel, double, double, double)> rows) {
    if (rows.isEmpty) {
      return pw.Text('No persons recorded.',
          style: const pw.TextStyle(color: PdfColors.grey600));
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: [
        _tableRow(['Name', 'Collection', 'Payment', 'Net'], isHeader: true),
        ...rows.map((r) {
          final net = r.$4;
          return _tableRow([
            r.$1.name,
            'Rs. ${r.$2.toStringAsFixed(0)}',
            'Rs. ${r.$3.toStringAsFixed(0)}',
            '${net >= 0 ? '+' : '-'} Rs. ${net.abs().toStringAsFixed(0)}',
          ]);
        }),
      ],
    );
  }

  // ─── Shared table row helper (identical to PdfExportService) ─────────────

  static pw.TableRow _tableRow(List<String> cells, {bool isHeader = false}) =>
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: isHeader ? PdfColors.grey200 : null,
        ),
        children: cells
            .map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    c,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: isHeader
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                ))
            .toList(),
      );

  // ─── Save & open ─────────────────────────────────────────────────────────

  static Future<File> _savePdf(pw.Document pdf, String name) async {
    Directory dir;
    if (Platform.isAndroid) {
      dir = (await getExternalStorageDirectory())!;
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    final file = File(
        '${dir.path}/Eleghart_${name}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
