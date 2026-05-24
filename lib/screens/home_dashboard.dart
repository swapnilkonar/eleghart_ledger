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
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';
import 'create_group_screen.dart';

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
        onTap: () => setState(() => _currentTab = index),
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
                _buildExpensesTab(),
                GroupsScreen(key: _groupsKey, userName: _userName),
                _buildPlaceholder('Insights', Icons.bar_chart_rounded),
                ProfileScreen(
                  userName: _userName,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
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
              color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your financial spaces',
            style: GoogleFonts.sora(
              fontSize: 13,
              color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.55) : Colors.white54,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCC0020).withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.dashboard_rounded,
                    color: Color(0xFFCC0020),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Dashboard',
                  style: GoogleFonts.sora(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.7) : Colors.white70,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Coming soon',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.35) : Colors.white30,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildExpensesTab() {
    final isWhite = AppThemeNotifier.isWhite;
    final cardColor = isWhite ? Colors.white : const Color(0xFF120404);
    final borderColor = isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.08);
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSecondary = isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Expense',
            style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w800, color: textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload a receipt or fill in manually',
            style: GoogleFonts.sora(fontSize: 13, color: textSecondary),
          ),
          const SizedBox(height: 20),

          // ── Upload box ──────────────────────────────────
          CustomPaint(
            painter: _DashedBorderPainter(color: const Color(0xFFCC0020).withOpacity(0.7)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: const Color(0xFFCC0020).withOpacity(isWhite ? 0.03 : 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_rounded, color: const Color(0xFFCC0020), size: 48),
                  const SizedBox(height: 12),
                  Text('Upload Receipt or Invoice',
                      style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                  const SizedBox(height: 6),
                  Text('PNG, JPG, PDF up to 10MB',
                      style: GoogleFonts.sora(fontSize: 12, color: textSecondary)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── OR divider ──────────────────────────────────
          Row(
            children: [
              Expanded(child: Divider(color: borderColor, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR', style: GoogleFonts.sora(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
              ),
              Expanded(child: Divider(color: borderColor, thickness: 1)),
            ],
          ),

          const SizedBox(height: 16),

          // ── Take Photo ──────────────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: isWhite ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))] : [],
            ),
            child: ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFCC0020).withOpacity(0.10),
                ),
                child: const Icon(Icons.camera_alt_outlined, color: Color(0xFFCC0020), size: 20),
              ),
              title: Text('Take Photo',
                  style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textSecondary),
            ),
          ),

          // ── Choose from Gallery ─────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: isWhite ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))] : [],
            ),
            child: ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFCC0020).withOpacity(0.10),
                ),
                child: const Icon(Icons.folder_outlined, color: Color(0xFFCC0020), size: 20),
              ),
              title: Text('Choose from Gallery',
                  style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textSecondary),
            ),
          ),

          // ── Eleghart AI Agent card ──────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: isWhite ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2))] : [],
            ),
            child: Row(
              children: [
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFCC0020).withOpacity(0.12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset('assets/icons/eleghart_icon.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Eleghart AI Agent',
                          style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
                      const SizedBox(height: 4),
                      Text('Reading your document...',
                          style: GoogleFonts.sora(fontSize: 12, color: textSecondary)),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: 0.75,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFCC0020), Color(0xFFFF3355)],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Extracting expenses and details',
                              style: GoogleFonts.sora(fontSize: 10, color: textSecondary)),
                          Text('75%',
                              style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFCC0020))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Supported formats ───────────────────────────
          Text('Supported formats',
              style: GoogleFonts.sora(fontSize: 12, color: textSecondary, letterSpacing: 0.4)),
          const SizedBox(height: 10),
          Row(
            children: [
              _formatChip('PNG', Icons.image_outlined, isWhite),
              const SizedBox(width: 10),
              _formatChip('JPG', Icons.photo_outlined, isWhite),
              const SizedBox(width: 10),
              _formatChip('PDF', Icons.picture_as_pdf_outlined, isWhite),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formatChip(String label, IconData icon, bool isWhite) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isWhite ? Colors.white : const Color(0xFF120404),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFCC0020).withOpacity(0.35),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFCC0020), size: 22),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.sora(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: isWhite ? EleghartColors.accentDark : Colors.white)),
          ],
        ),
      ),
    );
  }

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

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  const _DashedBorderPainter({required this.color, this.strokeWidth = 1.5, this.radius = 14});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius)));
    const dashWidth = 8.0;
    const dashSpace = 5.0;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dashWidth), paint);
        d += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => color != old.color;
}
