import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../theme/eleghart_colors.dart';
import '../widgets/themed_background.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../services/storage_service.dart';
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
  late List<GroupModel> _groups;
  late List<ExpenseModel> _expenses;
  Map<String, String> _categoryImages = {};
  bool _dataChanged = false;

  @override
  void initState() {
    super.initState();
    _groups = List.from(widget.allGroups);
    _expenses = List.from(widget.allExpenses);
    _loadCategoryImages();
    DateFilter.notifier.addListener(_onFilter);
    AppThemeNotifier.instance.addListener(_onFilter);
  }

  Future<void> _loadCategoryImages() async {
    final imgs = await StorageService.loadCategoryImages();
    if (mounted) setState(() => _categoryImages = imgs);
  }

  Future<void> _reloadData() async {
    final g = await StorageService.loadGroups();
    final e = await StorageService.loadExpenses();
    final imgs = await StorageService.loadCategoryImages();
    if (mounted) setState(() { _groups = g; _expenses = e; _categoryImages = imgs; _dataChanged = true; });
  }

  @override
  void dispose() {
    DateFilter.notifier.removeListener(_onFilter);
    AppThemeNotifier.instance.removeListener(_onFilter);
    super.dispose();
  }

  void _onFilter() => setState(() {});

  // ── All unique category names across all groups ───────────────────────────
  List<String> get _allCategories =>
      _groups.expand((g) => g.categories).toSet().toList()..sort();

  // ── Net amount for a category across all expenses (date-filtered) ─────────
  Map<String, double> _netFor(String category) {
    final related = _expenses
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

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _dataChanged);
        return false;
      },
      child: Scaffold(
      backgroundColor: AppThemeNotifier.isWhite ? Colors.white : Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.72)),
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
                        onTap: () => Navigator.pop(context, _dataChanged),
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
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
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
                                color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
                              ),
                            ),
                            Text(
                              '${categories.length} member${categories.length != 1 ? 's' : ''} across all groups',
                              style: GoogleFonts.sora(
                                  fontSize: 11, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white38),
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
                                fontSize: 14, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white38),
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
                            final groupCount = _groups
                                .where((g) => g.categories.contains(cat))
                                .length;

                            return GestureDetector(
                              onTap: () async {
                                final changed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CategoryDetailScreen(
                                      categoryName: cat,
                                      allGroups: _groups,
                                      allExpenses: _expenses,
                                    ),
                                  ),
                                );
                                if (changed == true) await _reloadData();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppThemeNotifier.isWhite ? Colors.white : Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.15),
                                    width: 1,
                                  ),
                                  boxShadow: AppThemeNotifier.isWhite ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 2))] : [],
                                ),
                                child: Row(
                                  children: [
                                    // Avatar
                                    Builder(builder: (_) {
                                      final imgPath = _categoryImages[cat];
                                      final hasImg = imgPath != null && File(imgPath).existsSync();
                                      return Container(
                                        key: ValueKey('$cat-${imgPath ?? ''}'),
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFFCC0020).withOpacity(0.15),
                                          border: Border.all(
                                            color: const Color(0xFFCC0020).withOpacity(0.4),
                                            width: 1,
                                          ),
                                          image: hasImg
                                              ? DecorationImage(
                                                  image: FileImage(File(imgPath!)),
                                                  fit: BoxFit.cover)
                                              : null,
                                        ),
                                        child: hasImg
                                            ? null
                                            : Center(
                                                child: Text(
                                                  cat.isNotEmpty ? cat[0].toUpperCase() : '?',
                                                  style: GoogleFonts.sora(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
                                                  ),
                                                ),
                                              ),
                                      );
                                    }),
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
                                              color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$groupCount group${groupCount != 1 ? 's' : ''}  ·  ₹${debit.toStringAsFixed(0)} spent',
                                            style: GoogleFonts.sora(
                                                fontSize: 11,
                                                color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white38),
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
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.3) : Colors.white24,
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
      ),
    );
  }
}
