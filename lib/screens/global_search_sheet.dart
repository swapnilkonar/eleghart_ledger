import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/expense_model.dart';
import '../models/group_model.dart';
import '../models/person_model.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import 'group_detail_screen.dart';
import 'udhaar_home_screen.dart';

class GlobalSearchSheet extends StatefulWidget {
  const GlobalSearchSheet({super.key});

  @override
  State<GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends State<GlobalSearchSheet> {
  final _ctrl = TextEditingController();
  String _query = '';
  bool _loading = true;

  List<ExpenseModel> _expenses = [];
  List<GroupModel> _groups = [];
  List<PersonModel> _persons = [];

  @override
  void initState() {
    super.initState();
    _loadFresh();
  }

  Future<void> _loadFresh() async {
    final results = await Future.wait([
      StorageService.loadExpenses(),
      StorageService.loadGroups(),
      StorageService.loadPersons(),
    ]);
    if (mounted) {
      setState(() {
        _expenses = results[0] as List<ExpenseModel>;
        _groups   = results[1] as List<GroupModel>;
        _persons  = results[2] as List<PersonModel>;
        _loading  = false;
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<ExpenseModel> get _filteredExpenses {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return _expenses
        .where((e) =>
            e.description.toLowerCase().contains(q) ||
            e.categories.any((c) => c.toLowerCase().contains(q)) ||
            e.amount.toStringAsFixed(0).contains(q))
        .take(8)
        .toList();
  }

  List<GroupModel> get _filteredGroups {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return _groups
        .where((g) => g.name.toLowerCase().contains(q))
        .take(4)
        .toList();
  }

  List<PersonModel> get _filteredPersons {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return _persons
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            (p.phone?.contains(q) ?? false))
        .take(4)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite
        ? EleghartColors.accentDark.withOpacity(0.5)
        : Colors.white54;
    final sheetBg = isWhite ? Colors.white : const Color(0xFF0E0303);

    final fe = _filteredExpenses;
    final fg = _filteredGroups;
    final fp = _filteredPersons;
    final hasResults = fe.isNotEmpty || fg.isNotEmpty || fp.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      snap: true,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Search',
                    style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary),
                  ),
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
                      child: Icon(Icons.close_rounded,
                          color: textSec, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: isWhite
                      ? const Color(0xFFF5F5F5)
                      : const Color(0xFF1A0505),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isWhite
                        ? const Color(0xFFEEEEEE)
                        : Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.search_rounded, color: textSec, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        style: GoogleFonts.sora(
                            fontSize: 14, color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Expenses, groups, people...',
                          hintStyle: GoogleFonts.sora(
                              fontSize: 14, color: textSec),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _ctrl.clear();
                          setState(() => _query = '');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(Icons.close_rounded,
                              color: textSec, size: 18),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const CircularProgressIndicator(
                              color: Color(0xFFCC0020), strokeWidth: 2),
                          const SizedBox(height: 14),
                          Text('Loading latest data…',
                              style: GoogleFonts.sora(
                                  fontSize: 13, color: textSec)),
                        ]),
                      ),
                    )
                  : _query.isEmpty
                  ? _placeholder(textSec, isWhite, scrollCtrl)
                  : !hasResults
                      ? _noResults(textSec, scrollCtrl)
                      : ListView(
                          controller: scrollCtrl,
                          padding:
                              const EdgeInsets.fromLTRB(20, 8, 20, 40),
                          children: [
                            if (fe.isNotEmpty) ...[
                              _sectionHeader(
                                  'Transactions',
                                  Icons.receipt_long_rounded),
                              ...fe.map((e) => _expenseTile(
                                  e, isWhite, textPrimary, textSec)),
                            ],
                            if (fg.isNotEmpty) ...[
                              _sectionHeader(
                                  'Groups', Icons.groups_rounded),
                              ...fg.map((g) => _groupTile(
                                  g, isWhite, textPrimary, textSec)),
                            ],
                            if (fp.isNotEmpty) ...[
                              _sectionHeader(
                                  'People', Icons.person_rounded),
                              ...fp.map((p) => _personTile(
                                  p, isWhite, textPrimary, textSec)),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(
      Color textSec, bool isWhite, ScrollController ctrl) {
    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _hintChip('Food', Icons.restaurant_rounded, isWhite, textSec),
            _hintChip('Travel', Icons.flight_rounded, isWhite, textSec),
            _hintChip('Bills', Icons.receipt_rounded, isWhite, textSec),
            _hintChip('EMI', Icons.credit_card_rounded, isWhite, textSec),
          ],
        ),
        const SizedBox(height: 36),
        Icon(Icons.manage_search_rounded,
            size: 56, color: textSec.withOpacity(0.2)),
        const SizedBox(height: 14),
        Text(
          'Search anything',
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textSec),
        ),
        const SizedBox(height: 6),
        Text(
          'Expenses · Groups · People · Categories',
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(
              fontSize: 12, color: textSec.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _hintChip(
      String label, IconData icon, bool isWhite, Color textSec) {
    return GestureDetector(
      onTap: () {
        _ctrl.text = label;
        setState(() => _query = label);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isWhite
              ? const Color(0xFFF5F5F5)
              : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isWhite
                  ? const Color(0xFFEEEEEE)
                  : Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFCC0020)),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.sora(
                    fontSize: 12,
                    color: textSec,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _noResults(Color textSec, ScrollController ctrl) {
    return ListView(
      controller: ctrl,
      children: [
        const SizedBox(height: 60),
        Icon(Icons.search_off_rounded,
            size: 52, color: textSec.withOpacity(0.2)),
        const SizedBox(height: 14),
        Text(
          'No results for "$_query"',
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textSec),
        ),
        const SizedBox(height: 6),
        Text(
          'Try a different keyword',
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(
              fontSize: 12, color: textSec.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 13, color: const Color(0xFFCC0020)),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.sora(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFCC0020),
                letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }

  Widget _expenseTile(ExpenseModel e, bool isWhite, Color textPrimary,
      Color textSec) {
    final isCredit = e.type == 'credit';
    final typeColor =
        isCredit ? const Color(0xFF00CC66) : const Color(0xFFFF3355);
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        final grp = _groups.firstWhere(
          (g) => g.id == e.groupId,
          orElse: () => GroupModel(id: '', name: '', categories: []),
        );
        if (grp.id.isNotEmpty) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => GroupDetailScreen(group: grp)));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isWhite
              ? const Color(0xFFFAFAFA)
              : const Color(0xFF120404),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isWhite
                  ? const Color(0xFFEEEEEE)
                  : Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  shape: BoxShape.circle),
              child: Icon(
                  isCredit ? Icons.add_rounded : Icons.remove_rounded,
                  color: typeColor,
                  size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.description.isEmpty ? 'Expense' : e.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary),
                  ),
                  Text(
                    '${e.categories.take(2).join(', ')} · ${e.date.toString().split(' ')[0]}',
                    style: GoogleFonts.sora(
                        fontSize: 11, color: textSec),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '₹${e.amount.toStringAsFixed(0)}',
              style: GoogleFonts.sora(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: typeColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupTile(GroupModel g, bool isWhite, Color textPrimary,
      Color textSec) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => GroupDetailScreen(group: g)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isWhite
              ? const Color(0xFFFAFAFA)
              : const Color(0xFF120404),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isWhite
                  ? const Color(0xFFEEEEEE)
                  : Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: const Color(0xFFCC0020).withOpacity(0.12),
                  shape: BoxShape.circle),
              child: const Icon(Icons.groups_rounded,
                  color: Color(0xFFCC0020), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                g.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textSec, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _personTile(PersonModel p, bool isWhite, Color textPrimary,
      Color textSec) {
    final hasPhoto =
        p.photoPath != null && File(p.photoPath!).existsSync();
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const UdhaarHomeScreen()));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isWhite
              ? const Color(0xFFFAFAFA)
              : const Color(0xFF120404),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isWhite
                  ? const Color(0xFFEEEEEE)
                  : Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            hasPhoto
                ? CircleAvatar(
                    radius: 18,
                    backgroundImage: FileImage(File(p.photoPath!)))
                : CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        const Color(0xFFCC0020).withOpacity(0.12),
                    child: Text(
                      p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                      style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFCC0020)),
                    ),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary),
                  ),
                  if (p.phone != null)
                    Text(p.phone!,
                        style:
                            GoogleFonts.sora(fontSize: 11, color: textSec)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textSec, size: 18),
          ],
        ),
      ),
    );
  }
}
