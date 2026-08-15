import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../models/expense_model.dart';
import '../models/group_model.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../utils/data_sync.dart';
import '../widgets/themed_background.dart';

class AddSplitExpenseScreen extends StatefulWidget {
  final GroupModel group;

  const AddSplitExpenseScreen({super.key, required this.group});

  @override
  State<AddSplitExpenseScreen> createState() => _AddSplitExpenseScreenState();
}

class _AddSplitExpenseScreenState extends State<AddSplitExpenseScreen> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'General';
  String _splitType = 'equal'; // 'equal', 'exact', 'percentage', 'shares'

  // Who Paid?
  bool _isMultiPayer = false;
  String _singlePayer = 'You';
  final Map<String, TextEditingController> _paidCtrls = {};

  // Owed Shares Controllers
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
    if (widget.group.categories.isNotEmpty) {
      _selectedCategory = widget.group.categories.first;
    }

    for (final m in _members) {
      _equalIncluded[m] = true;
      _paidCtrls[m] = TextEditingController(text: '0');
      _exactCtrls[m] = TextEditingController(text: '0');
      _pctCtrls[m] = TextEditingController(text: '0');
      _sharesCtrls[m] = TextEditingController(text: '1');
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
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

  void _saveExpense() async {
    final total = _totalAmount;
    final desc = _descCtrl.text.trim();

    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid expense amount')),
      );
      return;
    }

    final dist = _calculateDistribution();
    final paidBy = _calculatePaidBy();

    final newExpense = ExpenseModel(
      id: const Uuid().v4(),
      groupId: widget.group.id,
      amount: total,
      description: desc.isEmpty ? 'Split Expense' : desc,
      categories: [_selectedCategory],
      date: _selectedDate,
      type: 'debit',
      splitType: _splitType,
      distribution: dist,
      paidBy: paidBy,
    );

    final expenses = await StorageService.loadExpenses();
    expenses.insert(0, newExpense);
    await StorageService.saveExpenses(expenses);
    DataSyncNotifier.notifyDataChanged();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.85)),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text('Add Split Expense', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
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
                        // Amount & Description Card
                        _buildAmountCard(isWhite),
                        const SizedBox(height: 20),

                        // Paid By Section
                        _buildPaidBySection(isWhite),
                        const SizedBox(height: 24),

                        // Split Method Selector
                        Text('Split Method', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
                        const SizedBox(height: 10),
                        _buildSplitMethodSelector(isWhite),
                        const SizedBox(height: 16),

                        // Split Shares Calculator Input
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
            controller: _descCtrl,
            style: GoogleFonts.sora(fontSize: 14, color: textPrimary),
            decoration: InputDecoration(
              hintText: 'Description (e.g. Dinner, Taxi, Hotel)',
              hintStyle: GoogleFonts.sora(fontSize: 13, color: textPrimary.withOpacity(0.4)),
              prefixIcon: const Icon(Icons.description_rounded, color: Color(0xFFCC0020), size: 20),
              filled: true,
              fillColor: isWhite ? const Color(0xFFF8FAFC) : const Color(0xFF220A0A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaidBySection(bool isWhite) {
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Paid By', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
            TextButton(
              onPressed: () => setState(() => _isMultiPayer = !_isMultiPayer),
              child: Text(
                _isMultiPayer ? 'Single Payer' : 'Multiple Payers',
                style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFCC0020)),
              ),
            ),
          ],
        ),
        if (!_isMultiPayer)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _members.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final m = _members[i];
                final isSelected = m == _singlePayer;
                return ChoiceChip(
                  label: Text(m),
                  selected: isSelected,
                  selectedColor: const Color(0xFFCC0020),
                  backgroundColor: isWhite ? const Color(0xFFF1F5F9) : const Color(0xFF220C0C),
                  labelStyle: GoogleFonts.sora(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : textPrimary,
                  ),
                  onSelected: (_) => setState(() => _singlePayer = m),
                );
              },
            ),
          )
        else
          Column(
            children: _members.map((m) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(m, style: GoogleFonts.sora(fontSize: 13, color: textPrimary)),
                    const Spacer(),
                    SizedBox(
                      width: 100,
                      height: 38,
                      child: TextField(
                        controller: _paidCtrls[m],
                        keyboardType: TextInputType.number,
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWhite ? Colors.white : const Color(0xFF140404),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.2)),
      ),
      child: Column(
        children: _members.map((m) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                if (_splitType == 'equal')
                  Checkbox(
                    value: _equalIncluded[m] ?? true,
                    activeColor: const Color(0xFFCC0020),
                    onChanged: (val) => setState(() => _equalIncluded[m] = val ?? true),
                  ),
                Text(m, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                const Spacer(),
                if (_splitType == 'equal')
                  Text(
                    '₹${(_equalIncluded[m] == true && _totalAmount > 0 ? (_totalAmount / (_members.where((x) => _equalIncluded[x] == true).length)).toStringAsFixed(0) : '0')}',
                    style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFCC0020)),
                  )
                else
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
            ),
          );
        }).toList(),
      ),
    );
  }
}
