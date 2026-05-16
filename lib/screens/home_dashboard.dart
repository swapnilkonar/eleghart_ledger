import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';
import 'group_detail_screen.dart';
import 'profile_sheet.dart';
import 'create_group_screen.dart';

class HomeDashboard extends StatefulWidget {
  final String userName;
  
  const HomeDashboard({super.key, required this.userName});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  List<GroupModel> groups = [];
  List<ExpenseModel> expenses = [];
  bool loading = true;
  String userName = '';
  File? avatar;
  double totalDebit = 0;
  double totalCredit = 0;
  double netBalance = 0;
  String lastExpenseDate = '-';
  int totalExpensesCount = 0;

  @override
  void initState() {
    super.initState();
    userName = widget.userName;
    loadData();
  }

  loadData() async {
    try {
      final loadedGroups = await StorageService.loadGroups();
      final loadedExpenses = await StorageService.loadExpenses();
      
      final prefs = await SharedPreferences.getInstance();
      final avatarPath = prefs.getString('user_avatar_path');
      
      calculateSummary(loadedExpenses);
      
      setState(() {
        groups = loadedGroups;
        expenses = loadedExpenses;
        loading = false;
        if (avatarPath != null && File(avatarPath).existsSync()) {
          avatar = File(avatarPath);
        }
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
    }
  }

  calculateSummary(List<ExpenseModel> list) {
    if (list.isEmpty) {
      totalDebit = 0;
      totalCredit = 0;
      netBalance = 0;
      lastExpenseDate = '-';
      totalExpensesCount = 0;
      return;
    }

    double db = 0, cr = 0;
    for (final e in list) {
      if (e.type == 'credit') {
        cr += e.amount;
      } else {
        db += e.amount;
      }
    }

    totalDebit = db;
    totalCredit = cr;
    netBalance = cr - db;
    totalExpensesCount = list.length;

    if (list.isNotEmpty) {
      final last = list.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b);
      lastExpenseDate = last.toString().split(' ')[0];
    }
  }

  openCreateGroup() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
    );
    if (created == true) loadData();
  }

  openProfileSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ProfileSheet(
        onUpdated: () async {
          await loadData();
        },
      ),
    );
  }

  deleteGroup(GroupModel group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text('Delete "${group.name}"? All expenses will also be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;

    final updatedGroups = List<GroupModel>.from(groups)..removeWhere((g) => g.id == group.id);
    final allExpenses = await StorageService.loadExpenses();
    final updatedExpenses = allExpenses.where((e) => e.groupId != group.id).toList();

    await StorageService.saveGroups(updatedGroups);
    await StorageService.saveExpenses(updatedExpenses);

    loadData();
  }

  @override
  Widget build(BuildContext context) {
    final netIsPositive = netBalance >= 0;
    
    return Scaffold(
      backgroundColor: EleghartColors.bgLight,
      appBar: AppBar(
        title: const Text('Eleghart Ledger', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          GestureDetector(
            onTap: openProfileSheet,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GlassContainer(
                borderRadius: 50,
                padding: const EdgeInsets.all(2),
                interactive: false,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: EleghartColors.accentDark,
                  backgroundImage: avatar != null ? FileImage(avatar!) : null,
                  child: avatar == null ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
                ),
              ),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : groups.isEmpty
              ? buildEmptyState()
              : buildContent(netIsPositive),
      floatingActionButton: GlassContainer(
        borderRadius: 50,
        padding: const EdgeInsets.all(8),
        onTap: openCreateGroup,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_2_outlined, size: 64, color: EleghartColors.textSecondary),
          const SizedBox(height: 24),
          Text('No groups yet', style: GlassTheme.headingMedium.copyWith(fontSize: 22)),
          const SizedBox(height: 8),
          const Text('Create a group to get started'),
          const SizedBox(height: 32),
          GlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            onTap: openCreateGroup,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.group_add, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('New Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildContent(bool netIsPositive) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSummary(netIsPositive),
            const SizedBox(height: 24),
            Text('Groups', style: GlassTheme.headingSmall.copyWith(fontSize: 16)),
            const SizedBox(height: 12),
            buildGroupsList(),
          ],
        ),
      ),
    );
  }

  Widget buildSummary(bool netIsPositive) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: EleghartColors.accentDark.withOpacity(0.2),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Summary', style: GlassTheme.headingSmall.copyWith(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: buildStatBox('Debit', '₹${totalDebit.toStringAsFixed(0)}', Colors.redAccent)),
                  const SizedBox(width: 12),
                  Expanded(child: buildStatBox('Credit', '₹${totalCredit.toStringAsFixed(0)}', Colors.greenAccent)),
                  const SizedBox(width: 12),
                  Expanded(child: buildStatBox('Balance', '₹${netBalance.abs().toStringAsFixed(0)}', netIsPositive ? Colors.greenAccent : Colors.redAccent)),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.groups, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text('${groups.length} Groups', style: const TextStyle(fontSize: 12, color: Colors.white)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text('$totalExpensesCount Expenses', style: const TextStyle(fontSize: 12, color: Colors.white)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text('Last: $lastExpenseDate', style: const TextStyle(fontSize: 12, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget buildGroupsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final group = groups[index];
        final hasImage = group.imagePath != null && File(group.imagePath!).existsSync();
        
        return GlassMorphicCard(
          borderRadius: 16,
          onTap: () async {
            final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)));
            if (changed == true) loadData();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                hasImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(group.imagePath!), width: 48, height: 48, fit: BoxFit.cover),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [EleghartColors.accentDark, EleghartColors.accentLight],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.group, color: Colors.white, size: 24),
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const Text('Tap to view', style: TextStyle(fontSize: 12, color: EleghartColors.textSecondary)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (result) async {
                    if (result == 'edit') {
                      final updated = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CreateGroupScreen(existingGroup: group)));
                      if (updated == true) loadData();
                    } else if (result == 'delete') {
                      deleteGroup(group);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                  ],
                  child: Icon(Icons.more_vert, color: EleghartColors.textSecondary, size: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
