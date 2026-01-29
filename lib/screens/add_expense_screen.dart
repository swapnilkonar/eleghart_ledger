// Fully Updated AddExpenseScreen with Transaction Type (Debit/Credit)
import 'dart:io';
import 'package:flutter/material.dart';
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

  @override
  void dispose() {
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
      lastDate: DateTime.now(),
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

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Expense' : 'Add Expense'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Amount'),
            const SizedBox(height: 8),
            _luxuryField(
              controller: _amountController,
              hint: 'Enter amount (₹)',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 18),

            _sectionTitle('Transaction Type'),
            const SizedBox(height: 10),
            Row(
              children: [
                _typeChip('debit', 'Debit', Colors.redAccent),
                const SizedBox(width: 12),
                _typeChip('credit', 'Credit', Colors.green),
              ],
            ),

            const SizedBox(height: 22),

            _sectionTitle('Description (optional)'),
            const SizedBox(height: 8),
            _luxuryField(
              controller: _descController,
              hint: 'Dinner, Taxi, Refund...',
            ),

            const SizedBox(height: 22),

            _sectionTitle('For whom?'),
            const SizedBox(height: 10),

            if (widget.categories.isEmpty)
              const Text(
                'No members available.\nPlease add members in group first.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: EleghartColors.textSecondary,
                  height: 1.4,
                ),
              ),

            if (widget.categories.isNotEmpty)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: widget.categories.map((c) {
                  final selected = _selected.contains(c);

                  return FilterChip(
                    label: Text(
                      c,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : EleghartColors.textPrimary,
                      ),
                    ),
                    selected: selected,
                    selectedColor: EleghartColors.accentDark,
                    backgroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: Colors.black26,
                    onSelected: (_) {
                      setState(() {
                        selected ? _selected.remove(c) : _selected.add(c);
                      });
                    },
                  );
                }).toList(),
              ),

            const SizedBox(height: 22),

            _sectionTitle('Date'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: _luxuryBox(
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 18, color: EleghartColors.textSecondary),
                    const SizedBox(width: 10),
                    Text(
                      '${_date.toLocal()}'.split(' ')[0],
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: EleghartColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            _sectionTitle('Receipt (optional)'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickImage,
              child: _luxuryBox(
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long,
                        size: 20, color: EleghartColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _image == null
                            ? 'Add receipt photo'
                            : 'Receipt added',
                        style: const TextStyle(
                          fontSize: 15,
                          color: EleghartColors.textPrimary,
                        ),
                      ),
                    ),
                    if (_image != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _image!,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 36),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: !_isValid || _saving ? null : _saveExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EleghartColors.accentDark,
                  foregroundColor: Colors.white,
                  elevation: 10,
                  shadowColor: Colors.black38,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isEditMode ? 'Save Changes' : 'Save Expense',
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- UI HELPERS ----------------

  Widget _typeChip(String value, String label, Color color) {
    final selected = _type == value;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            value == 'debit' ? Icons.remove_circle : Icons.add_circle,
            size: 18,
            color: selected ? Colors.white : color,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: selected,
      selectedColor: color,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : EleghartColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => setState(() => _type = value),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        color: EleghartColors.textPrimary,
      ),
    );
  }

  Widget _luxuryField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: _cardDecoration(),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: EleghartColors.textHint),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
    );
  }

  Widget _luxuryBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: _cardDecoration(),
      child: child,
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 14,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
