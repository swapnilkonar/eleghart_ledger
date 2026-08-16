import '../models/wealth_models.dart';

class WealthAIAction {
  final String action; // 'CREATE', 'ADD_SAVINGS', 'DELETE'
  final String title;
  final double targetAmount;
  final double amount;
  final int months;
  final String? goalId;

  WealthAIAction({
    required this.action,
    required this.title,
    this.targetAmount = 0,
    this.amount = 0,
    this.months = 12,
    this.goalId,
  });
}

class AIWealthService {
  /// Parse natural language user text into a WealthAIAction
  static Future<WealthAIAction?> parsePrompt(
    String prompt,
    List<WealthGoal> existingGoals,
  ) async {
    final lower = prompt.trim().toLowerCase();
    if (lower.isEmpty) return null;

    // Check for DELETE intent
    if (lower.contains('delete') || lower.contains('remove') || lower.contains('cancel')) {
      for (final g in existingGoals) {
        if (lower.contains(g.name.toLowerCase())) {
          return WealthAIAction(
            action: 'DELETE',
            title: g.name,
            goalId: g.id,
          );
        }
      }
    }

    // Parse numeric amounts
    final numbers = RegExp(r'(?:₹|rs\.?|inr)?\s*([\d,]+(?:\.\d+)?)')
        .allMatches(lower)
        .map((m) => double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0.0)
        .where((n) => n > 0)
        .toList();

    // Check for ADD SAVINGS intent
    if ((lower.contains('add') || lower.contains('save') || lower.contains('deposit') || lower.contains('contribute')) && existingGoals.isNotEmpty) {
      for (final g in existingGoals) {
        if (lower.contains(g.name.toLowerCase()) && numbers.isNotEmpty) {
          return WealthAIAction(
            action: 'ADD_SAVINGS',
            title: g.name,
            amount: numbers.first,
            goalId: g.id,
          );
        }
      }
    }

    // Check for CREATE GOAL intent
    if (numbers.isNotEmpty) {
      final amount = numbers.first;
      String title = prompt
          .replaceAll(RegExp(r'(?:₹|rs\.?|inr)?\s*[\d,]+(?:\.\d+)?', caseSensitive: false), '')
          .replaceAll(RegExp(r'\b(save|for|in|months|month|years|year|i|want|to|goal|a|new)\b', caseSensitive: false), '')
          .trim();

      if (title.isEmpty) title = 'Financial Goal';
      title = title[0].toUpperCase() + title.substring(1);

      int months = 12;
      final monthMatch = RegExp(r'(\d+)\s*(?:month|mth|mon)').firstMatch(lower);
      final yearMatch = RegExp(r'(\d+)\s*(?:year|yr)').firstMatch(lower);
      if (monthMatch != null) {
        months = int.tryParse(monthMatch.group(1)!) ?? 12;
      } else if (yearMatch != null) {
        months = (int.tryParse(yearMatch.group(1)!) ?? 1) * 12;
      }

      return WealthAIAction(
        action: 'CREATE',
        title: title,
        targetAmount: amount,
        months: months,
      );
    }

    return null;
  }
}
