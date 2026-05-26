import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/expense_model.dart';
import '../models/group_model.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';

class AiChatScreen extends StatefulWidget {
  final List<ExpenseModel> expenses;
  final List<GroupModel> groups;

  const AiChatScreen({super.key, required this.expenses, required this.groups});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _ctrl = TextEditingController();
  final List<Map<String, String>> _messages = [
    {"role": "ai", "text": "Hi! I am your personal financial CFO. How can I help you analyze your spending today?"}
  ];

  bool _isTyping = false;

  final List<String> _suggestions = [
    "Where did my money go?",
    "How much on food?",
    "Which group spent most?",
    "Can I save money?"
  ];

  // Your FastAPI backend address (10.0.2.2 points to localhost on Android Emulators)
  // Change this to your computer's local IP (e.g., 192.168.1.100) if testing on a real physical device.
  final String _backendUrl = "http://10.0.2.2:8000/api/chat";

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isTyping) return;
    setState(() {
      _messages.add({"role": "user", "text": text});
      _ctrl.clear();
      _isTyping = true;
      _messages.add({"role": "ai", "text": "..."});
    });
    
    // Prepare context data to feed the local LLM
    final contextData = {
      "total_groups": widget.groups.length,
      "total_expenses": widget.expenses.length,
      "recent_expenses": widget.expenses.take(15).map((e) => "${e.date.toIso8601String().split('T')[0]} - ${e.description}: ₹${e.amount} [${e.categories.first}]").toList(),
    };

    try {
      // Attempt to contact the Advanced Local Backend (FastAPI + LangGraph + Ollama)
      final res = await http.post(
        Uri.parse(_backendUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"query": text, "ledger_context": contextData}),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        _streamResponse(data['reply'] ?? "I received an empty response.");
        return;
      }
    } catch (_) {
      // Silently catch Timeout/Connection errors
    }
    // Fallback: If server is offline, use the on-device math engine
    if (mounted) _streamResponse(_generateLocalResponse(text));
  }

  Future<void> _streamResponse(String fullText) async {
    String currentText = "";
    for (int i = 0; i < fullText.length; i++) {
      if (!mounted) return;
      currentText += fullText[i];
      setState(() {
        _messages.last["text"] = currentText;
      });
      // Simulate LLM token streaming speed
      await Future.delayed(const Duration(milliseconds: 15));
    }
    if (mounted) setState(() => _isTyping = false);
  }

  String _generateLocalResponse(String query) {
    final q = query.toLowerCase();
    final now = DateTime.now();
    
    // NLP Context: Check if user is asking about "last month"
    bool isLastMonth = q.contains("last month") || q.contains("previous month");
    final targetMonth = isLastMonth ? (now.month == 1 ? 12 : now.month - 1) : now.month;
    final targetYear = isLastMonth ? (now.month == 1 ? now.year - 1 : now.year) : now.year;
    
    final targetExpenses = widget.expenses.where((e) => e.date.month == targetMonth && e.date.year == targetYear && e.isDebit).toList();
    final total = targetExpenses.fold(0.0, (sum, item) => sum + item.amount);
    final monthStr = isLastMonth ? "last month" : "this month";

    // 0. Greetings
    if (q == "hi" || q == "hello" || q == "hey" || q == "help") {
      final responses = [
        "Hello! I'm Eleghart, your personal CFO. Ask me anything about your spending.",
        "Hi there! Ready to analyze your finances?",
        "Greetings! How can I help you manage your money today?"
      ];
      responses.shuffle();
      return responses.first;
    }

    if (targetExpenses.isEmpty) {
      return "I don't see any expenses for $monthStr yet. Try asking about a different time frame or start tracking!";
    }

    // 1. Biggest Expense
    if (q.contains("biggest") || q.contains("highest") || q.contains("most expensive") || q.contains("largest")) {
      final biggest = targetExpenses.reduce((a, b) => a.amount > b.amount ? a : b);
      return "Your biggest expense $monthStr was ₹${biggest.amount.toStringAsFixed(0)} for '${biggest.description}' on ${biggest.date.day}/${biggest.date.month}.";
    }

    // 2. Top Category
    if (q.contains("top category") || q.contains("where did i spend most") || q.contains("most money on")) {
      Map<String, double> catTotals = {};
      for (var e in targetExpenses) {
        for (var c in e.categories) {
          catTotals[c] = (catTotals[c] ?? 0) + (e.amount / e.categories.length);
        }
      }
      if (catTotals.isEmpty) return "You haven't categorized your expenses yet $monthStr.";
      final topCat = catTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
      return "Your top spending category $monthStr is '${topCat.key}' at ₹${topCat.value.toStringAsFixed(0)} (${((topCat.value/total)*100).toStringAsFixed(0)}% of your total spend).";
    }
    
    // 3. Top Group
    if (q.contains("group spent most") || q.contains("top group") || q.contains("most active group")) {
      if (widget.groups.isEmpty) return "You don't have any groups yet.";
      Map<String, double> groupTotals = {};
      for (var e in targetExpenses) {
        groupTotals[e.groupId] = (groupTotals[e.groupId] ?? 0) + e.amount;
      }
      if (groupTotals.isEmpty) return "No group spending recorded $monthStr.";
      final topGroupEntry = groupTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
      final topGroupName = widget.groups.firstWhere((g) => g.id == topGroupEntry.key, orElse: () => widget.groups.first).name;
      return "Your top spending group $monthStr is '$topGroupName' with ₹${topGroupEntry.value.toStringAsFixed(0)} spent.";
    }

    // 4. Savings / Advice
    if (q.contains("save") || q.contains("advice") || q.contains("tips") || q.contains("reduce") || q.contains("budget")) {
      Map<String, double> catTotals = {};
      for (var e in targetExpenses) {
        for (var c in e.categories) {
          catTotals[c] = (catTotals[c] ?? 0) + (e.amount / e.categories.length);
        }
      }
      if (catTotals.isEmpty) return "Track more categorized expenses so I can find savings opportunities!";
      final topCat = catTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
      final potential = topCat.value * 0.15; // suggest 15% cut on top category
      
      return "Here's a strategy:\nYour highest spending is on '${topCat.key}'. If you reduce this by just 15%, you could save ₹${potential.toStringAsFixed(0)} $monthStr!\n\nAlso, consider reviewing any auto-renewing subscriptions.";
    }

    // 5. Specific Group Analysis (Dynamic Match)
    for (var g in widget.groups) {
      if (q.contains(g.name.toLowerCase())) {
        final groupExp = widget.expenses.where((e) => e.groupId == g.id && e.isDebit).toList();
        if (groupExp.isEmpty) return "You haven't spent anything in the '${g.name}' group yet.";
        final groupTotal = groupExp.fold(0.0, (s, e) => s + e.amount);
        return "In the '${g.name}' group, you've spent a total of ₹${groupTotal.toStringAsFixed(0)} across ${groupExp.length} transactions overall.";
      }
    }

    // 6. Specific Category Analysis (Dynamic Match)
    final allCategories = widget.expenses.expand((e) => e.categories).map((c) => c.toLowerCase()).toSet();
    for (var cat in allCategories) {
      if (cat.length > 3 && q.contains(cat)) {
        final catExp = targetExpenses.where((e) => e.categories.any((c) => c.toLowerCase() == cat)).toList();
        if (catExp.isEmpty) return "You didn't spend anything on '$cat' $monthStr.";
        final catTotal = catExp.fold(0.0, (s, e) => s + e.amount);
        return "You've spent ₹${catTotal.toStringAsFixed(0)} on '${cat[0].toUpperCase()}${cat.substring(1)}' $monthStr. That's ${((catTotal/total)*100).toStringAsFixed(1)}% of your monthly spending.";
      }
    }

    // 7. Total Spend
    if (q.contains("total") || q.contains("where did my money go") || q.contains("how much did i spend") || q.contains("how much")) {
      return "You've spent a total of ₹${total.toStringAsFixed(0)} $monthStr.\n\nWant to know your 'top category' or 'biggest expense'?";
    }

    // 8. General fallback
    final fallbacks = [
      "I'm analyzing your ledger locally. Try asking 'What was my biggest expense?' or 'How much did I spend on Food?'",
      "I didn't quite catch that. You can ask me about your total spending, top categories, or specific group expenses.",
      "As your local AI, I track patterns. Ask me 'How can I save money?' or name a category to see its total!"
    ];
    fallbacks.shuffle();
    return fallbacks.first;
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.85)),
          SafeArea(
            child: Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20), onPressed: () => Navigator.pop(context)),
                      const SizedBox(width: 8),
                      CircleAvatar(backgroundColor: const Color(0xFFCC0020).withOpacity(0.15), radius: 18, child: Padding(padding: const EdgeInsets.all(6), child: Image.asset('assets/icons/eleghart_icon.png'))),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Eleghart AI', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                          Row(
                            children: [
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF00CC66), shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text('Online • Local', style: GoogleFonts.sora(fontSize: 11, color: isWhite ? Colors.black54 : Colors.white54)),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                Container(height: 1, color: isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.1)),

                // ── Chat List ──
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = _messages[i];
                      final isAi = msg["role"] == "ai";
                      return Align(
                        alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isAi ? (isWhite ? Colors.white : const Color(0xFF1A0505)) : const Color(0xFFCC0020),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isAi ? Radius.zero : const Radius.circular(16),
                              bottomRight: isAi ? const Radius.circular(16) : Radius.zero,
                            ),
                            border: isAi ? Border.all(color: isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.2)) : null,
                          ),
                          child: Text(msg["text"]!, style: GoogleFonts.sora(fontSize: 14, color: isAi ? textPrimary : Colors.white, height: 1.5)),
                        ),
                      );
                    },
                  ),
                ),

                // ── Suggestions ──
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) => ActionChip(
                      label: Text(_suggestions[i], style: GoogleFonts.sora(fontSize: 12, color: textPrimary)),
                      backgroundColor: isWhite ? Colors.white : const Color(0xFF120404),
                      side: BorderSide(color: isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.1)),
                      onPressed: () => _sendMessage(_suggestions[i]),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Input ──
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 16),
                  child: Container(
                    decoration: BoxDecoration(color: isWhite ? Colors.white : const Color(0xFF120404), borderRadius: BorderRadius.circular(24), border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.1))),
                    child: Row(
                      children: [
                        const SizedBox(width: 20),
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            style: GoogleFonts.sora(color: textPrimary, fontSize: 14),
                            decoration: InputDecoration(hintText: 'Ask about your expenses...', hintStyle: GoogleFonts.sora(color: isWhite ? Colors.black38 : Colors.white38), border: InputBorder.none),
                            onSubmitted: _sendMessage,
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.send_rounded, color: Color(0xFFCC0020)), onPressed: () => _sendMessage(_ctrl.text)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}