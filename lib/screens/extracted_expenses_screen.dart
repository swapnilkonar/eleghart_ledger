import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/expense_model.dart';
import '../models/group_model.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';

// ─── Data model for a single AI-extracted item ─────────────────────────────

class ExtractedItem {
  final String id;
  String description;
  double amount;
  String category;
  DateTime date;
  bool isSelected;

  ExtractedItem({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    this.isSelected = true,
  });
}

// ─── Screen ────────────────────────────────────────────────────────────────

class ExtractedExpensesScreen extends StatefulWidget {
  final List<ExtractedItem> items;
  final String? sourceName;

  const ExtractedExpensesScreen(
      {super.key, required this.items, this.sourceName});

  @override
  State<ExtractedExpensesScreen> createState() =>
      _ExtractedExpensesScreenState();
}

class _ExtractedExpensesScreenState extends State<ExtractedExpensesScreen> {
  late List<ExtractedItem> _items;
  List<GroupModel> _groups = [];
  bool _saving = false;

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

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
    AppThemeNotifier.instance.addListener(_onThemeChanged);
    _loadGroups();
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _loadGroups() async {
    final g = await StorageService.loadGroups();
    if (mounted) setState(() => _groups = g);
  }

  List<ExtractedItem> get _selected =>
      _items.where((e) => e.isSelected).toList();

  // ─── Add to expense list ──────────────────────────────────────────────────

  Future<void> _addToExpenseList() async {
    final sel = _selected;
    if (sel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one expense')));
      return;
    }
    if (_groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please create a group first!')));
      return;
    }

    final group = await _pickGroup();
    if (group == null || !mounted) return;

    final details = await _promptGroupDetails(group);
    if (details == null || !mounted) return;

    setState(() => _saving = true);
    final existing = await StorageService.loadExpenses();

    final date = details['date'] as DateTime;
    final List<String> groupCats = details['categories'] as List<String>;

    final newItems = sel
        .map((item) {
          final cats = [item.category];
          if (groupCats.isNotEmpty) cats.addAll(groupCats);
          return ExpenseModel(
              id: const Uuid().v4(),
              groupId: group.id,
              amount: item.amount,
              description: item.description,
              categories: cats,
              date: date,
              type: 'debit',
            );
        })
        .toList();
    await StorageService.saveExpenses([...existing, ...newItems]);

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${sel.length} expense${sel.length == 1 ? '' : 's'} added!')));
      Navigator.pop(context, true);
    }
  }

  Future<GroupModel?> _pickGroup() =>
      showModalBottomSheet<GroupModel>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _GroupPickerSheet(groups: _groups),
      );

  Future<Map<String, dynamic>?> _promptGroupDetails(GroupModel group) async {
    final isWhite = AppThemeNotifier.isWhite;
    final bg = isWhite ? Colors.white : const Color(0xFF120404);
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;

    DateTime selectedDate = DateTime.now();
    Set<String> selectedMembers = {};

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Details for ${group.name}',
                  style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary)),
              const SizedBox(height: 20),
              Text('Select Members/Categories',
                  style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: group.categories.map((c) {
                  final sel = selectedMembers.contains(c);
                  return GestureDetector(
                    onTap: () => setSt(() {
                      sel ? selectedMembers.remove(c) : selectedMembers.add(c);
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: sel ? const Color(0xFFCC0020).withOpacity(0.12) : Colors.transparent,
                          border: Border.all(
                              color: sel ? const Color(0xFFCC0020) : Colors.grey.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(c, style: GoogleFonts.sora(color: textPrimary, fontSize: 13)),
                    ),
                  );
                }).toList(),
              ),
              if (group.categories.isEmpty)
                Text('No members in this group.',
                    style: GoogleFonts.sora(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 20),
              Text('Date',
                  style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setSt(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: isWhite ? const Color(0xFFF8F8F8) : const Color(0xFF1C0606),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFFCC0020)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${selectedDate.toLocal()}'.split(' ')[0],
                            style: GoogleFonts.sora(fontSize: 14, color: textPrimary)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _actionButton('Confirm & Add', () {
                if (selectedMembers.isEmpty && group.categories.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select at least one member/category')));
                  return;
                }
                Navigator.pop(ctx, {
                  'date': selectedDate,
                  'categories': selectedMembers.toList(),
                });
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Edit item ────────────────────────────────────────────────────────────

  void _editItem(int index) {
    final item = _items[index];
    final isWhite = AppThemeNotifier.isWhite;
    final bg = isWhite ? Colors.white : const Color(0xFF120404);
    final amtCtrl =
        TextEditingController(text: item.amount.toStringAsFixed(2));
    final descCtrl = TextEditingController(text: item.description);
    String cat = _categories.contains(item.category)
        ? item.category
        : 'Others';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          margin: const EdgeInsets.only(top: 80),
          decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Edit Expense',
                  style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isWhite
                          ? EleghartColors.accentDark
                          : Colors.white)),
              const SizedBox(height: 20),
              _inputField(descCtrl, 'Description', isWhite),
              const SizedBox(height: 12),
              _inputField(amtCtrl, 'Amount (₹)', isWhite, isNumber: true),
              const SizedBox(height: 12),
              _categoryDropdown(cat, isWhite, (v) => setSt(() => cat = v!)),
              const SizedBox(height: 24),
              _actionButton('Save Changes', () {
                setState(() {
                  _items[index].description = descCtrl.text.trim().isEmpty
                      ? item.description
                      : descCtrl.text.trim();
                  _items[index].amount =
                      double.tryParse(amtCtrl.text) ?? item.amount;
                  _items[index].category = cat;
                });
                Navigator.pop(ctx);
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Add manually ─────────────────────────────────────────────────────────

  void _addManually() {
    final isWhite = AppThemeNotifier.isWhite;
    final bg = isWhite ? Colors.white : const Color(0xFF120404);
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String cat = 'Others';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          margin: const EdgeInsets.only(top: 80),
          decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Add Manually',
                  style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isWhite
                          ? EleghartColors.accentDark
                          : Colors.white)),
              const SizedBox(height: 20),
              _inputField(descCtrl, 'Description', isWhite),
              const SizedBox(height: 12),
              _inputField(amtCtrl, 'Amount (₹)', isWhite, isNumber: true),
              const SizedBox(height: 12),
              _categoryDropdown(cat, isWhite, (v) => setSt(() => cat = v!)),
              const SizedBox(height: 24),
              _actionButton('Add', () {
                final desc = descCtrl.text.trim();
                final amt = double.tryParse(amtCtrl.text.trim());
                if (desc.isEmpty || amt == null || amt <= 0) return;
                setState(() {
                  _items.add(ExtractedItem(
                    id: const Uuid().v4(),
                    description: desc,
                    amount: amt,
                    category: cat,
                    date: DateTime.now(),
                    isSelected: true,
                  ));
                });
                Navigator.pop(ctx);
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helper widgets ───────────────────────────────────────────────────────

  Widget _inputField(TextEditingController ctrl, String label, bool isWhite,
      {bool isNumber = false}) {
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSecondary =
        isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54;
    final border =
        isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.08);
    return TextField(
      controller: ctrl,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: GoogleFonts.sora(fontSize: 14, color: textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.sora(fontSize: 13, color: textSecondary),
        filled: true,
        fillColor:
            isWhite ? const Color(0xFFF8F8F8) : const Color(0xFF1C0606),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCC0020))),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _categoryDropdown(
      String value, bool isWhite, ValueChanged<String?> onChanged) {
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSecondary =
        isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54;
    final border =
        isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.08);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
          color: isWhite ? const Color(0xFFF8F8F8) : const Color(0xFF1C0606),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border)),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor:
            isWhite ? Colors.white : const Color(0xFF120404),
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary),
        onChanged: onChanged,
        items: _categories
            .map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c,
                      style: GoogleFonts.sora(
                          fontSize: 14, color: textPrimary)),
                ))
            .toList(),
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        height: 48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF7A0010), Color(0xFFCC0020)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(label,
                style: GoogleFonts.sora(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      );

  IconData _catIcon(String c) {
    final l = c.toLowerCase();
    if (l.contains('food') || l.contains('dining'))
      return Icons.restaurant_rounded;
    if (l.contains('travel')) return Icons.directions_car_rounded;
    if (l.contains('shop')) return Icons.shopping_bag_outlined;
    if (l.contains('bill') || l.contains('util'))
      return Icons.receipt_long_rounded;
    if (l.contains('fuel')) return Icons.local_gas_station_rounded;
    return Icons.category_rounded;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSecondary =
        isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54;
    final cardColor = isWhite ? Colors.white : const Color(0xFF120404);
    final borderColor =
        isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.08);
    final selCount = _selected.length;

    return Scaffold(
      backgroundColor: isWhite ? const Color(0xFFF5F5F5) : Colors.black,
      appBar: AppBar(
        backgroundColor:
            isWhite ? Colors.white : const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Extracted Expenses',
            style: GoogleFonts.sora(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textPrimary)),
      ),
      body: Column(
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                      color: Color(0xFF22C55E), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_items.length} expenses found',
                          style: GoogleFonts.sora(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary)),
                      Text(
                          'Review and confirm the expenses before adding.',
                          style: GoogleFonts.sora(
                              fontSize: 11, color: textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── List ──
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final item = _items[i];
                return Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: item.isSelected
                            ? const Color(0xFFCC0020).withOpacity(0.4)
                            : borderColor),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: item.isSelected,
                            onChanged: (v) => setState(
                                () => _items[i].isSelected = v ?? false),
                            activeColor: const Color(0xFFCC0020),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                            side: BorderSide(
                                color: textSecondary, width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFCC0020)
                                .withOpacity(isWhite ? 0.08 : 0.15),
                          ),
                          child: Icon(_catIcon(item.category),
                              color: const Color(0xFFCC0020), size: 15),
                        ),
                      ],
                    ),
                    title: Text(item.description,
                        style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPrimary)),
                    subtitle: Text(
                        '${item.category}  •  ${DateFormat('d MMM yyyy').format(item.date)}',
                        style: GoogleFonts.sora(
                            fontSize: 11, color: textSecondary)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('₹${item.amount.toStringAsFixed(2)}',
                            style: GoogleFonts.sora(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFCC0020))),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _editItem(i),
                          child: Icon(Icons.edit_outlined,
                              size: 16, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Footer ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              children: [
                TextButton.icon(
                  onPressed: _addManually,
                  icon: const Icon(Icons.add_rounded,
                      color: Color(0xFFCC0020), size: 18),
                  label: Text('Add Manually',
                      style: GoogleFonts.sora(
                          color: const Color(0xFFCC0020),
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: selCount == 0
                              ? [Colors.grey.shade400, Colors.grey.shade500]
                              : const [
                                  Color(0xFF7A0010),
                                  Color(0xFFCC0020)
                                ]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: selCount > 0
                          ? [
                              BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ]
                          : [],
                    ),
                    child: ElevatedButton(
                      onPressed: (selCount == 0 || _saving)
                          ? null
                          : _addToExpenseList,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              selCount == 0
                                  ? 'Add to Expense List'
                                  : 'Add to Expense List ($selCount)',
                              style: GoogleFonts.sora(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16),
                            ),
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
}

// ─── Group picker for extracted expenses ──────────────────────────────────────

class _GroupPickerSheet extends StatelessWidget {
  final List<GroupModel> groups;

  const _GroupPickerSheet({required this.groups});

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
          Text('Add to Group',
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
                        onTap: () => Navigator.pop(context, g),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
