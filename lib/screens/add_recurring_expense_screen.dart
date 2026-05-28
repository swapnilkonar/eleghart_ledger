import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/group_model.dart';
import '../models/recurring_expense_model.dart';
import '../services/storage_service.dart';
import '../services/recurring_engine.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';

class AddRecurringExpenseScreen extends StatefulWidget {
  final RecurringExpenseModel? existing;

  const AddRecurringExpenseScreen({super.key, this.existing});

  @override
  State<AddRecurringExpenseScreen> createState() =>
      _AddRecurringExpenseScreenState();
}

class _AddRecurringExpenseScreenState
    extends State<AddRecurringExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _frequency = 'monthly';
  Set<String> _selectedCategories = {};
  String _groupId = '';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _hasEndDate = false;

  List<GroupModel> _groups = [];
  bool _saving = false;

  static const _frequencies = ['weekly', 'monthly', 'quarterly', 'yearly'];
  static const _categories = [
    'Food & Dining', 'Travel', 'Shopping', 'Bills & Utilities',
    'Fuel', 'Entertainment', 'Health', 'Rent', 'EMI', 'Others',
  ];

  @override
  void initState() {
    super.initState();
    AppThemeNotifier.instance.addListener(_onTheme);
    _loadGroups();
    if (widget.existing != null) {
      final e = widget.existing!;
      _nameCtrl.text = e.name;
      _amountCtrl.text = e.amount.toStringAsFixed(0);
      _descCtrl.text = e.description;
      _frequency = e.frequency;
      _selectedCategories = e.categories.toSet();
      _groupId = e.groupId;
      _startDate = e.startDate;
      _endDate = e.endDate;
      _hasEndDate = e.endDate != null;
    }
  }

  void _onTheme() => setState(() {});

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_onTheme);
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  List<String> get _currentCategories {
    if (_groups.isEmpty) return _categories;
    final group = _groups.firstWhere((g) => g.id == _groupId,
        orElse: () => _groups.first);
    return group.categories.isNotEmpty ? group.categories : _categories;
  }

  Future<void> _loadGroups() async {
    final g = await StorageService.loadGroups();
    if (mounted) {
      setState(() {
        _groups = g;
        if (_groupId.isEmpty && g.isNotEmpty) _groupId = g.first.id;
        if (g.isNotEmpty) {
          final validCategories = _currentCategories;
          if (_selectedCategories.isEmpty && validCategories.isNotEmpty) {
            _selectedCategories.add(validCategories.first);
          }
        }
      });
    }
  }

  Future<void> _showCategoryPicker() async {
    final validCategories = _currentCategories;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF120404),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppThemeNotifier.isWhite ? const Color(0xFFCC0020).withOpacity(0.25) : Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('Select Categories',
                  style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: validCategories.map((c) {
                      final sel = _selectedCategories.contains(c);
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            sel ? _selectedCategories.remove(c) : _selectedCategories.add(c);
                          });
                          setState(() {});
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: sel
                                ? const Color(0xFFCC0020).withOpacity(0.12)
                                : (AppThemeNotifier.isWhite ? Colors.white : Colors.white.withOpacity(0.05)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sel
                                  ? const Color(0xFFCC0020).withOpacity(0.5)
                                  : (AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.10)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.label_outline_rounded,
                                  size: 18,
                                  color: sel
                                      ? const Color(0xFFCC0020)
                                      : (AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.45) : Colors.white38)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(c,
                                    style: GoogleFonts.sora(
                                        fontSize: 14,
                                        color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
                                        fontWeight: sel
                                            ? FontWeight.w600
                                            : FontWeight.w400)),
                              ),
                              if (sel)
                                const Icon(Icons.check_rounded,
                                    color: Color(0xFFCC0020), size: 18),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one category')));
      return;
    }
    setState(() => _saving = true);

    final list = await StorageService.loadRecurring();
    final model = RecurringExpenseModel(
      id: widget.existing?.id ?? '',
      name: _nameCtrl.text.trim(),
      amount: double.parse(_amountCtrl.text.trim()),
      frequency: _frequency,
      startDate: _startDate,
      endDate: _hasEndDate ? _endDate : null,
      groupId: _groupId,
      categories: _selectedCategories.toList(),
      description: _descCtrl.text.trim(),
      isActive: widget.existing?.isActive ?? true,
      lastGeneratedDate: widget.existing?.lastGeneratedDate,
    );

    if (widget.existing != null) {
      final idx = list.indexWhere((r) => r.id == widget.existing!.id);
      if (idx >= 0) list[idx] = model;
    } else {
      list.add(RecurringExpenseModel.create(
        name: model.name,
        amount: model.amount,
        frequency: model.frequency,
        startDate: model.startDate,
        endDate: model.endDate,
        groupId: model.groupId,
        categories: model.categories,
        description: model.description,
      ));
    }

    await StorageService.saveRecurring(list);
    await RecurringEngine.run();
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? now),
      firstDate: isStart ? DateTime(2020) : _startDate,
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
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
      body: Stack(
        children: [
          Positioned.fill(
              child: ThemedBackground(darkOverlayOpacity: 0.72)),
          SafeArea(
            child: Column(
              children: [
                _appBar(textPrimary, textSec),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _field(
                            label: 'Expense Name',
                            ctrl: _nameCtrl,
                            hint: 'e.g. Rent, Netflix, Insurance',
                            textPrimary: textPrimary,
                            textSec: textSec,
                            border: border,
                            cardBg: cardBg,
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          _field(
                            label: 'Amount (₹)',
                            ctrl: _amountCtrl,
                            hint: '0',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]'))
                            ],
                            textPrimary: textPrimary,
                            textSec: textSec,
                            border: border,
                            cardBg: cardBg,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (double.tryParse(v) == null ||
                                  double.parse(v) <= 0) {
                                return 'Enter a valid amount';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _sectionLabel('Frequency', textSec),
                          const SizedBox(height: 8),
                          _frequencySelector(textPrimary, textSec, border, cardBg),
                          const SizedBox(height: 16),
                          if (_groups.isNotEmpty) ...[
                            _dropdownField(
                              label: 'Group',
                              value: _groupId.isEmpty ? _groups.first.id : _groupId,
                              items: _groups.map((g) => g.id).toList(),
                              displayNames: _groups.map((g) => g.name).toList(),
                              onChanged: (v) {
                                setState(() {
                                  _groupId = v!;
                                  final validCategories = _currentCategories;
                                  // Clear selected categories that are no longer valid for the new group
                                  _selectedCategories.removeWhere((c) => !validCategories.contains(c));
                                  // If no valid categories remain but the new group has categories, select the first one
                                  if (_selectedCategories.isEmpty && validCategories.isNotEmpty) {
                                    _selectedCategories.add(validCategories.first);
                                  }
                                });
                              },
                              textPrimary: textPrimary,
                              textSec: textSec,
                              border: border,
                              cardBg: cardBg,
                            ),
                            const SizedBox(height: 16),
                          ],
                          _sectionLabel('Category', textSec),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _showCategoryPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedCategories.isEmpty
                                          ? 'Select Categories'
                                          : _selectedCategories.join(', '),
                                      style: GoogleFonts.sora(fontSize: 14, color: textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.arrow_drop_down, color: textSec),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _dateRow(
                            label: 'Start Date',
                            date: _startDate,
                            onTap: () => _pickDate(isStart: true),
                            textPrimary: textPrimary,
                            textSec: textSec,
                            border: border,
                            cardBg: cardBg,
                          ),
                          const SizedBox(height: 16),
                          _endDateSection(
                              textPrimary, textSec, border, cardBg),
                          const SizedBox(height: 16),
                          _field(
                            label: 'Description (optional)',
                            ctrl: _descCtrl,
                            hint: 'e.g. House Rent Mumbai',
                            textPrimary: textPrimary,
                            textSec: textSec,
                            border: border,
                            cardBg: cardBg,
                          ),
                          const SizedBox(height: 32),
                          _saveButton(),
                          const SizedBox(height: 20),
                        ],
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

  // ─── App Bar ───────────────────────────────────────────────────────────────

  Widget _appBar(Color textPrimary, Color textSec) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            widget.existing == null
                ? 'Add Recurring'
                : 'Edit Recurring',
            style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrimary),
          ),
        ],
      ),
    );
  }

  // ─── Frequency Selector ────────────────────────────────────────────────────

  Widget _frequencySelector(Color textPrimary, Color textSec, Color border,
      Color cardBg) {
    return Row(
      children: _frequencies
          .map((f) => Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _frequency = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _frequency == f
                          ? const Color(0xFFCC0020)
                          : cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _frequency == f
                              ? const Color(0xFFCC0020)
                              : border),
                    ),
                    child: Center(
                      child: Text(
                        _capitalize(f),
                        style: GoogleFonts.sora(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _frequency == f
                              ? Colors.white
                              : textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  // ─── End Date Section ──────────────────────────────────────────────────────

  Widget _endDateSection(
      Color textPrimary, Color textSec, Color border, Color cardBg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('End Date',
                style: GoogleFonts.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSec)),
            Row(
              children: [
                Text('Never',
                    style: GoogleFonts.sora(
                        fontSize: 12, color: textSec)),
                const SizedBox(width: 8),
                Switch(
                  value: _hasEndDate,
                  onChanged: (v) => setState(() {
                    _hasEndDate = v;
                    if (v && _endDate == null) {
                      _endDate = DateTime.now()
                          .add(const Duration(days: 365));
                    }
                  }),
                  activeColor: const Color(0xFFCC0020),
                ),
                Text('Set Date',
                    style: GoogleFonts.sora(
                        fontSize: 12, color: textSec)),
              ],
            ),
          ],
        ),
        if (_hasEndDate && _endDate != null)
          _dateRow(
            label: '',
            date: _endDate!,
            onTap: () => _pickDate(isStart: false),
            textPrimary: textPrimary,
            textSec: textSec,
            border: border,
            cardBg: cardBg,
          ),
      ],
    );
  }

  // ─── Save Button ───────────────────────────────────────────────────────────

  Widget _saveButton() => SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF7A0010), Color(0xFFCC0020)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFCC0020).withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
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
                    widget.existing == null
                        ? 'Create Recurring Expense'
                        : 'Save Changes',
                    style: GoogleFonts.sora(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
          ),
        ),
      );

  // ─── Reusable widgets ──────────────────────────────────────────────────────

  Widget _sectionLabel(String label, Color color) => Text(label,
      style: GoogleFonts.sora(
          fontSize: 13, fontWeight: FontWeight.w600, color: color));

  Widget _field({
    required String label,
    required TextEditingController ctrl,
    required String hint,
    required Color textPrimary,
    required Color textSec,
    required Color border,
    required Color cardBg,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          _sectionLabel(label, textSec),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: GoogleFonts.sora(fontSize: 14, color: textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.sora(fontSize: 13, color: textSec),
            filled: true,
            fillColor: cardBg,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFCC0020), width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Colors.red)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Colors.red, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    List<String>? displayNames,
    required ValueChanged<String?> onChanged,
    required Color textPrimary,
    required Color textSec,
    required Color border,
    required Color cardBg,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label, textSec),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              dropdownColor: cardBg,
              style: GoogleFonts.sora(fontSize: 14, color: textPrimary),
              items: items.asMap().entries.map((entry) {
                final display = displayNames != null
                    ? displayNames[entry.key]
                    : _capitalize(entry.value);
                return DropdownMenuItem(
                  value: entry.value,
                  child: Text(display,
                      style: GoogleFonts.sora(
                          fontSize: 14, color: textPrimary)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateRow({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
    required Color textPrimary,
    required Color textSec,
    required Color border,
    required Color cardBg,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          _sectionLabel(label, textSec),
          const SizedBox(height: 6),
        ],
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    color: Color(0xFFCC0020), size: 18),
                const SizedBox(width: 10),
                Text(DateFormat('dd MMM yyyy').format(date),
                    style:
                        GoogleFonts.sora(fontSize: 14, color: textPrimary)),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: textSec),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
