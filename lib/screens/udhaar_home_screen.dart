import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../models/ledger_transaction_model.dart';
import '../models/person_model.dart';
import '../services/storage_service.dart';
import '../services/udhaar_pdf_export_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';
import 'add_person_screen.dart';
import 'person_detail_screen.dart';

class UdhaarHomeScreen extends StatefulWidget {
  const UdhaarHomeScreen({super.key});

  @override
  State<UdhaarHomeScreen> createState() => _UdhaarHomeScreenState();
}

class _UdhaarHomeScreenState extends State<UdhaarHomeScreen>
    with SingleTickerProviderStateMixin {
  List<PersonModel> _persons = [];
  List<LedgerTransactionModel> _transactions = [];
  bool _loading = true;
  bool _searchActive = false;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _tabIndex = 0;

  late TabController _tabCtrl;
  static const _tabs = ['All', 'To Collect', 'To Pay', 'Settled'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) return;
      setState(() {
        _tabIndex = _tabCtrl.index;
      });
    });
    AppThemeNotifier.instance.addListener(_onTheme);
    _load();
  }

  void _onTheme() => setState(() {});

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    AppThemeNotifier.instance.removeListener(_onTheme);
    super.dispose();
  }

  Future<void> _load() async {
    final persons = await StorageService.loadPersons();
    final txs = await StorageService.loadUdhaarTransactions();
    if (!mounted) return;
    setState(() {
      _persons = persons;
      _transactions = txs;
      _loading = false;
    });
  }

  // ─── Balance helpers ──────────────────────────────────────────────────────

  double _toCollectFor(String personId) => _transactions
      .where((t) => t.personId == personId && t.isCollection)
      .fold(0.0, (s, t) => s + t.amount);

  double _toPayFor(String personId) => _transactions
      .where((t) => t.personId == personId && t.isPayment)
      .fold(0.0, (s, t) => s + t.amount);

  double _netFor(String personId) =>
      _toCollectFor(personId) - _toPayFor(personId);

  DateTime? _lastActivityFor(String personId) {
    final pTx = _transactions
        .where((t) => t.personId == personId)
        .toList();
    if (pTx.isEmpty) return null;
    pTx.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    return pTx.first.transactionDate;
  }

  double get _grandCollect => _persons.fold(
      0.0, (s, p) => s + _toCollectFor(p.id).clamp(0, double.infinity));
  double get _grandPay => _persons
      .fold(0.0, (s, p) => s + _toPayFor(p.id).clamp(0, double.infinity));
  double get _grandNet => _grandCollect - _grandPay;

  // ─── Filtered persons ─────────────────────────────────────────────────────

  List<PersonModel> get _filteredPersons {
    List<PersonModel> base = _persons;
    final q = _searchQuery.toLowerCase().trim();
    if (q.isNotEmpty) {
      base = base
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              (p.phone?.contains(q) ?? false) ||
              (p.address?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    switch (_tabIndex) {
      case 1: // To Collect
        base = base.where((p) => _netFor(p.id) > 0).toList();
        break;
      case 2: // To Pay
        base = base.where((p) => _netFor(p.id) < 0).toList();
        break;
      case 3: // Settled
        base = base.where((p) => _netFor(p.id) == 0).toList();
        break;
    }
    // Sort: non-zero balances first, then by absolute net desc
    base.sort((a, b) {
      final na = _netFor(a.id).abs();
      final nb = _netFor(b.id).abs();
      if (nb == 0 && na > 0) return -1;
      if (na == 0 && nb > 0) return 1;
      return nb.compareTo(na);
    });
    return base;
  }

  // ─── Delete person ────────────────────────────────────────────────────────

  Future<void> _deletePerson(PersonModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${p.name}?',
            style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        content: Text('All transactions for this person will also be deleted.',
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
      final persons = await StorageService.loadPersons();
      persons.removeWhere((x) => x.id == p.id);
      await StorageService.savePersons(persons);
      final txs = await StorageService.loadUdhaarTransactions();
      txs.removeWhere((t) => t.personId == p.id);
      await StorageService.saveUdhaarTransactions(txs);
      _load();
    }
  }

  // ─── Export ───────────────────────────────────────────────────────────────

  Future<void> _exportPdf({DateTime? from, DateTime? to}) async {
    try {
      final file = await UdhaarPdfExportService.exportFullSummary(
          persons: _persons, transactions: _transactions, from: from, to: to);
      if (!mounted) return;
      _showPdfSuccess(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  void _showExportOptions() {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final cardBg = isWhite ? Colors.white : const Color(0xFF120404);
    DateTime? from;
    DateTime? to;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final fmt = DateFormat('dd MMM yyyy');
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCC0020).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Export PDF',
                    style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary)),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: _datePickerTile(
                      label: 'From',
                      value: from == null ? 'Any' : fmt.format(from!),
                      textPrimary: textPrimary,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: from ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setS(() => from = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _datePickerTile(
                      label: 'To',
                      value: to == null ? 'Any' : fmt.format(to!),
                      textPrimary: textPrimary,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: to ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setS(() => to = d);
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCC0020)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _exportPdf();
                      },
                      child: Text('Export All',
                          style: GoogleFonts.sora(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFCC0020))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCC0020),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _exportPdf(
                          from: from != null
                              ? DateTime(from!.year, from!.month, from!.day)
                              : null,
                          to: to != null
                              ? DateTime(to!.year, to!.month, to!.day, 23, 59, 59)
                              : null,
                        );
                      },
                      child: Text('Export Range',
                          style: GoogleFonts.sora(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _datePickerTile({
    required String label,
    required String value,
    required Color textPrimary,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCC0020).withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.sora(
                      fontSize: 10,
                      color: textPrimary.withValues(alpha: 0.5))),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 13, color: Color(0xFFCC0020)),
                const SizedBox(width: 6),
                Text(value,
                    style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary)),
              ]),
            ],
          ),
        ),
      );

  void _showPdfSuccess(String path) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    showModalBottomSheet(
      context: context,
      backgroundColor: isWhite ? Colors.white : const Color(0xFF120404),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCC0020).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFCC0020).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFCC0020).withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded,
                  size: 26, color: Color(0xFFCC0020)),
            ),
            const SizedBox(height: 14),
            Text('PDF Exported Successfully',
                style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary)),
            const SizedBox(height: 6),
            Text(path.split('/').last,
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(
                    fontSize: 11,
                    color: textPrimary.withValues(alpha: 0.4))),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0020),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.open_in_new_rounded,
                    color: Colors.white, size: 16),
                label: Text('Open PDF',
                    style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                onPressed: () {
                  OpenFilex.open(path);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite
        ? EleghartColors.accentDark.withValues(alpha: 0.55)
        : Colors.white54;
    final cardBg = isWhite ? Colors.white : const Color(0xFF120404);
    final border = isWhite
        ? const Color(0xFFEEEEEE)
        : Colors.white.withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddPersonScreen()));
          if (ok == true) _load();
        },
        backgroundColor: const Color(0xFFCC0020),
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text('Add Person',
            style: GoogleFonts.sora(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.85)),
          SafeArea(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFFCC0020)))
                : Column(
                    children: [
                      _header(isWhite, textPrimary, textSec),
                      if (_searchActive)
                        _searchBar(isWhite, textPrimary, textSec, border),
                      _summaryCard(),
                      const SizedBox(height: 8),
                      _tabBar(isWhite, textPrimary, textSec, border),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _filteredPersons.isEmpty
                            ? _emptyState(textSec)
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 4, 16, 100),
                                itemCount: _filteredPersons.length,
                                itemBuilder: (_, i) => _personCard(
                                    _filteredPersons[i],
                                    isWhite,
                                    cardBg,
                                    textPrimary,
                                    textSec,
                                    border),
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header(bool isWhite, Color textPrimary, Color textSec) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            Text(
              'Udhaar',
              style: GoogleFonts.sora(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textPrimary),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.search_rounded, color: textPrimary, size: 22),
              onPressed: () =>
                  setState(() => _searchActive = !_searchActive),
            ),
            IconButton(
              icon: Icon(Icons.picture_as_pdf_rounded,
                  color: const Color(0xFFCC0020), size: 22),
              onPressed: _showExportOptions,
            ),
          ],
        ),
      );

  Widget _searchBar(bool isWhite, Color textPrimary, Color textSec,
          Color border) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          decoration: BoxDecoration(
            color: isWhite ? Colors.white : const Color(0xFF1A0505),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.search_rounded, color: textSec, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: GoogleFonts.sora(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone...',
                    hintStyle: GoogleFonts.sora(color: textSec, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textSec, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
            ],
          ),
        ),
      );

  Widget _summaryCard() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7A0010), Color(0xFFCC0020)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFCC0020).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            _summaryItem('To Collect', _grandCollect, const Color(0xFF4ADE80)),
            _vDivider(),
            _summaryItem('To Pay', _grandPay, Colors.white70),
            _vDivider(),
            _summaryItem(
              'Net Position',
              _grandNet.abs(),
              _grandNet >= 0
                  ? const Color(0xFF4ADE80)
                  : Colors.redAccent.shade100,
              prefix: _grandNet >= 0 ? '+' : '-',
            ),
          ],
        ),
      );

  Widget _summaryItem(String label, double amount, Color color,
          {String prefix = ''}) =>
      Expanded(
        child: Column(
          children: [
            Text(label,
                style: GoogleFonts.sora(
                    fontSize: 10, color: Colors.white70),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              '$prefix₹${amount >= 1000 ? (amount / 1000).toStringAsFixed(1) + 'K' : amount.toStringAsFixed(0)}',
              style: GoogleFonts.sora(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _vDivider() => Container(
      width: 1, height: 36, color: Colors.white.withValues(alpha: 0.2));

  Widget _tabBar(bool isWhite, Color textPrimary, Color textSec,
          Color border) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            color:
                isWhite ? const Color(0xFFF0F0F0) : const Color(0xFF1A0505),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: false,
            labelStyle: GoogleFonts.sora(
                fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.sora(
                fontSize: 11, fontWeight: FontWeight.w400),
            labelColor: Colors.white,
            unselectedLabelColor: textSec,
            indicator: BoxDecoration(
              color: const Color(0xFFCC0020),
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
      );

  Widget _personCard(PersonModel p, bool isWhite, Color cardBg,
      Color textPrimary, Color textSec, Color border) {
    final net = _netFor(p.id);
    final lastActivity = _lastActivityFor(p.id);
    final isSettled = net == 0;
    final isCollect = net > 0;

    final statusColor = isSettled
        ? textSec
        : isCollect
            ? const Color(0xFF22C55E)
            : const Color(0xFFCC0020);
    final statusLabel = isSettled
        ? 'Settled'
        : isCollect
            ? 'To Collect'
            : 'To Pay';

    return Dismissible(
      key: Key(p.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_rounded, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        await _deletePerson(p);
        return false;
      },
      child: GestureDetector(
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PersonDetailScreen(person: p)));
          _load();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              p.photoPath != null
                  ? CircleAvatar(
                      radius: 24,
                      backgroundImage: FileImage(File(p.photoPath!)),
                    )
                  : CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          statusColor.withValues(alpha: 0.12),
                      child: Text(
                        p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                        style: GoogleFonts.sora(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: statusColor),
                      ),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.sora(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: statusColor),
                          ),
                        ),
                        if (lastActivity != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            _relativeDate(lastActivity),
                            style:
                                GoogleFonts.sora(fontSize: 10, color: textSec),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isSettled
                        ? '₹0'
                        : '${isCollect ? '+' : '-'}₹${net.abs() >= 1000 ? (net.abs() / 1000).toStringAsFixed(1) + 'K' : net.abs().toStringAsFixed(0)}',
                    style: GoogleFonts.sora(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: statusColor),
                  ),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right_rounded,
                      color: textSec, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(Color textSec) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 60, color: textSec.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No people yet',
                style: GoogleFonts.sora(fontSize: 15, color: textSec)),
            const SizedBox(height: 6),
            Text(
              _tabIndex == 0
                  ? 'Tap + to add your first person'
                  : 'No entries for this filter',
              style: GoogleFonts.sora(
                  fontSize: 12, color: textSec.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );

  String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    if (diff < 14) return '1 week ago';
    if (diff < 30) return '${(diff / 7).floor()} weeks ago';
    return DateFormat('dd MMM').format(date);
  }
}
