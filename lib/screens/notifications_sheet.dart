import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/emi_model.dart';
import '../models/expense_model.dart';
import '../models/ledger_transaction_model.dart';
import '../models/person_model.dart';
import '../models/recurring_expense_model.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import 'emi_list_screen.dart';
import 'insights_screen.dart';
import 'person_detail_screen.dart';
import 'recurring_expense_list_screen.dart';

class NotificationsSheet extends StatefulWidget {
  final List<ExpenseModel> expenses;

  const NotificationsSheet({super.key, required this.expenses});

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  List<_NotifItem>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final persons = await StorageService.loadPersons();
    final txns = await StorageService.loadUdhaarTransactions();
    final emis = await StorageService.loadEmis();
    final recurrings = await StorageService.loadRecurring();

    final items = <_NotifItem>[];
    final now = DateTime.now();

    // ── Udhaar balances ───────────────────────────────────────────
    final netByPerson = <String, double>{};
    for (final t in txns) {
      final sign = t.isCollection ? 1.0 : -1.0;
      netByPerson[t.personId] =
          (netByPerson[t.personId] ?? 0) + sign * t.amount;
    }
    final personMap = {for (final p in persons) p.id: p};

    final collects = netByPerson.entries
        .where((e) => e.value > 0.01)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in collects.take(3)) {
      final person = personMap[e.key];
      final name = person?.name ?? 'Someone';
      items.add(_NotifItem(
        icon: Icons.arrow_downward_rounded,
        color: const Color(0xFF22C55E),
        title: '$name owes you',
        sub: '₹${e.value.toStringAsFixed(0)} · Tap to view',
        route: _NotifRoute.udhaarPerson,
        person: person,
      ));
    }

    final pays = netByPerson.entries
        .where((e) => e.value < -0.01)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final e in pays.take(2)) {
      final person = personMap[e.key];
      final name = person?.name ?? 'Someone';
      items.add(_NotifItem(
        icon: Icons.arrow_upward_rounded,
        color: const Color(0xFFCC0020),
        title: 'You owe $name',
        sub: '₹${e.value.abs().toStringAsFixed(0)} · Tap to view',
        route: _NotifRoute.udhaarPerson,
        person: person,
      ));
    }

    // ── EMI due in next 7 days ────────────────────────────────────
    final soon = now.add(const Duration(days: 7));
    for (final e in emis.where((e) => !e.isCompleted && e.nextDueDate.isBefore(soon))) {
      final days = e.nextDueDate.difference(now).inDays;
      final label = days <= 0
          ? 'Due today'
          : days == 1
              ? 'Due tomorrow'
              : 'Due in $days days';
      items.add(_NotifItem(
        icon: Icons.credit_card_rounded,
        color: const Color(0xFF0EA5E9),
        title: 'EMI: ${e.productName}',
        sub: '₹${e.amount.toStringAsFixed(0)} · $label · ${e.remaining} left',
        route: _NotifRoute.emi,
      ));
    }

    // ── Recurring due in next 7 days ─────────────────────────────
    for (final r in recurrings.where((r) => r.isActive)) {
      try {
        final due = r.nextDueDate(now);
        if (due.isBefore(soon)) {
          final days = due.difference(now).inDays;
          final label = days <= 0
              ? 'Due today'
              : days == 1
                  ? 'Due tomorrow'
                  : 'Due in $days days';
          items.add(_NotifItem(
            icon: Icons.repeat_rounded,
            color: const Color(0xFF6366F1),
            title: r.name,
            sub: '₹${r.amount.toStringAsFixed(0)} · ${r.frequencyLabel} · $label',
            route: _NotifRoute.recurring,
          ));
        }
      } catch (_) {}
    }

    // ── Spending alert: >20% increase this month ─────────────────
    final thisMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);
    double thisSpend = 0, lastSpend = 0;
    for (final e in widget.expenses) {
      if (e.type == 'debit') {
        final d = e.date;
        if (d.year == thisMonth.year && d.month == thisMonth.month) {
          thisSpend += e.amount;
        }
        if (d.year == lastMonth.year && d.month == lastMonth.month) {
          lastSpend += e.amount;
        }
      }
    }
    if (lastSpend > 0 && thisSpend > lastSpend * 1.2) {
      final pct = ((thisSpend - lastSpend) / lastSpend * 100).round();
      items.add(_NotifItem(
        icon: Icons.trending_up_rounded,
        color: const Color(0xFFF59E0B),
        title: 'Spending up $pct% this month',
        sub:
            'This month: ₹${thisSpend.toStringAsFixed(0)} vs ₹${lastSpend.toStringAsFixed(0)} last month',
        route: _NotifRoute.insights,
      ));
    }

    if (mounted) setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite
        ? EleghartColors.accentDark.withOpacity(0.5)
        : Colors.white54;
    final sheetBg = isWhite ? Colors.white : const Color(0xFF0E0303);
    final items = _items;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isWhite ? Colors.black12 : Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.sora(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textPrimary),
                ),
                if (items != null && items.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCC0020),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${items.length}',
                      style: GoogleFonts.sora(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isWhite
                          ? const Color(0xFFF5F5F5)
                          : Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(Icons.close_rounded, color: textSec, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (items == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(
                    color: Color(0xFFCC0020), strokeWidth: 2),
              )
            else if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.notifications_none_rounded,
                        size: 52, color: textSec.withOpacity(0.25)),
                    const SizedBox(height: 12),
                    Text(
                      "You're all caught up!",
                      style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textSec),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No pending reminders or alerts.',
                      style: GoogleFonts.sora(
                          fontSize: 12, color: textSec.withOpacity(0.6)),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _tile(items[i], isWhite, textPrimary, textSec),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _navigate(_NotifItem item) {
    Navigator.pop(context);
    switch (item.route) {
      case _NotifRoute.udhaarPerson:
        if (item.person != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => PersonDetailScreen(person: item.person!)),
          );
        }
        break;
      case _NotifRoute.emi:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const EmiListScreen()));
        break;
      case _NotifRoute.recurring:
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const RecurringExpenseListScreen()));
        break;
      case _NotifRoute.insights:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InsightsScreen()));
        break;
    }
  }

  Widget _tile(
      _NotifItem item, bool isWhite, Color textPrimary, Color textSec) {
    return GestureDetector(
      onTap: () => _navigate(item),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isWhite ? const Color(0xFFF8F8F8) : const Color(0xFF120404),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: item.color.withOpacity(isWhite ? 0.2 : 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  shape: BoxShape.circle),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(fontSize: 11, color: textSec),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: item.color.withOpacity(0.5), size: 18),
          ],
        ),
      ),
    );
  }
}

enum _NotifRoute { udhaarPerson, emi, recurring, insights }

class _NotifItem {
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final _NotifRoute route;
  final PersonModel? person;

  const _NotifItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    required this.route,
    this.person,
  });
}
