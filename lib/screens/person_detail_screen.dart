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
import 'add_udhaar_transaction_screen.dart';

class PersonDetailScreen extends StatefulWidget {
  final PersonModel person;

  const PersonDetailScreen({super.key, required this.person});

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen>
    with SingleTickerProviderStateMixin {
  late PersonModel _person;
  List<LedgerTransactionModel> _transactions = [];
  List<LedgerTransactionModel> _filtered = [];
  bool _loading = true;

  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _tabIndex = 0;

  static const _tabs = ['All', 'Collection', 'Payment'];

  @override
  void initState() {
    super.initState();
    _person = widget.person;
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) return;
      setState(() {
        _tabIndex = _tabCtrl.index;
        _applyFilter();
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
    final all = await StorageService.loadUdhaarTransactions();
    if (!mounted) return;
    setState(() {
      _transactions = all
          .where((t) => t.personId == _person.id)
          .toList()
        ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
      _loading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final q = _searchQuery.toLowerCase();
    List<LedgerTransactionModel> base = _transactions;
    if (_tabIndex == 1) base = base.where((t) => t.isCollection).toList();
    if (_tabIndex == 2) base = base.where((t) => t.isPayment).toList();
    if (q.isNotEmpty) {
      base = base.where((t) =>
          t.description.toLowerCase().contains(q) ||
          (t.notes?.toLowerCase().contains(q) ?? false)).toList();
    }
    _filtered = base;
  }

  double get _toCollect =>
      _transactions.where((t) => t.isCollection).fold(0.0, (s, t) => s + t.amount);
  double get _toPay =>
      _transactions.where((t) => t.isPayment).fold(0.0, (s, t) => s + t.amount);
  double get _net => _toCollect - _toPay;

  Future<void> _deleteTransaction(LedgerTransactionModel t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Transaction?',
            style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        content: Text('This cannot be undone.',
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
      final all = await StorageService.loadUdhaarTransactions();
      all.removeWhere((x) => x.id == t.id);
      await StorageService.saveUdhaarTransactions(all);
      _load();
    }
  }

  Future<void> _exportPdf({DateTime? from, DateTime? to}) async {
    try {
      final file = await UdhaarPdfExportService.exportPersonLedger(
          person: _person, transactions: _transactions, from: from, to: to);
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
          final ok = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      AddUdhaarTransactionScreen(person: _person)));
          if (ok == true) _load();
        },
        backgroundColor: const Color(0xFFCC0020),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Transaction',
            style: GoogleFonts.sora(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.85)),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFCC0020)))
                : Column(
                    children: [
                      _header(isWhite, textPrimary, textSec),
                      _summaryCard(isWhite, textPrimary),
                      const SizedBox(height: 10),
                      _searchBar(isWhite, textPrimary, textSec, border),
                      const SizedBox(height: 8),
                      _tabBar(isWhite, textPrimary, textSec, border, cardBg),
                      Expanded(
                        child: _filtered.isEmpty
                            ? _emptyState(textSec)
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                                itemCount: _filtered.length,
                                itemBuilder: (_, i) => _txCard(
                                    _filtered[i], isWhite, cardBg,
                                    textPrimary, textSec, border),
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
        padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            _person.photoPath != null
                ? CircleAvatar(
                    radius: 20,
                    backgroundImage: FileImage(File(_person.photoPath!)),
                  )
                : CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        const Color(0xFFCC0020).withValues(alpha: 0.15),
                    child: Text(
                      _person.name.isNotEmpty
                          ? _person.name[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.sora(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFCC0020)),
                    ),
                  ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _person.name,
                    style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (_person.phone != null)
                    Text(_person.phone!,
                        style:
                            GoogleFonts.sora(fontSize: 11, color: textSec)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_rounded, color: textSec, size: 20),
              onPressed: () async {
                final ok = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AddPersonScreen(existing: _person)));
                if (ok == true) {
                  final persons = await StorageService.loadPersons();
                  final updated = persons.firstWhere(
                      (p) => p.id == _person.id,
                      orElse: () => _person);
                  if (mounted) setState(() => _person = updated);
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.picture_as_pdf_rounded,
                  color: const Color(0xFFCC0020), size: 20),
              onPressed: _showExportOptions,
            ),
          ],
        ),
      );

  Widget _summaryCard(bool isWhite, Color textPrimary) {
    final net = _net;
    return Container(
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
          _summaryItem('To Collect', _toCollect, const Color(0xFF4ADE80)),
          _summaryDivider(),
          _summaryItem('To Pay', _toPay, Colors.white70),
          _summaryDivider(),
          _summaryItem(
            'Net',
            net.abs(),
            net >= 0 ? const Color(0xFF4ADE80) : Colors.redAccent.shade100,
            prefix: net >= 0 ? '+' : '-',
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double amount, Color color,
          {String prefix = ''}) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label,
                style: GoogleFonts.sora(fontSize: 10, color: Colors.white70),
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

  Widget _summaryDivider() => Container(
      width: 1, height: 36, color: Colors.white.withValues(alpha: 0.2));

  Widget _searchBar(bool isWhite, Color textPrimary, Color textSec,
          Color border) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  style: GoogleFonts.sora(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    hintStyle: GoogleFonts.sora(color: textSec, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) =>
                      setState(() {
                        _searchQuery = v;
                        _applyFilter();
                      }),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textSec, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _searchQuery = '';
                      _applyFilter();
                    });
                  },
                ),
            ],
          ),
        ),
      );

  Widget _tabBar(bool isWhite, Color textPrimary, Color textSec, Color border,
      Color cardBg) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            color: isWhite ? const Color(0xFFF0F0F0) : const Color(0xFF1A0505),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: TabBar(
            controller: _tabCtrl,
            labelStyle: GoogleFonts.sora(
                fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle:
                GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w400),
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

  Widget _txCard(LedgerTransactionModel t, bool isWhite, Color cardBg,
      Color textPrimary, Color textSec, Color border) {
    final isCol = t.isCollection;
    final color = isCol ? const Color(0xFF22C55E) : const Color(0xFFCC0020);
    return Dismissible(
      key: Key(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_rounded, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        await _deleteTransaction(t);
        return false;
      },
      child: GestureDetector(
        onTap: () async {
          final ok = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AddUdhaarTransactionScreen(
                      person: _person, existing: t)));
          if (ok == true) _load();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    isCol
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: color,
                    size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.description,
                      style: GoogleFonts.sora(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd MMM yyyy').format(t.transactionDate),
                      style: GoogleFonts.sora(
                          fontSize: 11, color: textSec),
                    ),
                    if (t.notes != null) ...[
                      const SizedBox(height: 2),
                      Text(t.notes!,
                          style:
                              GoogleFonts.sora(fontSize: 10, color: textSec),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                    ],
                  ],
                ),
              ),
              if (t.attachmentPath != null &&
                  File(t.attachmentPath!).existsSync()) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _showReceiptDialog(t.attachmentPath!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(t.attachmentPath!),
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isCol ? '+' : '-'}₹${t.amount.toStringAsFixed(0)}',
                    style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isCol ? 'Collection' : 'Payment',
                      style: GoogleFonts.sora(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: color),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReceiptDialog(String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
            Positioned(
              top: 8, right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(Color textSec) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 56, color: textSec.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('No transactions yet',
                style: GoogleFonts.sora(fontSize: 14, color: textSec)),
            const SizedBox(height: 4),
            Text('Tap + to add the first one',
                style:
                    GoogleFonts.sora(fontSize: 12, color: textSec.withValues(alpha: 0.6))),
          ],
        ),
      );
}
