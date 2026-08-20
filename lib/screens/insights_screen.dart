import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/expense_model.dart';
import '../models/group_model.dart';
import '../models/person_model.dart';
import '../models/ledger_transaction_model.dart';
import '../models/emi_model.dart';
import '../models/recurring_expense_model.dart';
import '../models/wealth_models.dart';
import '../services/storage_service.dart';
import '../services/wealth_repository.dart';
import '../services/gemini_ai_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../utils/date_filter.dart';
import '../widgets/date_filter_pill.dart';
import 'ai_chat_screen.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => InsightsScreenState();
}

class InsightsScreenState extends State<InsightsScreen> {
  bool _loading = true;
  List<ExpenseModel> _expenses = [];
  List<GroupModel> _groups = [];
  List<PersonModel> _udhaarPersons = [];
  List<LedgerTransactionModel> _udhaarTxns = [];
  List<EmiModel> _emis = [];
  List<RecurringExpenseModel> _recurrings = [];
  List<WealthGoal> _wealthGoals = [];

  // Analytics
  double _totalIncome = 0;
  double _totalDebit = 0;
  double _lastPeriodDebit = 0;
  double _growth = 0;
  int _healthScore = 0;
  String _aiExecutiveSummary = '';

  Map<String, double> _categoryTotals = {};
  ExpenseModel? _biggestExpense;
  String _topCategory = '-';
  String _mostActiveGroup = '-';

  final List<String> _quickPrompts = [
    "Where did my money go?",
    "How can I save ₹10,000?",
    "Which group spent most?",
    "Am I on track for my goals?",
  ];

  @override
  void initState() {
    super.initState();
    AppThemeNotifier.instance.addListener(_onThemeChanged);
    DateFilter.notifier.addListener(_onFilterChanged);
    _loadData();
  }

  void _onThemeChanged() => setState(() {});
  void _onFilterChanged() => _loadData();

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_onThemeChanged);
    DateFilter.notifier.removeListener(_onFilterChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    final expenses = await StorageService.loadExpenses();
    final groups = await StorageService.loadGroups();
    final globalCats = await StorageService.loadGlobalCategories();
    final persons = await StorageService.loadPersons();
    final txns = await StorageService.loadUdhaarTransactions();
    final emis = await StorageService.loadEmis();
    final recurrings = await StorageService.loadRecurring();
    List<WealthGoal> wealthGoals = [];
    try {
      wealthGoals = await WealthRepository.loadGoals();
    } catch (_) {}

    // Filter by DateFilter
    final inRangeExpenses = expenses.where((e) => DateFilter.isInRange(e.date)).toList();

    double income = 0;
    double debit = 0;
    for (final e in inRangeExpenses) {
      if (e.isCredit) {
        income += e.amount;
      } else {
        debit += e.amount;
      }
    }

    _totalIncome = income;
    _totalDebit = debit;

    // Build category breakdown
    final Set<String> activeCategories = globalCats.map((c) => c.toLowerCase().trim()).toSet();
    for (var g in groups) {
      activeCategories.addAll(g.categories.map((c) => c.toLowerCase().trim()));
    }

    _categoryTotals.clear();
    _biggestExpense = null;
    _topCategory = '-';
    _mostActiveGroup = '-';

    final debitExpenses = inRangeExpenses.where((e) => e.isDebit).toList();

    for (var e in debitExpenses) {
      final validCategories = e.categories.where((cat) {
        final lower = cat.toLowerCase().trim();
        if (lower == 'emi' || lower == 'recurring') return false;
        return activeCategories.isEmpty || activeCategories.contains(lower);
      }).toList();

      if (validCategories.isEmpty) {
        _categoryTotals['Others'] = (_categoryTotals['Others'] ?? 0) + e.amount;
      } else {
        for (var cat in validCategories) {
          _categoryTotals[cat] = (_categoryTotals[cat] ?? 0) + e.shareForCategory(cat);
        }
      }
    }

    if (_categoryTotals.isNotEmpty) {
      var top = _categoryTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
      _topCategory = top.key;
    }

    if (debitExpenses.isNotEmpty) {
      _biggestExpense = debitExpenses.reduce((a, b) => a.amount > b.amount ? a : b);
    }

    // Active Group calculation
    var groupCounts = <String, int>{};
    for (var e in inRangeExpenses) {
      if (e.groupId != null) {
        groupCounts[e.groupId!] = (groupCounts[e.groupId!] ?? 0) + 1;
      }
    }
    if (groupCounts.isNotEmpty) {
      var topG = groupCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
      var g = groups.where((gr) => gr.id == topG.key).firstOrNull;
      if (g != null) _mostActiveGroup = g.name;
    }

    // Calculate Health Score (0 - 100)
    double score = 100;
    if (_totalIncome > 0) {
      final savingsRate = ((_totalIncome - _totalDebit) / _totalIncome).clamp(0.0, 1.0);
      score = (savingsRate * 70) + 30;
    } else {
      if (_totalDebit > 50000) score = 45;
      else if (_totalDebit > 20000) score = 65;
      else if (_totalDebit > 0) score = 85;
      else score = 100;
    }
    _healthScore = score.toInt().clamp(0, 100);

    // Build Executive AI Summary
    _aiExecutiveSummary = _generateLocalCfoSummary();

    if (mounted) {
      setState(() {
        _expenses = expenses;
        _groups = groups;
        _udhaarPersons = persons;
        _udhaarTxns = txns;
        _emis = emis;
        _recurrings = recurrings;
        _wealthGoals = wealthGoals;
        _loading = false;
      });
    }

    // Try background Gemini API call for real AI executive summary
    _fetchGeminiExecutiveSummary(expenses, groups, persons, txns, emis, recurrings, wealthGoals);
  }

  Future<void> _fetchGeminiExecutiveSummary(
    List<ExpenseModel> expenses,
    List<GroupModel> groups,
    List<PersonModel> persons,
    List<LedgerTransactionModel> txns,
    List<EmiModel> emis,
    List<RecurringExpenseModel> recurrings,
    List<WealthGoal> wealthGoals,
  ) async {
    try {
      final sysPrompt = GeminiAiService.buildSystemContext(
        expenses: expenses,
        groups: groups,
        udhaarPersons: persons,
        udhaarTxns: txns,
        emis: emis,
        recurrings: recurrings,
        wealthGoals: wealthGoals,
      );

      final result = await GeminiAiService.generateContent(
        systemInstruction: sysPrompt,
        userPrompt: "Provide a 2-sentence executive summary of my financial health for ${DateFilter.label} with 1 key recommendation.",
      );

      if (result.isNotEmpty &&
          !result.startsWith(GeminiAiService.quotaErrorPrefix) &&
          !result.startsWith(GeminiAiService.authErrorPrefix) &&
          !result.contains("Service Unavailable") &&
          !result.contains("API Error") &&
          !result.contains("Invalid API Key") &&
          mounted) {
        setState(() {
          _aiExecutiveSummary = result;
        });
      } else if (mounted) {
        setState(() {
          _aiExecutiveSummary = _generateLocalCfoSummary();
        });
      }
    } catch (_) {}
  }

  String _generateLocalCfoSummary() {
    if (_totalDebit == 0) {
      return "No debit transactions recorded for ${DateFilter.label}. Your financial health score is optimal!";
    }

    final topCatStr = _topCategory != '-' ? "Top spending went to '$_topCategory' (₹${(_categoryTotals[_topCategory] ?? 0).toStringAsFixed(0)})." : "";
    if (_totalIncome > 0) {
      final savings = _totalIncome - _totalDebit;
      if (savings >= 0) {
        return "You're in a positive cash flow position for ${DateFilter.label} with ₹${savings.toStringAsFixed(0)} saved! $topCatStr";
      } else {
        return "You've spent ₹${savings.abs().toStringAsFixed(0)} more than your recorded income for ${DateFilter.label}. $topCatStr";
      }
    } else {
      return "Total expenses for ${DateFilter.label} stand at ₹${_totalDebit.toStringAsFixed(0)}. $topCatStr";
    }
  }

  void reload() {
    setState(() => _loading = true);
    _loadData();
  }

  BoxDecoration _cardDeco(bool isWhite) => BoxDecoration(
    color: isWhite ? Colors.white : const Color(0xFF120404),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.15)),
    boxShadow: isWhite ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2))] : [],
  );

  Widget _sectionTitle(String title, bool isWhite) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: GoogleFonts.sora(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: isWhite ? EleghartColors.accentDark : Colors.white,
      ),
    ),
  );

  void _openChatWithPrompt(String prompt) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiChatScreen(expenses: _expenses, groups: _groups),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54;

    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0020)));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header & Date Filter ────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Insights', style: GoogleFonts.sora(fontSize: 26, fontWeight: FontWeight.w800, color: textPrimary)),
                      Text('AI-Powered Financial CFO', style: GoogleFonts.sora(fontSize: 12, color: textSec)),
                    ],
                  ),
                ),
                const DateFilterPill(),
              ],
            ),
            const SizedBox(height: 20),

            // SECTION 1: AI Executive Summary Card
            _buildExecutiveSummaryCard(isWhite),
            const SizedBox(height: 20),

            // SECTION 2: Ask Eleghart AI Bar & Quick Prompt Chips
            _buildAskAiSection(isWhite),
            const SizedBox(height: 24),

            // SECTION 3: Financial Health Score
            _sectionTitle('Financial Health', isWhite),
            _buildHealthScore(isWhite),
            const SizedBox(height: 24),

            // SECTION 4: Quick Highlights
            _sectionTitle('Key Metrics', isWhite),
            _buildHighlights(isWhite),
            const SizedBox(height: 24),

            // SECTION 5: Spending Distribution Donut Chart
            _sectionTitle('Spending Distribution', isWhite),
            _buildDistributionChart(isWhite),
            const SizedBox(height: 24),

            // SECTION 6: Smart AI Recommendations
            _sectionTitle('AI Recommendations', isWhite),
            _buildRecommendations(isWhite),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveSummaryCard(bool isWhite) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isWhite
              ? [const Color(0xFF8B0010), const Color(0xFFCC0020)]
              : [const Color(0xFF5A000A), const Color(0xFF990018)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCC0020).withOpacity(isWhite ? 0.25 : 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'AI CFO Scorecard (${DateFilter.label})',
                style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _aiExecutiveSummary,
            style: GoogleFonts.sora(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _summaryPill('Income: ₹${_totalIncome.toStringAsFixed(0)}', const Color(0xFF22C55E)),
              const SizedBox(width: 8),
              _summaryPill('Spent: ₹${_totalDebit.toStringAsFixed(0)}', Colors.white70),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildAskAiSection(bool isWhite) {
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AiChatScreen(expenses: _expenses, groups: _groups),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isWhite ? Colors.white : const Color(0xFF160606),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFCC0020).withOpacity(0.3)),
              boxShadow: isWhite
                  ? [
                      BoxShadow(
                        color: const Color(0xFFCC0020).withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : [],
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFFCC0020), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ask Eleghart AI CFO...',
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      color: isWhite
                          ? EleghartColors.accentDark.withOpacity(0.5)
                          : Colors.white54,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCC0020),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Chat',
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _quickPrompts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final prompt = _quickPrompts[i];
              return GestureDetector(
                onTap: () => _openChatWithPrompt(prompt),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCC0020).withOpacity(isWhite ? 0.08 : 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCC0020).withOpacity(0.2)),
                  ),
                  child: Text(
                    prompt,
                    style: GoogleFonts.sora(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isWhite ? EleghartColors.accentDark : Colors.white70,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHealthScore(bool isWhite) {
    String interpretation = "Fair";
    Color color = Colors.amber;
    if (_healthScore >= 85) {
      interpretation = "Excellent";
      color = const Color(0xFF00CC66);
    } else if (_healthScore >= 70) {
      interpretation = "Good";
      color = Colors.blueAccent;
    } else if (_healthScore < 50) {
      interpretation = "Needs Attention";
      color = const Color(0xFFFF3355);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(isWhite),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: _healthScore / 100,
                    strokeWidth: 10,
                    color: color,
                    backgroundColor: color.withOpacity(0.15),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_healthScore',
                      style: GoogleFonts.sora(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: isWhite ? EleghartColors.accentDark : Colors.white,
                      ),
                    ),
                    Text(
                      '/ 100',
                      style: GoogleFonts.sora(
                        fontSize: 10,
                        color: isWhite ? Colors.black45 : Colors.white54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score Status',
                  style: GoogleFonts.sora(
                    fontSize: 12,
                    color: isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54,
                  ),
                ),
                Text(
                  interpretation,
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Analyzed against spending rate & net financial velocity for ${DateFilter.label}.',
                  style: GoogleFonts.sora(
                    fontSize: 11,
                    color: isWhite ? EleghartColors.accentDark.withOpacity(0.6) : Colors.white38,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlights(bool isWhite) {
    return Column(
      children: [
        Row(
          children: [
            _highlightCard('Top Category', _topCategory, '₹${(_categoryTotals[_topCategory] ?? 0).toStringAsFixed(0)}', Icons.pie_chart_rounded, isWhite),
            const SizedBox(width: 12),
            _highlightCard('Biggest Expense', _biggestExpense?.description ?? '-', '₹${(_biggestExpense?.amount ?? 0).toStringAsFixed(0)}', Icons.receipt_long_rounded, isWhite),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _highlightCard('Active Group', _mostActiveGroup, 'Most activity', Icons.group_rounded, isWhite),
            const SizedBox(width: 12),
            _highlightCard('Total Spent', '₹${_totalDebit.toStringAsFixed(0)}', DateFilter.label, Icons.account_balance_wallet_rounded, isWhite),
          ],
        ),
      ],
    );
  }

  Widget _highlightCard(String title, String main, String sub, IconData icon, bool isWhite) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco(isWhite),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFCC0020), size: 20),
            const SizedBox(height: 8),
            Text(title, style: GoogleFonts.sora(fontSize: 11, color: isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54)),
            Text(main, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: isWhite ? EleghartColors.accentDark : Colors.white)),
            Text(sub, style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCC0020))),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionChart(bool isWhite) {
    if (_categoryTotals.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: _cardDeco(isWhite),
        child: Center(
          child: Text(
            'No expense data for ${DateFilter.label}',
            style: GoogleFonts.sora(fontSize: 13, color: isWhite ? Colors.black54 : Colors.white54),
          ),
        ),
      );
    }

    Map<String, double> processedTotals = {};
    double otherTotal = 0;
    
    for (var entry in _categoryTotals.entries) {
      double percentage = _totalDebit > 0 ? (entry.value / _totalDebit) * 100 : 0;
      if (percentage < 3) {
        otherTotal += entry.value;
      } else {
        processedTotals[entry.key] = entry.value;
      }
    }

    if (otherTotal > 0) {
      processedTotals['Others'] = otherTotal;
    }
    
    var sortedEntries = processedTotals.entries.toList()
      ..sort((a, b) => a.key == 'Others' ? 1 : (b.key == 'Others' ? -1 : b.value.compareTo(a.value)));

    final List<Color> colors = [
      const Color(0xFF7F1D1D),
      const Color(0xFF991B1B),
      const Color(0xFFB91C1C),
      const Color(0xFFDC2626),
      const Color(0xFFEF4444),
      const Color(0xFFF87171),
      const Color(0xFFFCA5A5),
    ];

    return Container(
      height: 240,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: _cardDeco(isWhite),
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(enabled: false),
                    sectionsSpace: 3,
                    centerSpaceRadius: 55,
                    sections: sortedEntries.asMap().entries.map((mapEntry) {
                      final idx = mapEntry.key;
                      final e = mapEntry.value;
                      final color = colors[idx % colors.length];
                      
                      return PieChartSectionData(
                        color: color,
                        value: e.value,
                        title: '',
                        showTitle: false,
                        radius: 14,
                      );
                    }).toList(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('TOTAL SPENT', 
                      style: GoogleFonts.sora(
                        fontSize: 9, 
                        fontWeight: FontWeight.w700, 
                        letterSpacing: 0.5,
                        color: isWhite ? const Color(0xFF7F1D1D).withOpacity(0.6) : Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('₹${_totalDebit.toStringAsFixed(0)}', 
                      style: GoogleFonts.sora(
                        fontSize: 18, 
                        fontWeight: FontWeight.w800, 
                        color: isWhite ? const Color(0xFF7F1D1D) : Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 10,
            child: ListView(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              children: sortedEntries.asMap().entries.map((mapEntry) {
                final idx = mapEntry.key;
                final e = mapEntry.value;
                final color = colors[idx % colors.length];
                final percentage = _totalDebit > 0 ? (e.value / _totalDebit) * 100 : 0;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 9, 
                        height: 9, 
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.key, 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis, 
                          style: GoogleFonts.sora(
                            fontSize: 12, 
                            fontWeight: FontWeight.w600, 
                            color: isWhite ? const Color(0xFF1E1E1E) : Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%', 
                        style: GoogleFonts.sora(
                          fontSize: 11, 
                          fontWeight: FontWeight.w700, 
                          color: isWhite ? const Color(0xFF7F1D1D) : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations(bool isWhite) {
    return Column(
      children: [
        if (_topCategory != '-')
          _recCard(
            Icons.warning_amber_rounded,
            'Top Category Focus',
            'Your highest expenditure in ${DateFilter.label} is "$_topCategory" (₹${(_categoryTotals[_topCategory] ?? 0).toStringAsFixed(0)}). Monitoring this category can net immediate savings.',
            const Color(0xFFCC6600),
            isWhite,
          ),
        const SizedBox(height: 10),
        _recCard(
          Icons.savings_rounded,
          'Savings Optimization',
          'Reducing discretionary categories by 15% could add ₹${(_totalDebit * 0.15).toStringAsFixed(0)} to your monthly savings pool.',
          const Color(0xFF00CC66),
          isWhite,
        ),
      ],
    );
  }

  Widget _recCard(IconData icon, String title, String desc, Color color, bool isWhite) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(isWhite),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: isWhite ? EleghartColors.accentDark : Colors.white)),
                const SizedBox(height: 4),
                Text(desc, style: GoogleFonts.sora(fontSize: 12, color: isWhite ? EleghartColors.accentDark.withOpacity(0.7) : Colors.white70, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}