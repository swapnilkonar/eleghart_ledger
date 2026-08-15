import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense_model.dart';
import '../models/group_model.dart';
import '../models/person_model.dart';
import '../models/ledger_transaction_model.dart';
import '../models/emi_model.dart';
import '../models/recurring_expense_model.dart';
import '../models/wealth_models.dart';
import '../utils/date_filter.dart';

class GeminiAiService {
  static const String _prefApiKey = 'ai_cfo_api_key';

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefApiKey) ?? prefs.getString('gemini_api_key');
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiKey, key.trim());
  }

  /// Build comprehensive system context prompt with all app financial data
  static String buildSystemContext({
    required List<ExpenseModel> expenses,
    required List<GroupModel> groups,
    List<PersonModel>? udhaarPersons,
    List<LedgerTransactionModel>? udhaarTxns,
    List<EmiModel>? emis,
    List<RecurringExpenseModel>? recurrings,
    List<WealthGoal>? wealthGoals,
  }) {
    final buffer = StringBuffer();
    final now = DateTime.now();

    buffer.writeln("You are Eleghart AI, an elite personal Chief Financial Officer (CFO) and wealth management expert built into the Eleghart Ledger mobile application.");
    buffer.writeln("Analyze the user's financial ledger below and deliver concise, intelligent, actionable, and encouraging insights.");
    buffer.writeln("Rules:");
    buffer.writeln("1. Format currency as ₹ (Indian Rupees).");
    buffer.writeln("2. Be direct, clear, and professional yet friendly.");
    buffer.writeln("3. Highlight overspending, savings opportunities, and progress toward wealth goals.");
    buffer.writeln("4. Keep responses succinct (2-4 bullet points or short paragraphs).");
    buffer.writeln("");
    buffer.writeln("=== CURRENT USER FINANCIAL LEDGER CONTEXT ===");
    buffer.writeln("Current Date: ${now.toIso8601String().split('T')[0]}");
    buffer.writeln("Active Date Filter: ${DateFilter.label}");
    buffer.writeln("");

    // 1. Expense Metrics
    final filteredExpenses = expenses.where((e) => DateFilter.isInRange(e.date)).toList();
    double totalDebit = 0;
    double totalCredit = 0;
    final categoryTotals = <String, double>{};

    for (final e in filteredExpenses) {
      if (e.isCredit) {
        totalCredit += e.amount;
      } else {
        totalDebit += e.amount;
        for (final cat in e.validCategories) {
          categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.shareForCategory(cat);
        }
      }
    }

    final netBalance = totalCredit - totalDebit;

    buffer.writeln("SUMMARY METRICS (${DateFilter.label}):");
    buffer.writeln("- Total Income (Credit): ₹${totalCredit.toStringAsFixed(0)}");
    buffer.writeln("- Total Spent (Debit): ₹${totalDebit.toStringAsFixed(0)}");
    buffer.writeln("- Net Position: ₹${netBalance.toStringAsFixed(0)}");
    buffer.writeln("- Total Transactions Count: ${filteredExpenses.length}");
    buffer.writeln("");

    // Top Categories
    if (categoryTotals.isNotEmpty) {
      final sortedCats = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      buffer.writeln("TOP SPENDING CATEGORIES:");
      for (final entry in sortedCats.take(5)) {
        final pct = totalDebit > 0 ? (entry.value / totalDebit * 100).toStringAsFixed(1) : '0';
        buffer.writeln("  • ${entry.key}: ₹${entry.value.toStringAsFixed(0)} ($pct%)");
      }
      buffer.writeln("");
    }

    // Recent Expenses
    if (filteredExpenses.isNotEmpty) {
      buffer.writeln("RECENT TRANSACTIONS:");
      for (final e in filteredExpenses.take(8)) {
        buffer.writeln("  • ${e.date.toString().split(' ')[0]} - ${e.description.isEmpty ? 'Expense' : e.description}: ${e.isCredit ? '+' : '-'}₹${e.amount.toStringAsFixed(0)} [${e.categories.join(', ')}]");
      }
      buffer.writeln("");
    }

    // 2. Financial Groups
    if (groups.isNotEmpty) {
      buffer.writeln("FINANCIAL GROUPS (${groups.length}):");
      for (final g in groups) {
        final grpExpenses = filteredExpenses.where((e) => e.groupId == g.id).toList();
        final grpTotal = grpExpenses.fold(0.0, (sum, item) => sum + (item.isDebit ? item.amount : 0));
        buffer.writeln("  • Group '${g.name}': ₹${grpTotal.toStringAsFixed(0)} (${grpExpenses.length} txns)");
      }
      buffer.writeln("");
    }

    // 3. Udhaar Ledger (Lend & Borrow)
    if (udhaarPersons != null && udhaarPersons.isNotEmpty && udhaarTxns != null) {
      double totalCollect = 0;
      double totalPay = 0;
      final personBalances = <String, double>{};
      for (final t in udhaarTxns) {
        final sign = t.isCollection ? 1.0 : -1.0;
        personBalances[t.personId] = (personBalances[t.personId] ?? 0) + sign * t.amount;
      }
      for (final bal in personBalances.values) {
        if (bal > 0) totalCollect += bal;
        if (bal < 0) totalPay += bal.abs();
      }

      buffer.writeln("UDHAAR LEDGER (Lend & Borrow):");
      buffer.writeln("  • Total to Collect (Lent out): ₹${totalCollect.toStringAsFixed(0)}");
      buffer.writeln("  • Total to Pay (Borrowed): ₹${totalPay.toStringAsFixed(0)}");
      buffer.writeln("");
    }

    // 4. EMIs & Recurring
    if (emis != null && emis.isNotEmpty) {
      final activeEmis = emis.where((e) => !e.isCompleted).toList();
      if (activeEmis.isNotEmpty) {
        final totalEmiMonthly = activeEmis.fold(0.0, (sum, e) => sum + e.amount);
        buffer.writeln("ACTIVE EMIS (${activeEmis.length}): Total monthly obligation ₹${totalEmiMonthly.toStringAsFixed(0)}");
      }
    }

    if (recurrings != null && recurrings.isNotEmpty) {
      final activeRec = recurrings.where((r) => r.isActive).toList();
      if (activeRec.isNotEmpty) {
        buffer.writeln("RECURRING SUBSCRIPTIONS (${activeRec.length}):");
        for (final r in activeRec.take(4)) {
          buffer.writeln("  • ${r.name}: ₹${r.amount.toStringAsFixed(0)} (${r.frequency})");
        }
      }
    }

    // 5. Wealth Goals
    if (wealthGoals != null && wealthGoals.isNotEmpty) {
      buffer.writeln("WEALTH JOURNEY GOALS (${wealthGoals.length}):");
      for (final g in wealthGoals.take(3)) {
        buffer.writeln("  • '${g.name}': ₹${g.currentAmount.toStringAsFixed(0)} / ₹${g.targetAmount.toStringAsFixed(0)} (${g.progressPercent.toStringAsFixed(1)}% complete)");
      }
    }

    return buffer.toString();
  }

  /// Call OpenAI ChatGPT (gpt-4o-mini) or Google Gemini API depending on key format
  static Future<String> generateContent({
    required String systemInstruction,
    required String userPrompt,
    String? apiKeyOverride,
  }) async {
    final apiKey = apiKeyOverride ?? await getApiKey();

    if (apiKey == null || apiKey.trim().isEmpty) {
      return "";
    }

    final apiKeyClean = apiKey.trim();

    // 1. OpenAI ChatGPT API Key (starts with 'sk-')
    if (apiKeyClean.startsWith('sk-')) {
      final url = Uri.parse('https://api.openai.com/v1/chat/completions');
      try {
        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKeyClean',
              },
              body: jsonEncode({
                "model": "gpt-4o-mini",
                "messages": [
                  {"role": "system", "content": systemInstruction},
                  {"role": "user", "content": userPrompt}
                ],
                "temperature": 0.3,
                "max_tokens": 800,
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final content = choices.first['message']?['content'] as String?;
            if (content != null && content.trim().isNotEmpty) {
              return content.trim();
            }
          }
        }
      } catch (_) {}
    }

    // 2. Google Gemini API Key
    final models = ["gemini-2.5-flash", "gemini-1.5-flash"];

    for (final model in models) {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKeyClean',
      );

      try {
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                "system_instruction": {
                  "parts": [
                    {"text": systemInstruction}
                  ]
                },
                "contents": [
                  {
                    "role": "user",
                    "parts": [
                      {"text": userPrompt}
                    ]
                  }
                ],
                "generationConfig": {
                  "temperature": 0.3,
                  "maxOutputTokens": 800,
                }
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates.first['content']?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts.first['text'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                return text.trim();
              }
            }
          }
        }
      } catch (_) {
        // Fall through
      }
    }

    return "";
  }
}
