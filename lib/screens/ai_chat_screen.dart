import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/expense_model.dart';
import '../models/group_model.dart';
import '../models/person_model.dart';
import '../models/ledger_transaction_model.dart';
import '../services/gemma_service.dart';
import '../services/storage_service.dart';
import '../services/gemini_ai_service.dart';
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

  // Udhaar data for AI context
  List<PersonModel> _udhaarPersons = [];
  List<LedgerTransactionModel> _udhaarTransactions = [];

  // Gemma on-device AI state
  bool _gemmaReady = false;
  bool _isDownloading = false;
  int _downloadProgress = 0;
  String? _downloadError;
  final _hfTokenCtrl = TextEditingController();

  final List<String> _suggestions = [
    "Where did my money go?",
    "How much on food?",
    "Which group spent most?",
    "Can I save money?"
  ];

  final String _backendUrl = "http://10.0.2.2:8000/api/chat";

  String? _savedApiKey;

  String get _aiSubtitle {
    if (_savedApiKey != null && _savedApiKey!.trim().isNotEmpty) {
      final k = _savedApiKey!.trim();
      if (k.startsWith('gsk_')) {
        return 'Your Personal CFO • Groq LLaMA 3.3 (Free)';
      } else if (k.startsWith('sk-')) {
        return 'Your Personal CFO • ChatGPT AI';
      }
      return 'Your Personal CFO • Gemini AI';
    }
    return 'Your Personal CFO';
  }

  Future<void> _loadApiKey() async {
    final key = await GeminiAiService.getApiKey();
    if (mounted) setState(() => _savedApiKey = key);
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isTyping) return;
    setState(() {
      _messages.add({"role": "user", "text": text});
      _ctrl.clear();
      _isTyping = true;
      _messages.add({"role": "ai", "text": "..."});
    });

    // 0. Off-topic & Coding Query Guardrail
    if (GeminiAiService.isOffTopicQuery(text)) {
      if (mounted) _streamResponse(GeminiAiService.offTopicGenericMessage);
      return;
    }

    // 1. Check if user has an API Key saved (ChatGPT or Gemini)
    final apiKey = await GeminiAiService.getApiKey();

    if (apiKey != null && apiKey.trim().isNotEmpty) {
      try {
        final sysPrompt = GeminiAiService.buildSystemContext(
          expenses: widget.expenses,
          groups: widget.groups,
          udhaarPersons: _udhaarPersons,
          udhaarTxns: _udhaarTransactions,
        );
        final geminiRes = await GeminiAiService.generateContent(
          systemInstruction: sysPrompt,
          userPrompt: text,
          apiKeyOverride: apiKey,
        );
        if (mounted) {
          if (geminiRes.startsWith(GeminiAiService.quotaErrorPrefix)) {
            final localAnswer = _generateLocalResponse(text);
            _streamResponse("⚡ Note: Your API key reached OpenAI/Gemini quota limits (Error 429). Answering with Eleghart Smart Local CFO:\n\n$localAnswer");
            return;
          } else if (geminiRes.startsWith(GeminiAiService.authErrorPrefix)) {
            final localAnswer = _generateLocalResponse(text);
            _streamResponse("🔑 Note: API Key authentication error (401). Please verify your key. Answering with Eleghart Smart Local CFO:\n\n$localAnswer");
            return;
          } else if (geminiRes.isEmpty) {
            final localAnswer = _generateLocalResponse(text);
            _streamResponse(localAnswer);
            return;
          }

          _streamResponse(geminiRes);
          return;
        }
      } catch (e) {
        if (mounted) {
          _streamResponse("API Connection Error: Unable to reach AI service. Please check your API key and internet connection.");
          return;
        }
      }
    }

    // 2. On-device Gemma AI (when no API key is provided)
    if (_gemmaReady && GemmaService.isAvailable) {
      try {
        final response = await GemmaService.respond(
          systemInstruction: _buildSystemInstruction(),
          userMessage: text,
        );
        if (mounted) {
          _streamResponse(response.isEmpty ? _generateLocalResponse(text) : response);
        }
        return;
      } catch (_) {}
    }

    // 3. Rule-based local engine (fallback when no API key)
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
    if (GeminiAiService.isOffTopicQuery(query)) {
      return GeminiAiService.offTopicGenericMessage;
    }

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
        for (var c in e.validCategories) {
          catTotals[c] = (catTotals[c] ?? 0) + e.shareForCategory(c);
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
        for (var c in e.validCategories) {
          catTotals[c] = (catTotals[c] ?? 0) + e.shareForCategory(c);
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

    // 8. Udhaar queries
    if (q.contains('udhaar') || q.contains('owe') || q.contains('collect') ||
        q.contains('pending') || q.contains('dues') || q.contains('lend') ||
        q.contains('borrow')) {
      if (_udhaarPersons.isEmpty) {
        return 'You have no Udhaar records yet. Open the Udhaar module to start tracking.';
      }
      final totalCollect = _udhaarTransactions
          .where((t) => t.isCollection)
          .fold(0.0, (s, t) => s + t.amount);
      final totalPay = _udhaarTransactions
          .where((t) => t.isPayment)
          .fold(0.0, (s, t) => s + t.amount);
      final netPositive = _udhaarPersons
          .where((p) {
            final c = _udhaarTransactions
                .where((t) => t.personId == p.id && t.isCollection)
                .fold(0.0, (s, t) => s + t.amount);
            final pay = _udhaarTransactions
                .where((t) => t.personId == p.id && t.isPayment)
                .fold(0.0, (s, t) => s + t.amount);
            return c - pay > 0;
          })
          .toList();
      final highestOwing = netPositive.isEmpty
          ? null
          : netPositive.reduce((a, b) {
              double netA(PersonModel p) => _udhaarTransactions
                  .where((t) => t.personId == p.id && t.isCollection)
                  .fold(0.0, (s, t) => s + t.amount) -
                  _udhaarTransactions
                      .where((t) => t.personId == p.id && t.isPayment)
                      .fold(0.0, (s, t) => s + t.amount);
              return netA(a) >= netA(b) ? a : b;
            });

      if (q.contains('who owes') || q.contains('who should pay') ||
          q.contains('highest') || q.contains('most')) {
        if (highestOwing == null) return 'Nobody owes you money right now.';
        final amt = _udhaarTransactions
            .where((t) => t.personId == highestOwing.id && t.isCollection)
            .fold(0.0, (s, t) => s + t.amount) -
            _udhaarTransactions
                .where((t) =>
                    t.personId == highestOwing.id && t.isPayment)
                .fold(0.0, (s, t) => s + t.amount);
        return '${highestOwing.name} owes you the most — ₹${amt.toStringAsFixed(0)}';
      }
      return 'Udhaar summary: To Collect ₹${totalCollect.toStringAsFixed(0)}, '
          'To Pay ₹${totalPay.toStringAsFixed(0)}, '
          'Net ${(totalCollect - totalPay) >= 0 ? "+" : ""}₹${(totalCollect - totalPay).toStringAsFixed(0)}. '
          'You have ${netPositive.length} pending collection(s).';
    }

    // 9. General fallback
    final fallbacks = [
      "I'm analyzing your ledger locally. Try asking 'What was my biggest expense?' or 'How much did I spend on Food?'",
      "I didn't quite catch that. You can ask me about your total spending, top categories, or specific group expenses.",
      "As your local AI, I track patterns. Ask me 'How can I save money?' or name a category to see its total!"
    ];
    fallbacks.shuffle();
    return fallbacks.first;
  }

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _initGemma();
    _loadUdhaarData();
  }

  Future<void> _loadUdhaarData() async {
    final persons = await StorageService.loadPersons();
    final txs = await StorageService.loadUdhaarTransactions();
    if (mounted) setState(() {
      _udhaarPersons = persons;
      _udhaarTransactions = txs;
    });
  }

  Future<void> _initGemma() async {
    final installed = await GemmaService.isModelInstalled();
    if (!installed) return;
    try {
      await GemmaService.initialize();
      if (mounted) setState(() => _gemmaReady = true);
    } catch (_) {
      // Model installed but init failed — show download option
    }
  }

  Future<void> _downloadGemma() async {
    final token = _hfTokenCtrl.text.trim();
    if (token.isEmpty) {
      setState(() => _downloadError = 'Enter your HuggingFace token to continue.');
      return;
    }
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _downloadError = null;
    });
    try {
      await GemmaService.installModel(
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
        hfToken: token,
      );
      await GemmaService.initialize(hfToken: token);
      if (mounted) setState(() {
        _isDownloading = false;
        _gemmaReady = true;
      });
    } catch (e) {
      if (mounted) setState(() {
        _isDownloading = false;
        _downloadError = 'Download failed. Check your token and internet connection.';
      });
    }
  }

  String _buildSystemInstruction() {
    final now = DateTime.now();
    final debitTotal = widget.expenses
        .where((e) => e.isDebit)
        .fold(0.0, (s, e) => s + e.amount);
    final recent = widget.expenses
        .take(20)
        .map((e) =>
            '${e.date.toIso8601String().split('T')[0]}: ${e.description.isEmpty ? 'Expense' : e.description} ₹${e.amount.toStringAsFixed(0)} [${e.categories.join(', ')}]')
        .join('\n');

    final udhaarSummary = _udhaarPersons.isNotEmpty
        ? _udhaarPersons.map((p) {
            final collect = _udhaarTransactions
                .where((t) => t.personId == p.id && t.isCollection)
                .fold(0.0, (s, t) => s + t.amount);
            final pay = _udhaarTransactions
                .where((t) => t.personId == p.id && t.isPayment)
                .fold(0.0, (s, t) => s + t.amount);
            final net = collect - pay;
            return '${p.name}: net ₹${net >= 0 ? '+' : ''}${net.toStringAsFixed(0)}';
          }).join('; ')
        : 'No Udhaar records.';
    final totalCollect = _udhaarTransactions
        .where((t) => t.isCollection)
        .fold(0.0, (s, t) => s + t.amount);
    final totalPay = _udhaarTransactions
        .where((t) => t.isPayment)
        .fold(0.0, (s, t) => s + t.amount);

    return 'You are Eleghart AI, a personal financial CFO assistant embedded '
        'in a mobile ledger app. Today is ${now.toIso8601String().split('T')[0]}. '
        'The user has ${widget.expenses.length} total expenses across '
        '${widget.groups.length} group(s). Total spending: ₹${debitTotal.toStringAsFixed(0)}. '
        'Recent transactions:\n$recent\n\n'
        'Udhaar (dues) — To Collect total: ₹${totalCollect.toStringAsFixed(0)}, '
        'To Pay total: ₹${totalPay.toStringAsFixed(0)}. '
        'Per person: $udhaarSummary\n\n'
        'Respond concisely in 1-3 sentences. Be specific with numbers from the data above. '
        'Always use ₹ symbol for Indian Rupees.';
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
                                  Text(_aiSubtitle, style: GoogleFonts.sora(fontSize: 11, color: isWhite ? Colors.black54 : Colors.white54)),
                                ],
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.key_rounded, color: Color(0xFFCC0020), size: 22),
                            tooltip: 'Configure Free Gemini API Key',
                            onPressed: () => _showApiKeyDialog(isWhite),
                          ),
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

  Future<void> _launchWebUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _showApiKeyDialog(bool isWhite) async {
    final keyCtrl = TextEditingController(text: await GeminiAiService.getApiKey() ?? '');
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isWhite ? Colors.white : const Color(0xFF180808),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const Icon(Icons.key_rounded, color: Color(0xFFCC0020), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Add Free AI Key (Groq / Gemini)',
                style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: isWhite ? EleghartColors.accentDark : Colors.white),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unlock 100% Free AI CFO intelligence (no credit card needed):',
                style: GoogleFonts.sora(fontSize: 12, color: isWhite ? Colors.black54 : Colors.white54, height: 1.4),
              ),
              const SizedBox(height: 12),

              // Guide Box 1: Groq Key (RECOMMENDED 100% FREE)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isWhite ? const Color(0xFFF0FDF4) : const Color(0xFF0C2417),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flash_on_rounded, color: Color(0xFF10B981), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Option A: Groq LLaMA 3.3 (Recommended 100% Free)',
                            style: GoogleFonts.sora(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isWhite ? const Color(0xFF065F46) : const Color(0xFF6EE7B7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      children: [
                        Text('1. Go to ', style: GoogleFonts.sora(fontSize: 11, color: isWhite ? Colors.black54 : Colors.white54)),
                        GestureDetector(
                          onTap: () => _launchWebUrl('https://console.groq.com/keys'),
                          child: Text(
                            'console.groq.com/keys',
                            style: GoogleFonts.sora(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF10B981),
                              decoration: TextDecoration.underline,
                              decorationColor: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text('2. Sign in with Google & click "Create API Key"\n3. Paste key starting with gsk_... (14,400 free requests/day)', style: GoogleFonts.sora(fontSize: 11, color: isWhite ? Colors.black54 : Colors.white54, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Guide Box 2: Gemini Key
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isWhite ? const Color(0xFFF1F5F9) : const Color(0xFF220C0C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCC0020).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Color(0xFF1A73E8), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Option B: Google Gemini Key (100% Free)',
                            style: GoogleFonts.sora(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isWhite ? EleghartColors.accentDark : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      children: [
                        Text('1. Go to ', style: GoogleFonts.sora(fontSize: 11, color: isWhite ? Colors.black54 : Colors.white54)),
                        GestureDetector(
                          onTap: () => _launchWebUrl('https://aistudio.google.com'),
                          child: Text(
                            'aistudio.google.com',
                            style: GoogleFonts.sora(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2563EB),
                              decoration: TextDecoration.underline,
                              decorationColor: const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text('2. Sign in & tap "Get API Key"\n3. Paste key starting with AIzaSy... (1,500 free requests/day)', style: GoogleFonts.sora(fontSize: 11, color: isWhite ? Colors.black54 : Colors.white54, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Guide Box 3: ChatGPT Key
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isWhite ? const Color(0xFFF1F5F9) : const Color(0xFF220C0C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCC0020).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt_rounded, color: Color(0xFF10A37F), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Option C: ChatGPT API Key',
                            style: GoogleFonts.sora(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isWhite ? EleghartColors.accentDark : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      children: [
                        Text('1. Go to ', style: GoogleFonts.sora(fontSize: 11, color: isWhite ? Colors.black54 : Colors.white54)),
                        GestureDetector(
                          onTap: () => _launchWebUrl('https://platform.openai.com/api-keys'),
                          child: Text(
                            'platform.openai.com/api-keys',
                            style: GoogleFonts.sora(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2563EB),
                              decoration: TextDecoration.underline,
                              decorationColor: const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text('2. Log in & paste key starting with sk-...', style: GoogleFonts.sora(fontSize: 11, color: isWhite ? Colors.black54 : Colors.white54, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: keyCtrl,
                decoration: InputDecoration(
                  hintText: 'Paste gsk_..., AIzaSy..., or sk-... API Key',
                  hintStyle: GoogleFonts.sora(fontSize: 12, color: isWhite ? Colors.black38 : Colors.white38),
                  filled: true,
                  fillColor: isWhite ? const Color(0xFFF8FAFC) : const Color(0xFF2B0E0E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                style: GoogleFonts.sora(fontSize: 13, color: isWhite ? EleghartColors.accentDark : Colors.white),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.sora(color: isWhite ? Colors.black54 : Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCC0020),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await GeminiAiService.saveApiKey(keyCtrl.text);
              await _loadApiKey();
              if (mounted) {
                Navigator.pop(context);
                final keyText = keyCtrl.text.trim();
                final modelName = keyText.startsWith('gsk_') ? 'Groq LLaMA 3.3 (Free)' : (keyText.startsWith('sk-') ? 'ChatGPT' : 'Gemini');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$modelName API Key saved successfully! All chats will now use your key.')),
                );
              }
            },
            child: Text('Save Key', style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}