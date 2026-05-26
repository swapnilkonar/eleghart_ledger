// Fully Updated AddExpenseScreen with Transaction Type (Debit/Credit)
import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';

class AddExpenseScreen extends StatefulWidget {
  final GroupModel group;
  final List<String> categories;
  final ExpenseModel? existingExpense; // edit mode

  const AddExpenseScreen({
    super.key,
    required this.group,
    required this.categories,
    this.existingExpense,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  final Set<String> _selected = {};
  DateTime _date = DateTime.now();
  File? _image;
  bool _saving = false;

  // Transaction type
  String _type = 'debit'; // default

  bool get isEditMode => widget.existingExpense != null;

  @override
  void initState() {
    super.initState();
    AppThemeNotifier.instance.addListener(_onThemeChanged);

    if (isEditMode) {
      final e = widget.existingExpense!;
      _amountController.text = e.amount.toStringAsFixed(0);
      _descController.text = e.description;
      _date = e.date;
      _selected.addAll(e.categories);
      _type = e.type;

      if (e.imagePath != null && File(e.imagePath!).existsSync()) {
        _image = File(e.imagePath!);
      }
    }
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_onThemeChanged);
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // ---------------- PICK RECEIPT ----------------

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(source: source, imageQuality: 75);
    if (picked == null) return;

    setState(() => _image = File(picked.path));
  }

  // ---------------- DATE PICKER ----------------

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  // ---------------- SAVE EXPENSE ----------------

  Future<void> _saveExpense() async {
    final amountText = _amountController.text.trim();

    if (amountText.isEmpty) {
      _toast('Please enter amount');
      return;
    }

    if (_selected.isEmpty) {
      _toast('Please select at least one member/category');
      return;
    }

    double totalAmount;
    try {
      totalAmount = double.parse(amountText);
    } catch (_) {
      _toast('Enter a valid number');
      return;
    }

    if (totalAmount <= 0) {
      _toast('Amount must be greater than zero');
      return;
    }

    setState(() => _saving = true);

    final expenses = await StorageService.loadExpenses();

    if (isEditMode) {
      final index = expenses.indexWhere(
        (e) => e.id == widget.existingExpense!.id,
      );

      if (index != -1) {
        expenses[index] = ExpenseModel(
          id: widget.existingExpense!.id,
          groupId: widget.group.id,
          amount: totalAmount,
          description: _descController.text.trim(),
          categories: _selected.toList(),
          date: _date,
          imagePath: _image?.path,
          type: _type,
        );
      }
    } else {
      expenses.add(
        ExpenseModel(
          id: const Uuid().v4(),
          groupId: widget.group.id,
          amount: totalAmount,
          description: _descController.text.trim(),
          categories: _selected.toList(),
          date: _date,
          imagePath: _image?.path,
          type: _type,
        ),
      );
    }

    await StorageService.saveExpenses(expenses);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  bool get _isValid =>
      _amountController.text.trim().isNotEmpty && _selected.isNotEmpty;

  Future<void> _showMemberPicker() async {
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
              Text('Select Members',
                  style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white)),
              const SizedBox(height: 16),
              ...widget.categories.map((c) {
                final sel = _selected.contains(c);
                return GestureDetector(
                  onTap: () {
                    setModalState(() {
                      sel ? _selected.remove(c) : _selected.add(c);
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
                        Icon(Icons.person_rounded,
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
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final selectedText = _selected.isEmpty
        ? 'Select members'
        : _selected.join(', ');

    return Scaffold(
      backgroundColor: AppThemeNotifier.isWhite ? Colors.white : Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.72)),
          SafeArea(
            child: Column(
              children: [
                // ── App bar ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFCC0020).withOpacity(0.6),
                              width: 1.5,
                            ),
                            color: const Color(0xFFCC0020).withOpacity(0.10),
                          ),
                          child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        isEditMode ? 'Edit Expense' : 'Add Expense',
                        style: GoogleFonts.sora(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable form ──────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Amount
                        _label('Amount'),
                        const SizedBox(height: 8),
                        _darkField(
                          controller: _amountController,
                          hint: 'Enter amount (₹)',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(10),
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCC0020).withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text('₹',
                                  style: GoogleFonts.sora(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFCC0020))),
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*')),
                          ],
                          onChanged: (_) => setState(() {}),
                        ),

                        const SizedBox(height: 20),

                        // Transaction Type
                        _label('Transaction Type'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _typeButton('debit', 'Debit',
                                Icons.remove_circle_rounded,
                                const Color(0xFFFF3355))),
                            const SizedBox(width: 12),
                            Expanded(child: _typeButton('credit', 'Credit',
                                Icons.add_circle_rounded,
                                const Color(0xFF00CC66))),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Description
                        _label('Description (optional)'),
                        const SizedBox(height: 8),
                        _darkField(
                          controller: _descController,
                          hint: 'Dinner, Taxi, Refund...',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Icon(Icons.description_rounded,
                                size: 18,
                                color: const Color(0xFFCC0020)
                                    .withOpacity(0.7)),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // For whom
                        _label('For whom?'),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: widget.categories.isEmpty
                              ? null
                              : _showMemberPicker,
                          child: _darkRow(
                            icon: Icons.groups_rounded,
                            text: widget.categories.isEmpty
                                ? 'No members in group yet'
                                : selectedText,
                            textColor: _selected.isEmpty
                                ? Colors.white38
                                : Colors.white,
                            showChevron: widget.categories.isNotEmpty,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Date
                        _label('Date'),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickDate,
                          child: _darkRow(
                            icon: Icons.calendar_month_rounded,
                            text: '${_date.toLocal()}'.split(' ')[0],
                            showChevron: true,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Receipt
                        _label('Receipt (optional)'),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: _darkBox(),
                            child: Row(
                              children: [
                                Icon(Icons.receipt_long_rounded,
                                    size: 18,
                                    color: const Color(0xFFCC0020)
                                        .withOpacity(0.7)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _image == null
                                        ? 'Add receipt photo'
                                        : 'Receipt added ✓',
                                    style: GoogleFonts.sora(
                                      fontSize: 14,
                                      color: _image == null
                                          ? (AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.4) : Colors.white38)
                                          : const Color(0xFF00CC66),
                                    ),
                                  ),
                                ),
                                if (_image != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(_image!,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover),
                                  )
                                else
                                  const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.white24, size: 20),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // ── Save button ──────────────────────────────────────────
                Padding(
                  padding:
                      EdgeInsets.fromLTRB(20, 8, 20, safeBottom + 16),
                  child: GestureDetector(
                    onTap: !_isValid || _saving ? null : _saveExpense,
                    child: AnimatedOpacity(
                      opacity: _isValid ? 1.0 : 0.45,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const RadialGradient(
                            center: Alignment.center,
                            radius: 0.9,
                            colors: [
                              Color(0xFFCC0020),
                              Color(0xFF6B0010),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFCC0020)
                                  .withOpacity(0.5),
                              blurRadius: 22,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFFFF2040).withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: 6, left: 60, right: 60,
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: LinearGradient(colors: [
                                    Colors.transparent,
                                    Colors.white.withOpacity(0.22),
                                    Colors.transparent,
                                  ]),
                                ),
                              ),
                            ),
                            _saving
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white),
                                  )
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                          Icons.save_rounded,
                                          color: Colors.white, size: 20),
                                      const SizedBox(width: 10),
                                      Text(
                                        isEditMode
                                            ? 'Save Changes'
                                            : 'Save Expense',
                                        style: GoogleFonts.sora(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                          ],
                        ),
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

  // ---------------- UI HELPERS ----------------

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.sora(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white),
      );

  BoxDecoration _darkBox() => AppThemeNotifier.isWhite
      ? BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
          boxShadow: [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 2))],
        )
      : BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
        );

  Widget _darkField({
    required TextEditingController controller,
    required String hint,
    Widget? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: _darkBox(),
      child: Row(
        children: [
          if (prefixIcon != null) prefixIcon,
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              onChanged: onChanged,
              style: GoogleFonts.sora(fontSize: 14, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.sora(
                    fontSize: 14, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.35) : Colors.white30),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: prefixIcon == null ? 16 : 0,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _darkRow({
    required IconData icon,
    required String text,
    Color textColor = Colors.white,
    bool showChevron = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: _darkBox(),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: const Color(0xFFCC0020).withOpacity(0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(fontSize: 14, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : textColor),
            ),
          ),
          if (showChevron)
            Icon(Icons.chevron_right_rounded,
                color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.3) : Colors.white24, size: 20),
        ],
      ),
    );
  }

  Widget _typeButton(
      String value, String label, IconData icon, Color color) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : (AppThemeNotifier.isWhite ? Colors.white : Colors.white.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color.withOpacity(0.8) : (AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.12)),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 12)]
              : (AppThemeNotifier.isWhite ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))] : []),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : (AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white54),
                  ),
                ),
              ],
            ),
            if (selected)
              Positioned(
                top: 0, right: 8,
                child: Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
