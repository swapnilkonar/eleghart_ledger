import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/expense_model.dart';
import '../models/group_model.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import 'expenses_screen.dart';
import 'recurring_expense_list_screen.dart';
import 'emi_list_screen.dart';

class ExpenseListScreen extends StatefulWidget {
  final VoidCallback? onExpenseAdded;

  const ExpenseListScreen({super.key, this.onExpenseAdded});

  @override
  State<ExpenseListScreen> createState() => ExpenseListScreenState();
}

class ExpenseListScreenState extends State<ExpenseListScreen> {
  List<ExpenseModel> _expenses = [];
  List<GroupModel> _groups = [];
  String _activeCategory = 'All';
  DateTime _selectedMonth = DateTime.now();
  final Set<String> _selectedIds = {};

  static const _tabs = ['All', 'Food', 'Travel', 'Shopping', 'Bills', 'Others'];

  @override
  void initState() {
    super.initState();
    AppThemeNotifier.instance.addListener(_onThemeChanged);
    reload();
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> reload() async {
    final e = await StorageService.loadExpenses();
    final g = await StorageService.loadGroups();
    if (mounted) {
      setState(() {
        _expenses = e;
        _groups = g;
      });
    }
  }

  // ─── filtering ─────────────────────────────────────────────────────────────

  bool _matchesTab(ExpenseModel e) {
    if (_activeCategory == 'All') return true;
    final cats = e.categories.map((c) => c.toLowerCase()).join(' ');
    switch (_activeCategory) {
      case 'Food':
        return cats.contains('food') ||
            cats.contains('dining') ||
            cats.contains('restaurant') ||
            cats.contains('café') ||
            cats.contains('coffee');
      case 'Travel':
        return cats.contains('travel') ||
            cats.contains('uber') ||
            cats.contains('ola') ||
            cats.contains('cab') ||
            cats.contains('transport') ||
            cats.contains('flight');
      case 'Shopping':
        return cats.contains('shop') ||
            cats.contains('retail') ||
            cats.contains('amazon') ||
            cats.contains('mall');
      case 'Bills':
        return cats.contains('bill') ||
            cats.contains('util') ||
            cats.contains('electr') ||
            cats.contains('water') ||
            cats.contains('rent');
      default:
        return !_matchesMajorTab(e);
    }
  }

  bool _matchesMajorTab(ExpenseModel e) {
    final cats = e.categories.map((c) => c.toLowerCase()).join(' ');
    return cats.contains('food') ||
        cats.contains('dining') ||
        cats.contains('travel') ||
        cats.contains('uber') ||
        cats.contains('shop') ||
        cats.contains('retail') ||
        cats.contains('bill') ||
        cats.contains('util');
  }

  List<ExpenseModel> get _filtered => _expenses
      .where((e) =>
          e.date.year == _selectedMonth.year &&
          e.date.month == _selectedMonth.month &&
          _matchesTab(e))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  double get _filteredTotal =>
      _filtered.fold(0.0, (s, e) => s + (e.isDebit ? e.amount : -e.amount));

  // ─── helpers ───────────────────────────────────────────────────────────────

  IconData _icon(List<String> cats) {
    final c = cats.join(' ').toLowerCase();
    if (c.contains('food') || c.contains('dining') || c.contains('restaurant'))
      return Icons.restaurant_rounded;
    if (c.contains('travel') ||
        c.contains('uber') ||
        c.contains('cab') ||
        c.contains('transport')) return Icons.directions_car_rounded;
    if (c.contains('shop') || c.contains('retail'))
      return Icons.shopping_bag_outlined;
    if (c.contains('fuel') || c.contains('gas') || c.contains('petrol'))
      return Icons.local_gas_station_rounded;
    if (c.contains('bill') || c.contains('util') || c.contains('electr'))
      return Icons.receipt_long_rounded;
    if (c.contains('health') || c.contains('medical'))
      return Icons.health_and_safety_rounded;
    return Icons.category_rounded;
  }

  String _groupName(String groupId) {
    try {
      return _groups.firstWhere((g) => g.id == groupId).name;
    } catch (_) {
      return '';
    }
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }

  // ─── selection ─────────────────────────────────────────────────────────────

  void _toggle(String id) => setState(() =>
      _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id));

  void _clearSelection() => setState(() => _selectedIds.clear());

  Future<void> _deleteSelected() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete expenses?'),
        content: Text('Delete ${_selectedIds.length} selected expense(s)?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final updated =
          _expenses.where((e) => !_selectedIds.contains(e.id)).toList();
      await StorageService.saveExpenses(updated);
      _clearSelection();
      reload();
    }
  }

  void _showBulkSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BulkActionsSheet(
        selectedIds: Set.from(_selectedIds),
        expenses: _expenses,
        groups: _groups,
        onApplied: () {
          _clearSelection();
          reload();
          widget.onExpenseAdded?.call();
        },
      ),
    );
  }

  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonthPickerSheet(
        current: _selectedMonth,
        onSelected: (m) => setState(() => _selectedMonth = m),
      ),
    );
  }

  Future<void> _openAddExpense() async {
    await _showAddTypePicker();
  }

  Future<void> _showAddTypePicker() async {
    final isWhite = AppThemeNotifier.isWhite;
    final sheetBg = isWhite ? Colors.white : const Color(0xFF120404);
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite
        ? EleghartColors.accentDark.withOpacity(0.5)
        : Colors.white54;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: textSec.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('What do you want to add?',
                style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary)),
            const SizedBox(height: 20),
            _typeOption(
              Icons.receipt_long_rounded,
              '💸  Expense',
              'One-time payment or income',
              textPrimary, textSec, sheetBg,
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const ExpensesScreen()));
                reload();
                widget.onExpenseAdded?.call();
              },
            ),
            const SizedBox(height: 10),
            _typeOption(
              Icons.repeat_rounded,
              '🔄  Recurring',
              'Weekly, Monthly or Yearly auto-expense',
              textPrimary, textSec, sheetBg,
              accent: const Color(0xFF6366F1),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const RecurringExpenseListScreen()));
                reload();
                widget.onExpenseAdded?.call();
              },
            ),
            const SizedBox(height: 10),
            _typeOption(
              Icons.credit_card_outlined,
              '📱  EMI',
              'Track monthly instalments & progress',
              textPrimary, textSec, sheetBg,
              accent: const Color(0xFF0EA5E9),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const EmiListScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeOption(
    IconData icon,
    String title,
    String subtitle,
    Color textPrimary,
    Color textSec,
    Color sheetBg, {
    Color accent = const Color(0xFFCC0020),
    required VoidCallback onTap,
  }) {
    final isWhite = AppThemeNotifier.isWhite;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: accent.withOpacity(isWhite ? 0.05 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.12),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPrimary)),
                Text(subtitle,
                    style: GoogleFonts.sora(
                        fontSize: 11, color: textSec)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: textSec),
        ]),
      ),
    );
  }

  // ─── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSecondary =
        isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54;
    final cardColor = isWhite ? Colors.white : const Color(0xFF120404);
    final borderColor =
        isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.08);
    final isSelecting = _selectedIds.isNotEmpty;
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isSelecting ? null : _buildFab(),
      body: SafeArea(
        child: Column(
          children: [
            _buildCategoryChips(cardColor, borderColor, textSecondary),
            _buildSummaryRow(filtered, textSecondary),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmpty(textSecondary)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _buildItem(
                          filtered[i],
                          isSelecting,
                          cardColor,
                          borderColor,
                          textPrimary,
                          textSecondary,
                          isWhite),
                    ),
            ),
            if (isSelecting)
              _buildBulkBar(isWhite, textPrimary, textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildFab() => Padding(
        padding: const EdgeInsets.only(bottom: 104.0, right: 8.0),
        child: SizedBox(
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF7A0010), Color(0xFFCC0020)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 6))
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _openAddExpense,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              label: Text('Add',
                  style: GoogleFonts.sora(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
          ),
        ),
      );

  Widget _buildCategoryChips(
          Color cardColor, Color borderColor, Color textSecondary) =>
      SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: _tabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final tab = _tabs[i];
            final sel = tab == _activeCategory;
            return GestureDetector(
              onTap: () => setState(() => _activeCategory = tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFFCC0020) : cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel
                          ? const Color(0xFFCC0020)
                          : borderColor),
                ),
                child: Text(tab,
                    style: GoogleFonts.sora(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : textSecondary)),
              ),
            );
          },
        ),
      );

  Widget _buildSummaryRow(List<ExpenseModel> filtered, Color textSecondary) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${filtered.length} expense${filtered.length == 1 ? '' : 's'}  •  ₹${_fmt(_filteredTotal.abs())}',
                style: GoogleFonts.sora(fontSize: 12, color: textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _showMonthPicker,
              child: Row(children: [
                Text(DateFormat('MMM yyyy').format(_selectedMonth),
                    style: GoogleFonts.sora(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFCC0020))),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16, color: Color(0xFFCC0020)),
              ]),
            ),
          ],
        ),
      );

  Widget _buildItem(
      ExpenseModel e,
      bool isSelecting,
      Color cardColor,
      Color borderColor,
      Color textPrimary,
      Color textSecondary,
      bool isWhite) {
    final isSel = _selectedIds.contains(e.id);
    final cat = e.categories.isNotEmpty ? e.categories.first : 'Others';
    final grp = _groupName(e.groupId);
    final hasReceipt =
        e.imagePath != null && File(e.imagePath!).existsSync();

    return GestureDetector(
      onLongPress: () => _toggle(e.id),
      onTap: isSelecting ? () => _toggle(e.id) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSel
              ? const Color(0xFFCC0020).withOpacity(isWhite ? 0.08 : 0.15)
              : cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSel
                  ? const Color(0xFFCC0020).withOpacity(0.5)
                  : borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Checkbox (select mode) ──────────────────────
            if (isSelecting) ...[
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: isSel,
                  onChanged: (_) => _toggle(e.id),
                  activeColor: const Color(0xFFCC0020),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  side: BorderSide(color: textSecondary, width: 1.5),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // ── Category icon ───────────────────────────────
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFCC0020)
                    .withOpacity(isWhite ? 0.08 : 0.15),
              ),
              child: Icon(_icon(e.categories),
                  color: const Color(0xFFCC0020), size: 18),
            ),
            const SizedBox(width: 10),

            // ── Main content ────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description + amount row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          e.description.trim().isEmpty ? 'Expense' : e.description,
                          style: GoogleFonts.sora(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${e.isDebit ? '-' : '+'}₹${_fmt(e.amount)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: e.isDebit
                                ? const Color(0xFFCC0020)
                                : Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Chips row: category + group
                  Row(
                    children: [
                      Flexible(
                        child: _infoChip(cat, Icons.label_outline_rounded,
                            const Color(0xFFCC0020), isWhite),
                      ),
                      if (grp.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: _infoChip(grp, Icons.group_outlined,
                              isWhite
                                  ? EleghartColors.accentDark
                                  : Colors.white70,
                              isWhite),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Date + receipt badge
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 10, color: textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('d MMM yyyy').format(e.date),
                        style: GoogleFonts.sora(
                            fontSize: 11, color: textSecondary),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _badgesRow(e, textSecondary),
                              if (hasReceipt) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF22C55E)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.receipt_rounded,
                                          size: 10, color: Color(0xFF22C55E)),
                                      const SizedBox(width: 3),
                                      Text('Receipt',
                                          style: GoogleFonts.sora(
                                              fontSize: 9,
                                              color: const Color(0xFF22C55E),
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Receipt thumbnail ───────────────────────────
            if (hasReceipt) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _showReceiptDialog(e.imagePath!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(e.imagePath!),
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCC0020).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.broken_image_outlined,
                          color: Color(0xFFCC0020), size: 20),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badgesRow(ExpenseModel e, Color textSec) {
    final cats = e.categories.map((c) => c.toLowerCase()).toList();
    final isRecurring = cats.contains('recurring');
    final isEmi = cats.contains('emi');
    if (!isRecurring && !isEmi) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isRecurring) ...[  
          const SizedBox(width: 8),
          _typeBadge('Recurring', Icons.repeat_rounded,
              const Color(0xFF6366F1)),
        ],
        if (isEmi) ...[  
          const SizedBox(width: 8),
          _typeBadge('EMI', Icons.credit_card_outlined,
              const Color(0xFF0EA5E9)),
        ],
      ],
    );
  }

  Widget _typeBadge(String label, IconData icon, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 9, color: color),
            const SizedBox(width: 3),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                      fontSize: 9,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _infoChip(String label, IconData icon, Color color, bool isWhite) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(isWhite ? 0.08 : 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
            Flexible(
              child: Text(label,
                  style: GoogleFonts.sora(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );

  void _showReceiptDialog(String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(Color textSecondary) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 56, color: textSecondary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No expenses this month',
                style:
                    GoogleFonts.sora(fontSize: 15, color: textSecondary)),
            const SizedBox(height: 6),
            Text('Tap + Add Expense to get started',
                style: GoogleFonts.sora(
                    fontSize: 12,
                    color: textSecondary.withOpacity(0.6))),
          ],
        ),
      );

  Widget _buildBulkBar(
          bool isWhite, Color textPrimary, Color textSecondary) =>
      Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: isWhite ? Colors.white : const Color(0xFF1A0505),
          border: Border(
              top: BorderSide(
                  color: isWhite
                      ? const Color(0xFFEEEEEE)
                      : Colors.white.withOpacity(0.08))),
        ),
        child: Row(
          children: [
            Text('${_selectedIds.length} Selected',
                style: GoogleFonts.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFCC0020))),
            const Spacer(),
            _barBtn(Icons.label_outline_rounded, 'Category', textSecondary,
                _showBulkSheet),
            const SizedBox(width: 20),
            _barBtn(Icons.group_outlined, 'Group', textSecondary, _showBulkSheet),
            const SizedBox(width: 20),
            _barBtn(Icons.delete_outline_rounded, 'Delete', Colors.red,
                _deleteSelected),
            const SizedBox(width: 20),
            _barBtn(Icons.more_horiz_rounded, 'More', textSecondary,
                _showBulkSheet),
          ],
        ),
      );

  Widget _barBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(label,
                style: GoogleFonts.sora(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
}

// ─── Bulk Actions Sheet ────────────────────────────────────────────────────────

class _BulkActionsSheet extends StatefulWidget {
  final Set<String> selectedIds;
  final List<ExpenseModel> expenses;
  final List<GroupModel> groups;
  final VoidCallback onApplied;

  const _BulkActionsSheet({
    required this.selectedIds,
    required this.expenses,
    required this.groups,
    required this.onApplied,
  });

  @override
  State<_BulkActionsSheet> createState() => _BulkActionsSheetState();
}

class _BulkActionsSheetState extends State<_BulkActionsSheet> {
  String _category = 'Food & Dining';
  GroupModel? _selectedGroup;
  final _noteCtrl = TextEditingController();
  bool _applying = false;

  static const _categories = [
    'Food & Dining',
    'Travel',
    'Shopping',
    'Bills & Utilities',
    'Fuel',
    'Entertainment',
    'Health',
    'Others'
  ];

  List<ExpenseModel> get _selected =>
      widget.expenses.where((e) => widget.selectedIds.contains(e.id)).toList();

  double get _total => _selected.fold(0.0, (s, e) => s + e.amount);

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    final note = _noteCtrl.text.trim();
    final updated = widget.expenses.map((e) {
      if (!widget.selectedIds.contains(e.id)) return e;
      return e.copyWith(
        categories: [_category],
        groupId: _selectedGroup?.id,
        description: note.isNotEmpty ? '${e.description} · $note' : null,
      );
    }).toList();
    await StorageService.saveExpenses(updated);
    if (mounted) Navigator.pop(context);
    widget.onApplied();
  }

  IconData _catIcon(String c) {
    final l = c.toLowerCase();
    if (l.contains('food') || l.contains('dining'))
      return Icons.restaurant_rounded;
    if (l.contains('travel')) return Icons.directions_car_rounded;
    if (l.contains('shop')) return Icons.shopping_bag_outlined;
    if (l.contains('bill') || l.contains('util'))
      return Icons.receipt_long_rounded;
    if (l.contains('fuel')) return Icons.local_gas_station_rounded;
    if (l.contains('entertain')) return Icons.movie_outlined;
    if (l.contains('health')) return Icons.health_and_safety_rounded;
    return Icons.category_rounded;
  }

  void _pickGroup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupPickerSheet(
        groups: widget.groups,
        selected: _selectedGroup,
        onPicked: (g) => setState(() => _selectedGroup = g),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final bg = isWhite ? Colors.white : const Color(0xFF120404);
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSecondary =
        isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54;
    final border = isWhite
        ? const Color(0xFFEEEEEE)
        : Colors.white.withOpacity(0.08);
    final inputBg =
        isWhite ? const Color(0xFFF8F8F8) : const Color(0xFF1C0606);

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: border,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('${_selected.length} expenses selected',
                  style:
                      GoogleFonts.sora(fontSize: 13, color: textSecondary)),
              Text('₹${_total.toStringAsFixed(2)}',
                  style: GoogleFonts.sora(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFCC0020))),
              const SizedBox(height: 24),

              // ── Update Category ──
              _sectionLabel('Update Category', textSecondary),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border)),
                child: DropdownButton<String>(
                  value: _category,
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: bg,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: textSecondary),
                  onChanged: (v) => setState(() => _category = v!),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Row(children: [
                              Icon(_catIcon(c),
                                  size: 18,
                                  color: const Color(0xFFCC0020)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(c,
                                    style: GoogleFonts.sora(
                                        fontSize: 14, color: textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),

              // ── Add to Group ──
              _sectionLabel('Add to Group (optional)', textSecondary),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickGroup,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border)),
                  child: Row(
                    children: [
                      Icon(Icons.group_outlined,
                          size: 18, color: const Color(0xFFCC0020)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                        _selectedGroup?.name ?? 'Select Group',
                        style: GoogleFonts.sora(
                            fontSize: 14,
                            color: _selectedGroup != null
                                ? textPrimary
                                : textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
                      if (_selectedGroup != null)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _selectedGroup = null),
                          child: Icon(Icons.close_rounded,
                              size: 18, color: textSecondary),
                        )
                      else
                        Icon(Icons.keyboard_arrow_down_rounded,
                            color: textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Add Note ──
              _sectionLabel('Add Note (optional)', textSecondary),
              const SizedBox(height: 8),
              TextField(
                controller: _noteCtrl,
                style:
                    GoogleFonts.sora(fontSize: 14, color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g., Lunch during team trip',
                  hintStyle: GoogleFonts.sora(
                      fontSize: 14, color: textSecondary),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFFCC0020))),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                ),
              ),
              const SizedBox(height: 28),

              // ── Apply ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF7A0010), Color(0xFFCC0020)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _applying ? null : _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _applying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text('Apply Changes',
                            style: GoogleFonts.sora(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: GoogleFonts.sora(
                          color: const Color(0xFFCC0020), fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) => Row(
        children: [
          Icon(Icons.edit_outlined, size: 13, color: color),
          const SizedBox(width: 6),
          Text(text,
              style: GoogleFonts.sora(fontSize: 12, color: color)),
        ],
      );
}

// ─── Group Picker Sheet ────────────────────────────────────────────────────────

class _GroupPickerSheet extends StatelessWidget {
  final List<GroupModel> groups;
  final GroupModel? selected;
  final ValueChanged<GroupModel?> onPicked;

  const _GroupPickerSheet(
      {required this.groups, this.selected, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final bg = isWhite ? Colors.white : const Color(0xFF120404);
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSecondary =
        isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54;

    return Container(
      decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Select Group',
              style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: ListView(
              shrinkWrap: true,
              children: groups
                  .map((g) => ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              const Color(0xFFCC0020).withOpacity(0.12),
                          backgroundImage: g.imagePath != null &&
                                  File(g.imagePath!).existsSync()
                              ? FileImage(File(g.imagePath!))
                              : null,
                          child: g.imagePath == null
                              ? const Icon(Icons.group,
                                  color: Color(0xFFCC0020), size: 18)
                              : null,
                        ),
                        title: Text(g.name,
                            style: GoogleFonts.sora(color: textPrimary)),
                        trailing: selected?.id == g.id
                            ? const Icon(Icons.check_circle,
                                color: Color(0xFFCC0020))
                            : null,
                        onTap: () {
                          onPicked(selected?.id == g.id ? null : g);
                          Navigator.pop(context);
                        },
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Month Picker Sheet ────────────────────────────────────────────────────────

class _MonthPickerSheet extends StatefulWidget {
  final DateTime current;
  final ValueChanged<DateTime> onSelected;

  const _MonthPickerSheet({required this.current, required this.onSelected});

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.current.year;
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final bg = isWhite ? Colors.white : const Color(0xFF120404);
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSecondary =
        isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();

    return Container(
      decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left_rounded, color: textPrimary),
                onPressed: () => setState(() => _year--),
              ),
              Text('$_year',
                  style: GoogleFonts.sora(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPrimary)),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded, color: textPrimary),
                onPressed: _year < now.year
                    ? () => setState(() => _year++)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            childAspectRatio: 2.2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: List.generate(12, (i) {
              final m = DateTime(_year, i + 1);
              final sel = m.year == widget.current.year &&
                  m.month == widget.current.month;
              final future = m.isAfter(DateTime(now.year, now.month));
              return GestureDetector(
                onTap: future
                    ? null
                    : () {
                        widget.onSelected(m);
                        Navigator.pop(context);
                      },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFFCC0020)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: sel
                            ? const Color(0xFFCC0020)
                            : textSecondary.withOpacity(0.2)),
                  ),
                  child: Text(months[i],
                      style: GoogleFonts.sora(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel
                              ? Colors.white
                              : future
                                  ? textSecondary.withOpacity(0.3)
                                  : textPrimary)),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
