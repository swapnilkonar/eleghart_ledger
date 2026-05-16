// GroupDetailScreen — Modern Glassmorphic UI with Interactive Effects
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/pdf_export_service.dart';
import '../screens/export_pdf_screen.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';
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

  // -------- NEW: FILTER + SEARCH STATE --------
  String _expenseFilter = 'all'; // all | debit | credit
  String _searchQuery = '';

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

  // ---------------- MEMBER STATS (LEDGER AWARE) ----------------

  void _buildMemberStats(List<ExpenseModel> expenses) {
    _memberStats.clear();

    for (final c in _categories) {
      final related = expenses.where((e) => e.categories.contains(c)).toList();

      final total = related.fold<double>(0, (s, e) {
        final share = e.amount / e.categories.length;
        return e.type == 'credit' ? s + share : s - share;
      });

      related.sort((a, b) => b.date.compareTo(a.date));

      _memberStats[c] = {
        'total': total,
        'lastDate': related.isNotEmpty
            ? related.first.date.toString().split(' ')[0]
            : '-',
      };
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            widget.group.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: EleghartColors.textPrimary,
          actions: [
            GlassContainer(
              borderRadius: 12,
              padding: const EdgeInsets.all(6),
              interactive: true,
              onTap: () async {
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
              child: const Icon(Icons.picture_as_pdf,
                  color: EleghartColors.accentDark, size: 24),
            ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: GestureDetector(
          onTap: () async {
            if (_categories.isEmpty) {
              _toast('Please add at least one member / category first 👥');
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
          child: GlassContainer(
            borderRadius: 28,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Add Expense',
                  style: GlassTheme.headingSmall.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 22),
              _sectionTitle('Members / Category'),
              _buildAddMemberField(),
              const SizedBox(height: 14),
              _buildMemberCards(),
              const SizedBox(height: 26),
              _sectionTitle('Expenses'),
              const SizedBox(height: 10),

              // -------- FILTER CHIPS --------
              Row(
                children: [
                  _filterChip('all', 'All'),
                  const SizedBox(width: 8),
                  _filterChip('debit', 'Debit'),
                  const SizedBox(width: 8),
                  _filterChip('credit', 'Credit'),
                ],
              ),

              const SizedBox(height: 12),

              // -------- SEARCH FIELD --------
              Container(
                decoration: _cardDecoration(),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by name, amount, description…',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
              ),

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

  // ---------------- SUMMARY HEADER ----------------

  Widget _buildHeader() {
    double totalDebit = 0;
    double totalCredit = 0;

    for (final e in _expenses) {
      if (e.type == 'credit') {
        totalCredit += e.amount;
      } else {
        totalDebit += e.amount;
      }
    }

    final netBalance = totalCredit - totalDebit;
    final isPositive = netBalance >= 0;
    final netColor = isPositive ? Colors.greenAccent : Colors.redAccent;
    final netSign = isPositive ? '+' : '–';

    final lastDate = _expenses.isEmpty
        ? '-'
        : _expenses
            .map((e) => e.date)
            .reduce((a, b) => a.isAfter(b) ? a : b)
            .toString()
            .split(' ')[0];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Transform.scale(
          scale: 0.8 + (value * 0.2),
          alignment: Alignment.topCenter,
          child: Opacity(
            opacity: value,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        EleghartColors.accentDark.withOpacity(0.25),
                        EleghartColors.accentLight.withOpacity(0.15),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: EleghartColors.accentDark.withOpacity(0.2),
                        blurRadius: 32,
                        offset: const Offset(0, 16),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.remove_circle,
                                    size: 18, color: Colors.white70),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '₹${totalDebit.toStringAsFixed(0)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('Debit',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.white70)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.add_circle,
                                    size: 18, color: Colors.white70),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '₹${totalCredit.toStringAsFixed(0)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('Credit',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.white70)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.account_balance_wallet,
                                    size: 18, color: Colors.white70),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '$netSign ₹${netBalance.abs().toStringAsFixed(0)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: netColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        );
      },
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
          backgroundImage: FileImage(File(widget.group.imagePath!)),
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

  // ---------------- EXPENSE LIST ----------------

  Widget _buildExpenseList() {
    final visibleExpenses = _expenses.where((e) {
      // ---- TYPE FILTER ----
      if (_expenseFilter != 'all' && e.type != _expenseFilter) {
        return false;
      }

      // ---- SEARCH FILTER ----
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();

        final desc = e.description.toLowerCase();
        final cats = e.categories.join(',').toLowerCase();
        final amt = e.amount.toString();

        if (!desc.contains(q) && !cats.contains(q) && !amt.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();

    if (visibleExpenses.isEmpty) {
      return const Text('No matching expenses.',
          style: TextStyle(color: EleghartColors.textSecondary));
    }

    return Column(
      children: visibleExpenses.map((e) {
        final isCredit = e.type == 'credit';
        final typeLabel = isCredit ? 'CREDIT' : 'DEBIT';
        final typeColor = isCredit ? Colors.green : Colors.red;

        return GestureDetector(
          onTap: () => _openExpenseDetails(e),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(typeLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: typeColor)),
                ),
                const SizedBox(width: 10),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(e.categories.join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: EleghartColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(e.date.toString().split(' ')[0],
                            style: const TextStyle(
                                fontSize: 12,
                                color: EleghartColors.textSecondary)),
                      ]),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  child: Text('₹${e.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: typeColor)),
                ),
                IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () async {
                      final updated = await Navigator.push(
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
          ),
        );
      }).toList(),
    );
  }

  // ---------------- EXPENSE DETAILS POPUP ----------------

  void _openExpenseDetails(ExpenseModel e) {
    final isCredit = e.type == 'credit';
    final typeLabel = isCredit ? 'CREDIT' : 'DEBIT';
    final typeColor = isCredit ? Colors.green : Colors.red;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14)),
                    child: Text(typeLabel,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: typeColor))),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context))
              ]),
              const SizedBox(height: 10),
              Text('₹${e.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: typeColor)),
              const SizedBox(height: 10),
              if (e.description.isNotEmpty) ...[
                const Text('Description',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: EleghartColors.textSecondary)),
                const SizedBox(height: 4),
                Text(e.description,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
              ],
              const Text('Members / Category',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: EleghartColors.textSecondary)),
              const SizedBox(height: 4),
              Text(e.categories.join(', '),
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const Text('Date',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: EleghartColors.textSecondary)),
              const SizedBox(height: 4),
              Text(e.date.toString().split(' ')[0],
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              if (e.imagePath != null && File(e.imagePath!).existsSync()) ...[
                const Text('Receipt',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: EleghartColors.textSecondary)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _openReceiptPreview(e.imagePath!);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(e.imagePath!),
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- HELPERS ----------------

  Widget _filterChip(String value, String label) {
    final selected = _expenseFilter == value;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? EleghartColors.accentDark.withOpacity(0.25)
                : Colors.white.withOpacity(0.15),
            border: Border.all(
              color: selected
                  ? EleghartColors.accentLight.withOpacity(0.5)
                  : Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: GestureDetector(
            onTap: () => setState(() => _expenseFilter = value),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : EleghartColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildAddMemberField() {
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      interactive: false,
      child: TextField(
        controller: _categoryController,
        decoration: InputDecoration(
          hintText: 'Add member / category',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          suffixIcon: GestureDetector(
            onTap: _addCategory,
            child: const Icon(Icons.add_circle_outline,
                color: EleghartColors.accentDark),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCards() {
    if (_categories.isEmpty) {
      return const Text('No members / category yet.',
          style: TextStyle(color: EleghartColors.textSecondary));
    }

    return Column(
      children: _categories.asMap().entries.map((entry) {
        final index = entry.key;
        final c = entry.value;
        final stats = _memberStats[c] ?? {'total': 0.0, 'lastDate': '-'};

        final total = stats['total'] as double;
        final isPositive = total >= 0;
        final sign = isPositive ? '+' : '–';
        final color = isPositive ? Colors.green : Colors.red;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 400 + (index * 100)),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return Transform.translate(
              offset: Offset(30 * (1 - value), 0),
              child: Opacity(
                opacity: value,
                child: GlassMorphicCard(
                  borderRadius: 20,
                  bgColor: Colors.white,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              EleghartColors.accentDark,
                              EleghartColors.accentLight,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person,
                            size: 22, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$sign ₹${total.abs().toStringAsFixed(0)} • Last: ${stats['lastDate']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _editCategory(c),
                        child: const Icon(Icons.edit,
                            size: 20,
                            color: EleghartColors.textSecondary),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _deleteCategory(c),
                        child: const Icon(Icons.delete,
                            size: 20, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              );
            );
          },
        );
      }).toList(),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: GlassTheme.headingSmall.copyWith(
          fontSize: 16.5,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 14,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // ---------------- CATEGORY CRUD ----------------

  Future<void> _addCategory() async {
    final name = _categoryController.text.trim();

    if (name.isEmpty) {
      _toast('Please enter a name');
      return;
    }

    if (_categories.any((c) => c.toLowerCase() == name.toLowerCase())) {
      _toast('Member / Category already exists');
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
        title: const Text('Edit member / category'),
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

    if (_categories.any((c) => c.toLowerCase() == newName.toLowerCase())) {
      _toast('Member / Category already exists');
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
          type: e.type,
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
        title: const Text('Delete member / category?'),
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
      (e) => e.groupId == widget.group.id && e.categories.contains(category),
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
}
