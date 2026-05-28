import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/emi_model.dart';
import '../models/group_model.dart';
import '../services/storage_service.dart';
import '../services/recurring_engine.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';

class AddEmiScreen extends StatefulWidget {
  final EmiModel? existing;
  const AddEmiScreen({super.key, this.existing});

  @override
  State<AddEmiScreen> createState() => _AddEmiScreenState();
}

class _AddEmiScreenState extends State<AddEmiScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _groupId = '';
  Set<String> _selectedCategories = {'EMI'};
  DateTime _startDate = DateTime.now();
  List<GroupModel> _groups = [];
  bool _saving = false;

  static const _categories = [
    'EMI', 'Shopping', 'Bills & Utilities', 'Health', 'Travel', 'Others',
  ];

  @override
  void initState() {
    super.initState();
    AppThemeNotifier.instance.addListener(_onTheme);
    _loadGroups();
    if (widget.existing != null) {
      final e = widget.existing!;
      _nameCtrl.text = e.productName;
      _amountCtrl.text = e.amount.toStringAsFixed(0);
      _tenureCtrl.text = e.tenure.toString();
      _descCtrl.text = e.description;
      _groupId = e.groupId;
      _selectedCategories = e.categories.toSet();
      _startDate = e.startDate;
    }
  }

  void _onTheme() => setState(() {});

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_onTheme);
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _tenureCtrl.dispose();
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

    final list = await StorageService.loadEmis();

    if (widget.existing != null) {
      final updated = widget.existing!.copyWith(
        productName: _nameCtrl.text.trim(),
        amount: double.parse(_amountCtrl.text.trim()),
        tenure: int.parse(_tenureCtrl.text.trim()),
        groupId: _groupId,
        categories: _selectedCategories.toList(),
        description: _descCtrl.text.trim(),
        startDate: _startDate,
      );
      final idx = list.indexWhere((e) => e.id == widget.existing!.id);
      if (idx >= 0) list[idx] = updated;
    } else {
      list.add(EmiModel.create(
        productName: _nameCtrl.text.trim(),
        amount: double.parse(_amountCtrl.text.trim()),
        tenure: int.parse(_tenureCtrl.text.trim()),
        startDate: _startDate,
        groupId: _groupId,
        categories: _selectedCategories.toList(),
        description: _descCtrl.text.trim(),
      ));
    }

    await StorageService.saveEmis(list);
    await RecurringEngine.run();
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
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
      body: Stack(
        children: [
          Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.72)),
          SafeArea(
            child: Column(
              children: [
                _appBar(textPrimary),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _field('Product Name', _nameCtrl,
                              'e.g. iPhone 17 Pro, Bike Loan',
                              textPrimary, textSec, border, cardBg,
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Required'
                                  : null),
                          const SizedBox(height: 16),
                          _field('Amount Per EMI (₹)', _amountCtrl, '0',
                              textPrimary, textSec, border, cardBg,
                              keyboardType: TextInputType.number,
                              formatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[\d.]'))
                              ],
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (double.tryParse(v) == null ||
                                    double.parse(v) <= 0) {
                                  return 'Enter valid amount';
                                }
                                return null;
                              }),
                          const SizedBox(height: 16),
                          _field('Tenure (Months)', _tenureCtrl, '12',
                              textPrimary, textSec, border, cardBg,
                              keyboardType: TextInputType.number,
                              formatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                final n = int.tryParse(v);
                                if (n == null || n <= 0) {
                                  return 'Enter valid tenure';
                                }
                                return null;
                              }),
                          const SizedBox(height: 16),
                          _label('Start Date', textSec),
                          const SizedBox(height: 6),
                          _datePicker(textPrimary, textSec, border, cardBg),
                          const SizedBox(height: 16),
                          if (_groups.isNotEmpty) ...[
                            _label('Group (optional)', textSec),
                            const SizedBox(height: 6),
                            _dropdown(
                                _groupId.isEmpty
                                    ? _groups.first.id
                                    : _groupId,
                                _groups.map((g) => g.id).toList(),
                                _groups.map((g) => g.name).toList(),
                                (v) {
                                  setState(() {
                                    _groupId = v!;
                                    final validCategories = _currentCategories;
                                    if (_selectedCategories.isEmpty && validCategories.isNotEmpty) {
                                      _selectedCategories.add(validCategories.first);
                                    }
                                  });
                                },
                                textPrimary, textSec, border, cardBg),
                            const SizedBox(height: 16),
                          ],
                          _label('Category', textSec),
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
                          _field('Description (optional)', _descCtrl,
                              'e.g. iPhone Purchase',
                              textPrimary, textSec, border, cardBg),
                          const SizedBox(height: 16),
                          _preview(textPrimary, textSec, border, cardBg),
                          const SizedBox(height: 32),
                          _saveBtn(),
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

  Widget _appBar(Color textPrimary) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            Text(
              widget.existing == null ? 'Add EMI' : 'Edit EMI',
              style: GoogleFonts.sora(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary),
            ),
          ],
        ),
      );

  Widget _preview(Color textPrimary, Color textSec, Color border, Color cardBg) {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final tenure = int.tryParse(_tenureCtrl.text) ?? 0;
    if (amount <= 0 || tenure <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFCC0020).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCC0020).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFCC0020), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Total: ₹${(amount * tenure).toStringAsFixed(0)} over $tenure months'
              '   |   ₹${amount.toStringAsFixed(0)}/month',
              style: GoogleFonts.sora(
                  fontSize: 12, color: const Color(0xFFCC0020)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveBtn() => SizedBox(
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
                    widget.existing == null ? 'Create EMI' : 'Save Changes',
                    style: GoogleFonts.sora(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
          ),
        ),
      );

  Widget _label(String t, Color c) => Text(t,
      style: GoogleFonts.sora(
          fontSize: 13, fontWeight: FontWeight.w600, color: c));

  Widget _datePicker(Color textPrimary, Color textSec, Color border,
      Color cardBg) {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
            Text(DateFormat('dd MMM yyyy').format(_startDate),
                style: GoogleFonts.sora(fontSize: 14, color: textPrimary)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textSec),
          ],
        ),
      ),
    );
  }

  Widget _dropdown(String value, List<String> items, List<String>? display,
      ValueChanged<String?> onChange, Color textPrimary, Color textSec,
      Color border, Color cardBg) {
    final safeValue = items.contains(value) ? value : items.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          dropdownColor: cardBg,
          style: GoogleFonts.sora(fontSize: 14, color: textPrimary),
          items: items.asMap().entries.map((e) {
            final label = display != null ? display[e.key] : e.value;
            return DropdownMenuItem(
                value: e.value,
                child: Text(label,
                    style:
                        GoogleFonts.sora(fontSize: 14, color: textPrimary)));
          }).toList(),
          onChanged: onChange,
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint,
      Color textPrimary, Color textSec, Color border, Color cardBg,
      {TextInputType keyboardType = TextInputType.text,
      List<TextInputFormatter>? formatters,
      String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, textSec),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          validator: validator,
          onChanged: (_) => setState(() {}),
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
                borderSide: const BorderSide(color: Colors.red)),
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
}
