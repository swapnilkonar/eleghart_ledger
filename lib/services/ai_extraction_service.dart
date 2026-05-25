import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:uuid/uuid.dart';

import '../screens/extracted_expenses_screen.dart';

class AIExtractionService {
  // ─── Main entry: on-device OCR, no API key needed ─────────────────────────

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
      return _ReceiptParser.parse(result.text);
    } finally {
      recognizer.close();
    }
  }

  static Future<List<ExtractedItem>> extractFromPdf({
    required File pdfFile,
  }) async {
    throw UnsupportedError(
        'PDF text extraction is not supported on-device. Please take a photo of the document and upload as an image.');
  }
}

// ─── Smart receipt parser ──────────────────────────────────────────────────

class _ReceiptParser {
  static final _amountRe =
      RegExp(r'(?:Rs\.?|₹|INR|USD|\$)?\s*(\d{1,6}(?:,\d{3})*(?:\.\d{1,2})?)',
          caseSensitive: false);
  static final _dateRe = RegExp(
      r'\b(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})\b'
      r'|\b(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})\b');
  static final _totalRe =
      RegExp(r'(total|grand\s*total|amount\s*due|net\s*amount|subtotal)',
          caseSensitive: false);
  static final _skipLineRe =
      RegExp(r'^(gst|cgst|sgst|igst|tax|vat|discount|savings|you\s*saved)',
          caseSensitive: false);

  static List<ExtractedItem> parse(String raw) {
    final lines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final merchant = _merchantName(lines);
    final date = _extractDate(raw);
    final category = _inferCategory(merchant, raw);
    final lineItems = _extractLineItems(lines, date);

    if (lineItems.isNotEmpty) return lineItems;

    // Fallback: single item with best total amount
    final total = _bestTotal(raw, lines);
    return [
      ExtractedItem(
        id: const Uuid().v4(),
        description: merchant,
        amount: total,
        category: category,
        date: date,
      ),
    ];
  }

  // ── Merchant name: first non-numeric, non-short line ──
  static String _merchantName(List<String> lines) {
    for (final line in lines.take(6)) {
      if (line.length >= 3 &&
          !RegExp(r'^\d').hasMatch(line) &&
          !_skipLineRe.hasMatch(line)) {
        return _clean(line);
      }
    }
    return 'Expense';
  }

  // ── Date extraction ──
  static DateTime _extractDate(String text) {
    final m = _dateRe.firstMatch(text);
    if (m == null) return DateTime.now();
    try {
      // Format: DD/MM/YYYY or MM/DD/YYYY
      if (m.group(1) != null) {
        final d = int.parse(m.group(1)!);
        final mo = int.parse(m.group(2)!);
        var yr = int.parse(m.group(3)!);
        if (yr < 100) yr += 2000;
        // Prefer DD/MM
        if (mo <= 12 && d <= 31) return DateTime(yr, mo, d);
      }
      // Format: YYYY/MM/DD
      if (m.group(4) != null) {
        return DateTime(int.parse(m.group(4)!), int.parse(m.group(5)!),
            int.parse(m.group(6)!));
      }
    } catch (_) {}
    return DateTime.now();
  }

  // ── Best total amount (prefer line with "total", else largest amount) ──
  static double _bestTotal(String raw, List<String> lines) {
    // Try "total" line first
    for (final line in lines) {
      if (_totalRe.hasMatch(line)) {
        final amt = _amountsIn(line);
        if (amt.isNotEmpty) return amt.last;
      }
    }
    // Fall back to largest amount in entire text
    final all = _amountsIn(raw);
    if (all.isEmpty) return 0;
    all.sort();
    return all.last;
  }

  // ── Line items: rows that have a description + price ──
  static List<ExtractedItem> _extractLineItems(
      List<String> lines, DateTime date) {
    final items = <ExtractedItem>[];
    for (final line in lines) {
      if (_skipLineRe.hasMatch(line)) continue;
      if (_totalRe.hasMatch(line)) continue;
      final amounts = _amountsIn(line);
      if (amounts.isEmpty) continue;
      // Must have some text besides the number
      final desc = line
          .replaceAll(_amountRe, '')
          .replaceAll(RegExp(r'[₹\$\|:,]'), ' ')
          .trim();
      if (desc.length < 3) continue;
      final amount = amounts.last;
      if (amount <= 0 || amount > 1000000) continue;
      items.add(ExtractedItem(
        id: const Uuid().v4(),
        description: _clean(desc),
        amount: amount,
        category: _inferCategory(desc, line),
        date: date,
      ));
    }
    // If too many items (likely noise), fall back to single total
    if (items.length > 10) return [];
    return items;
  }

  static List<double> _amountsIn(String text) {
    return _amountRe
        .allMatches(text)
        .map((m) => double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0.0)
        .where((v) => v > 0)
        .toList();
  }

  static String _clean(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim();

  // ── Category inference from keywords ──
  static String _inferCategory(String desc, String context) {
    final t = '${desc.toLowerCase()} ${context.toLowerCase()}';
    if (_matches(t, ['restaurant', 'cafe', 'coffee', 'food', 'pizza', 'burger',
          'zomato', 'swiggy', 'blinkit', 'chai', 'dhaba', 'kitchen', 'bakery',
          'hotel', 'meal', 'lunch', 'dinner', 'breakfast', 'snack', 'eat'])) {
      return 'Food & Dining';
    }
    if (_matches(t, ['uber', 'ola', 'rapido', 'taxi', 'cab', 'auto', 'bus',
          'train', 'flight', 'airline', 'irctc', 'metro', 'fuel', 'petrol',
          'diesel', 'toll', 'travel', 'transport'])) {
      return 'Travel';
    }
    if (_matches(t, ['petrol', 'diesel', 'cng', 'fuel', 'hp', 'bpcl', 'iocl',
          'pump', 'gas station'])) {
      return 'Fuel';
    }
    if (_matches(t, ['amazon', 'flipkart', 'myntra', 'ajio', 'store', 'mall',
          'shop', 'mart', 'market', 'buy', 'purchase', 'retail', 'reliance',
          'dmart', 'big bazaar', 'jiomart'])) {
      return 'Shopping';
    }
    if (_matches(t, ['electricity', 'bill', 'water', 'gas', 'internet',
          'broadband', 'airtel', 'jio', 'vi', 'bsnl', 'recharge', 'topup',
          'utility', 'postpaid', 'prepaid', 'insurance', 'emi', 'loan'])) {
      return 'Bills & Utilities';
    }
    if (_matches(t, ['hospital', 'clinic', 'doctor', 'pharmacy', 'medicine',
          'medical', 'health', 'lab', 'apollo', 'diagnostic', 'test'])) {
      return 'Health';
    }
    if (_matches(t, ['movie', 'cinema', 'pvr', 'inox', 'bookmyshow', 'netflix',
          'spotify', 'game', 'concert', 'event', 'entertainment', 'park',
          'ticket'])) {
      return 'Entertainment';
    }
    return 'Others';
  }

  static bool _matches(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));
}
