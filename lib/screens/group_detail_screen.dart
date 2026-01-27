import 'dart:io';
import 'package:flutter/material.dart';
import '../services/pdf_export_service.dart';
import '../screens/export_pdf_screen.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';
import 'add_expense_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final GroupModel group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _categoryController = TextEditingController();

  late List<String> _categories;
  List<ExpenseModel> _expenses = [];
  bool _loadingExpenses = true;

  final Map<String, Map<String, dynamic>> _memberStats = {};
  bool _dataChanged = false;

  @override
  void initState() {
    super.initState();
    _categories = [...widget.group.categories];
    _loadExpenses();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  void _markChanged() {
    _dataChanged = true;
  }

  Future<bool> _onWillPop() async {
    Navigator.pop(context, _dataChanged);
    return false;
  }

  Future<void> _loadExpenses() async {
    final all = await StorageService.loadExpenses();

    final groupExpenses =
        all.where((e) => e.groupId == widget.group.id).toList();

    groupExpenses.sort((a, b) => b.date.compareTo(a.date));

    _buildMemberStats(groupExpenses);

    setState(() {
      _expenses = groupExpenses;
      _loadingExpenses = false;
    });
  }

  void _buildMemberStats(List<ExpenseModel> expenses) {
    _memberStats.clear();

    for (final c in _categories) {
      final related = expenses.where((e) => e.categories.contains(c)).toList();

      final total = related.fold<double>(
        0,
        (s, e) => s + (e.amount / e.categories.length),
      );

      related.sort((a, b) => b.date.compareTo(a.date));

      _memberStats[c] = {
        'total': total,
        'lastDate': related.isNotEmpty
            ? related.first.date.toString().split(' ')[0]
            : '-',
      };
    }
  }

  // ---------------- EXPORT ----------------

  Future<void> _exportPdf() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 0);

    final file = await PdfExportService.exportGroupReport(
      group: widget.group,
      expenses: _expenses,
      from: from,
      to: to,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PDF saved to files:\n${file.path}'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ---------------- CATEGORY CRUD ----------------

  Future<void> _addCategory() async {
    final name = _categoryController.text.trim();

    if (name.isEmpty) {
      _toast('Please enter a name');
      return;
    }

    final exists =
        _categories.any((c) => c.toLowerCase() == name.toLowerCase());

    if (exists) {
      _toast('Member already exists');
      return;
    }

    setState(() {
      _categories = [..._categories, name];
      _categoryController.clear();
    });

    await _persistCategories();
    _markChanged();
  }

  Future<void> _editCategory(String oldName) async {
    final controller = TextEditingController(text: oldName);

    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit member'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    final exists =
        _categories.any((c) => c.toLowerCase() == newName.toLowerCase());

    if (exists) {
      _toast('Member already exists');
      return;
    }

    setState(() {
      _categories =
          _categories.map((c) => c == oldName ? newName : c).toList();
    });

    final allExpenses = await StorageService.loadExpenses();

    final updatedExpenses = allExpenses.map((e) {
      if (e.groupId == widget.group.id && e.categories.contains(oldName)) {
        final updatedCats = [...e.categories];
        final i = updatedCats.indexOf(oldName);
        updatedCats[i] = newName;

        return ExpenseModel(
          id: e.id,
          groupId: e.groupId,
          amount: e.amount,
          description: e.description,
          categories: updatedCats,
          date: e.date,
          imagePath: e.imagePath,
        );
      }
      return e;
    }).toList();

    await StorageService.saveExpenses(updatedExpenses);
    await _persistCategories();
    await _loadExpenses();
    _markChanged();
  }

  Future<void> _deleteCategory(String category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete member?'),
        content:
            Text('All expenses linked to "$category" will also be deleted.'),
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

    if (confirmed != true) return;

    setState(() {
      _categories = _categories.where((c) => c != category).toList();
    });

    final allExpenses = await StorageService.loadExpenses();
    allExpenses.removeWhere(
      (e) =>
          e.groupId == widget.group.id &&
          e.categories.contains(category),
    );

    await StorageService.saveExpenses(allExpenses);
    await _persistCategories();
    await _loadExpenses();
    _markChanged();
  }

  Future<void> _persistCategories() async {
    final groups = await StorageService.loadGroups();
    final index = groups.indexWhere((g) => g.id == widget.group.id);
    if (index == -1) return;

    groups[index] = GroupModel(
      id: widget.group.id,
      name: widget.group.name,
      imagePath: widget.group.imagePath,
      categories: _categories,
    );

    await StorageService.saveGroups(groups);
  }

  // ---------------- EXPENSE CRUD ----------------

  Future<void> _deleteExpense(ExpenseModel expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This expense will be permanently deleted.'),
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

    if (confirmed != true) return;

    final allExpenses = await StorageService.loadExpenses();
    allExpenses.removeWhere((e) => e.id == expense.id);

    await StorageService.saveExpenses(allExpenses);
    await _loadExpenses();
    _markChanged();
  }

  // ---------------- RECEIPT PREVIEW ----------------

  void _openReceiptPreview(String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              title: const Text('Receipt'),
              actions: [
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                child: Image.file(File(path)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.group.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExportPdfScreen(
                      group: widget.group,
                      allExpenses: _expenses,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: EleghartColors.accentDark,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add Expense',
              style:
                  TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
          onPressed: () async {
            if (_categories.isEmpty) {
              _toast('Please add at least one member first 👥');
              return;
            }

            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddExpenseScreen(
                  group: widget.group,
                  categories: _categories,
                ),
              ),
            );

            if (result == true) {
              await _loadExpenses();
              _markChanged();
            }
          },
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 22),
              _sectionTitle('Members'),
              _buildAddMemberField(),
              const SizedBox(height: 14),
              _buildMemberCards(),
              const SizedBox(height: 26),
              _sectionTitle('Expenses'),
              const SizedBox(height: 12),
              if (_loadingExpenses)
                const Center(child: CircularProgressIndicator()),
              if (!_loadingExpenses) _buildExpenseList(),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- THEMED HEADER ----------------

  Widget _buildHeader() {
    final total =
        _expenses.fold<double>(0, (sum, e) => sum + e.amount);

    final lastDate = _expenses.isEmpty
        ? '-'
        : _expenses
            .map((e) => e.date)
            .reduce((a, b) => a.isAfter(b) ? a : b)
            .toString()
            .split(' ')[0];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            EleghartColors.accentDark,
            EleghartColors.accentLight.withOpacity(0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: EleghartColors.accentDark.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildGroupAvatarThemed(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.group.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.currency_rupee,
                        size: 18, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      total.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Total Expenses',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      'Last expense: $lastDate',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupAvatarThemed() {
    if (widget.group.imagePath != null &&
        File(widget.group.imagePath!).existsSync()) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 28,
          backgroundImage:
              FileImage(File(widget.group.imagePath!)),
        ),
      );
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.85),
            Colors.white.withOpacity(0.65),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        Icons.group,
        color: EleghartColors.accentDark,
        size: 28,
      ),
    );
  }

  // ---------------- REST UI ----------------

  Widget _buildExpenseList() {
    if (_expenses.isEmpty) {
      return const Text('No expenses yet.',
          style: TextStyle(color: EleghartColors.textSecondary));
    }

    return Column(
      children: _expenses.map((e) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              GestureDetector(
                onTap: e.imagePath == null
                    ? null
                    : () => _openReceiptPreview(e.imagePath!),
                child: e.imagePath == null
                    ? const Icon(Icons.receipt, size: 22)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(File(e.imagePath!),
                            width: 36, height: 36, fit: BoxFit.cover),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.description.isEmpty
                          ? 'Expense'
                          : e.description,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                          '${e.categories.join(", ")} • ${e.date.toString().split(" ")[0]}',
                          style: const TextStyle(
                              fontSize: 12.5,
                              color:
                                  EleghartColors.textSecondary)),
                    ]),
              ),
              Text('₹${e.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800)),
              IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () async {
                    final updated =
                        await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddExpenseScreen(
                          group: widget.group,
                          categories: _categories,
                          existingExpense: e,
                        ),
                      ),
                    );

                    if (updated == true) {
                      await _loadExpenses();
                      _markChanged();
                    }
                  }),
              IconButton(
                  icon: const Icon(Icons.delete,
                      size: 20, color: Colors.red),
                  onPressed: () => _deleteExpense(e)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAddMemberField() {
    return Container(
      decoration: _cardDecoration(),
      child: TextField(
        controller: _categoryController,
        decoration: InputDecoration(
          hintText: 'Add member',
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          suffixIcon: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: EleghartColors.accentDark,
              onPressed: _addCategory),
        ),
      ),
    );
  }

  Widget _buildMemberCards() {
    if (_categories.isEmpty) {
      return const Text('No members yet.',
          style: TextStyle(color: EleghartColors.textSecondary));
    }

    return Column(
      children: _categories.map((c) {
        final stats = _memberStats[c] ??
            {'total': 0.0, 'lastDate': '-'};

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: EleghartColors.accentDark,
                child:
                    Icon(Icons.person, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(c,
                          style: const TextStyle(
                              fontWeight:
                                  FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                          '₹${(stats['total'] as double).toStringAsFixed(0)} • Last: ${stats['lastDate']}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: EleghartColors
                                  .textSecondary)),
                    ]),
              ),
              IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _editCategory(c)),
              IconButton(
                  icon: const Icon(Icons.delete,
                      size: 20, color: Colors.red),
                  onPressed: () => _deleteCategory(c)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildGroupAvatar() {
    if (widget.group.imagePath != null &&
        File(widget.group.imagePath!).existsSync()) {
      return CircleAvatar(
        radius: 26,
        backgroundImage:
            FileImage(File(widget.group.imagePath!)),
      );
    }

    return const CircleAvatar(
      radius: 26,
      backgroundColor: EleghartColors.accentDark,
      child: Icon(Icons.group, color: Colors.white),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
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
