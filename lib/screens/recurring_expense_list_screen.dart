import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/group_model.dart';
import '../models/recurring_expense_model.dart';
import '../services/storage_service.dart';
import '../services/recurring_engine.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';
import 'add_recurring_expense_screen.dart';

class RecurringExpenseListScreen extends StatefulWidget {
  const RecurringExpenseListScreen({super.key});

  @override
  State<RecurringExpenseListScreen> createState() =>
      _RecurringExpenseListScreenState();
}

class _RecurringExpenseListScreenState
    extends State<RecurringExpenseListScreen> {
  List<RecurringExpenseModel> _list = [];
  List<GroupModel> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    AppThemeNotifier.instance.addListener(_onTheme);
    _load();
  }

  void _onTheme() => setState(() {});

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_onTheme);
    super.dispose();
  }

  Future<void> _load() async {
    final r = await StorageService.loadRecurring();
    final g = await StorageService.loadGroups();
    if (mounted) setState(() { _list = r; _groups = g; _loading = false; });
  }

  String _groupName(String id) {
    try { return _groups.firstWhere((g) => g.id == id).name; } catch (_) { return ''; }
  }

  // ── summary stats
  int get _activeCount => _list.where((r) => r.isActive).length;
  double get _monthlyTotal {
    double t = 0;
    for (final r in _list.where((r) => r.isActive)) {
      switch (r.frequency) {
        case 'weekly': t += r.amount * 4.33; break;
        case 'monthly': t += r.amount; break;
        case 'quarterly': t += r.amount / 3; break;
        case 'yearly': t += r.amount / 12; break;
      }
    }
    return t;
  }

  Map<String, int> get _freqCounts {
    final m = <String, int>{};
    for (final r in _list.where((r) => r.isActive)) {
      m[r.frequency] = (m[r.frequency] ?? 0) + 1;
    }
    return m;
  }

  // ── actions
  Future<void> _toggleActive(RecurringExpenseModel r) async {
    final updated = r.copyWith(isActive: !r.isActive);
    final list = await StorageService.loadRecurring();
    final idx = list.indexWhere((x) => x.id == r.id);
    if (idx >= 0) list[idx] = updated;
    await StorageService.saveRecurring(list);
    await RecurringEngine.run();
    _load();
  }

  Future<void> _delete(RecurringExpenseModel r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete recurring?',
            style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        content: Text('Delete "${r.name}"? This won\'t remove past expenses.',
            style: GoogleFonts.sora(fontSize: 13)),
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
      final list = await StorageService.loadRecurring();
      list.removeWhere((x) => x.id == r.id);
      await StorageService.saveRecurring(list);
      _load();
    }
  }

  Future<void> _duplicate(RecurringExpenseModel r) async {
    final list = await StorageService.loadRecurring();
    list.add(RecurringExpenseModel.create(
      name: '${r.name} (copy)',
      amount: r.amount,
      frequency: r.frequency,
      startDate: DateTime.now(),
      groupId: r.groupId,
      categories: r.categories,
      description: r.description,
    ));
    await StorageService.saveRecurring(list);
    await RecurringEngine.run();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final bg = isWhite ? const Color(0xFFF5F5F5) : Colors.black;
    final cardBg = isWhite ? Colors.white : const Color(0xFF120404);
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite
        ? EleghartColors.accentDark.withOpacity(0.5)
        : Colors.white54;
    final border =
        isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.08);

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AddRecurringExpenseScreen()));
          if (ok == true) _load();
        },
        backgroundColor: const Color(0xFFCC0020),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Recurring',
            style: GoogleFonts.sora(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.72)),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFCC0020)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _appBar(textPrimary, textSec),
                      if (_list.isNotEmpty) _summaryCard(isWhite, cardBg, textPrimary, textSec, border),
                      Expanded(
                        child: _list.isEmpty
                            ? _emptyState(textPrimary, textSec)
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                                itemCount: _list.length,
                                itemBuilder: (_, i) => _recurringCard(
                                    _list[i], isWhite, cardBg, textPrimary,
                                    textSec, border),
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ─── App Bar ───────────────────────────────────────────────────────────────

  Widget _appBar(Color textPrimary, Color textSec) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recurring Expenses',
                    style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textPrimary)),
                Text('Auto-generates expenses on schedule',
                    style:
                        GoogleFonts.sora(fontSize: 11, color: textSec)),
              ],
            ),
          ],
        ),
      );

  // ─── Summary Card ──────────────────────────────────────────────────────────

  Widget _summaryCard(bool isWhite, Color cardBg, Color textPrimary,
      Color textSec, Color border) {
    final fc = _freqCounts;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF7A0010), Color(0xFFCC0020)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFCC0020).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_activeCount Active',
                    style: GoogleFonts.sora(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                    '₹${_monthlyTotal >= 1000 ? (_monthlyTotal / 1000).toStringAsFixed(1) + 'K' : _monthlyTotal.toStringAsFixed(0)} / month',
                    style: GoogleFonts.sora(
                        fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if ((fc['weekly'] ?? 0) > 0)
                _freqBadge('${fc['weekly']} Weekly'),
              if ((fc['monthly'] ?? 0) > 0)
                _freqBadge('${fc['monthly']} Monthly'),
              if ((fc['quarterly'] ?? 0) > 0)
                _freqBadge('${fc['quarterly']} Quarterly'),
              if ((fc['yearly'] ?? 0) > 0)
                _freqBadge('${fc['yearly']} Yearly'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _freqBadge(String label) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: GoogleFonts.sora(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      );

  // ─── Recurring Card ────────────────────────────────────────────────────────

  Widget _recurringCard(RecurringExpenseModel r, bool isWhite, Color cardBg,
      Color textPrimary, Color textSec, Color border) {
    final icon = _categoryIcon(r.category);
    final nextDue = r.isActive ? r.nextDueDate(DateTime.now()) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: r.isActive
                ? border
                : border.withOpacity(0.5)),
        boxShadow: isWhite
            ? [
                BoxShadow(
                    color: const Color(0xFFCC0020).withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]
            : [],
      ),
      child: Opacity(
        opacity: r.isActive ? 1.0 : 0.5,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFCC0020).withOpacity(0.1)),
                child: Icon(icon, color: const Color(0xFFCC0020), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(r.name,
                              style: GoogleFonts.sora(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary)),
                        ),
                        _statusBadge(r.isActive),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${_fmt(r.amount)} · ${r.frequencyLabel}${_groupName(r.groupId).isNotEmpty ? ' · ${_groupName(r.groupId)}' : ''}',
                      style: GoogleFonts.sora(
                          fontSize: 11, color: textSec),
                    ),
                    if (nextDue != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Next: ${DateFormat('dd MMM').format(nextDue)}',
                        style: GoogleFonts.sora(
                            fontSize: 11,
                            color: const Color(0xFFCC0020)),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: textSec, size: 20),
                color: cardBg,
                onSelected: (action) async {
                  switch (action) {
                    case 'edit':
                      final ok = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  AddRecurringExpenseScreen(existing: r)));
                      if (ok == true) _load();
                      break;
                    case 'pause':
                      await _toggleActive(r);
                      break;
                    case 'duplicate':
                      await _duplicate(r);
                      break;
                    case 'delete':
                      await _delete(r);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  _popupItem('edit', Icons.edit_outlined, 'Edit', textPrimary),
                  _popupItem(
                      'pause',
                      r.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                      r.isActive ? 'Pause' : 'Resume',
                      textPrimary),
                  _popupItem('duplicate', Icons.copy_outlined, 'Duplicate', textPrimary),
                  _popupItem('delete', Icons.delete_outline, 'Delete',
                      Colors.red),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _popupItem(
          String value, IconData icon, String label, Color color) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Text(label,
                style: GoogleFonts.sora(fontSize: 13, color: color)),
          ],
        ),
      );

  Widget _statusBadge(bool isActive) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF22C55E).withOpacity(0.12)
              : Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isActive ? 'ACTIVE' : 'PAUSED',
          style: GoogleFonts.sora(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isActive
                  ? const Color(0xFF22C55E)
                  : Colors.grey),
        ),
      );

  Widget _emptyState(Color textPrimary, Color textSec) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.repeat_rounded,
                size: 56, color: textSec.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('No recurring expenses yet',
                style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary)),
            const SizedBox(height: 6),
            Text('Tap + Add Recurring to get started',
                style: GoogleFonts.sora(fontSize: 12, color: textSec)),
          ],
        ),
      );

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  IconData _categoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'rent': return Icons.home_outlined;
      case 'food & dining': return Icons.restaurant_outlined;
      case 'bills & utilities': return Icons.receipt_long_outlined;
      case 'travel': return Icons.directions_car_outlined;
      case 'health': return Icons.health_and_safety_outlined;
      case 'entertainment': return Icons.movie_outlined;
      case 'emi': return Icons.credit_card_outlined;
      default: return Icons.repeat_rounded;
    }
  }
}
