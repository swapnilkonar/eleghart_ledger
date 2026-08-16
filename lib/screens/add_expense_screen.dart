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
import '../widgets/expense_distribution_widget.dart';

class AddExpenseScreen extends StatefulWidget {
  final GroupModel group;
  final List<String> categories;
  final ExpenseModel? existingExpense; // edit mode
  final File? initialImage;

  const AddExpenseScreen({
    super.key,
    required this.group,
    required this.categories,
    this.existingExpense,
    this.initialImage,
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

  // Distribution
  Map<String, double>? _distribution;
  bool _customSplitValid = true;

  // Dynamic Categories
  List<String> _availableCategories = [];
  late GroupModel _currentGroup;

  bool get isEditMode => widget.existingExpense != null;

  @override
  void initState() {
    super.initState();
    _currentGroup = widget.group;
    _image = widget.initialImage;
    AppThemeNotifier.instance.addListener(_onThemeChanged);
    _loadCategories();

    if (isEditMode) {
      final e = widget.existingExpense!;
      _amountController.text = e.amount.toStringAsFixed(0);
      _descController.text = e.description;
      _date = e.date;
      _selected.addAll(e.categories);
      _type = e.type;
      _distribution = e.distribution;

      if (e.imagePath != null && File(e.imagePath!).existsSync()) {
        _image = File(e.imagePath!);
      }
    }
  }

  Future<void> _loadCategories() async {
    final gc = await StorageService.loadGlobalCategories();
    final set = <String>{};
    set.addAll(widget.categories);
    set.addAll(gc);
    set.addAll(_currentGroup.categories);
    if (mounted) {
      setState(() {
        _availableCategories = set.toList();
      });
    }
  }

  Future<void> _switchGroup() async {
    final groups = await StorageService.loadGroups();
    if (groups.isEmpty) return;

    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite ? Colors.black54 : Colors.white54;

    final selected = await showModalBottomSheet<GroupModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isWhite ? Colors.white : const Color(0xFF160606),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_copy_rounded, color: Color(0xFFCC0020), size: 22),
                const SizedBox(width: 10),
                Text('Switch Group', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
                const Spacer(),
                IconButton(icon: Icon(Icons.close, color: textPrimary), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Select group for this expense:', style: GoogleFonts.sora(fontSize: 12, color: textSec)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: groups.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final g = groups[i];
                  return InkWell(
                    onTap: () => Navigator.pop(ctx, g),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isWhite ? const Color(0xFFF8FAFC) : const Color(0xFF220C0C),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCC0020).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.group_rounded, color: Color(0xFFCC0020), size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(g.name, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
                                Text('${g.categories.length} categories / members', style: GoogleFonts.sora(fontSize: 11, color: textSec)),
                              ],
                            ),
                          ),
                          if (g.id == _currentGroup.id)
                            const Icon(Icons.check_circle_rounded, color: Color(0xFFCC0020), size: 20)
                          else
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFCC0020)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
    );

    if (selected != null) {
      setState(() {
        _currentGroup = selected;
        _availableCategories = selected.categories.isEmpty ? ['General'] : selected.categories;
        _selected.clear();
      });
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

    try {
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) return;

      if (mounted) setState(() => _image = File(picked.path));
    } catch (e) {
      debugPrint("Error picking expense image: $e");
    }
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
          groupId: _currentGroup.id,
          amount: totalAmount,
          description: _descController.text.trim(),
          categories: _selected.toList(),
          date: _date,
          imagePath: _image?.path,
          type: _type,
          distribution: _distribution,
        );
      }
    } else {
      expenses.add(
        ExpenseModel(
          id: const Uuid().v4(),
          groupId: _currentGroup.id,
          amount: totalAmount,
          description: _descController.text.trim(),
          categories: _selected.toList(),
          date: _date,
          imagePath: _image?.path,
          type: _type,
          distribution: _distribution,
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
      _amountController.text.trim().isNotEmpty &&
      _selected.isNotEmpty &&
      _customSplitValid;

  Future<void> _showMemberPicker() async {
    final addCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF120404),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isWhite = AppThemeNotifier.isWhite;
          final categoriesList = _availableCategories.isNotEmpty
              ? _availableCategories
              : widget.categories;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: isWhite ? const Color(0xFFCC0020).withValues(alpha: 0.25) : Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('For Whom? (Members / Categories)',
                        style: GoogleFonts.sora(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isWhite ? EleghartColors.accentDark : Colors.white)),
                    Text(
                      '${_selected.length} selected',
                      style: GoogleFonts.sora(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFCC0020),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Inline Input to add New Member / Category
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isWhite ? const Color(0xFFF4F6F9) : const Color(0xFF1C080B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFCC0020).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFCC0020), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: addCtrl,
                          textCapitalization: TextCapitalization.words,
                          style: GoogleFonts.sora(
                            fontSize: 13,
                            color: isWhite ? EleghartColors.accentDark : Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add new member or category...',
                            hintStyle: GoogleFonts.sora(
                              fontSize: 13,
                              color: isWhite ? EleghartColors.accentDark.withValues(alpha: 0.35) : Colors.white38,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onSubmitted: (val) async {
                            final name = val.trim();
                            if (name.isNotEmpty) {
                              await _addNewMemberOrCategory(name, setModalState);
                              addCtrl.clear();
                            }
                          },
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final name = addCtrl.text.trim();
                          if (name.isNotEmpty) {
                            await _addNewMemberOrCategory(name, setModalState);
                            addCtrl.clear();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCC0020),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Add',
                            style: GoogleFonts.sora(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: SingleChildScrollView(
                    child: Column(
                      children: categoriesList.map((c) {
                        final sel = _selected.contains(c);
                        final isNumericName = RegExp(r'^\d+$').hasMatch(c.trim());

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
                                  ? const Color(0xFFCC0020).withValues(alpha: 0.12)
                                  : (isWhite ? Colors.white : Colors.white.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: sel
                                    ? const Color(0xFFCC0020).withValues(alpha: 0.5)
                                    : (isWhite ? const Color(0xFFEEEEEE) : Colors.white.withValues(alpha: 0.10)),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: sel
                                        ? const Color(0xFFCC0020)
                                        : (isWhite ? const Color(0xFFF4F6F9) : Colors.white10),
                                  ),
                                  child: Center(
                                    child: isNumericName
                                        ? Icon(
                                            Icons.person_rounded,
                                            size: 15,
                                            color: sel
                                                ? Colors.white
                                                : (isWhite
                                                    ? const Color(0xFFCC0020)
                                                    : Colors.white70),
                                          )
                                        : Text(
                                            c.isNotEmpty ? c[0].toUpperCase() : '?',
                                            style: GoogleFonts.sora(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: sel
                                                  ? Colors.white
                                                  : (isWhite
                                                      ? EleghartColors.accentDark
                                                      : Colors.white70),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(c,
                                      style: GoogleFonts.sora(
                                          fontSize: 14,
                                          color: isWhite ? EleghartColors.accentDark : Colors.white,
                                          fontWeight: sel
                                              ? FontWeight.w700
                                              : FontWeight.w400)),
                                ),
                                if (sel)
                                  const Icon(Icons.check_circle_rounded,
                                      color: Color(0xFFCC0020), size: 20),
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
          );
        },
      ),
    );
  }

  Future<void> _addNewMemberOrCategory(String name, StateSetter setModalState) async {
    // 1. Add to global categories
    final gc = await StorageService.loadGlobalCategories();
    if (!gc.contains(name)) {
      gc.add(name);
      await StorageService.saveGlobalCategories(gc);
    }

    // 2. Add to group categories in storage
    final allGroups = await StorageService.loadGroups();
    final gIdx = allGroups.indexWhere((g) => g.id == widget.group.id);
    if (gIdx != -1) {
      if (!allGroups[gIdx].categories.contains(name)) {
        allGroups[gIdx].categories.add(name);
        await StorageService.saveGroups(allGroups);
      }
    }

    // 3. Update memory state & select
    setModalState(() {
      if (!_availableCategories.contains(name)) {
        _availableCategories.add(name);
      }
      if (!widget.categories.contains(name)) {
        widget.categories.add(name);
      }
      if (!widget.group.categories.contains(name)) {
        widget.group.categories.add(name);
      }
      _selected.add(name);
    });

    setState(() {});
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
                        // Target Group Card
                        GestureDetector(
                          onTap: _switchGroup,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppThemeNotifier.isWhite ? const Color(0xFFF8FAFC) : const Color(0xFF1B0A0A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFCC0020).withOpacity(0.35), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCC0020).withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.folder_special_rounded, color: Color(0xFFCC0020), size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Destination Group', style: GoogleFonts.sora(fontSize: 11, color: AppThemeNotifier.isWhite ? Colors.black54 : Colors.white54)),
                                      const SizedBox(height: 2),
                                      Text(_currentGroup.name, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCC0020).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('Change Group', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFCC0020))),
                                ),
                              ],
                            ),
                          ),
                        ),

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

                        // Distribution
                        if (_selected.length > 1) ...
                          [
                            _label('Expense Distribution'),
                            const SizedBox(height: 8),
                            ExpenseDistributionWidget(
                              key: ValueKey(_selected.join(',')),
                              totalAmount: double.tryParse(_amountController.text.trim()) ?? 0,
                              items: _selected.toList(),
                              initialDistribution: _distribution,
                              onChanged: (dist, valid) {
                                setState(() {
                                  _distribution = dist;
                                  _customSplitValid = valid;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                          ],

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
