import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/emi_model.dart';
import '../models/group_model.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';
import 'add_emi_screen.dart';

class EmiListScreen extends StatefulWidget {
  const EmiListScreen({super.key});

  @override
  State<EmiListScreen> createState() => _EmiListScreenState();
}

class _EmiListScreenState extends State<EmiListScreen>
    with SingleTickerProviderStateMixin {
  List<EmiModel> _list = [];
  List<GroupModel> _groups = [];
  bool _loading = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    AppThemeNotifier.instance.addListener(_onTheme);
    _load();
  }

  void _onTheme() => setState(() {});

  @override
  void dispose() {
    _tabCtrl.dispose();
    AppThemeNotifier.instance.removeListener(_onTheme);
    super.dispose();
  }

  Future<void> _load() async {
    final e = await StorageService.loadEmis();
    final g = await StorageService.loadGroups();
    if (mounted) setState(() { _list = e; _groups = g; _loading = false; });
  }

  String _groupName(String id) {
    try { return _groups.firstWhere((g) => g.id == id).name; } catch (_) { return ''; }
  }

  List<EmiModel> get _active => _list.where((e) => !e.isCompleted).toList();
  List<EmiModel> get _completed => _list.where((e) => e.isCompleted).toList();

  double get _monthlyTotal =>
      _active.fold(0.0, (s, e) => s + e.amount);

  int get _completingSoon => _active
      .where((e) => e.remaining <= 3 && e.remaining > 0)
      .length;

  Future<void> _delete(EmiModel e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete EMI?',
            style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        content: Text('Delete "${e.productName}"?',
            style: GoogleFonts.sora(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      final list = await StorageService.loadEmis();
      list.removeWhere((x) => x.id == e.id);
      await StorageService.saveEmis(list);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final bg = isWhite ? const Color(0xFFF5F5F5) : Colors.black;
    final cardBg = isWhite ? Colors.white : const Color(0xFF120404);
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec =
        isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54;
    final border =
        isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.08);

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddEmiScreen()));
          if (ok == true) _load();
        },
        backgroundColor: const Color(0xFFCC0020),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add EMI',
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
                    children: [
                      _appBar(textPrimary, textSec),
                      if (_active.isNotEmpty)
                        _summaryCard(textPrimary),
                      _tabs(isWhite, textPrimary, textSec, border),
                      Expanded(
                        child: TabBarView(
                          controller: _tabCtrl,
                          children: [
                            _emiList(_active, isWhite, cardBg, textPrimary,
                                textSec, border),
                            _emiList(_completed, isWhite, cardBg, textPrimary,
                                textSec, border),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _appBar(Color textPrimary, Color textSec) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
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
                Text('EMI Tracker',
                    style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textPrimary)),
                Text('Track all your EMI instalments',
                    style: GoogleFonts.sora(
                        fontSize: 11, color: textSec)),
              ],
            ),
          ],
        ),
      );

  Widget _summaryCard(Color textPrimary) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF1A0005), Color(0xFF7A0010)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFCC0020).withOpacity(0.25),
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
                  Text('${_active.length} Active EMIs',
                      style: GoogleFonts.sora(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                      '₹${_monthlyTotal >= 1000 ? (_monthlyTotal / 1000).toStringAsFixed(1) + 'K' : _monthlyTotal.toStringAsFixed(0)} Monthly',
                      style: GoogleFonts.sora(
                          fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
            if (_completingSoon > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.orange.withOpacity(0.5)),
                ),
                child: Text('$_completingSoon Completing Soon',
                    style: GoogleFonts.sora(
                        fontSize: 10,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      );

  Widget _tabs(bool isWhite, Color textPrimary, Color textSec, Color border) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isWhite ? const Color(0xFFF0F0F0) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabCtrl,
          indicator: BoxDecoration(
              color: const Color(0xFFCC0020),
              borderRadius: BorderRadius.circular(10)),
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: GoogleFonts.sora(
              fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w400),
          labelColor: Colors.white,
          unselectedLabelColor: textSec,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
      );

  Widget _emiList(List<EmiModel> items, bool isWhite, Color cardBg,
      Color textPrimary, Color textSec, Color border) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.credit_card_outlined,
                size: 56, color: textSec.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('No EMIs here',
                style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary)),
            const SizedBox(height: 6),
            Text('Tap + Add EMI to track one',
                style: GoogleFonts.sora(fontSize: 12, color: textSec)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: items.length,
      itemBuilder: (_, i) =>
          _emiCard(items[i], isWhite, cardBg, textPrimary, textSec, border),
    );
  }

  Widget _emiCard(EmiModel e, bool isWhite, Color cardBg, Color textPrimary,
      Color textSec, Color border) {
    final gName = _groupName(e.groupId);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: isWhite
            ? [
                BoxShadow(
                    color: const Color(0xFFCC0020).withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFCC0020).withOpacity(0.1)),
                child: const Icon(Icons.credit_card_outlined,
                    color: Color(0xFFCC0020), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.productName,
                        style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPrimary)),
                    Text(
                      '₹${e.amount.toStringAsFixed(0)}/month${gName.isNotEmpty ? ' · $gName' : ''}',
                      style: GoogleFonts.sora(fontSize: 11, color: textSec),
                    ),
                  ],
                ),
              ),
              if (e.isCompleted)
                _badge('Completed', const Color(0xFF22C55E))
              else if (e.remaining <= 3)
                _badge('${e.remaining} left', Colors.orange)
              else
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      color: textSec, size: 20),
                  color: cardBg,
                  onSelected: (action) async {
                    if (action == 'edit') {
                      final ok = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AddEmiScreen(existing: e)));
                      if (ok == true) _load();
                    } else if (action == 'delete') {
                      await _delete(e);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined,
                            color: textPrimary, size: 18),
                        const SizedBox(width: 10),
                        Text('Edit',
                            style: GoogleFonts.sora(
                                fontSize: 13, color: textPrimary)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_outline,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 10),
                        Text('Delete',
                            style: GoogleFonts.sora(
                                fontSize: 13, color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${e.completed}/${e.tenure} Paid',
                            style: GoogleFonts.sora(
                                fontSize: 11, color: textSec)),
                        Text('${e.remaining} Remaining',
                            style: GoogleFonts.sora(
                                fontSize: 11, color: textSec)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: e.progress,
                        backgroundColor: isWhite
                            ? const Color(0xFFEEEEEE)
                            : Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          e.isCompleted
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFCC0020),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!e.isCompleted) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 12, color: Color(0xFFCC0020)),
                const SizedBox(width: 4),
                Text(
                  'Next EMI: ${DateFormat('dd MMM yyyy').format(e.nextDueDate)}',
                  style: GoogleFonts.sora(
                      fontSize: 11, color: const Color(0xFFCC0020)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.sora(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color)),
      );
}
