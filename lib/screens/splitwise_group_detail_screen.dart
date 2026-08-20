import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/splitwise_models.dart';
import '../services/splitwise_storage_service.dart';
import '../services/splitwise_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../utils/data_sync.dart';
import '../widgets/themed_background.dart';
import 'add_splitwise_expense_screen.dart';

class SplitwiseGroupDetailScreen extends StatefulWidget {
  final SplitwiseGroupModel group;

  const SplitwiseGroupDetailScreen({super.key, required this.group});

  @override
  State<SplitwiseGroupDetailScreen> createState() => _SplitwiseGroupDetailScreenState();
}

class _SplitwiseGroupDetailScreenState extends State<SplitwiseGroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late SplitwiseGroupModel _group;

  bool _loading = true;
  List<SplitwiseExpenseModel> _expenses = [];
  List<MemberBalance> _balances = [];
  List<SplitTransfer> _transfers = [];
  double _totalGroupExpenses = 0;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _tabController = TabController(length: 3, vsync: this);
    DataSyncNotifier.instance.addListener(_loadData);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    DataSyncNotifier.instance.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    final allGroups = await SplitwiseStorageService.loadGroups();
    final updatedGroup = allGroups.where((g) => g.id == _group.id).firstOrNull ?? _group;

    // Auto sanitize equal split expenses to distribute across all group members
    await SplitwiseStorageService.sanitizeExpensesForGroup(updatedGroup);

    final allExpenses = await SplitwiseStorageService.loadExpenses();
    final grpExpenses = allExpenses.where((e) => e.splitwiseGroupId == updatedGroup.id).toList();

    _totalGroupExpenses = grpExpenses.fold(0.0, (sum, e) => sum + e.amount);
    _balances = SplitwiseService.calculateMemberBalances(updatedGroup, grpExpenses);
    _transfers = SplitwiseService.simplifyDebts(_balances);

    if (mounted) {
      setState(() {
        _group = updatedGroup;
        _expenses = grpExpenses;
        _loading = false;
      });
    }
  }

  void _recordSettlement(SplitTransfer transfer) async {
    final settlementExpense = SplitwiseExpenseModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      splitwiseGroupId: _group.id,
      title: 'Settlement: ${transfer.fromMember} ➔ ${transfer.toMember}',
      amount: transfer.amount,
      date: DateTime.now(),
      splitType: 'exact',
      paidBy: {transfer.fromMember: transfer.amount},
      distribution: {transfer.toMember: transfer.amount},
    );

    await SplitwiseStorageService.addExpense(settlementExpense);
    DataSyncNotifier.notifyDataChanged();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recorded settlement: ₹${transfer.amount.toStringAsFixed(0)} paid to ${transfer.toMember}')),
      );
    }
  }

  void _addMemberDialog(bool isWhite) {
    final memberCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isWhite ? Colors.white : const Color(0xFF180808),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add Member to ${_group.name}', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: isWhite ? EleghartColors.accentDark : Colors.white)),
        content: TextField(
          controller: memberCtrl,
          style: GoogleFonts.sora(fontSize: 13, color: isWhite ? EleghartColors.accentDark : Colors.white),
          decoration: InputDecoration(
            hintText: 'Member Name (e.g. Amit)',
            hintStyle: GoogleFonts.sora(fontSize: 12, color: isWhite ? Colors.black38 : Colors.white38),
            filled: true,
            fillColor: isWhite ? const Color(0xFFF8FAFC) : const Color(0xFF220A0A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.sora(color: isWhite ? Colors.black54 : Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0020), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              final newMember = memberCtrl.text.trim();
              if (newMember.isNotEmpty && !_group.members.contains(newMember)) {
                final updatedMembers = List<String>.from(_group.members)..add(newMember);
                final updatedGroup = _group.copyWith(members: updatedMembers);
                await SplitwiseStorageService.updateGroup(updatedGroup);
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              }
            },
            child: Text('Add Member', style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _renameMemberDialog(bool isWhite, String oldName) {
    final ctrl = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isWhite ? Colors.white : const Color(0xFF180808),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename Member', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: isWhite ? EleghartColors.accentDark : Colors.white)),
        content: TextField(
          controller: ctrl,
          style: GoogleFonts.sora(fontSize: 13, color: isWhite ? EleghartColors.accentDark : Colors.white),
          decoration: InputDecoration(
            hintText: 'New Member Name',
            hintStyle: GoogleFonts.sora(fontSize: 12, color: isWhite ? Colors.black38 : Colors.white38),
            filled: true,
            fillColor: isWhite ? const Color(0xFFF8FAFC) : const Color(0xFF220A0A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.sora(color: isWhite ? Colors.black54 : Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0020), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                await SplitwiseStorageService.renameMemberInGroup(
                  groupId: _group.id,
                  oldName: oldName,
                  newName: newName,
                );
                DataSyncNotifier.notifyDataChanged();
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              }
            },
            child: Text('Rename', style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _removeMemberDialog(bool isWhite, String memberName) {
    if (_group.members.length <= 1) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isWhite ? Colors.white : const Color(0xFF180808),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove $memberName?', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: isWhite ? EleghartColors.accentDark : Colors.white)),
        content: Text('Are you sure you want to remove $memberName from ${_group.name}?', style: GoogleFonts.sora(fontSize: 13, color: isWhite ? Colors.black87 : Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.sora(color: isWhite ? Colors.black54 : Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0020), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              final updatedMembers = List<String>.from(_group.members)..remove(memberName);
              final updatedGroup = _group.copyWith(members: updatedMembers);
              await SplitwiseStorageService.updateGroup(updatedGroup);
              DataSyncNotifier.notifyDataChanged();
              if (mounted) {
                Navigator.pop(context);
                _loadData();
              }
            },
            child: Text('Remove', style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _editGroupDialog(bool isWhite) {
    final nameCtrl = TextEditingController(text: _group.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isWhite ? Colors.white : const Color(0xFF180808),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Group Name', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: isWhite ? EleghartColors.accentDark : Colors.white)),
        content: TextField(
          controller: nameCtrl,
          style: GoogleFonts.sora(fontSize: 13, color: isWhite ? EleghartColors.accentDark : Colors.white),
          decoration: InputDecoration(
            hintText: 'Group Name',
            hintStyle: GoogleFonts.sora(fontSize: 12, color: isWhite ? Colors.black38 : Colors.white38),
            filled: true,
            fillColor: isWhite ? const Color(0xFFF8FAFC) : const Color(0xFF220A0A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.sora(color: isWhite ? Colors.black54 : Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0020), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty) {
                final updated = _group.copyWith(name: newName);
                await SplitwiseStorageService.updateGroup(updated);
                DataSyncNotifier.notifyDataChanged();
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              }
            },
            child: Text('Save', style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _deleteGroupDialog(bool isWhite) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isWhite ? Colors.white : const Color(0xFF180808),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Group?', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: isWhite ? EleghartColors.accentDark : Colors.white)),
        content: Text('Are you sure you want to delete "${_group.name}" and all its shared bills? This action cannot be undone.', style: GoogleFonts.sora(fontSize: 13, color: isWhite ? Colors.black87 : Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.sora(color: isWhite ? Colors.black54 : Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0020), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              await SplitwiseStorageService.deleteGroup(_group.id);
              DataSyncNotifier.notifyDataChanged();
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: Text('Delete Group', style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _deleteExpenseDialog(bool isWhite, SplitwiseExpenseModel expense) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isWhite ? Colors.white : const Color(0xFF180808),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Bill?', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: isWhite ? EleghartColors.accentDark : Colors.white)),
        content: Text('Delete "${expense.title}" (₹${expense.amount.toStringAsFixed(0)})?', style: GoogleFonts.sora(fontSize: 13, color: isWhite ? Colors.black87 : Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.sora(color: isWhite ? Colors.black54 : Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0020), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              await SplitwiseStorageService.deleteExpense(expense.id);
              DataSyncNotifier.notifyDataChanged();
              if (mounted) {
                Navigator.pop(context);
                _loadData();
              }
            },
            child: Text('Delete Bill', style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _shareWhatsAppSummary() {
    final summary = SplitwiseService.generateWhatsAppSummary(
      group: _group,
      balances: _balances,
      transfers: _transfers,
      totalGroupExpenses: _totalGroupExpenses,
    );
    Clipboard.setData(ClipboardData(text: summary));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Splitz summary copied to clipboard! Ready to paste into WhatsApp.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54;

    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0020)));

    final userBalance = _balances.where((b) => b.member == 'You' || b.member == 'Swapnil' || b.member == _group.members.first).firstOrNull;
    final net = userBalance?.netBalance ?? 0;
    final isOwed = net > 0.01;
    final owes = net < -0.01;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.85)),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_group.name, style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
                          Text('${_group.members.length} members', style: GoogleFonts.sora(fontSize: 11, color: textSec)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFFCC0020), size: 22),
                        tooltip: 'Add Member',
                        onPressed: () => _addMemberDialog(isWhite),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_rounded, color: Color(0xFFCC0020), size: 20),
                        tooltip: 'Share WhatsApp Summary',
                        onPressed: _shareWhatsAppSummary,
                      ),
                      PopupMenuButton<String>(
                        color: isWhite ? Colors.white : const Color(0xFF1E0B0B),
                        icon: Icon(Icons.more_vert_rounded, color: textPrimary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        onSelected: (val) {
                          if (val == 'edit') _editGroupDialog(isWhite);
                          if (val == 'delete') _deleteGroupDialog(isWhite);
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit_rounded, color: Color(0xFFCC0020), size: 18),
                                const SizedBox(width: 10),
                                Text('Edit Group Name', style: GoogleFonts.sora(fontSize: 13, color: isWhite ? EleghartColors.accentDark : Colors.white)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 18),
                                const SizedBox(width: 10),
                                Text('Delete Group', style: GoogleFonts.sora(fontSize: 13, color: const Color(0xFFEF4444))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.1)),

                // Hero Group Balance Card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _buildHeroGroupCard(isWhite, isOwed, owes, net),
                ),

                // Tab Bar
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFFCC0020),
                  labelColor: const Color(0xFFCC0020),
                  unselectedLabelColor: textSec,
                  labelStyle: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Bills'),
                    Tab(text: 'Balances'),
                    Tab(text: 'Members'),
                  ],
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBillsTab(isWhite),
                      _buildBalancesTab(isWhite),
                      _buildMembersTab(isWhite),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFCC0020),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Bill', style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddSplitwiseExpenseScreen(group: _group)),
        ).then((_) => _loadData()),
      ),
    );
  }

  Widget _buildHeroGroupCard(bool isWhite, bool isOwed, bool owes, double net) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOwed
              ? [const Color(0xFF047857), const Color(0xFF10B981)]
              : (owes
                  ? [const Color(0xFFB91C1C), const Color(0xFFEF4444)]
                  : [const Color(0xFF334155), const Color(0xFF475569)]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isOwed ? const Color(0xFF10B981) : const Color(0xFFCC0020)).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR GROUP POSITION', style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70)),
                const SizedBox(height: 4),
                Text(
                  isOwed
                      ? 'You are owed ₹${net.toStringAsFixed(0)}'
                      : (owes ? 'You owe ₹${net.abs().toStringAsFixed(0)}' : 'You are fully settled!'),
                  style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text('Total Group Expenses: ₹${_totalGroupExpenses.toStringAsFixed(0)}', style: GoogleFonts.sora(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(
              isOwed ? Icons.arrow_downward_rounded : (owes ? Icons.arrow_upward_rounded : Icons.check_circle_rounded),
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillsTab(bool isWhite) {
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite ? Colors.black45 : Colors.white54;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        // Instant Debt Settlement Summary Banner at the top of Bills Tab
        if (_transfers.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isWhite ? Colors.white : const Color(0xFF140404),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.swap_horiz_rounded, color: Color(0xFFCC0020), size: 18),
                    const SizedBox(width: 8),
                    Text('Group Debts Summary', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  children: _transfers.map((t) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(text: t.fromMember, style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444))),
                                  TextSpan(text: ' pays ', style: GoogleFonts.sora(fontSize: 12, color: textPrimary)),
                                  TextSpan(text: t.toMember, style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                                  TextSpan(text: ': ₹${t.amount.toStringAsFixed(0)}', style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFCC0020))),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _recordSettlement(t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFCC0020), borderRadius: BorderRadius.circular(8)),
                              child: Text('Settle Up', style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        Text('Shared Bills (${_expenses.length})', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
        const SizedBox(height: 10),

        if (_expenses.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long_rounded, color: Color(0xFFCC0020), size: 40),
                  const SizedBox(height: 10),
                  Text('No bills added yet', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
                  Text('Tap "+ Add Bill" to record a shared group expense.', style: GoogleFonts.sora(fontSize: 12, color: textSec)),
                ],
              ),
            ),
          )
        else
          ..._expenses.map((e) {
            // Calculate individual impact of this bill for 'You'
            final paidByYou = e.paidBy['You'] ?? (e.paidBy.keys.first == 'You' ? e.amount : 0.0);
            final shareYou = e.distribution['You'] ?? (e.distribution.isEmpty ? e.amount / _group.members.length : 0.0);
            final netBillYou = paidByYou - shareYou;

            final isYouLent = netBillYou > 0.01;
            final isYouOwe = netBillYou < -0.01;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isWhite ? Colors.white : const Color(0xFF140404),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFCC0020).withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.receipt_rounded, color: Color(0xFFCC0020), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
                        const SizedBox(height: 2),
                        Text('Paid by ${e.primaryPayer} • ${e.date.day}/${e.date.month}/${e.date.year}', style: GoogleFonts.sora(fontSize: 11, color: textSec)),
                        const SizedBox(height: 4),

                        // Bill Impact Badge
                        if (isYouLent)
                          Text('🟢 You lent ₹${netBillYou.toStringAsFixed(0)} on this bill', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)))
                        else if (isYouOwe)
                          Text('🔴 You owe ₹${netBillYou.abs().toStringAsFixed(0)} on this bill', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444)))
                        else
                          Text('⚪ You are even on this bill', style: GoogleFonts.sora(fontSize: 11, color: textSec)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${e.amount.toStringAsFixed(0)}', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFFCC0020))),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFFCC0020), size: 18),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddSplitwiseExpenseScreen(
                                    group: _group,
                                    existingExpense: e,
                                  ),
                                ),
                              );
                              _loadData();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 18),
                            onPressed: () => _deleteExpenseDialog(isWhite, e),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildBalancesTab(bool isWhite) {
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Member Net Positions', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
          const SizedBox(height: 10),
          Column(
            children: _balances.map((b) {
              final isOwed = b.isOwed;
              final owes = b.owes;
              final color = isOwed ? const Color(0xFF10B981) : (owes ? const Color(0xFFEF4444) : Colors.grey);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isWhite ? Colors.white : const Color(0xFF140404),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withOpacity(0.15),
                      radius: 16,
                      child: Text(b.member.isNotEmpty ? b.member[0].toUpperCase() : 'M', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.member, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                          Text('Paid ₹${b.totalPaid.toStringAsFixed(0)} • Share ₹${b.totalOwed.toStringAsFixed(0)}', style: GoogleFonts.sora(fontSize: 10.5, color: isWhite ? Colors.black45 : Colors.white54)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        isOwed ? 'Gets ₹${b.netBalance.toStringAsFixed(0)}' : (owes ? 'Owes ₹${b.netBalance.abs().toStringAsFixed(0)}' : 'Settled'),
                        style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          Text('Simplified Settlements', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
          Text('Min-Cash-Flow algorithm reduces group transfers into direct settlements:', style: GoogleFonts.sora(fontSize: 11, color: isWhite ? Colors.black45 : Colors.white54)),
          const SizedBox(height: 10),
          if (_transfers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isWhite ? Colors.white : const Color(0xFF140404),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.15)),
              ),
              child: Center(
                child: Text('🎉 Everyone in this group is fully settled!', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
              ),
            )
          else
            Column(
              children: _transfers.map((t) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isWhite ? Colors.white : const Color(0xFF140404),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(text: t.fromMember, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444))),
                                  TextSpan(text: ' pays ', style: GoogleFonts.sora(fontSize: 13, color: textPrimary)),
                                  TextSpan(text: t.toMember, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                                ],
                              ),
                            ),
                            Text('₹${t.amount.toStringAsFixed(0)}', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFFCC0020))),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCC0020),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        onPressed: () => _recordSettlement(t),
                        child: Text('Settle Up', style: GoogleFonts.sora(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMembersTab(bool isWhite) {
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: _group.members.length,
      itemBuilder: (ctx, i) {
        final m = _group.members[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isWhite ? Colors.white : const Color(0xFF140404),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.15)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFCC0020).withOpacity(0.12),
                radius: 18,
                child: Text(m.isNotEmpty ? m[0].toUpperCase() : 'M', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFFCC0020))),
              ),
              const SizedBox(width: 12),
              Text(m, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
              const Spacer(),
              if (m == 'You' || m == 'Swapnil')
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFCC0020).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('Admin', style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFCC0020))),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: Color(0xFFCC0020), size: 18),
                    tooltip: 'Rename Member',
                    onPressed: () => _renameMemberDialog(isWhite, m),
                  ),
                  if (_group.members.length > 1)
                    IconButton(
                      icon: const Icon(Icons.person_remove_rounded, color: Colors.grey, size: 18),
                      tooltip: 'Remove Member',
                      onPressed: () => _removeMemberDialog(isWhite, m),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
