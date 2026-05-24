// GroupDetailScreen — Ledger UX: Net Balance, Filters, Search, Type Badge, Date Visible, Expense Details Popup
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../widgets/themed_background.dart';
import '../utils/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/pdf_export_service.dart';
import '../screens/export_pdf_screen.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';
import 'add_expense_screen.dart';
import '../utils/date_filter.dart';
import '../widgets/date_filter_pill.dart';

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
  Map<String, String> _categoryImages = {};

  final Map<String, Map<String, dynamic>> _memberStats = {};
  bool _dataChanged = false;
  late String _groupName;
  String? _groupImagePath;

  // -------- NEW: FILTER + SEARCH STATE --------
  String _expenseFilter = 'all'; // all | debit | credit
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _categories = [...widget.group.categories];
    _groupName = widget.group.name;
    _groupImagePath = widget.group.imagePath;
    _loadExpenses();
    DateFilter.notifier.addListener(_onFilterChanged);
    AppThemeNotifier.instance.addListener(_onThemeChanged);
  }

  void _onThemeChanged() => setState(() {});

  void _onFilterChanged() {
    _buildMemberStats(_expenses);
    setState(() {});
  }

  @override
  void dispose() {
    DateFilter.notifier.removeListener(_onFilterChanged);
    AppThemeNotifier.instance.removeListener(_onThemeChanged);
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
    final catImages = await StorageService.loadCategoryImages();
    if (mounted) setState(() => _categoryImages = catImages);
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
      final related = expenses.where((e) => e.categories.contains(c) && DateFilter.isInRange(e.date)).toList();

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

  Future<void> _addExpense() async {
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
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.72)),
            SafeArea(
              child: Column(
                children: [
                  // ── Custom AppBar ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context, _dataChanged),
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
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _groupName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.sora(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExportPdfScreen(
                                group: widget.group,
                                allExpenses: _expenses,
                              ),
                            ),
                          ),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFCC0020).withOpacity(0.4),
                                width: 1,
                              ),
                              color: const Color(0xFFCC0020).withOpacity(0.08),
                            ),
                            child: const Icon(Icons.picture_as_pdf_rounded,
                                color: Color(0xFFCC0020), size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Scrollable body ────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 22),
                          _sectionTitle('Members / Category'),
                          _buildAddMemberField(),
                          const SizedBox(height: 10),
                          _buildMemberCards(),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _sectionTitle('Expenses'),
                              const DateFilterPill(),
                            ],
                          ),
                          const SizedBox(height: 10),
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
                          // Search
                          Container(
                            decoration: BoxDecoration(
                              color: AppThemeNotifier.isWhite ? Colors.white : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.10)),
                              boxShadow: AppThemeNotifier.isWhite ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))] : [],
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 14),
                                Icon(Icons.search_rounded,
                                    color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.4) : Colors.white38, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    style: GoogleFonts.sora(
                                        fontSize: 13, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Search by name, amount, description...',
                                      hintStyle: GoogleFonts.sora(
                                          fontSize: 13, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.35) : Colors.white30),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 14),
                                    ),
                                    onChanged: (v) =>
                                        setState(() => _searchQuery = v.trim()),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.tune_rounded,
                                    color: const Color(0xFFCC0020)
                                        .withOpacity(0.7),
                                    size: 18),
                                const SizedBox(width: 14),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_loadingExpenses)
                            const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFFCC0020)),
                            )
                          else
                            _buildExpenseList(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // ── Add Expense button ─────────────────────────────────
                  Padding(
                    padding:
                        EdgeInsets.fromLTRB(20, 8, 20, safeBottom + 16),
                    child: GestureDetector(
                      onTap: _addExpense,
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
                              color:
                                  const Color(0xFFCC0020).withOpacity(0.5),
                              blurRadius: 22,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color:
                                  const Color(0xFFCC0020).withOpacity(0.2),
                              blurRadius: 40,
                              spreadRadius: 4,
                            ),
                          ],
                          border: Border.all(
                            color:
                                const Color(0xFFFF2040).withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: 6,
                              left: 60,
                              right: 60,
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.22),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_rounded,
                                    color: Colors.white, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  'Add Expense',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- SUMMARY HEADER ----------------

  Widget _buildHeader() {
    final filtered = _expenses.where((e) => DateFilter.isInRange(e.date)).toList();
    double totalDebit = 0;
    double totalCredit = 0;
    for (final e in filtered) {
      if (e.type == 'credit') totalCredit += e.amount;
      else totalDebit += e.amount;
    }
    final netBalance = totalCredit - totalDebit;
    final isPositive = netBalance >= 0;
    final netColor = isPositive ? const Color(0xFF00CC66) : const Color(0xFFFF3355);
    final lastDate = filtered.isEmpty
        ? '-'
        : filtered.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b).toString().split(' ')[0];

    return Container(
      decoration: BoxDecoration(
        color: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF120404),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.45), width: AppThemeNotifier.isWhite ? 1 : 1.2),
        boxShadow: AppThemeNotifier.isWhite
            ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.10), blurRadius: 12, offset: const Offset(0, 2))]
            : [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.2), blurRadius: 24, spreadRadius: 2)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            // Mountain silhouette background
            if (!AppThemeNotifier.isWhite)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Opacity(
                  opacity: 0.18,
                  child: Image.asset(
                    'assets/images/background_theme_top_glow.png',
                    height: 90,
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sora(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _editGroupName,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFCC0020).withOpacity(0.12),
                          ),
                          child: Icon(Icons.edit_rounded, size: 14,
                            color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildGroupAvatar(),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _statRow(
                              Icons.remove_circle_rounded,
                              const Color(0xFFFF3355),
                              '₹${totalDebit.toStringAsFixed(0)}',
                              'Total Debit',
                            ),
                            const SizedBox(height: 10),
                            _statRow(
                              Icons.add_circle_rounded,
                              const Color(0xFF00CC66),
                              '₹${totalCredit.toStringAsFixed(0)}',
                              'Total Credit',
                            ),
                            const SizedBox(height: 10),
                            _statRow(
                              Icons.account_balance_wallet_rounded,
                              const Color(0xFF00BBCC),
                              '₹${netBalance.abs().toStringAsFixed(0)}',
                              'Net Balance',
                              valueColor: netColor,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_rounded,
                                    size: 13, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.4) : Colors.white38),
                                const SizedBox(width: 6),
                                Text(
                                  'Last expense: $lastDate',
                                  style: GoogleFonts.sora(
                                      fontSize: 12, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white38),
                                ),
                              ],
                            ),
                          ],
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
    );
  }

  Widget _statRow(IconData icon, Color iconColor, String value, String label,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.sora(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: valueColor ?? (AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.sora(fontSize: 12, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54),
        ),
      ],
    );
  }

  Widget _buildGroupAvatar() {
    final hasImg = _groupImagePath != null && File(_groupImagePath!).existsSync();
    Widget avatar = hasImg
        ? CircleAvatar(
            key: ValueKey(_groupImagePath),
            radius: 36,
            backgroundImage: FileImage(File(_groupImagePath!)),
          )
        : Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppThemeNotifier.isWhite ? const Color(0xFFFFF0F0) : const Color(0xFF1A0505),
              border: Border.all(
                  color: const Color(0xFFCC0020).withOpacity(AppThemeNotifier.isWhite ? 0.3 : 0.2), width: 1),
            ),
            child: const Icon(Icons.groups_rounded, color: Color(0xFFCC0020), size: 32),
          );
    return GestureDetector(
      onTap: _pickGroupImage,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              width: 24, height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFCC0020),
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editGroupName() async {
    final ctrl = TextEditingController(text: _groupName);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF120404),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Group Name', style: GoogleFonts.sora(
          color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
          fontWeight: FontWeight.w700, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.sora(color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white),
          decoration: InputDecoration(
            hintText: 'Group name',
            hintStyle: GoogleFonts.sora(color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.35) : Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.sora(
              color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text('Save', style: GoogleFonts.sora(
              color: const Color(0xFFCC0020), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || result == _groupName) return;
    await _saveGroupEdits(newName: result);
  }

  Future<void> _pickGroupImage() async {
    final picker = ImagePicker();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF120404),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppThemeNotifier.isWhite ? Colors.black12 : Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFFCC0020)),
              title: Text('Take photo', style: GoogleFonts.sora(
                  color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white)),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFCC0020)),
              title: Text('Choose from gallery', style: GoogleFonts.sora(
                  color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white)),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (_groupImagePath != null)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Color(0xFFFF3355)),
                title: Text('Remove photo', style: GoogleFonts.sora(
                    color: const Color(0xFFFF3355))),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == 'remove') { await _saveGroupEdits(removeImage: true); return; }
    if (action == null) return;
    final source = action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final picked = await picker.pickImage(source: source, imageQuality: 75);
    if (picked == null) return;
    await _saveGroupEdits(newImagePath: picked.path);
  }

  Future<void> _saveGroupEdits({String? newName, String? newImagePath, bool removeImage = false}) async {
    final allGroups = await StorageService.loadGroups();
    final idx = allGroups.indexWhere((g) => g.id == widget.group.id);
    if (idx == -1) return;
    allGroups[idx] = GroupModel(
      id: widget.group.id,
      name: newName ?? _groupName,
      imagePath: removeImage ? null : (newImagePath ?? _groupImagePath),
      categories: allGroups[idx].categories,
    );
    await StorageService.saveGroups(allGroups);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    setState(() {
      if (newName != null) _groupName = newName;
      if (newImagePath != null) _groupImagePath = newImagePath;
      if (removeImage) _groupImagePath = null;
    });
    _markChanged();
  }

  // ---------------- EXPENSE LIST ----------------

  Widget _buildExpenseList() {
    final visibleExpenses = _expenses.where((e) {
      if (!DateFilter.isInRange(e.date)) return false;
      if (_expenseFilter != 'all' && e.type != _expenseFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!e.description.toLowerCase().contains(q) &&
            !e.categories.join(',').toLowerCase().contains(q) &&
            !e.amount.toString().contains(q)) return false;
      }
      return true;
    }).toList();

    if (visibleExpenses.isEmpty) {
      return ValueListenableBuilder<bool>(
        valueListenable: AppThemeNotifier.instance,
        builder: (_, isWhite, __) => Column(
          children: [
            const SizedBox(height: 28),
            Center(
              child: Image.asset(
                isWhite ? 'assets/images/empty_expenses_white.png' : 'assets/images/empty_expenses.png',
                height: 150,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No matching expenses.',
              style: GoogleFonts.sora(
                fontSize: 14,
                color: isWhite ? Colors.black45 : Colors.white38,
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      );
    }

    return Column(
      children: visibleExpenses.map((e) {
        final isCredit = e.type == 'credit';
        final typeColor =
            isCredit ? const Color(0xFF00CC66) : const Color(0xFFFF3355);
        final typeLabel = isCredit ? 'CREDIT' : 'DEBIT';

        return GestureDetector(
          onTap: () => _openExpenseDetails(e),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF0E0505),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.07), width: 1),
              boxShadow: AppThemeNotifier.isWhite ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 2))] : [],
            ),
            child: Row(
              children: [
                // Type icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCredit
                        ? Icons.add_rounded
                        : Icons.remove_rounded,
                    color: typeColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.description.isEmpty ? 'Expense' : e.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${e.categories.join(', ')} · ${e.date.toString().split(' ')[0]}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sora(
                            fontSize: 11, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.45) : Colors.white38),
                      ),
                    ],
                  ),
                ),
                // Receipt thumbnail
                if (e.imagePath != null &&
                    File(e.imagePath!).existsSync()) ...[
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(e.imagePath!),
                        width: 36, height: 36, fit: BoxFit.cover),
                  ),
                ],
                const SizedBox(width: 8),
                // Amount + type badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${e.amount.toStringAsFixed(0)}',
                      style: GoogleFonts.sora(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: typeColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        typeLabel,
                        style: GoogleFonts.sora(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: typeColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                // Action icons
                Column(
                  children: [
                    GestureDetector(
                      onTap: () async {
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
                      },
                      child: Icon(Icons.edit_rounded,
                          size: 16, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.3) : Colors.white30),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _deleteExpense(e),
                      child: const Icon(Icons.delete_rounded,
                          size: 16, color: Color(0xFFFF3355)),
                    ),
                  ],
                ),
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
    final typeColor =
        isCredit ? const Color(0xFF00CC66) : const Color(0xFFFF3355);
    final typeLabel = isCredit ? 'CREDIT' : 'DEBIT';
    final hasReceipt =
        e.imagePath != null && File(e.imagePath!).existsSync();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(18),
        child: Container(
          decoration: BoxDecoration(
            color: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF120404),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.25), width: 1),
            boxShadow: AppThemeNotifier.isWhite ? [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 2))] : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 8, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(typeLabel,
                          style: GoogleFonts.sora(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: typeColor)),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.4) : Colors.white38, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${e.amount.toStringAsFixed(0)}',
                      style: GoogleFonts.sora(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: typeColor),
                    ),
                    const SizedBox(height: 14),
                    if (e.description.isNotEmpty) ...[
                      _detailLabel('Description'),
                      const SizedBox(height: 4),
                      Text(e.description,
                          style: GoogleFonts.sora(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white)),
                      const SizedBox(height: 12),
                    ],
                    _detailLabel('Members / Category'),
                    const SizedBox(height: 4),
                    Text(e.categories.join(', '),
                        style: GoogleFonts.sora(
                            fontSize: 14, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.75) : Colors.white70)),
                    const SizedBox(height: 12),
                    _detailLabel('Date'),
                    const SizedBox(height: 4),
                    Text(e.date.toString().split(' ')[0],
                        style: GoogleFonts.sora(
                            fontSize: 14, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.75) : Colors.white70)),
                    if (hasReceipt) ...[
                      const SizedBox(height: 14),
                      _detailLabel('Receipt'),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _openReceiptPreview(e.imagePath!);
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(e.imagePath!),
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'Tap image to expand',
                          style: GoogleFonts.sora(
                              fontSize: 11, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.35) : Colors.white30),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailLabel(String text) => Text(
        text,
        style: GoogleFonts.sora(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.4) : Colors.white38,
            letterSpacing: 0.8),
      );

  // ---------------- HELPERS ----------------

  Widget _filterChip(String value, String label) {
    final selected = _expenseFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _expenseFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFCC0020).withOpacity(0.18)
              : (AppThemeNotifier.isWhite ? Colors.white : Colors.white.withOpacity(0.06)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFFCC0020)
                : (AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.18)),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.3), blurRadius: 10, spreadRadius: 1)]
              : (AppThemeNotifier.isWhite ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.07), blurRadius: 6, offset: const Offset(0, 1))] : []),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[  
              const Icon(Icons.check_rounded,
                  color: Color(0xFFCC0020), size: 13),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.sora(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected
                  ? (AppThemeNotifier.isWhite ? const Color(0xFFCC0020) : Colors.white)
                  : (AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.7) : Colors.white60),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildAddMemberField() {
    return Container(
      decoration: BoxDecoration(
        color: AppThemeNotifier.isWhite ? Colors.white : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.10), width: 1),
        boxShadow: AppThemeNotifier.isWhite ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))] : [],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          // Dashed circle + button
          GestureDetector(
            onTap: _addCategory,
            child: CustomPaint(
              size: const Size(32, 32),
              painter: _DashedCirclePainter(),
              child: const SizedBox(
                width: 32, height: 32,
                child: Icon(Icons.add_rounded,
                    color: Color(0xFFCC0020), size: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _categoryController,
              style: GoogleFonts.sora(
                  fontSize: 13, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white),
              decoration: InputDecoration(
                hintText: 'Add member / category',
                hintStyle: GoogleFonts.sora(
                    fontSize: 13, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.35) : Colors.white38),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 16),
              ),
              onSubmitted: (_) => _addCategory(),
            ),
          ),
          GestureDetector(
            onTap: _pickExistingCategories,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: const Icon(Icons.people_alt_rounded,
                  color: Color(0xFFCC0020), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCards() {
    if (_categories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppThemeNotifier.isWhite ? Colors.white : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.07), width: 1),
          boxShadow: AppThemeNotifier.isWhite ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.07), blurRadius: 6)] : [],
        ),
        child: Column(
          children: [
            Icon(Icons.group_off_rounded,
                size: 28, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.2) : Colors.white.withOpacity(0.2)),
            const SizedBox(height: 8),
            Text(
              'No members / category yet.',
              style: GoogleFonts.sora(
                  fontSize: 13, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.4) : Colors.white30),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _categories.map((c) {
        final stats = _memberStats[c] ?? {'total': 0.0, 'lastDate': '-'};
        final total = stats['total'] as double;
        final isPositive = total >= 0;
        final color = isPositive
            ? const Color(0xFF00CC66)
            : const Color(0xFFFF3355);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF0E0505),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.07), width: 1),
            boxShadow: AppThemeNotifier.isWhite ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))] : [],
          ),
          child: Row(children: [
            GestureDetector(
              onTap: () => _pickCategoryImage(c),
              child: _categoryAvatar(c, size: 36),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white)),
                  const SizedBox(height: 3),
                  Text(
                    '₹${total.abs().toStringAsFixed(0)} · Last: ${stats['lastDate']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(
                        fontSize: 11, color: color),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _editCategory(c),
              child: Icon(Icons.edit_rounded,
                  size: 16, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.3) : Colors.white30),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _deleteCategory(c),
              child: const Icon(Icons.delete_rounded,
                  size: 16, color: Color(0xFFFF3355)),
            ),
          ]),
        );
      }).toList(),
    );
  }

  // ── Category avatar (image or initial with consistent colour) ─────────────
  static const _avatarPalette = [
    Color(0xFFCC0020), Color(0xFF0066CC), Color(0xFF00AA55),
    Color(0xFFCC6600), Color(0xFF8833CC), Color(0xFF0099AA),
  ];

  Widget _categoryAvatar(String cat, {double size = 36}) {
    final imgPath = _categoryImages[cat];
    final hasImg = imgPath != null && File(imgPath).existsSync();
    final color = _avatarPalette[cat.hashCode.abs() % _avatarPalette.length];

    return Stack(
      children: [
        Container(
          key: ValueKey('$cat-${_categoryImages[cat] ?? ''}'),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5), width: 1.2),
            image: hasImg
                ? DecorationImage(
                    image: FileImage(File(imgPath!)), fit: BoxFit.cover)
                : null,
          ),
          child: hasImg
              ? null
              : Center(
                  child: Text(
                    cat.isNotEmpty ? cat[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontSize: size * 0.38,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: size * 0.32,
            height: size * 0.32,
            decoration: BoxDecoration(
              color: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF1A0505),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5), width: 0.8),
            ),
            child: Icon(Icons.camera_alt_rounded,
                size: size * 0.18, color: color),
          ),
        ),
      ],
    );
  }

  Future<void> _pickCategoryImage(String categoryName) async {
    final picker = ImagePicker();

    // 'camera' | 'gallery' | 'remove' | null (dismissed)
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF120404),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppThemeNotifier.isWhite ? Colors.black12 : Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: Color(0xFFCC0020)),
              title: Text('Take photo',
                  style: GoogleFonts.sora(color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white)),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: Color(0xFFCC0020)),
              title: Text('Choose from gallery',
                  style: GoogleFonts.sora(color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white)),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (_categoryImages.containsKey(categoryName))
              ListTile(
                leading: const Icon(Icons.delete_rounded,
                    color: Color(0xFFFF3355)),
                title: Text('Remove photo',
                    style: GoogleFonts.sora(color: const Color(0xFFFF3355))),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == 'remove') {
      _categoryImages.remove(categoryName);
      await StorageService.saveCategoryImages(_categoryImages);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      setState(() {});
      return;
    }

    if (action == null) return;

    final source =
        action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final picked =
        await picker.pickImage(source: source, imageQuality: 75);
    if (picked == null) return;

    _categoryImages[categoryName] = picked.path;
    await StorageService.saveCategoryImages(_categoryImages);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    setState(() {});
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.sora(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF0E0505),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.07), width: 1),
      boxShadow: AppThemeNotifier.isWhite ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 2))] : [],
    );
  }

  // ---------------- PICK FROM EXISTING ----------------

  Future<void> _pickExistingCategories() async {
    final allGroups = await StorageService.loadGroups();

    // Gather all categories from OTHER groups, excluding already added ones
    final existing = allGroups
        .where((g) => g.id != widget.group.id)
        .expand((g) => g.categories)
        .toSet()
        .where((c) => !_categories.any(
            (existing) => existing.toLowerCase() == c.toLowerCase()))
        .toList()
          ..sort();

    if (existing.isEmpty) {
      _toast('No new categories from other groups');
      return;
    }

    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF120404),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ExistingCategoryPicker(existing: existing),
    );

    if (picked == null || picked.isEmpty) return;

    setState(() {
      _categories = [..._categories, ...picked];
    });
    await _persistCategories();
    _markChanged();
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

// ── Custom painter: dashed red circle for add member button ──────────────────
class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCC0020).withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dashCount = 12;
    const dashAngle = 3.14159 * 2 / dashCount;
    const gapRatio = 0.4;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width / 2) - 2;
    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle,
        dashAngle * (1 - gapRatio),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Custom painter: empty receipts box illustration ──────────────────────────
class _EmptyBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Glow under box
    final glowPaint = Paint()
      ..color = const Color(0xFFCC0020).withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, size.height * 0.82),
          width: size.width * 0.7,
          height: 18),
      glowPaint,
    );

    // Box body
    final boxPaint = Paint()..color = const Color(0xFF1C0808);
    final boxBorderPaint = Paint()
      ..color = const Color(0xFFCC0020).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final boxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 52, cy - 4, 104, 60),
      const Radius.circular(6),
    );
    canvas.drawRRect(boxRect, boxPaint);
    canvas.drawRRect(boxRect, boxBorderPaint);

    // Box front panel (darker)
    final frontPaint = Paint()..color = const Color(0xFF140505);
    final frontRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 52, cy + 28, 104, 32),
      const Radius.circular(4),
    );
    canvas.drawRRect(frontRect, frontPaint);
    canvas.drawRRect(frontRect, boxBorderPaint);

    // Handle on front
    final handlePaint = Paint()
      ..color = const Color(0xFFCC0020).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(cx - 14, cy + 44), Offset(cx + 14, cy + 44), handlePaint);

    // Papers sticking out
    final paperPaint = Paint()..color = const Color(0xFF2A0A0A);
    final paperBorder = Paint()
      ..color = const Color(0xFFCC0020).withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Paper 1 (left, tilted)
    final paper1 = Path()
      ..moveTo(cx - 24, cy - 4)
      ..lineTo(cx - 36, cy - 42)
      ..lineTo(cx - 10, cy - 42)
      ..lineTo(cx - 8, cy - 4)
      ..close();
    canvas.drawPath(paper1, paperPaint);
    canvas.drawPath(paper1, paperBorder);

    // Paper 2 (center, straight)
    final paper2 = Path()
      ..moveTo(cx - 14, cy - 4)
      ..lineTo(cx - 14, cy - 50)
      ..lineTo(cx + 14, cy - 50)
      ..lineTo(cx + 14, cy - 4)
      ..close();
    canvas.drawPath(paper2, paperPaint);
    canvas.drawPath(paper2, paperBorder);
    // Lines on paper
    final linePaint = Paint()
      ..color = const Color(0xFFCC0020).withOpacity(0.3)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(cx - 8, cy - 40), Offset(cx + 8, cy - 40), linePaint);
    canvas.drawLine(Offset(cx - 8, cy - 32), Offset(cx + 8, cy - 32), linePaint);
    canvas.drawLine(Offset(cx - 8, cy - 24), Offset(cx + 8, cy - 24), linePaint);

    // Paper 3 (right, tilted)
    final paper3 = Path()
      ..moveTo(cx + 8, cy - 4)
      ..lineTo(cx + 10, cy - 42)
      ..lineTo(cx + 36, cy - 42)
      ..lineTo(cx + 24, cy - 4)
      ..close();
    canvas.drawPath(paper3, paperPaint);
    canvas.drawPath(paper3, paperBorder);

    // Red bottom glow line
    final glowLine = Paint()
      ..color = const Color(0xFFCC0020).withOpacity(0.6)
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawLine(
      Offset(cx - 50, cy + 58),
      Offset(cx + 50, cy + 58),
      glowLine,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Existing category picker bottom sheet ────────────────────────────────────
class _ExistingCategoryPicker extends StatefulWidget {
  final List<String> existing;
  const _ExistingCategoryPicker({required this.existing});

  @override
  State<_ExistingCategoryPicker> createState() =>
      _ExistingCategoryPickerState();
}

class _ExistingCategoryPickerState extends State<_ExistingCategoryPicker> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppThemeNotifier.isWhite ? Colors.black12 : Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.people_alt_rounded,
                  color: Color(0xFFCC0020), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add from existing members',
                  style: GoogleFonts.sora(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white),
                ),
              ),
              if (_selected.isNotEmpty)
                Text(
                  '${_selected.length} selected',
                  style: GoogleFonts.sora(
                      fontSize: 12,
                      color: const Color(0xFFCC0020),
                      fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.existing.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final cat = widget.existing[i];
                final isSelected = _selected.contains(cat);
                return GestureDetector(
                  onTap: () => setState(() {
                    isSelected ? _selected.remove(cat) : _selected.add(cat);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFCC0020).withOpacity(0.12)
                          : (AppThemeNotifier.isWhite ? Colors.white : Colors.white.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFCC0020).withOpacity(0.6)
                            : (AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.10)),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFCC0020).withOpacity(0.15),
                          ),
                          child: Center(
                            child: Text(
                              cat.isNotEmpty ? cat[0].toUpperCase() : '?',
                              style: GoogleFonts.sora(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            cat,
                            style: GoogleFonts.sora(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFFCC0020), size: 20)
                        else
                          Icon(Icons.radio_button_unchecked_rounded,
                              color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.25) : Colors.white24, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, _selected.toList()),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: _selected.isEmpty
                    ? null
                    : const RadialGradient(
                        center: Alignment.center,
                        radius: 0.9,
                        colors: [Color(0xFFCC0020), Color(0xFF6B0010)],
                      ),
                color: _selected.isEmpty
                    ? (AppThemeNotifier.isWhite ? Colors.white : Colors.white.withOpacity(0.05))
                    : null,
                border: Border.all(
                  color: _selected.isEmpty
                      ? (AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white12)
                      : const Color(0xFFFF2040).withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  _selected.isEmpty
                      ? 'Select members to add'
                      : 'Add ${_selected.length} member${_selected.length != 1 ? 's' : ''}',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _selected.isEmpty
                        ? (AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.4) : Colors.white30)
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
