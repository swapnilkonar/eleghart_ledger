import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../models/splitwise_models.dart';
import '../services/splitwise_storage_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../utils/data_sync.dart';
import '../widgets/themed_background.dart';

class AddSplitwiseExpenseScreen extends StatefulWidget {
  final SplitwiseGroupModel group;
  final SplitwiseExpenseModel? existingExpense;

  const AddSplitwiseExpenseScreen({
    super.key,
    required this.group,
    this.existingExpense,
  });

  @override
  State<AddSplitwiseExpenseScreen> createState() => _AddSplitwiseExpenseScreenState();
}

class _AddSplitwiseExpenseScreenState extends State<AddSplitwiseExpenseScreen> {
  final _amountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _splitType = 'equal'; // 'equal', 'exact', 'percentage', 'shares'

  bool _isMultiPayer = false;
  String _singlePayer = 'You';
  final Map<String, TextEditingController> _paidCtrls = {};

  final Map<String, bool> _equalIncluded = {};
  final Map<String, TextEditingController> _exactCtrls = {};
  final Map<String, TextEditingController> _pctCtrls = {};
  final Map<String, TextEditingController> _sharesCtrls = {};

  List<String> get _members =>
      widget.group.members.isEmpty ? ['You'] : widget.group.members;

  @override
  void initState() {
    super.initState();
    _singlePayer = _members.first;

    for (final m in _members) {
      _equalIncluded[m] = true;
      _paidCtrls[m] = TextEditingController(text: '0');
      _exactCtrls[m] = TextEditingController(text: '0');
      _pctCtrls[m] = TextEditingController(text: '0');
      _sharesCtrls[m] = TextEditingController(text: '1');
    }

    if (widget.existingExpense != null) {
      final e = widget.existingExpense!;
      _titleCtrl.text = e.title;
      _amountCtrl.text = e.amount.toStringAsFixed(e.amount.truncateToDouble() == e.amount ? 0 : 2);
      _splitType = e.splitType;
      _selectedDate = e.date;

      if (e.paidBy.length > 1) {
        _isMultiPayer = true;
        for (final entry in e.paidBy.entries) {
          if (_paidCtrls.containsKey(entry.key)) {
            _paidCtrls[entry.key]!.text = entry.value.toStringAsFixed(0);
          }
        }
      } else if (e.paidBy.isNotEmpty) {
        _singlePayer = e.paidBy.keys.first;
      }

      if (_splitType == 'exact') {
        for (final entry in e.distribution.entries) {
          if (_exactCtrls.containsKey(entry.key)) {
            _exactCtrls[entry.key]!.text = entry.value.toStringAsFixed(0);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    for (final c in _paidCtrls.values) {
      c.dispose();
    }
    for (final c in _exactCtrls.values) {
      c.dispose();
    }
    for (final c in _pctCtrls.values) {
      c.dispose();
    }
    for (final c in _sharesCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _totalAmount => double.tryParse(_amountCtrl.text.trim()) ?? 0;

  Map<String, double> _calculateDistribution() {
    final Map<String, double> dist = {};
    final total = _totalAmount;

    if (total <= 0) return dist;

    if (_splitType == 'equal') {
      final included = _members.where((m) => _equalIncluded[m] == true).toList();
      if (included.isNotEmpty) {
        final share = total / included.length;
        for (final m in included) {
          dist[m] = share;
        }
      }
    } else if (_splitType == 'exact') {
      for (final m in _members) {
        final val = double.tryParse(_exactCtrls[m]?.text.trim() ?? '0') ?? 0;
        if (val > 0) dist[m] = val;
      }
    } else if (_splitType == 'percentage') {
      for (final m in _members) {
        final pct = double.tryParse(_pctCtrls[m]?.text.trim() ?? '0') ?? 0;
        if (pct > 0) dist[m] = (pct / 100) * total;
      }
    } else if (_splitType == 'shares') {
      double totalShares = 0;
      for (final m in _members) {
        final s = double.tryParse(_sharesCtrls[m]?.text.trim() ?? '0') ?? 0;
        totalShares += s;
      }
      if (totalShares > 0) {
        for (final m in _members) {
          final s = double.tryParse(_sharesCtrls[m]?.text.trim() ?? '0') ?? 0;
          if (s > 0) dist[m] = (s / totalShares) * total;
        }
      }
    }

    return dist;
  }

  Map<String, double> _calculatePaidBy() {
    final total = _totalAmount;
    if (!_isMultiPayer) {
      return {_singlePayer: total};
    }
    final Map<String, double> paid = {};
    for (final m in _members) {
      final val = double.tryParse(_paidCtrls[m]?.text.trim() ?? '0') ?? 0;
      if (val > 0) paid[m] = val;
    }
    return paid.isEmpty ? {_singlePayer: total} : paid;
  }

  String _buildLiveSummaryText() {
    final total = _totalAmount;
    if (total <= 0) return 'Enter bill amount to see split summary.';

    final paidByMap = _calculatePaidBy();
    final payerStr = paidByMap.length == 1
        ? paidByMap.keys.first
        : '${paidByMap.keys.first} +${paidByMap.length - 1}';

    final dist = _calculateDistribution();
    if (dist.isEmpty) return 'Select members or enter split shares.';

    if (_splitType == 'equal') {
      final count = dist.length;
      final perPerson = total / count;
      return 'Paid by $payerStr (₹${total.toStringAsFixed(0)}). Split equally between $count members (₹${perPerson.toStringAsFixed(0)} each).';
    } else if (_splitType == 'exact') {
      final sumExact = dist.values.fold(0.0, (a, b) => a + b);
      final diff = total - sumExact;
      if (diff.abs() > 0.01) {
        return 'Paid by $payerStr (₹${total.toStringAsFixed(0)}). Total exact split: ₹${sumExact.toStringAsFixed(0)} (Remaining: ₹${diff.toStringAsFixed(0)}).';
      }
      return 'Paid by $payerStr (₹${total.toStringAsFixed(0)}). Exact custom split applied.';
    } else if (_splitType == 'percentage') {
      double totalPct = 0;
      for (final m in _members) {
        totalPct += double.tryParse(_pctCtrls[m]?.text.trim() ?? '0') ?? 0;
      }
      return 'Paid by $payerStr (₹${total.toStringAsFixed(0)}). Total percentage entered: ${totalPct.toStringAsFixed(0)}% / 100%.';
    } else {
      return 'Paid by $payerStr (₹${total.toStringAsFixed(0)}). Split by relative member shares.';
    }
  }

  void _saveExpense() async {
    final total = _totalAmount;
    final title = _titleCtrl.text.trim();

    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid expense amount')),
      );
      return;
    }

    final dist = _calculateDistribution();
    final paidBy = _calculatePaidBy();

    final expense = SplitwiseExpenseModel(
      id: widget.existingExpense?.id ?? const Uuid().v4(),
      splitwiseGroupId: widget.group.id,
      title: title.isEmpty ? 'Bill' : title,
      amount: total,
      date: _selectedDate,
      splitType: _splitType,
      paidBy: paidBy,
      distribution: dist,
    );

    if (widget.existingExpense != null) {
      await SplitwiseStorageService.updateExpense(expense);
    } else {
      await SplitwiseStorageService.addExpense(expense);
    }
    DataSyncNotifier.notifyDataChanged();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.85)),
          SafeArea(
            child: Column(
              children: [
                // Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.existingExpense != null ? 'Edit Split Expense' : 'Add Split Expense',
                        style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCC0020),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: _saveExpense,
                        child: Text('Save', style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.1)),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bill Amount & Title Card
                        _buildAmountCard(isWhite),
                        const SizedBox(height: 16),

                        // Summary Live Sentence Banner
                        _buildLiveSummaryBanner(isWhite),
                        const SizedBox(height: 20),

                        // Step 1: Who Paid Upfront?
                        _buildPaidBySection(isWhite),
                        const SizedBox(height: 24),

                        // Step 2: Split Cost Between (Who Owes?)
                        Text('2. How is the cost shared?', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
                        Text('Select split method and members who share this expense:', style: GoogleFonts.sora(fontSize: 11, color: isWhite ? Colors.black54 : Colors.white54)),
                        const SizedBox(height: 10),
                        _buildSplitMethodSelector(isWhite),
                        const SizedBox(height: 16),
                        _buildSplitSharesCalculator(isWhite),
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

  Widget _buildAmountCard(bool isWhite) {
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isWhite ? Colors.white : const Color(0xFF140404),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('₹', style: GoogleFonts.sora(fontSize: 32, fontWeight: FontWeight.w800, color: const Color(0xFFCC0020))),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.sora(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: GoogleFonts.sora(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary.withOpacity(0.3)),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            style: GoogleFonts.sora(fontSize: 14, color: textPrimary),
            decoration: InputDecoration(
              hintText: 'Bill Title (e.g. Dinner, Taxi, Hotel)',
              hintStyle: GoogleFonts.sora(fontSize: 13, color: isWhite ? Colors.black38 : Colors.white38),
              prefixIcon: const Icon(Icons.receipt_long_rounded, color: Color(0xFFCC0020), size: 20),
              filled: true,
              fillColor: isWhite ? const Color(0xFFF8FAFC) : const Color(0xFF220A0A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveSummaryBanner(bool isWhite) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFCC0020).withOpacity(isWhite ? 0.08 : 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCC0020).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFCC0020), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _buildLiveSummaryText(),
              style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w600, color: isWhite ? EleghartColors.accentDark : Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaidBySection(bool isWhite) {
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWhite ? Colors.white : const Color(0xFF140404),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1. Who paid upfront?', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
              GestureDetector(
                onTap: () => setState(() => _isMultiPayer = !_isMultiPayer),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCC0020).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isMultiPayer ? 'Switch to Single Payer' : 'Multiple Payers',
                    style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFCC0020)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (!_isMultiPayer) ...[
            Text('Tap the member who paid the entire bill:', style: GoogleFonts.sora(fontSize: 11, color: isWhite ? Colors.black54 : Colors.white54)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _members.map((m) {
                final isSelected = m == _singlePayer;
                return ChoiceChip(
                  label: Text(m),
                  selected: isSelected,
                  selectedColor: const Color(0xFFCC0020),
                  backgroundColor: isWhite ? const Color(0xFFF1F5F9) : const Color(0xFF220C0C),
                  labelStyle: GoogleFonts.sora(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : textPrimary,
                  ),
                  onSelected: (_) => setState(() => _singlePayer = m),
                );
              }).toList(),
            ),
          ] else ...[
            Text('Enter exact amount paid upfront by each person:', style: GoogleFonts.sora(fontSize: 11, color: isWhite ? Colors.black54 : Colors.white54)),
            const SizedBox(height: 10),
            Column(
              children: _members.map((m) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(m, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                      const Spacer(),
                      SizedBox(
                        width: 110,
                        height: 38,
                        child: TextField(
                          controller: _paidCtrls[m],
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.sora(fontSize: 13, color: textPrimary),
                          decoration: InputDecoration(
                            prefixText: '₹ ',
                            filled: true,
                            fillColor: isWhite ? const Color(0xFFF8FAFC) : const Color(0xFF220A0A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSplitMethodSelector(bool isWhite) {
    final methods = [
      {'id': 'equal', 'label': '= Equal'},
      {'id': 'exact', 'label': '₹ Exact'},
      {'id': 'percentage', 'label': '% Pct'},
      {'id': 'shares', 'label': 'x Shares'},
    ];

    return Row(
      children: methods.map((m) {
        final isSelected = m['id'] == _splitType;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _splitType = m['id']!),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFCC0020)
                    : (isWhite ? const Color(0xFFF1F5F9) : const Color(0xFF220C0C)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  m['label']!,
                  style: GoogleFonts.sora(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : (isWhite ? EleghartColors.accentDark : Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSplitSharesCalculator(bool isWhite) {
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final dist = _calculateDistribution();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWhite ? Colors.white : const Color(0xFF140404),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.2)),
      ),
      child: Column(
        children: _members.map((m) {
          final shareVal = dist[m] ?? 0;
          final isIncluded = _equalIncluded[m] ?? true;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                if (_splitType == 'equal')
                  Checkbox(
                    value: isIncluded,
                    activeColor: const Color(0xFFCC0020),
                    onChanged: (val) => setState(() => _equalIncluded[m] = val ?? true),
                  ),
                Text(m, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                const Spacer(),
                if (_splitType == 'equal') ...[
                  Text(
                    isIncluded ? 'Owes ₹${shareVal.toStringAsFixed(0)}' : 'Excluded (₹0)',
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isIncluded ? const Color(0xFFCC0020) : Colors.grey,
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: 90,
                    height: 38,
                    child: TextField(
                      controller: _splitType == 'exact'
                          ? _exactCtrls[m]
                          : (_splitType == 'percentage' ? _pctCtrls[m] : _sharesCtrls[m]),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.sora(fontSize: 13, color: textPrimary),
                      decoration: InputDecoration(
                        prefixText: _splitType == 'exact' ? '₹ ' : (_splitType == 'percentage' ? '% ' : 'x '),
                        filled: true,
                        fillColor: isWhite ? const Color(0xFFF8FAFC) : const Color(0xFF220A0A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
