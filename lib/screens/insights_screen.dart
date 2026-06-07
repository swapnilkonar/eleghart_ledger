import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/expense_model.dart';
import '../models/group_model.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';
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

  // Analytics
  double _thisMonthTotal = 0;
  double _lastMonthTotal = 0;
  double _growth = 0;
  int _healthScore = 0;
  
  Map<String, double> _categoryTotals = {};
  ExpenseModel? _biggestExpense;
  String _topCategory = '-';
  String _mostActiveGroup = '-';

  @override
  void initState() {
    super.initState();
    AppThemeNotifier.instance.addListener(_onThemeChanged);
    _loadData();
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    final expenses = await StorageService.loadExpenses();
    final groups = await StorageService.loadGroups();
    final globalCats = await StorageService.loadGlobalCategories();

    // Build a set of all currently active/valid categories (case-insensitive)
    final Set<String> activeCategories = globalCats.map((c) => c.toLowerCase().trim()).toSet();
    for (var g in groups) {
      activeCategories.addAll(g.categories.map((c) => c.toLowerCase().trim()));
    }

    final now = DateTime.now();
    final thisMonthExpenses = expenses.where((e) => e.date.month == now.month && e.date.year == now.year && e.isDebit).toList();
    final lastMonthExpenses = expenses.where((e) => 
      (now.month == 1 ? e.date.month == 12 : e.date.month == now.month - 1) && 
      (now.month == 1 ? e.date.year == now.year - 1 : e.date.year == now.year) && e.isDebit).toList();

    _thisMonthTotal = thisMonthExpenses.fold(0, (sum, item) => sum + item.amount);
    _lastMonthTotal = lastMonthExpenses.fold(0, (sum, item) => sum + item.amount);

    if (_lastMonthTotal > 0) {
      _growth = ((_thisMonthTotal - _lastMonthTotal) / _lastMonthTotal) * 100;
    } else {
      _growth = 0;
    }

    // Reset before recalculating
    _categoryTotals.clear();
    _biggestExpense = null;
    _topCategory = '-';
    _mostActiveGroup = '-';

    // Category Totals
    for (var e in thisMonthExpenses) {
      final validCategories = e.categories.where((cat) {
        final lower = cat.toLowerCase().trim();
        if (lower == 'emi' || lower == 'recurring') return false;
        
        // Strict check: Only allow if it belongs to an active group or global category
        return activeCategories.contains(lower);
      }).toList();

      if (validCategories.isEmpty) {
        _categoryTotals['Others'] = (_categoryTotals['Others'] ?? 0) + e.amount;
      } else {
        for (var cat in validCategories) {
          _categoryTotals[cat] = (_categoryTotals[cat] ?? 0) + (e.amount / validCategories.length);
        }
      }
    }

    if (_categoryTotals.isNotEmpty) {
      var top = _categoryTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
      _topCategory = top.key;
    }

    if (thisMonthExpenses.isNotEmpty) {
      _biggestExpense = thisMonthExpenses.reduce((a, b) => a.amount > b.amount ? a : b);
    }

    // Group activity
    var groupCounts = <String, int>{};
    for (var e in expenses) {
      if (e.groupId != null) {
        groupCounts[e.groupId!] = (groupCounts[e.groupId!] ?? 0) + 1;
      }
    }
    if (groupCounts.isNotEmpty) {
      var topG = groupCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
      var g = groups.where((gr) => gr.id == topG.key).firstOrNull;
      if (g != null) _mostActiveGroup = g.name;
    }

    // Calculate Health Score
    double score = 100;
    if (_growth > 0) score -= _growth.clamp(0, 30); // deduct for spending more
    if (thisMonthExpenses.isEmpty) score = 0; // No data → 0
    _healthScore = score.toInt().clamp(0, 100);

    setState(() {
      _expenses = expenses;
      _groups = groups;
      _loading = false;
    });
  }

  void reload() {
    setState(() => _loading = true);
    _loadData();
  }

  // ── UI Helpers ────────────────────────────────────────────────────────────

  BoxDecoration _cardDeco(bool isWhite) => BoxDecoration(
    color: isWhite ? Colors.white : const Color(0xFF120404),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.15)),
    boxShadow: isWhite ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2))] : [],
  );

  Widget _sectionTitle(String title, bool isWhite) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: isWhite ? EleghartColors.accentDark : Colors.white)),
  );

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
            Text('AI Insights', style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary)),
            Text('Your personal financial analyst', style: GoogleFonts.sora(fontSize: 13, color: textSec)),
            const SizedBox(height: 20),

            // SECTION 1: AI Summary Card
            _buildSummaryCard(isWhite),
            const SizedBox(height: 24),

            // SECTION 2: Ask Eleghart AI
            _buildAskAiBar(isWhite),
            const SizedBox(height: 24),

            // SECTION 4: Health Score
            _sectionTitle('Financial Health', isWhite),
            _buildHealthScore(isWhite),
            const SizedBox(height: 24),

            // SECTION 5: Quick Highlights
            _sectionTitle('Quick Highlights', isWhite),
            _buildHighlights(isWhite),
            const SizedBox(height: 24),

            // SECTION 7: Distribution
            _sectionTitle('Spending Distribution', isWhite),
            _buildDistributionChart(isWhite),
            const SizedBox(height: 24),

            // SECTION 6 & 9: Recommendations & Savings
            _sectionTitle('AI Recommendations', isWhite),
            _buildRecommendations(isWhite),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isWhite) {
    final savings = _lastMonthTotal > 0 && _thisMonthTotal < _lastMonthTotal 
        ? _lastMonthTotal - _thisMonthTotal 
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF7A0010), Color(0xFFCC0020)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You spent', style: GoogleFonts.sora(fontSize: 12, color: Colors.white70)),
                Text('₹${_thisMonthTotal.toStringAsFixed(0)}', style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 12),
                if (_growth > 0)
                  Text('📈 Spending increased by ${_growth.toStringAsFixed(1)}%', style: GoogleFonts.sora(fontSize: 12, color: const Color(0xFFFFB3B3)))
                else
                  Text('📉 Spending decreased by ${_growth.abs().toStringAsFixed(1)}%', style: GoogleFonts.sora(fontSize: 12, color: const Color(0xFF00FF88))),
                if (savings > 0)
                  Text('💡 Potential savings: ₹${savings.toStringAsFixed(0)}', style: GoogleFonts.sora(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Image.asset('assets/icons/eleghart_icon.png'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAskAiBar(bool isWhite) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AiChatScreen(expenses: _expenses, groups: _groups))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isWhite ? const Color(0xFFF8F8F8) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Color(0xFFCC0020), size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text('Ask Eleghart AI...', style: GoogleFonts.sora(fontSize: 14, color: isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFCC0020).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('Ask', style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFCC0020))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthScore(bool isWhite) {
    String interpretation = "Average";
    Color color = Colors.orangeAccent;
    if (_healthScore >= 90) { interpretation = "Excellent"; color = const Color(0xFF00CC66); }
    else if (_healthScore >= 75) { interpretation = "Good"; color = Colors.blueAccent; }
    else if (_healthScore < 50) { interpretation = "Needs Attention"; color = const Color(0xFFFF3355); }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(isWhite),
      child: Row(
        children: [
          SizedBox(
            width: 140, height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120, height: 120,
                  child: CircularProgressIndicator(value: _healthScore / 100, strokeWidth: 12, color: color, backgroundColor: color.withOpacity(0.15)),
                ),
                Text('$_healthScore', style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w800, color: isWhite ? EleghartColors.accentDark : Colors.white)),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Health Score', style: GoogleFonts.sora(fontSize: 14, color: isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54)),
                Text(interpretation, style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 4),
                Text('Based on spending stability and budget compliance.', style: GoogleFonts.sora(fontSize: 11, color: isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white38)),
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
            _highlightCard('Active Group', _mostActiveGroup, 'Most transactions', Icons.group_rounded, isWhite),
            const SizedBox(width: 12),
            _highlightCard('Month Growth', '${_growth > 0 ? '+' : ''}${_growth.toStringAsFixed(1)}%', 'vs last month', Icons.trending_up_rounded, isWhite),
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
    if (_categoryTotals.isEmpty) return const SizedBox.shrink();

    // 1. Process data: Group small categories (< 3% for higher detail)
    Map<String, double> processedTotals = {};
    double otherTotal = 0;
    
    for (var entry in _categoryTotals.entries) {
      double percentage = (entry.value / _thisMonthTotal) * 100;
      if (percentage < 3) {
        otherTotal += entry.value;
      } else {
        processedTotals[entry.key] = entry.value;
      }
    }

    if (otherTotal > 0) {
      processedTotals['Others'] = otherTotal;
    }
    
    // Sort by largest first, 'Others' at the end
    var sortedEntries = processedTotals.entries.toList()
      ..sort((a, b) => a.key == 'Others' ? 1 : (b.key == 'Others' ? -1 : b.value.compareTo(a.value)));

    // Strict Elegant Monochromatic Red Palette
    final List<Color> colors = [
      const Color(0xFF7F1D1D), // Deep wine
      const Color(0xFF991B1B), // Rich crimson
      const Color(0xFFB91C1C), // Ruby red
      const Color(0xFFDC2626), // Premium red
      const Color(0xFFEF4444), // Soft coral
      const Color(0xFFF87171), // Blush red
      const Color(0xFFFCA5A5), // Muted rose
    ];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        height: 240,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: isWhite ? Colors.white : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(28),
          boxShadow: isWhite ? [
            BoxShadow(
              color: const Color(0xFF7F1D1D).withOpacity(0.08),
              blurRadius: 32,
              offset: const Offset(0, 12),
            )
          ] : [],
        ),
        child: Row(
          children: [
            // Left: Elegant Donut Chart
            Expanded(
              flex: 11,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(enabled: false),
                      sectionsSpace: 4, // Subtle spacing
                      centerSpaceRadius: 65, // Thin elegant ring
                      sections: sortedEntries.asMap().entries.map((mapEntry) {
                        final idx = mapEntry.key;
                        final e = mapEntry.value;
                        final color = colors[idx % colors.length];
                        
                        return PieChartSectionData(
                          color: color,
                          value: e.value,
                          title: '',
                          showTitle: false, // Clean, no clutter
                          radius: 12, // Thin elegant ring
                        );
                      }).toList(),
                    ),
                  ),
                  // Center Content
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('TOTAL SPENDING', 
                        style: GoogleFonts.sora(
                          fontSize: 9, 
                          fontWeight: FontWeight.w700, 
                          letterSpacing: 0.5,
                          color: isWhite ? const Color(0xFF7F1D1D).withOpacity(0.5) : Colors.white54
                        )
                      ),
                      const SizedBox(height: 4),
                      Text('₹${_thisMonthTotal.toStringAsFixed(0)}', 
                        style: GoogleFonts.sora(
                          fontSize: 20, 
                          fontWeight: FontWeight.w800, 
                          color: isWhite ? const Color(0xFF7F1D1D) : Colors.white
                        )
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right: Minimal Vertical Legend
            Expanded(
              flex: 9,
              child: ListView(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                children: sortedEntries.asMap().entries.map((mapEntry) {
                  final idx = mapEntry.key;
                  final e = mapEntry.value;
                  final color = colors[idx % colors.length];
                  final percentage = (e.value / _thisMonthTotal) * 100;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 10, 
                          height: 10, 
                          decoration: BoxDecoration(
                            color: color, 
                            shape: BoxShape.circle,
                            boxShadow: isWhite ? [
                              BoxShadow(color: color.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2))
                            ] : [],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            e.key, 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis, 
                            style: GoogleFonts.sora(
                              fontSize: 13, 
                              fontWeight: FontWeight.w600, 
                              color: isWhite ? const Color(0xFF1E1E1E) : Colors.white
                            )
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%', 
                          style: GoogleFonts.sora(
                            fontSize: 12, 
                            fontWeight: FontWeight.w700, 
                            color: isWhite ? const Color(0xFF7F1D1D).withOpacity(0.8) : Colors.white70
                          )
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations(bool isWhite) {
    return Column(
      children: [
        if (_growth > 0 && _topCategory != '-')
          _recCard(Icons.warning_amber_rounded, 'Overspending detected', 'You spent ${_growth.toStringAsFixed(0)}% more this month. Consider reducing spending in "$_topCategory" to stay on track.', const Color(0xFFCC6600), isWhite),
        const SizedBox(height: 10),
        _recCard(Icons.savings_rounded, 'Savings Goal', 'If you reduce non-essential expenses by 15%, you can easily save ₹${(_thisMonthTotal * 0.15).toStringAsFixed(0)} next month.', const Color(0xFF00CC66), isWhite),
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