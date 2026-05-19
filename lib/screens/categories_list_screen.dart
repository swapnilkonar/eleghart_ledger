import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../utils/date_filter.dart';
import '../widgets/date_filter_pill.dart';
import 'category_detail_screen.dart';

class CategoriesListScreen extends StatefulWidget {
  final List<GroupModel> allGroups;
  final List<ExpenseModel> allExpenses;

  const CategoriesListScreen({
    super.key,
    required this.allGroups,
    required this.allExpenses,
  });

  @override
  State<CategoriesListScreen> createState() => _CategoriesListScreenState();
}

class _CategoriesListScreenState extends State<CategoriesListScreen> {
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

  // ── All unique category names across all groups ───────────────────────────
  List<String> get _allCategories =>
      widget.allGroups.expand((g) => g.categories).toSet().toList()..sort();

  // ── Net amount for a category across all expenses (date-filtered) ─────────
  Map<String, double> _netFor(String category) {
    final related = widget.allExpenses
        .where((e) =>
            e.categories.contains(category) && DateFilter.isInRange(e.date))
        .toList();

    double debit = 0;
    double credit = 0;
    for (final e in related) {
      final share = e.amount / e.categories.length;
      if (e.type == 'debit') {
        debit += share;
      } else {
        credit += share;
      }
    }
    return {'debit': debit, 'credit': credit, 'net': credit - debit};
  }

  @override
  Widget build(BuildContext context) {
    final categories = _allCategories;

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
                // ── App bar ───────────────────────────────────────────────
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
                              'Categories',
                              style: GoogleFonts.sora(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${categories.length} member${categories.length != 1 ? 's' : ''} across all groups',
                              style: GoogleFonts.sora(
                                  fontSize: 11, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                      const DateFilterPill(),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Category list ─────────────────────────────────────────
                Expanded(
                  child: categories.isEmpty
                      ? Center(
                          child: Text(
                            'No categories found.',
                            style: GoogleFonts.sora(
                                fontSize: 14, color: Colors.white38),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: categories.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final cat = categories[i];
                            final stats = _netFor(cat);
                            final net = stats['net']!;
                            final debit = stats['debit']!;
                            final credit = stats['credit']!;
                            final isPositive = net >= 0;
                            final netColor = isPositive
                                ? const Color(0xFF00CC66)
                                : const Color(0xFFFF3355);

                            // Count groups this category belongs to
                            final groupCount = widget.allGroups
                                .where((g) => g.categories.contains(cat))
                                .length;

                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CategoryDetailScreen(
                                    categoryName: cat,
                                    allGroups: widget.allGroups,
                                    allExpenses: widget.allExpenses,
                                  ),
                                ),
                              ),
                              child: Container(
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
                                    // Avatar
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFFCC0020)
                                            .withOpacity(0.15),
                                        border: Border.all(
                                          color: const Color(0xFFCC0020)
                                              .withOpacity(0.4),
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          cat.isNotEmpty
                                              ? cat[0].toUpperCase()
                                              : '?',
                                          style: GoogleFonts.sora(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cat,
                                            style: GoogleFonts.sora(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$groupCount group${groupCount != 1 ? 's' : ''}  ·  ₹${debit.toStringAsFixed(0)} spent',
                                            style: GoogleFonts.sora(
                                                fontSize: 11,
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
                                          '₹${net.abs().toStringAsFixed(0)}',
                                          style: GoogleFonts.sora(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: netColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isPositive ? 'net credit' : 'net debit',
                                          style: GoogleFonts.sora(
                                              fontSize: 10,
                                              color: netColor
                                                  .withOpacity(0.7)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.white24,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
