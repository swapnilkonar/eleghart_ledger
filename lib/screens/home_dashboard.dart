// HomeDashboard — Ledger-aware + Font & Screen-Resilient UI + Profile
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'group_detail_screen.dart';
import 'profile_sheet.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';
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
    }
  }

  Future<void> _openProfileSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ProfileSheet(
        onUpdated: () async {
          await _loadProfile();
        },
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final greeting = _getGreeting();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eleghart Ledger'),
        elevation: 0,
        actions: [
          GestureDetector(
            onTap: _openProfileSheet,
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: EleghartColors.accentDark,
                backgroundImage: _avatar != null ? FileImage(_avatar!) : null,
                child: _avatar == null
                    ? const Icon(Icons.person, color: Colors.white, size: 18)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        '$greeting, $_userName 👋',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: EleghartColors.textPrimary,
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 18),

                  if (_groups.isNotEmpty) _buildSummaryCard(),

                  const SizedBox(height: 26),

                  Expanded(
                    child: _groups.isEmpty
                        ? _buildEmptyState(context)
                        : _buildGroupsList(),
                  ),
                ],
              ),
            ),

      floatingActionButton: _groups.isNotEmpty
        ? FloatingActionButton.extended(
            onPressed: _openCreateGroup,
            backgroundColor: EleghartColors.accentDark,
            elevation: 10,
            icon: const Icon(Icons.add, color: Colors.white, size: 22),
            label: const Text(
              'Add Group',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: Colors.white,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          )
        : null,
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
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
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
