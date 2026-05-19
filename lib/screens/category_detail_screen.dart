import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../services/pdf_export_service.dart';
import '../utils/date_filter.dart';
import '../widgets/date_filter_pill.dart';

class CategoryDetailScreen extends StatefulWidget {
  final String categoryName;
  final List<GroupModel> allGroups;
  final List<ExpenseModel> allExpenses;

  const CategoryDetailScreen({
    super.key,
    required this.categoryName,
    required this.allGroups,
    required this.allExpenses,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    DateFilter.notifier.addListener(_onFilter);
  }

  @override
  void dispose() {
    DateFilter.notifier.removeListener(_onFilter);
    super.dispose();
  }

  void _onFilter() => setState(() {});

  // ── Filtered expenses for this category ──────────────────────────────────
  List<ExpenseModel> get _filtered => widget.allExpenses
      .where((e) =>
          e.categories.contains(widget.categoryName) &&
          DateFilter.isInRange(e.date))
      .toList();

  // ── Overall stats ─────────────────────────────────────────────────────────
  Map<String, double> get _overallStats {
    double debit = 0;
    double credit = 0;
    for (final e in _filtered) {
      final share = e.amount / e.categories.length;
      if (e.type == 'debit') debit += share;
      else credit += share;
    }
    return {'debit': debit, 'credit': credit, 'net': credit - debit};
  }

  // ── Per-group stats ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _groupStats {
    final result = <Map<String, dynamic>>[];
    for (final g in widget.allGroups) {
      if (!g.categories.contains(widget.categoryName)) continue;
      final expenses = _filtered.where((e) => e.groupId == g.id).toList();
      if (expenses.isEmpty) continue;
      double debit = 0;
      double credit = 0;
      for (final e in expenses) {
        final share = e.amount / e.categories.length;
        if (e.type == 'debit') debit += share;
        else credit += share;
      }
      result.add({
        'group': g,
        'debit': debit,
        'credit': credit,
        'net': credit - debit,
        'count': expenses.length,
      });
    }
    result.sort((a, b) => (b['debit'] as double).compareTo(a['debit'] as double));
    return result;
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);

    final now = DateTime.now();
    DateTime from;
    DateTime to;

    switch (DateFilter.current) {
      case DateFilterType.currentMonth:
        from = DateTime(now.year, now.month, 1);
        to   = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case DateFilterType.lastMonth:
        final last = DateTime(now.year, now.month - 1);
        from = DateTime(last.year, last.month, 1);
        to   = DateTime(last.year, last.month + 1, 0, 23, 59, 59);
        break;
      case DateFilterType.allTime:
        from = DateTime(2000, 1, 1);
        to   = DateTime(2099, 12, 31, 23, 59, 59);
        break;
      case DateFilterType.custom:
        final cm = DateFilter.customMonth ?? now;
        from = DateTime(cm.year, cm.month, 1);
        to   = DateTime(cm.year, cm.month + 1, 0, 23, 59, 59);
        break;
    }

    final file = await PdfExportService.exportCategoryReport(
      categoryName: widget.categoryName,
      expenses: _filtered,
      groups: widget.allGroups,
      from: from,
      to: to,
    );

    if (!mounted) return;
    setState(() => _exporting = false);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF120404),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFCC0020).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFCC0020).withOpacity(0.4), width: 1),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded,
                  size: 26, color: Color(0xFFCC0020)),
            ),
            const SizedBox(height: 14),
            Text('PDF Exported',
                style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Text(file.path.split('/').last,
                style:
                    GoogleFonts.sora(fontSize: 12, color: Colors.white38)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Share.shareXFiles([XFile(file.path)]);
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFCC0020).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFCC0020).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.share_rounded,
                        color: Color(0xFFCC0020), size: 16),
                    const SizedBox(width: 8),
                    Text('Share PDF',
                        style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _overallStats;
    final net = stats['net']!;
    final debit = stats['debit']!;
    final credit = stats['credit']!;
    final isPositive = net >= 0;
    final netColor =
        isPositive ? const Color(0xFF00CC66) : const Color(0xFFFF3355);
    final groupStats = _groupStats;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_theme_top_glow.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.72)),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── App bar ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  const Color(0xFFCC0020).withOpacity(0.6),
                              width: 1.5,
                            ),
                            color:
                                const Color(0xFFCC0020).withOpacity(0.10),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.categoryName,
                              style: GoogleFonts.sora(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Category overview',
                              style: GoogleFonts.sora(
                                  fontSize: 11, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                      // PDF export icon
                      GestureDetector(
                        onTap: _exporting ? null : _exportPdf,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  const Color(0xFFCC0020).withOpacity(0.4),
                              width: 1,
                            ),
                            color:
                                const Color(0xFFCC0020).withOpacity(0.08),
                          ),
                          child: _exporting
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFCC0020),
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf_rounded,
                                  color: Color(0xFFCC0020), size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const DateFilterPill(),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Top net card ─────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF120404),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFCC0020).withOpacity(0.4),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFCC0020).withOpacity(0.2),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Avatar + name
                              Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFCC0020)
                                          .withOpacity(0.15),
                                      border: Border.all(
                                        color: const Color(0xFFCC0020)
                                            .withOpacity(0.5),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        widget.categoryName.isNotEmpty
                                            ? widget.categoryName[0]
                                                .toUpperCase()
                                            : '?',
                                        style: GoogleFonts.sora(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.categoryName,
                                        style: GoogleFonts.sora(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        DateFilter.label,
                                        style: GoogleFonts.sora(
                                            fontSize: 12,
                                            color: Colors.white38),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Container(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.07)),
                              const SizedBox(height: 16),
                              // Stats row
                              Row(
                                children: [
                                  _statCell(
                                    'Total Debit',
                                    '₹${debit.toStringAsFixed(0)}',
                                    const Color(0xFFFF3355),
                                  ),
                                  _divider(),
                                  _statCell(
                                    'Total Credit',
                                    '₹${credit.toStringAsFixed(0)}',
                                    const Color(0xFF00CC66),
                                  ),
                                  _divider(),
                                  _statCell(
                                    'Net Balance',
                                    '₹${net.abs().toStringAsFixed(0)}',
                                    netColor,
                                    sub: isPositive ? 'owed' : 'owes',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Per-group breakdown header ────────────────────
                        Text(
                          'Group Breakdown',
                          style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (groupStats.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.08)),
                            ),
                            child: Center(
                              child: Text(
                                'No expenses for ${DateFilter.label}',
                                style: GoogleFonts.sora(
                                    fontSize: 13, color: Colors.white38),
                              ),
                            ),
                          )
                        else
                          ...groupStats.map((s) {
                            final g = s['group'] as GroupModel;
                            final gDebit = s['debit'] as double;
                            final gCredit = s['credit'] as double;
                            final gNet = s['net'] as double;
                            final gCount = s['count'] as int;
                            final gPos = gNet >= 0;
                            final gColor = gPos
                                ? const Color(0xFF00CC66)
                                : const Color(0xFFFF3355);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFCC0020)
                                      .withOpacity(0.15),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFCC0020)
                                          .withOpacity(0.12),
                                    ),
                                    child: const Icon(
                                        Icons.folder_rounded,
                                        color: Color(0xFFCC0020),
                                        size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          g.name,
                                          style: GoogleFonts.sora(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$gCount expense${gCount != 1 ? 's' : ''}  ·  ₹${gDebit.toStringAsFixed(0)} debit  ·  ₹${gCredit.toStringAsFixed(0)} credit',
                                          style: GoogleFonts.sora(
                                              fontSize: 10.5,
                                              color: Colors.white38),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${gNet.abs().toStringAsFixed(0)}',
                                        style: GoogleFonts.sora(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: gColor,
                                        ),
                                      ),
                                      Text(
                                        gPos ? 'credit' : 'debit',
                                        style: GoogleFonts.sora(
                                            fontSize: 10,
                                            color: gColor.withOpacity(0.7)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
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

  Widget _statCell(String label, String value, Color color,
      {String? sub}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub != null ? '$label\n$sub' : label,
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(fontSize: 10.5, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 40,
        color: Colors.white.withOpacity(0.07),
      );
}
