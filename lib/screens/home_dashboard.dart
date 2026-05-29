// HomeDashboard — Ledger-aware + Font & Screen-Resilient UI + Profile
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'group_detail_screen.dart';
import 'groups_screen.dart';
import 'profile_screen.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../services/storage_service.dart';
import '../services/recurring_engine.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';
import 'create_group_screen.dart';
import 'expense_list_screen.dart';
import 'recurring_expense_list_screen.dart';
import 'emi_list_screen.dart';
import 'insights_screen.dart';

class HomeDashboard extends StatefulWidget {
  final String userName;

  const HomeDashboard({super.key, required this.userName});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  List<GroupModel> _groups = [];
  List<ExpenseModel> _expenses = [];
  bool _loading = true;

  int _currentTab = 0;
  final _groupsKey = GlobalKey<GroupsScreenState>();
  final _expenseListKey = GlobalKey<ExpenseListScreenState>();
  final _insightsKey = GlobalKey<InsightsScreenState>(); // Added Key for Insights

  // -------- LEDGER TOTALS --------
  double _totalDebit = 0;
  double _totalCredit = 0;
  double _netBalance = 0;

  String _lastExpenseDate = '-';
  int _totalExpensesCount = 0;

  // -------- PROFILE --------
  String _userName = '';
  File? _avatar;

  @override
  void initState() {
    super.initState();
    _userName = widget.userName;
    _loadProfile();
    _loadDashboardData();
    AppThemeNotifier.instance.addListener(_onThemeChanged);
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');
    final avatarPath = prefs.getString('user_avatar_path');

    setState(() {
      if (name != null) _userName = name;
      if (avatarPath != null && File(avatarPath).existsSync()) {
        _avatar = File(avatarPath);
      }
    });
  }

  // ---------------- LOAD DASHBOARD DATA ----------------

  Future<void> _loadDashboardData() async {
    await RecurringEngine.run();
    final groups = await StorageService.loadGroups();
    final expenses = await StorageService.loadExpenses();

    _recalculateSummary(groups, expenses);

    setState(() {
      _groups = groups;
      _expenses = expenses;
      _loading = false;
    });
  }

  void _recalculateSummary(
    List<GroupModel> groups,
    List<ExpenseModel> expenses,
  ) {
    if (expenses.isEmpty) {
      _totalDebit = 0;
      _totalCredit = 0;
      _netBalance = 0;
      _lastExpenseDate = '-';
      _totalExpensesCount = 0;
      return;
    }

    double debit = 0;
    double credit = 0;

    for (final e in expenses) {
      if (e.type == 'credit') {
        credit += e.amount;
      } else {
        debit += e.amount;
      }
    }

    _totalDebit = debit;
    _totalCredit = credit;
    _netBalance = credit - debit;

    _totalExpensesCount = expenses.length;

    final last = expenses
        .map((e) => e.date)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    _lastExpenseDate = last.toString().split(' ')[0];
  }

  // ---------------- GREETING ----------------

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  // ---------------- NAVIGATION ----------------

  Future<void> _openCreateGroup() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
    );

    if (created == true) {
      _loadDashboardData();
      _groupsKey.currentState?.reload();
      setState(() => _currentTab = 2);
    }
  }

  // _openAddExpenseWithGroupSelection moved to ExpensesScreen

  void _onExpenseAdded() {
    _loadDashboardData();
    _groupsKey.currentState?.reload();
    _expenseListKey.currentState?.reload();
    _insightsKey.currentState?.reload(); // Refresh Insights
  }

  void _switchTab(int index) {
    setState(() => _currentTab = index);
    if (index == 1) {
      _expenseListKey.currentState?.reload();
    } else if (index == 3) {
      _insightsKey.currentState?.reload(); // Refresh Insights on tab switch
    }
  }

  Future<void> _deleteGroup(GroupModel group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text(
          'Are you sure you want to delete "${group.name}"?\n\n'
          'All expenses inside this group will also be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final updatedGroups = List<GroupModel>.from(_groups)
      ..removeWhere((g) => g.id == group.id);

    final allExpenses = await StorageService.loadExpenses();
    final updatedExpenses =
        allExpenses.where((e) => e.groupId != group.id).toList();

    await StorageService.saveGroups(updatedGroups);
    await StorageService.saveExpenses(updatedExpenses);

    _loadDashboardData();
  }

  // ---------------- UI ----------------

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppThemeNotifier.isWhite ? Colors.white.withOpacity(0.95) : Colors.black.withOpacity(0.6),
      elevation: 0,
      titleSpacing: 20,
      title: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Eleghart ',
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppThemeNotifier.isWhite ? EleghartColors.textPrimary : Colors.white,
              ),
            ),
            TextSpan(
              text: 'Ledger',
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFCC0020),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search_rounded, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white70, size: 22),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.notifications_none_rounded, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white70, size: 22),
          onPressed: () {},
        ),
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: AppThemeNotifier.isWhite ? const Color(0xFFFFD6D6) : const Color(0xFF1A0A0A),
            backgroundImage: _avatar != null ? FileImage(_avatar!) : null,
            child: _avatar == null
                ? Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      'assets/icons/eleghart_icon.png',
                      fit: BoxFit.contain,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      color: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF0D0D0D),
      elevation: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            _navItem(0, Icons.home_rounded, 'Home'),
            _navItem(1, Icons.receipt_long_rounded, 'Expenses'),
            _navItem(2, Icons.groups_rounded, 'Groups'),
            _navItem(3, Icons.bar_chart_rounded, 'Insights'),
            _navItem(4, Icons.person_rounded, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFFCC0020) : (AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.4) : Colors.white38),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.sora(
                fontSize: 10,
                color: isActive ? const Color(0xFFCC0020) : (AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.4) : Colors.white38),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _getGreeting();

    return Scaffold(
      backgroundColor: AppThemeNotifier.isWhite ? Colors.white : Colors.black,
      extendBody: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.65)),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFCC0020)),
            )
          else
            IndexedStack(
            index: _currentTab,
            children: [
              _buildHomeTab(greeting),
              ExpenseListScreen(key: _expenseListKey, onExpenseAdded: _onExpenseAdded),
              GroupsScreen(key: _groupsKey, userName: _userName),
              InsightsScreen(key: _insightsKey),
              ProfileScreen(                  userName: _userName,
                  onNameChanged: (newName) {
                    setState(() => _userName = newName);
                  },
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeTab(String greeting) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite
        ? EleghartColors.accentDark.withOpacity(0.5)
        : Colors.white54;
    final cardBg = isWhite ? Colors.white : const Color(0xFF120404);
    final border =
        isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.08);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, $_userName 👋',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your financial spaces',
            style: GoogleFonts.sora(
              fontSize: 13,
              color: textSec,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 24),

          // ── Summary Card ──────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF7A0010), Color(0xFFCC0020)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFCC0020).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Expenses',
                    style: GoogleFonts.sora(
                        fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 4),
                Text(
                  '₹${_totalDebit >= 100000 ? (_totalDebit / 100000).toStringAsFixed(1) + 'L' : _totalDebit >= 1000 ? (_totalDebit / 1000).toStringAsFixed(1) + 'K' : _totalDebit.toStringAsFixed(0)}',
                  style: GoogleFonts.sora(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  _summaryPill('↑ Income',
                      '₹${_totalCredit >= 1000 ? (_totalCredit / 1000).toStringAsFixed(1) + 'K' : _totalCredit.toStringAsFixed(0)}',
                      const Color(0xFF22C55E)),
                  const SizedBox(width: 10),
                  _summaryPill('↓ Spent',
                      '₹${_totalDebit >= 1000 ? (_totalDebit / 1000).toStringAsFixed(1) + 'K' : _totalDebit.toStringAsFixed(0)}',
                      Colors.white70),
                  const SizedBox(width: 10),
                  _summaryPill('${_totalExpensesCount} Items', '', Colors.white54),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Quick Actions ─────────────────────────────────────
          Text('Quick Actions',
              style: GoogleFonts.sora(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _quickActionCard(
                icon: Icons.add_circle_outline_rounded,
                label: 'Add Expense',
                color: const Color(0xFFCC0020),
                cardBg: cardBg,
                border: border,
                textPrimary: textPrimary,
                textSec: textSec,
                onTap: () => _switchTab(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickActionCard(
                icon: Icons.repeat_rounded,
                label: 'Recurring',
                color: const Color(0xFF6366F1),
                cardBg: cardBg,
                border: border,
                textPrimary: textPrimary,
                textSec: textSec,
                onTap: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const RecurringExpenseListScreen()));
                  _loadDashboardData();
                  _groupsKey.currentState?.reload();
                  _expenseListKey.currentState?.reload();
                  _insightsKey.currentState?.reload();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickActionCard(
                icon: Icons.credit_card_outlined,
                label: 'EMI',
                color: const Color(0xFF0EA5E9),
                cardBg: cardBg,
                border: border,
                textPrimary: textPrimary,
                textSec: textSec,
                onTap: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EmiListScreen()));
                  _loadDashboardData();
                  _groupsKey.currentState?.reload();
                  _expenseListKey.currentState?.reload();
                  _insightsKey.currentState?.reload();
                },
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // ── Recent Activity placeholder ────────────────────────
          Text('Recent Activity',
              style: GoogleFonts.sora(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                Icon(Icons.bar_chart_rounded,
                    size: 40,
                    color: textSec.withOpacity(0.4)),
                const SizedBox(height: 12),
                Text('Dashboard & Insights',
                    style: GoogleFonts.sora(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textPrimary)),
                const SizedBox(height: 4),
                Text('Coming soon',
                    style: GoogleFonts.sora(
                        fontSize: 12, color: textSec)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryPill(String label, String value, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          value.isNotEmpty ? '$label: $value' : label,
          style: GoogleFonts.sora(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color),
        ),
      );

  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required Color cardBg,
    required Color border,
    required Color textPrimary,
    required Color textSec,
    required VoidCallback onTap,
  }) {
    final isWhite = AppThemeNotifier.isWhite;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(isWhite ? 0.06 : 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(label,
              style: GoogleFonts.sora(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textPrimary)),
        ]),
      ),
    );
  }

  // _buildExpensesTab and _formatChip moved to ExpensesScreen

  Widget _buildPlaceholder(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.25) : Colors.white24),
          const SizedBox(height: 16),
          Text(
            '$title coming soon',
            style: GoogleFonts.sora(
              fontSize: 16,
              color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.45) : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- SUMMARY CARD ----------------

  Widget _buildSummaryCard() {
    final netIsPositive = _netBalance >= 0;

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'Overall Summary',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
            letterSpacing: 0.4,
          ),
        ),

        const SizedBox(height: 12),

        Row(children: [
          const Icon(Icons.remove_circle, size: 18, color: Colors.white70),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '₹${_totalDebit.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Total Debit',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ]),

        const SizedBox(height: 6),

        Row(children: [
          const Icon(Icons.add_circle, size: 18, color: Colors.white70),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '₹${_totalCredit.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Total Credit',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ]),

        const SizedBox(height: 10),

        Row(children: [
          const Icon(Icons.account_balance_wallet,
              size: 18, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            '${netIsPositive ? '+' : '–'} ₹${_netBalance.abs().toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: netIsPositive
                  ? Colors.greenAccent
                  : Colors.redAccent,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Net Balance',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ]),

        const SizedBox(height: 14),

        Wrap(spacing: 10, runSpacing: 10, children: [
          _summaryChip(
            icon: Icons.groups,
            label: '${_groups.length} Groups',
          ),
          _summaryChip(
            icon: Icons.receipt_long,
            label: '$_totalExpensesCount Expenses',
          ),
        ]),

        const SizedBox(height: 12),

        Row(children: [
          const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Last expense: $_lastExpenseDate',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                color: Colors.white70,
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _summaryChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.08) : Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
            ),
          ),
        ),
      ]),
    );
  }

  // ---------------- EMPTY STATE ----------------

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.groups_2_outlined,
              size: 64, color: EleghartColors.textSecondary),
          const SizedBox(height: 18),
          const Text(
            'No expenses yet',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              height: 2,
              color: EleghartColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Start by creating a group\n(e.g. Friends, Family, Trip)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              color: EleghartColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _openCreateGroup,
            style: ElevatedButton.styleFrom(
              backgroundColor: EleghartColors.accentDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
            ),
            icon: const Icon(Icons.group_add, size: 20),
            label: const Text(
              'Create your first group',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ),
    );
  }

  // ---------------- GROUPS LIST ----------------

  Widget _buildGroupsList() {
    return ListView.separated(
      itemCount: _groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final group = _groups[index];

        return GestureDetector(
          onTap: () async {
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => GroupDetailScreen(group: group),
              ),
            );

            if (changed == true) {
              _loadDashboardData();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFF6F7FB)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              leading: _buildGroupAvatar(group),
              title: Text(
                group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16.5,
                  color: EleghartColors.textPrimary,
                ),
              ),
              subtitle: const Text(
                'Tap to view details',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: EleghartColors.textSecondary,
                  fontSize: 13.5,
                ),
              ),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: EleghartColors.textSecondary),
                  onPressed: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateGroupScreen(
                          existingGroup: group,
                        ),
                      ),
                    );

                    if (updated == true) {
                      _loadDashboardData();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent),
                  onPressed: () => _deleteGroup(group),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupAvatar(GroupModel group) {
    if (group.imagePath != null && File(group.imagePath!).existsSync()) {
      return CircleAvatar(
        radius: 26,
        backgroundImage: FileImage(File(group.imagePath!)),
      );
    }

    return const CircleAvatar(
      radius: 26,
      backgroundColor: EleghartColors.accentDark,
      child: Icon(Icons.group, color: Colors.white),
    );
  }
}

// _DashedBorderPainter moved to expenses_screen.dart
