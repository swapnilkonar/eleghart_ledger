import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/app_theme.dart';
import '../theme/eleghart_colors.dart';
import '../widgets/themed_background.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../services/pdf_export_service.dart';
import '../services/storage_service.dart';
import '../utils/date_filter.dart';
import '../widgets/date_filter_pill.dart';

class CategoryDetailScreen extends StatefulWidget {
  final String categoryName;
  final List<GroupModel> allGroups;
  final List<ExpenseModel> allExpenses;

  const CategoryDetailScreen({
    super.key,
    required this.categoryName,
    required this.allGroups,
    required this.allExpenses,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  bool _exporting = false;
  late String _categoryName;
  late List<GroupModel> _groups;
  late List<ExpenseModel> _expenses;
  Map<String, String> _categoryImages = {};
  bool _dataChanged = false;

  @override
  void initState() {
    super.initState();
    _categoryName = widget.categoryName;
    _groups = List.from(widget.allGroups);
    _expenses = List.from(widget.allExpenses);
    _loadCategoryImages();
    DateFilter.notifier.addListener(_onFilter);
    AppThemeNotifier.instance.addListener(_onFilter);
  }

  Future<void> _loadCategoryImages() async {
    final imgs = await StorageService.loadCategoryImages();
    if (mounted) setState(() => _categoryImages = imgs);
  }

  @override
  void dispose() {
    DateFilter.notifier.removeListener(_onFilter);
    AppThemeNotifier.instance.removeListener(_onFilter);
    super.dispose();
  }

  void _onFilter() => setState(() {});

  // ── Filtered expenses for this category ──────────────────────────────────
  List<ExpenseModel> get _filtered => _expenses
      .where((e) =>
          e.validCategories.contains(_categoryName) &&
          DateFilter.isInRange(e.date))
      .toList();

  // ── Overall stats ─────────────────────────────────────────────────────────
  Map<String, double> get _overallStats {
    double debit = 0;
    double credit = 0;
    for (final e in _filtered) {
      final share = e.categoryShare;
      if (e.type == 'debit') debit += share;
      else credit += share;
    }
    return {'debit': debit, 'credit': credit, 'net': credit - debit};
  }

  // ── Per-group stats ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _groupStats {
    final result = <Map<String, dynamic>>[];
    for (final g in _groups) {
      if (!g.categories.contains(_categoryName)) continue;
      final expenses = _filtered.where((e) => e.groupId == g.id).toList();
      if (expenses.isEmpty) continue;
      double debit = 0;
      double credit = 0;
      for (final e in expenses) {
        final share = e.categoryShare;
        if (e.type == 'debit') debit += share;
        else credit += share;
      }
      result.add({
        'group': g,
        'debit': debit,
        'credit': credit,
        'net': credit - debit,
        'count': expenses.length,
      });
    }
    result.sort((a, b) => (b['debit'] as double).compareTo(a['debit'] as double));
    return result;
  }

  // ── Edit category name ────────────────────────────────────────────────────
  Future<void> _editCategoryName() async {
    final ctrl = TextEditingController(text: _categoryName);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF120404),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rename Category', style: GoogleFonts.sora(
          color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
          fontWeight: FontWeight.w700, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.sora(color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white),
          decoration: InputDecoration(
            hintText: 'Category name',
            hintStyle: GoogleFonts.sora(color: Colors.white38),
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
    if (newName == null || newName.isEmpty || newName == _categoryName) return;
    await _renameCategoryTo(newName);
  }

  Future<void> _renameCategoryTo(String newName) async {
    final oldName = _categoryName;
    final allGroups = await StorageService.loadGroups();
    final updatedGroups = allGroups.map((g) {
      if (!g.categories.contains(oldName)) return g;
      return GroupModel(
        id: g.id, name: g.name, imagePath: g.imagePath,
        categories: g.categories.map((c) => c == oldName ? newName : c).toList(),
      );
    }).toList();
    await StorageService.saveGroups(updatedGroups);

    final allExpenses = await StorageService.loadExpenses();
    final updatedExpenses = allExpenses.map((e) {
      if (!e.categories.contains(oldName)) return e;
      return e.copyWith(categories: e.categories.map((c) => c == oldName ? newName : c).toList());
    }).toList();
    await StorageService.saveExpenses(updatedExpenses);

    if (_categoryImages.containsKey(oldName)) {
      _categoryImages[newName] = _categoryImages[oldName]!;
      _categoryImages.remove(oldName);
      await StorageService.saveCategoryImages(_categoryImages);
    }

    final globalCategories = await StorageService.loadGlobalCategories();
    if (globalCategories.contains(oldName)) {
      globalCategories.remove(oldName);
      if (!globalCategories.contains(newName)) globalCategories.add(newName);
      globalCategories.sort();
      await StorageService.saveGlobalCategories(globalCategories);
    }

    setState(() {
      _categoryName = newName;
      _groups = updatedGroups;
      _expenses = updatedExpenses;
      _dataChanged = true;
    });
  }

  // ── Edit category image ───────────────────────────────────────────────────
  Future<void> _pickCategoryImage() async {
    final picker = ImagePicker();
    final hasImg = _categoryImages.containsKey(_categoryName);
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
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
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
            if (hasImg)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Color(0xFFFF3355)),
                title: Text('Remove photo', style: GoogleFonts.sora(color: const Color(0xFFFF3355))),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == 'remove') {
      _categoryImages.remove(_categoryName);
      await StorageService.saveCategoryImages(_categoryImages);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      setState(() { _dataChanged = true; });
      return;
    }
    if (action == null) return;
    final source = action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final picked = await picker.pickImage(source: source, imageQuality: 75);
    if (picked == null) return;
    _categoryImages[_categoryName] = picked.path;
    await StorageService.saveCategoryImages(_categoryImages);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    setState(() { _dataChanged = true; });
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);

    final now = DateTime.now();
    DateTime from;
    DateTime to;

    switch (DateFilter.current) {
      case DateFilterType.currentMonth:
        from = DateTime(now.year, now.month, 1);
        to   = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case DateFilterType.lastMonth:
        final last = DateTime(now.year, now.month - 1);
        from = DateTime(last.year, last.month, 1);
        to   = DateTime(last.year, last.month + 1, 0, 23, 59, 59);
        break;
      case DateFilterType.allTime:
        from = DateTime(2000, 1, 1);
        to   = DateTime(2099, 12, 31, 23, 59, 59);
        break;
      case DateFilterType.custom:
        final cm = DateFilter.customMonth ?? now;
        from = DateTime(cm.year, cm.month, 1);
        to   = DateTime(cm.year, cm.month + 1, 0, 23, 59, 59);
        break;
    }

    final file = await PdfExportService.exportCategoryReport(
      categoryName: _categoryName,
      expenses: _filtered,
      groups: _groups,
      from: from,
      to: to,
    );

    if (!mounted) return;
    setState(() => _exporting = false);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF120404),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFCC0020).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFCC0020).withOpacity(0.4), width: 1),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded,
                  size: 26, color: Color(0xFFCC0020)),
            ),
            const SizedBox(height: 14),
            Text('PDF Exported',
                style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Text(file.path.split('/').last,
                style:
                    GoogleFonts.sora(fontSize: 12, color: Colors.white38)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Share.shareXFiles([XFile(file.path)]);
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFCC0020).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFCC0020).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.share_rounded,
                        color: Color(0xFFCC0020), size: 16),
                    const SizedBox(width: 8),
                    Text('Share PDF',
                        style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _overallStats;
    final net = stats['net']!;
    final debit = stats['debit']!;
    final credit = stats['credit']!;
    final isPositive = net >= 0;
    final netColor =
        isPositive ? const Color(0xFF00CC66) : const Color(0xFFFF3355);
    final groupStats = _groupStats;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _dataChanged);
        return false;
      },
      child: Scaffold(
      backgroundColor: AppThemeNotifier.isWhite ? Colors.white : Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.72)),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── App bar ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context, _dataChanged),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  const Color(0xFFCC0020).withOpacity(0.6),
                              width: 1.5,
                            ),
                            color:
                                const Color(0xFFCC0020).withOpacity(0.10),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                    _categoryName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.sora(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
                                    ),
                                  ),
                            Text(
                              'Category overview',
                              style: GoogleFonts.sora(
                                  fontSize: 11, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white38),
                            ),
                          ],
                        ),
                      ),
                      // PDF export icon
                      GestureDetector(
                        onTap: _exporting ? null : _exportPdf,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  const Color(0xFFCC0020).withOpacity(0.4),
                              width: 1,
                            ),
                            color:
                                const Color(0xFFCC0020).withOpacity(0.08),
                          ),
                          child: _exporting
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFCC0020),
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf_rounded,
                                  color: Color(0xFFCC0020), size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const DateFilterPill(),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Top net card ─────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF120404),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.4),
                              width: AppThemeNotifier.isWhite ? 1 : 1.2,
                            ),
                            boxShadow: AppThemeNotifier.isWhite
                                ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.10), blurRadius: 12, offset: const Offset(0, 2))]
                                : [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.2), blurRadius: 24, spreadRadius: 2)],
                          ),
                          child: Column(
                            children: [
                              // Avatar + name
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: _pickCategoryImage,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          key: ValueKey(_categoryImages[_categoryName] ?? _categoryName),
                                          width: 52, height: 52,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFFCC0020).withOpacity(0.15),
                                            border: Border.all(color: const Color(0xFFCC0020).withOpacity(0.5), width: 1.5),
                                            image: (_categoryImages[_categoryName] != null && File(_categoryImages[_categoryName]!).existsSync())
                                                ? DecorationImage(image: FileImage(File(_categoryImages[_categoryName]!)), fit: BoxFit.cover)
                                                : null,
                                          ),
                                          child: (_categoryImages[_categoryName] != null && File(_categoryImages[_categoryName]!).existsSync())
                                              ? null
                                              : Center(child: Text(
                                                  _categoryName.isNotEmpty ? _categoryName[0].toUpperCase() : '?',
                                                  style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                                                )),
                                        ),
                                        Positioned(
                                          bottom: 0, right: 0,
                                          child: Container(
                                            width: 18, height: 18,
                                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFCC0020)),
                                            child: const Icon(Icons.camera_alt_rounded, size: 10, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _categoryName,
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
                                            onTap: _editCategoryName,
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
                                      Text(
                                        DateFilter.label,
                                        style: GoogleFonts.sora(
                                            fontSize: 12,
                                            color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.4) : Colors.white38),
                                      ),
                                    ],
                                  ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Container(
                                  height: 1,
                                  color: AppThemeNotifier.isWhite ? const Color(0xFFCC0020).withOpacity(0.15) : Colors.white.withOpacity(0.07)),
                              const SizedBox(height: 16),
                              // Stats row
                              Row(
                                children: [
                                  _statCell(
                                    'Total Debit',
                                    '₹${debit.toStringAsFixed(0)}',
                                    const Color(0xFFFF3355),
                                  ),
                                  _divider(),
                                  _statCell(
                                    'Total Credit',
                                    '₹${credit.toStringAsFixed(0)}',
                                    const Color(0xFF00CC66),
                                  ),
                                  _divider(),
                                  _statCell(
                                    'Net Balance',
                                    '₹${net.abs().toStringAsFixed(0)}',
                                    netColor,
                                    sub: isPositive ? 'owed' : 'owes',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Per-group breakdown header ────────────────────
                        Text(
                          'Group Breakdown',
                          style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white70,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (groupStats.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppThemeNotifier.isWhite ? Colors.white : Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.08)),
                              boxShadow: AppThemeNotifier.isWhite ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.09), blurRadius: 10, offset: const Offset(0, 2))] : [],
                            ),
                            child: Center(
                              child: Text(
                                'No expenses for ${DateFilter.label}',
                                style: GoogleFonts.sora(
                                    fontSize: 13, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white38),
                              ),
                            ),
                          )
                        else
                          ...groupStats.map((s) {
                            final g = s['group'] as GroupModel;
                            final gDebit = s['debit'] as double;
                            final gCredit = s['credit'] as double;
                            final gNet = s['net'] as double;
                            final gCount = s['count'] as int;
                            final gPos = gNet >= 0;
                            final gColor = gPos
                                ? const Color(0xFF00CC66)
                                : const Color(0xFFFF3355);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppThemeNotifier.isWhite ? Colors.white : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.15),
                                  width: 1,
                                ),
                                boxShadow: AppThemeNotifier.isWhite ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 2))] : [],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFCC0020)
                                          .withOpacity(0.12),
                                    ),
                                    child: const Icon(
                                        Icons.folder_rounded,
                                        color: Color(0xFFCC0020),
                                        size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          g.name,
                                          style: GoogleFonts.sora(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$gCount expense${gCount != 1 ? 's' : ''}  ·  ₹${gDebit.toStringAsFixed(0)} debit  ·  ₹${gCredit.toStringAsFixed(0)} credit',
                                          style: GoogleFonts.sora(
                                              fontSize: 10.5,
                                              color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white38),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${gNet.abs().toStringAsFixed(0)}',
                                        style: GoogleFonts.sora(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: gColor,
                                        ),
                                      ),
                                      Text(
                                        gPos ? 'credit' : 'debit',
                                        style: GoogleFonts.sora(
                                            fontSize: 10,
                                            color: gColor.withOpacity(0.7)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
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

  Widget _statCell(String label, String value, Color color,
      {String? sub}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub != null ? '$label\n$sub' : label,
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(fontSize: 10.5, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 40,
        color: AppThemeNotifier.isWhite ? const Color(0xFFCC0020).withOpacity(0.15) : Colors.white.withOpacity(0.07),
      );
}
