import 'dart:io';

import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';

import '../screens/extracted_expenses_screen.dart';

class AIExtractionService {
  // ─── Image: ML Kit OCR → entity extraction → smart parser ─────────────────

  static Future<List<ExtractedItem>> extractFromImage({
    required File imageFile,
  }) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final result = await recognizer.processImage(inputImage);
      if (result.text.trim().isEmpty) {
        throw Exception('No text found in image. Try a clearer photo.');
      }
      return await _SmartParser.parse(result.text);
    } finally {
      recognizer.close();
    }
  }

  static Future<List<ExtractedItem>> extractFromPdf({
    required File pdfFile,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final allText = StringBuffer();

    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(pdfFile.path);
      final pageCount = document.pagesCount;
      // Process up to 10 pages to keep it fast
      final pagesToProcess = pageCount.clamp(1, 10);

      for (int i = 1; i <= pagesToProcess; i++) {
        PdfPage? page;
        PdfPageImage? pageImage;
        File? tempFile;
        TextRecognizer? recognizer;
        try {
          page = await document.getPage(i);
          // Render at 2x scale for better OCR accuracy
          pageImage = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
          );
          if (pageImage?.bytes == null) continue;

          tempFile = File('${tempDir.path}/ocr_pdf_page_$i.jpg');
          await tempFile.writeAsBytes(pageImage!.bytes);

          recognizer =
              TextRecognizer(script: TextRecognitionScript.latin);
          final inputImage = InputImage.fromFile(tempFile);
          final result = await recognizer.processImage(inputImage);
          if (result.text.isNotEmpty) {
            allText.writeln(result.text);
          }
        } catch (_) {
          // Skip unreadable pages silently
        } finally {
          recognizer?.close();
          await page?.close();
          try { await tempFile?.delete(); } catch (_) {}
        }
      }
    } finally {
      await document?.close();
    }

    final text = allText.toString().trim();
    if (text.isEmpty) {
      throw Exception(
          'No text found in this PDF. Make sure it is a receipt or statement with readable content.');
    }
    return await _SmartParser.parse(text);
  }
}

// ─── SmartParser: ML Kit Entity Extraction + improved heuristics ──────────
//
//  Pipeline:
//  1. ML Kit EntityExtractor detects money/date entities from raw OCR text
//     (on-device neural net, no API key)
//  2. Fallback to regex for amounts/dates if model not downloaded yet
//  3. Improved structural heuristics for merchant name, line items, categories

class _SmartParser {
  static Future<List<ExtractedItem>> parse(String raw) async {
    // ── Step 1: ML Kit entity extraction (async, on-device AI) ──────────────
    final mlAmounts = <double>[];
    DateTime? mlDate;

    EntityExtractor? extractor;
    try {
      extractor = EntityExtractor(
          language: EntityExtractorLanguage.english);
      final annotations = await extractor.annotateText(
        raw,
        entityTypesFilter: [
          EntityType.money,
          EntityType.dateTime,
        ],
      );

      for (final ann in annotations) {
        for (final entity in ann.entities) {
          if (entity is MoneyEntity) {
            final units = entity.integerPart.toDouble() +
                entity.fractionPart / 100.0;
            if (units > 0) mlAmounts.add(units);
          }
          if (entity is DateTimeEntity && mlDate == null) {
            try {
              // timestamp is milliseconds since epoch
              mlDate = DateTime.fromMillisecondsSinceEpoch(
                  entity.timestamp);
              if (mlDate.year < 2000 || mlDate.year > 2100) {
                mlDate = null;
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {
      // Model may not be downloaded yet — regex fallback handles it
    } finally {
      extractor?.close();
    }

    // ── Step 2: Structural receipt parsing ──────────────────────────────────
    final lines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final merchant = _merchantName(lines);
    final date = mlDate ?? _extractDateRegex(raw);
    final lineItems = _extractLineItems(lines, date);

    if (lineItems.isNotEmpty) return lineItems;

    // Fallback: single item — prefer ML Kit total, then regex total
    final total = _bestTotal(mlAmounts, raw, lines);
    return [
      ExtractedItem(
        id: const Uuid().v4(),
        description: merchant,
        amount: total,
        category: _inferCategory(merchant, raw),
        date: date,
      ),
    ];
  }

  // ── Merchant name ──────────────────────────────────────────────────────────
  // Prefers ALL-CAPS lines (store names), skips noise lines
  static String _merchantName(List<String> lines) {
    final noiseRe = RegExp(
        r'^(gst|cgst|sgst|igst|tax|vat|phone|tel|mobile|address|gstin|'
        r'invoice|bill|receipt|order|date|time|cashier|counter|table|'
        r'thank|visit|www\.|http|customer|#|no\.|sr\.)',
        caseSensitive: false);
    // Prefer ALL-CAPS short-to-medium lines (brand names)
    for (final line in lines.take(8)) {
      if (line.length >= 3 &&
          line.length <= 40 &&
          line == line.toUpperCase() &&
          RegExp(r'[A-Z]').hasMatch(line) &&
          !RegExp(r'^\d').hasMatch(line) &&
          !noiseRe.hasMatch(line)) {
        return _clean(line);
      }
    }
    // Fall back to first meaningful line
    for (final line in lines.take(8)) {
      if (line.length >= 3 &&
          !RegExp(r'^\d').hasMatch(line) &&
          !noiseRe.hasMatch(line)) {
        return _clean(line);
      }
    }
    return 'Expense';
  }

  // ── Date via regex (fallback if ML Kit model not ready) ────────────────────
  static final _dateNamedRe = RegExp(
      r'\b(\d{1,2})[- ]?(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[- ]?(\d{2,4})\b'
      r'|\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[- ]?(\d{1,2})[,- ]?(\d{2,4})\b',
      caseSensitive: false);
  static final _dateNumRe = RegExp(
      r'\b(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})\b'
      r'|\b(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})\b');
  static const _monthMap = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static DateTime _extractDateRegex(String text) {
    // Try named month first (most unambiguous)
    final mn = _dateNamedRe.firstMatch(text);
    if (mn != null) {
      try {
        if (mn.group(1) != null) {
          final d = int.parse(mn.group(1)!);
          final mo = _monthMap[mn.group(2)!.toLowerCase()] ?? 1;
          var yr = int.parse(mn.group(3)!);
          if (yr < 100) yr += 2000;
          return DateTime(yr, mo, d);
        } else {
          final mo = _monthMap[mn.group(4)!.toLowerCase()] ?? 1;
          final d = int.parse(mn.group(5)!);
          var yr = int.parse(mn.group(6)!);
          if (yr < 100) yr += 2000;
          return DateTime(yr, mo, d);
        }
      } catch (_) {}
    }
    // Fall back to numeric date
    final m = _dateNumRe.firstMatch(text);
    if (m == null) return DateTime.now();
    try {
      if (m.group(1) != null) {
        final a = int.parse(m.group(1)!);
        final b = int.parse(m.group(2)!);
        var yr = int.parse(m.group(3)!);
        if (yr < 100) yr += 2000;
        // Indian receipts: DD/MM/YYYY
        if (a <= 31 && b <= 12) return DateTime(yr, b, a);
        if (a <= 12 && b <= 31) return DateTime(yr, a, b);
      }
      if (m.group(4) != null) {
        return DateTime(int.parse(m.group(4)!), int.parse(m.group(5)!),
            int.parse(m.group(6)!));
      }
    } catch (_) {}
    return DateTime.now();
  }

  // ── Amount regex (handles Indian format 1,00,000 and plain decimals) ───────
  static final _amountRe = RegExp(
      r'(?:Rs\.?\s*|₹\s*|INR\s*)?(\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?|\d{1,6}(?:\.\d{1,2})?)',
      caseSensitive: false);

  static List<double> _amountsIn(String text) => _amountRe
      .allMatches(text)
      .map((m) => double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0.0)
      .where((v) => v > 0.5 && v < 10000000)
      .toList();

  // ── Best total: prefer ML Kit money entities → "total" line → largest ──────
  static final _totalRe = RegExp(
      r'(total|grand\s*total|amount\s*(?:due|payable|paid)|net\s*(?:amount|payable)|'
      r'sub\s*total|subtotal|bill\s*amount|to\s*pay|payable|charged|debit|dr\.?\b)',
      caseSensitive: false);

  static double _bestTotal(
      List<double> mlAmounts, String raw, List<String> lines) {
    // From ML Kit entities: largest money amount (usually the total)
    if (mlAmounts.isNotEmpty) {
      final sorted = List<double>.from(mlAmounts)..sort();
      return sorted.last;
    }
    // Total-keyword line
    for (final line in lines.reversed) {
      if (_totalRe.hasMatch(line)) {
        final amts = _amountsIn(line);
        if (amts.isNotEmpty) return amts.last;
      }
    }
    // Largest amount in whole text
    final all = _amountsIn(raw);
    if (all.isEmpty) return 0;
    all.sort();
    return all.last;
  }

  // ── Line items ─────────────────────────────────────────────────────────────
  static final _skipRe = RegExp(
      r'^(gst|cgst|sgst|igst|tax|vat|discount|saving|you\s*saved|'
      r'round\s*off|rounded|tips?|service\s*charge|sc\b|delivery)',
      caseSensitive: false);

  static List<ExtractedItem> _extractLineItems(
      List<String> lines, DateTime date) {
    final items = <ExtractedItem>[];
    for (final line in lines) {
      if (_skipRe.hasMatch(line)) continue;
      if (_totalRe.hasMatch(line)) continue;
      final amounts = _amountsIn(line);
      if (amounts.isEmpty) continue;
      // Remove the number(s) to get description
      final desc = line
          .replaceAll(_amountRe, '')
          .replaceAll(RegExp(r'[₹\$\|×x*:,\\/]'), ' ')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
      if (desc.length < 3) continue;
      final amount = amounts.last;
      if (amount <= 0 || amount > 500000) continue;
      items.add(ExtractedItem(
        id: const Uuid().v4(),
        description: _clean(desc),
        amount: amount,
        category: _inferCategory(desc, line),
        date: date,
      ));
    }
    // If >12 items it's likely noise — return empty and fall back to total
    if (items.length > 12) return [];
    return items;
  }

  static String _clean(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim();

  // ── Category inference ─────────────────────────────────────────────────────
  static String _inferCategory(String desc, String context) {
    final t = '${desc.toLowerCase()} ${context.toLowerCase()}';
    if (_has(t, ['restaurant', 'cafe', 'coffee', 'food', 'pizza', 'burger',
          'zomato', 'swiggy', 'blinkit', 'chai', 'dhaba', 'kitchen',
          'bakery', 'hotel', 'meal', 'lunch', 'dinner', 'breakfast',
          'snack', 'eat', 'drink', 'juice', 'biryani', 'chicken', 'rice',
          'paneer', 'dosa', 'idli', 'paratha', 'noodle', 'pasta',
          'pizza', 'subway', 'kfc', 'mcdonalds', 'dominos', 'haldirams'])) {
      return 'Food & Dining';
    }
    if (_has(t, ['uber', 'ola', 'rapido', 'taxi', 'cab', 'auto', 'bus',
          'train', 'flight', 'airline', 'irctc', 'metro', 'toll',
          'travel', 'transport', 'booking', 'goibibo', 'makemytrip',
          'redbus', 'ticket', 'pass', 'railway', 'airport'])) {
      return 'Travel';
    }
    if (_has(t, ['petrol', 'diesel', 'cng', 'fuel', 'hpcl', 'bpcl', 'iocl',
          'pump', 'filling', 'gas station', 'essar'])) {
      return 'Fuel';
    }
    if (_has(t, ['amazon', 'flipkart', 'myntra', 'ajio', 'store', 'mall',
          'shop', 'mart', 'market', 'retail', 'reliance', 'dmart',
          'big bazaar', 'jiomart', 'meesho', 'nykaa', 'lifestyle',
          'westside', 'zara', 'h&m', 'max', 'pantaloons', 'centrepoint',
          'croma', 'vijay sales', 'samsung', 'apple', 'laptop', 'phone',
          'watch', 'shoes', 'cloth', 'dress', 'shirt', 'pant'])) {
      return 'Shopping';
    }
    if (_has(t, ['electricity', 'bill', 'water', 'gas', 'internet',
          'broadband', 'airtel', 'jio', 'vodafone', 'bsnl', 'recharge',
          'topup', 'utility', 'postpaid', 'prepaid', 'insurance',
          'emi', 'loan', 'rent', 'maintenance', 'society', 'cable',
          'wifi', 'tata sky', 'dish tv', 'd2h', 'ott', 'netflix',
          'hotstar', 'spotify', 'prime'])) {
      return 'Bills & Utilities';
    }
    if (_has(t, ['hospital', 'clinic', 'doctor', 'pharmacy', 'medicine',
          'medical', 'health', 'lab', 'apollo', 'diagnostic', 'test',
          'pathology', 'scan', 'mri', 'xray', 'dental', 'eye', 'optician',
          'chemist', 'drug', 'tablet', 'syrup', 'injection', 'medplus',
          'netmeds', '1mg', 'pharmeasy'])) {
      return 'Health';
    }
    if (_has(t, ['movie', 'cinema', 'pvr', 'inox', 'bookmyshow', 'concert',
          'event', 'entertainment', 'park', 'amusement', 'game', 'gaming',
          'arcade', 'bowling', 'escape room', 'sport', 'gym', 'fitness',
          'swimming', 'spa', 'salon', 'massage'])) {
      return 'Entertainment';
    }
    return 'Others';
  }

  static bool _has(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));
}
