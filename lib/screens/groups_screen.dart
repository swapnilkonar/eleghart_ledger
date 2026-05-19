import 'dart:io';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../services/storage_service.dart';
import '../utils/date_filter.dart';
import '../widgets/date_filter_pill.dart';
import 'categories_list_screen.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatefulWidget {
  final String userName;
  const GroupsScreen({super.key, required this.userName});

  @override
  State<GroupsScreen> createState() => GroupsScreenState();
}

class GroupsScreenState extends State<GroupsScreen>
    with SingleTickerProviderStateMixin {
  List<GroupModel> _groups = [];
  List<ExpenseModel> _expenses = [];
  Map<String, String> _categoryImages = {};
  bool _loading = true;
  String _selectedFilter = 'All';
  late AnimationController _glowController;

  final List<String> _filters = ['All', 'Trips', 'Friends', 'Family', 'Work', 'Others'];
  final List<Color> _avatarColors = [
    const Color(0xFFCC0020),
    const Color(0xFF0066CC),
    const Color(0xFF00AA55),
    const Color(0xFFCC6600),
    const Color(0xFF8833CC),
  ];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _loadData();
    DateFilter.notifier.addListener(_onFilterChanged);
  }

  void _onFilterChanged() => setState(() {});

  @override
  void dispose() {
    DateFilter.notifier.removeListener(_onFilterChanged);
    _glowController.dispose();
    super.dispose();
  }

  Future<void> reload() => _loadData();

  Future<void> _loadData() async {
    final groups = await StorageService.loadGroups();
    final expenses = await StorageService.loadExpenses();
    final catImages = await StorageService.loadCategoryImages();
    if (mounted) {
      setState(() {
        _groups = groups;
        _expenses = expenses;
        _categoryImages = catImages;
        _loading = false;
      });
    }
  }

  Future<void> _deleteGroup(GroupModel group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF120404),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${group.name}"?',
            style: GoogleFonts.sora(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: Text(
            'All expenses in this group will be deleted. This cannot be undone.',
            style: GoogleFonts.sora(color: Colors.white54, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.sora(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.sora(
                    color: const Color(0xFFFF3355),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final groups = await StorageService.loadGroups();
    groups.removeWhere((g) => g.id == group.id);
    await StorageService.saveGroups(groups);

    final expenses = await StorageService.loadExpenses();
    expenses.removeWhere((e) => e.groupId == group.id);
    await StorageService.saveExpenses(expenses);

    _loadData();
  }

  Future<void> _openCreateGroup({GroupModel? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => CreateGroupScreen(existingGroup: existing)),
    );
    if (result == true) _loadData();
  }

  Future<void> _openGroup(GroupModel group) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
    );
    if (changed == true) _loadData();
  }

  List<ExpenseModel> _expensesFor(GroupModel g) =>
      _expenses.where((e) => e.groupId == g.id && DateFilter.isInRange(e.date)).toList();

  double _spentFor(GroupModel g) => _expensesFor(g)
      .where((e) => e.isDebit)
      .fold(0.0, (s, e) => s + e.amount);

  double _balanceFor(GroupModel g) {
    final ex = _expensesFor(g);
    final credit = ex.where((e) => e.isCredit).fold(0.0, (s, e) => s + e.amount);
    final debit = ex.where((e) => e.isDebit).fold(0.0, (s, e) => s + e.amount);
    return credit - debit;
  }

  double _totalBalance() {
    final filtered = _expenses.where((e) => DateFilter.isInRange(e.date));
    final credit = filtered.where((e) => e.isCredit).fold(0.0, (s, e) => s + e.amount);
    final debit = filtered.where((e) => e.isDebit).fold(0.0, (s, e) => s + e.amount);
    return credit - debit;
  }

  double _thisMonthSpent() {
    return _expenses
        .where((e) => e.isDebit && DateFilter.isInRange(e.date))
        .fold(0.0, (s, e) => s + e.amount);
  }

  String _lastExpenseLabel(GroupModel g) {
    final ex = _expensesFor(g);
    if (ex.isEmpty) return '—';
    final last = ex.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b);
    final diff = DateTime.now().difference(last);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  List<GroupModel> get _filteredGroups {
    if (_selectedFilter == 'All') return _groups;
    final filter = _selectedFilter.toLowerCase();
    return _groups
        .where((g) => g.categories
            .any((c) => c.toLowerCase() == filter ||
                        filter.startsWith(c.toLowerCase()) ||
                        c.toLowerCase().startsWith(filter.replaceAll('s', ''))))
        .toList();
  }

  _StatusInfo _statusFor(GroupModel g) {
    final bal = _balanceFor(g);
    final ex = _expensesFor(g);
    final recentCount = ex
        .where((e) =>
            DateTime.now().difference(e.date).inDays < 3)
        .length;
    if (recentCount >= 3) {
      return _StatusInfo('Most Active', const Color(0xFF8833CC));
    }
    if (bal > 200) return _StatusInfo('On Track', const Color(0xFF00AA66));
    if (bal >= -200 && bal <= 200) {
      return _StatusInfo('Balanced', const Color(0xFF00AA66));
    }
    return _StatusInfo('Overspending', const Color(0xFFCC0020));
  }

  // ── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFCC0020)));
    }
    return _groups.isEmpty ? _buildEmptyState() : _buildRichView();
  }

  // ── RICH VIEW ─────────────────────────────────────────────────────────────

  Widget _buildRichView() {
    final greeting = _getGreeting();
    final totalBal = _totalBalance();
    final monthSpent = _thisMonthSpent();
    final filtered = _filteredGroups;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting
                Text(
                  '$greeting, ${widget.userName} 👋',
                  style: GoogleFonts.sora(
                      fontSize: 13,
                      color: Colors.white54),
                ),
                const SizedBox(height: 2),
                Text(
                  'Groups',
                  style: GoogleFonts.sora(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your financial spaces',
                      style: GoogleFonts.sora(
                          fontSize: 13, color: Colors.white38),
                    ),
                    const DateFilterPill(),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Stats card ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF120505),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFCC0020).withOpacity(0.2),
                        width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFCC0020).withOpacity(0.15),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _statBlock(
                            Icons.groups_rounded,
                            'Total Groups',
                            '${DateFilter.current == DateFilterType.allTime ? _groups.length : _groups.where((g) => _expensesFor(g).isNotEmpty).length}',
                            DateFilter.current == DateFilterType.allTime ? 'Active' : 'With activity',
                            Colors.white70,
                          ),
                          _verticalDivider(),
                          _statBlock(
                            null,
                            'Total Balance',
                            '₹${totalBal.abs().toStringAsFixed(0)}',
                            totalBal >= 0 ? 'You are owed' : 'You owe',
                            totalBal >= 0
                                ? const Color(0xFF00CC66)
                                : const Color(0xFFFF3355),
                          ),
                          _verticalDivider(),
                          _statBlock(
                            null,
                            'This Month Spent',
                            '₹${monthSpent.toStringAsFixed(0)}',
                            '',
                            Colors.white70,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.07)),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategoriesListScreen(
                              allGroups: _groups,
                              allExpenses: _expenses,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCC0020).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_rounded,
                                  color: Color(0xFFCC0020), size: 14),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                () {
                                  final total = _groups
                                      .expand((g) => g.categories)
                                      .toSet()
                                      .length;
                                  return '$total categor${total != 1 ? 'ies' : 'y'} across all groups';
                                }(),
                                style: GoogleFonts.sora(
                                    fontSize: 12, color: Colors.white60),
                              ),
                            ),
                            Text(
                              'View All  ›',
                              style: GoogleFonts.sora(
                                fontSize: 12,
                                color: const Color(0xFFCC0020),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Filter tabs ───────────────────────────────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((f) {
                      final active = _selectedFilter == f;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFFCC0020)
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active
                                  ? Colors.transparent
                                  : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (active) ...[
                                const Icon(Icons.grid_view_rounded,
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                f,
                                style: GoogleFonts.sora(
                                  fontSize: 13,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: active
                                      ? Colors.white
                                      : Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Your Groups header ────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Groups',
                      style: GoogleFonts.sora(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Sort by: Recent',
                          style: GoogleFonts.sora(
                              fontSize: 12, color: Colors.white38),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white38, size: 18),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // ── Groups list ────────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildGroupCard(filtered[i]),
              ),
              childCount: filtered.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statBlock(
    IconData? icon,
    String label,
    String value,
    String sub,
    Color valueColor,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: const Color(0xFFCC0020), size: 22),
            const SizedBox(height: 4),
          ],
          Text(label,
              style: GoogleFonts.sora(
                  fontSize: 11, color: Colors.white38)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          if (sub.isNotEmpty)
            Text(sub,
                style: GoogleFonts.sora(
                    fontSize: 11, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _verticalDivider() => Container(
        width: 1,
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Colors.white.withOpacity(0.07),
      );

  // ── GROUP CARD ────────────────────────────────────────────────────────────

  Widget _buildGroupCard(GroupModel group) {
    final expenses = _expensesFor(group);
    final spent = _spentFor(group);
    final balance = _balanceFor(group);
    final status = _statusFor(group);
    final lastLabel = _lastExpenseLabel(group);
    final balPositive = balance >= 0;
    final sparkColor = status.color;

    return GestureDetector(
      onTap: () => _openGroup(group),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0E0505),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: const Color(0xFFCC0020).withOpacity(0.18), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFCC0020).withOpacity(0.18),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left image ─────────────────────────────────────────────
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
                child: Stack(
                  children: [
                    SizedBox(
                      width: 88,
                      child: group.imagePath != null &&
                              File(group.imagePath!).existsSync()
                          ? Image.file(File(group.imagePath!),
                              fit: BoxFit.cover)
                          : Container(
                              color: const Color(0xFF1A0505),
                              child: Center(
                                child: Icon(
                                  _categoryIcon(group.categories),
                                  color: const Color(0xFFCC0020)
                                      .withOpacity(0.5),
                                  size: 36,
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCC0020).withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _categoryIcon(group.categories),
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Middle: name + avatars + spent + balance ───────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sora(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildMemberAvatars(group),
                      const SizedBox(height: 10),
                      Text(
                        '₹${spent.toStringAsFixed(0)} spent',
                        style: GoogleFonts.sora(
                            fontSize: 13,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${balPositive ? '+' : '-'} ₹${balance.abs().toStringAsFixed(0)} balance',
                        style: GoogleFonts.sora(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: balPositive
                              ? const Color(0xFF00CC66)
                              : const Color(0xFFFF3355),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Right: status+⋮ / count+last / sparkline ──────────────
              ClipRect(
                child: SizedBox(
                  width: 124,
                  child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Status badge + 3-dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: _buildStatusBadge(status),
                            ),
                          ),
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                            icon: const Icon(Icons.more_vert_rounded,
                                color: Colors.white38, size: 16),
                            color: const Color(0xFF1A0505),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            onSelected: (v) {
                              if (v == 'edit')
                                _openCreateGroup(existing: group);
                              if (v == 'delete') _deleteGroup(group);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  const Icon(Icons.edit_rounded,
                                      size: 15, color: Colors.white70),
                                  const SizedBox(width: 8),
                                  Text('Edit Group',
                                      style: GoogleFonts.sora(
                                          fontSize: 13,
                                          color: Colors.white70)),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  const Icon(Icons.delete_rounded,
                                      size: 15,
                                      color: Color(0xFFFF3355)),
                                  const SizedBox(width: 8),
                                  Text('Delete Group',
                                      style: GoogleFonts.sora(
                                          fontSize: 13,
                                          color:
                                              const Color(0xFFFF3355))),
                                ]),
                              ),
                            ],
                          ),
                          ),  // SizedBox
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Expense count
                      Text(
                        '${expenses.length} expense${expenses.length != 1 ? 's' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sora(
                            fontSize: 11, color: Colors.white54),
                      ),
                      const SizedBox(height: 1),
                      // Last expense label + time
                      Text(
                        'Last expense',
                        style: GoogleFonts.sora(
                            fontSize: 9, color: Colors.white24),
                      ),
                      Text(
                        lastLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.sora(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white54),
                      ),
                      const Spacer(),
                      // Sparkline
                      SizedBox(
                        height: 44,
                        width: double.infinity,
                        child: _buildSparkLine(expenses, sparkColor),
                      ),
                    ],
                  ),
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(_StatusInfo info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: info.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: info.color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up_rounded, color: info.color, size: 10),
          const SizedBox(width: 3),
          Text(
            info.label,
            style: GoogleFonts.sora(
                fontSize: 9,
                color: info.color,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberAvatars(GroupModel group) {
    final cats = group.categories;
    if (cats.isEmpty) return const SizedBox(height: 24);
    final display = cats.take(5).toList();
    final overflow = cats.length > 5 ? cats.length - 5 : 0;

    return SizedBox(
      height: 24,
      child: Stack(
        children: [
          ...display.asMap().entries.map((entry) {
            final i = entry.key;
            final cat = entry.value;
            final color =
                _avatarColors[cat.hashCode.abs() % _avatarColors.length];
            final imgPath = _categoryImages[cat];
            final hasImg = imgPath != null && File(imgPath).existsSync();
            return Positioned(
              left: i * 16.0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.85),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF0E0505), width: 1.5),
                  image: hasImg
                      ? DecorationImage(
                          image: FileImage(File(imgPath!)),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: hasImg
                    ? null
                    : Center(
                        child: Text(
                          cat.isNotEmpty ? cat[0].toUpperCase() : '?',
                          style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
              ),
            );
          }),
          if (overflow > 0)
            Positioned(
              left: display.length * 16.0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF0E0505), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '+$overflow',
                    style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white54,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _categoryIcon(List<String> categories) {
    final cat = categories.isNotEmpty
        ? categories.first.toLowerCase()
        : '';
    if (cat.contains('trip') || cat.contains('travel')) {
      return Icons.airplanemode_active_rounded;
    }
    if (cat.contains('friend')) return Icons.groups_rounded;
    if (cat.contains('family') || cat.contains('home')) {
      return Icons.home_rounded;
    }
    if (cat.contains('work') || cat.contains('office')) {
      return Icons.work_rounded;
    }
    return Icons.folder_rounded;
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  // ── EMPTY STATE ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (_, child) => Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCC0020).withOpacity(
                          0.12 + _glowController.value * 0.12),
                      blurRadius: 60 + _glowController.value * 30,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: child,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFCC0020).withOpacity(0.04),
                      border: Border.all(
                          color: const Color(0xFFCC0020).withOpacity(0.12),
                          width: 1),
                    ),
                  ),
                  Container(
                    width: 130,
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0A0A),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: const Color(0xFFCC0020).withOpacity(0.3),
                          width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFCC0020).withOpacity(0.25),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.folder_special_rounded,
                        color: Color(0xFFCC0020), size: 56),
                  ),
                  Positioned(
                    top: 14,
                    right: 20,
                    child: _floatingBadge(Icons.bar_chart_rounded),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: _floatingBadge(Icons.pie_chart_rounded),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 12,
                    child: _floatingBadge(Icons.add_rounded),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: RichText(
              text: TextSpan(children: [
                TextSpan(
                    text: 'No groups ',
                    style: GoogleFonts.sora(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                TextSpan(
                    text: 'yet',
                    style: GoogleFonts.sora(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFCC0020))),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Create a group to start tracking\nshared expenses effortlessly.',
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                  fontSize: 14, color: Colors.white54, height: 1.6),
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 58,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF7A0010), Color(0xFFCC0020)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 1,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _openCreateGroup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.group_add_rounded,
                      color: Colors.white, size: 22),
                  label: Text('Create your first group',
                      style: GoogleFonts.sora(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('Not sure where to start?',
                style: GoogleFonts.sora(
                    fontSize: 13,
                    color: Colors.white38,
                    letterSpacing: 0.3)),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildTemplateCard(
                    Icons.airplanemode_active_rounded, 'Trip', 'Plan a trip\ntogether'),
                const SizedBox(width: 10),
                _buildTemplateCard(
                    Icons.groups_rounded, 'Friends', 'Track hangouts\n& outings'),
                const SizedBox(width: 10),
                _buildTemplateCard(
                    Icons.home_rounded, 'Family', 'Manage home\nexpenses'),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _floatingBadge(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A0A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFCC0020).withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFCC0020).withOpacity(0.2),
              blurRadius: 10)
        ],
      ),
      child: Icon(icon, color: const Color(0xFFCC0020), size: 18),
    );
  }

  Widget _buildTemplateCard(IconData icon, String title, String subtitle) {
    return Expanded(
      child: GestureDetector(
        onTap: _openCreateGroup,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.white.withOpacity(0.08), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFCC0020).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(icon, color: const Color(0xFFCC0020), size: 18),
              ),
              const SizedBox(height: 10),
              Text(title,
                  style: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: GoogleFonts.sora(
                      fontSize: 10,
                      color: Colors.white38,
                      height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status helper ─────────────────────────────────────────────────────────────

class _StatusInfo {
  final String label;
  final Color color;
  const _StatusInfo(this.label, this.color);
}

// ── Sparkline builder ─────────────────────────────────────────────────────────

Widget _buildSparkLine(List<ExpenseModel> expenses, Color color) {
  final debits = expenses
      .where((e) => e.isDebit)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  // Flat line for insufficient data
  if (debits.length < 3) {
    return LineChart(
      LineChartData(
        minX: 0, maxX: 6, minY: 0, maxY: 6,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [FlSpot(0, 3), FlSpot(6, 3)],
            isCurved: false,
            barWidth: 1.5,
            color: color.withOpacity(0.45),
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }

  final pts = debits.length > 8 ? debits.sublist(debits.length - 8) : debits;
  final amounts = pts.map((e) => e.amount).toList();
  final maxAmt = amounts.reduce(max);
  final minAmt = amounts.reduce(min);
  final range = max(maxAmt - minAmt, maxAmt * 0.2).clamp(1.0, double.infinity);

  final spots = List.generate(pts.length, (i) {
    final y = 0.5 + ((amounts[i] - minAmt) / range) * 5.0;
    return FlSpot(i.toDouble(), y.clamp(0.2, 5.8));
  });

  return LineChart(
    LineChartData(
      minX: 0,
      maxX: (pts.length - 1).toDouble(),
      minY: 0,
      maxY: 6,
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.25,
          barWidth: 1.6,
          gradient: LinearGradient(
            colors: [color.withOpacity(0.7), color, color.withOpacity(0.85)],
          ),
          shadow: Shadow(
            color: color.withOpacity(0.35),
            blurRadius: 6,
          ),
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
              radius: 2.5,
              color: color,
              strokeWidth: 1.5,
              strokeColor: const Color(0xFF0E0505),
            ),
          ),
          belowBarData: BarAreaData(show: false),
        ),
      ],
    ),
  );
}
