import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../models/splitwise_models.dart';
import '../services/splitwise_storage_service.dart';
import '../services/splitwise_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../utils/data_sync.dart';
import '../widgets/themed_background.dart';
import 'splitwise_group_detail_screen.dart';

class SplitwiseHomeScreen extends StatefulWidget {
  const SplitwiseHomeScreen({super.key});

  @override
  State<SplitwiseHomeScreen> createState() => _SplitwiseHomeScreenState();
}

class _SplitwiseHomeScreenState extends State<SplitwiseHomeScreen> {
  bool _loading = true;
  List<SplitwiseGroupModel> _groups = [];
  List<SplitwiseExpenseModel> _allExpenses = [];
  double _overallNetBalance = 0;

  @override
  void initState() {
    super.initState();
    DataSyncNotifier.instance.addListener(_loadData);
    _loadData();
  }

  @override
  void dispose() {
    DataSyncNotifier.instance.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    final groups = await SplitwiseStorageService.loadGroups();
    final expenses = await SplitwiseStorageService.loadExpenses();

    double overallNet = 0;
    for (final g in groups) {
      final grpExpenses = expenses.where((e) => e.splitwiseGroupId == g.id).toList();
      final balances = SplitwiseService.calculateMemberBalances(g, grpExpenses);
      final userBal = balances.where((b) => b.member == 'You' || b.member == 'Swapnil' || b.member == g.members.first).firstOrNull;
      if (userBal != null) {
        overallNet += userBal.netBalance;
      }
    }

    if (mounted) {
      setState(() {
        _groups = groups;
        _allExpenses = expenses;
        _overallNetBalance = overallNet;
        _loading = false;
      });
    }
  }

  void _showCreateGroupModal(bool isWhite) {
    final nameCtrl = TextEditingController();
    final memberCtrl = TextEditingController();
    final List<String> members = ['You'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isWhite ? Colors.white : const Color(0xFF160606),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('New Eleghart Split Group', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
                    IconButton(icon: Icon(Icons.close_rounded, color: textPrimary), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  style: GoogleFonts.sora(fontSize: 14, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Group Name (e.g. Goa Trip 🏖️, Flatmates 🏠)',
                    hintStyle: GoogleFonts.sora(fontSize: 13, color: isWhite ? Colors.black38 : Colors.white38),
                    filled: true,
                    fillColor: isWhite ? const Color(0xFFF8FAFC) : const Color(0xFF220A0A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                Text('Group Members', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: members.map((m) {
                    return Chip(
                      label: Text(m, style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                      backgroundColor: const Color(0xFFCC0020),
                      deleteIcon: m == 'You' ? null : const Icon(Icons.close, size: 14, color: Colors.white),
                      onDeleted: m == 'You' ? null : () => setModalState(() => members.remove(m)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: memberCtrl,
                        style: GoogleFonts.sora(fontSize: 13, color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Add member name (e.g. Rahul)',
                          hintStyle: GoogleFonts.sora(fontSize: 12, color: isWhite ? Colors.black38 : Colors.white38),
                          filled: true,
                          fillColor: isWhite ? const Color(0xFFF8FAFC) : const Color(0xFF220A0A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_rounded, color: Color(0xFFCC0020), size: 28),
                      onPressed: () {
                        final val = memberCtrl.text.trim();
                        if (val.isNotEmpty && !members.contains(val)) {
                          setModalState(() {
                            members.add(val);
                            memberCtrl.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCC0020),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final newGroup = SplitwiseGroupModel(
                        id: const Uuid().v4(),
                        name: name,
                        members: members,
                        createdAt: DateTime.now(),
                      );
                      await SplitwiseStorageService.addGroup(newGroup);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        _loadData();
                      }
                    },
                    child: Text('Create Group', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54;

    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0020)));

    final isOwed = _overallNetBalance > 0.01;
    final owes = _overallNetBalance < -0.01;

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
                          Text('Eleghart Split', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w800, color: textPrimary)),
                          Text('Independent Bill Splitting Engine', style: GoogleFonts.sora(fontSize: 11, color: textSec)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFCC0020), size: 24),
                        onPressed: () => _showCreateGroupModal(isWhite),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.1)),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Overall Balance Card
                        _buildHeroOverallCard(isWhite, isOwed, owes),
                        const SizedBox(height: 24),

                        // Groups Header & Create Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Eleghart Split Groups (${_groups.length})', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                            TextButton.icon(
                              onPressed: () => _showCreateGroupModal(isWhite),
                              icon: const Icon(Icons.add_rounded, color: Color(0xFFCC0020), size: 16),
                              label: Text('New Group', style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFCC0020))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_groups.isEmpty)
                          _buildEmptyState(isWhite)
                        else
                          Column(
                            children: _groups.map((g) => _buildGroupCard(g, isWhite)).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroOverallCard(bool isWhite, bool isOwed, bool owes) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (isOwed ? const Color(0xFF10B981) : const Color(0xFFCC0020)).withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOTAL OVERALL BALANCE', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70)),
                const SizedBox(height: 4),
                Text(
                  isOwed
                      ? 'Overall, you are owed ₹${_overallNetBalance.toStringAsFixed(0)}'
                      : (owes ? 'Overall, you owe ₹${_overallNetBalance.abs().toStringAsFixed(0)}' : 'You are fully settled across all groups!'),
                  style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(
              isOwed ? Icons.trending_up_rounded : (owes ? Icons.trending_down_rounded : Icons.check_circle_rounded),
              color: Colors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isWhite) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isWhite ? Colors.white : const Color(0xFF140404),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.groups_rounded, color: Color(0xFFCC0020), size: 44),
          const SizedBox(height: 12),
          Text('No Eleghart Split Groups Yet', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: isWhite ? EleghartColors.accentDark : Colors.white)),
          const SizedBox(height: 6),
          Text('Create an Eleghart Split group for trips, flatmates, or dining to split bills offline.', style: GoogleFonts.sora(fontSize: 12, color: isWhite ? Colors.black45 : Colors.white54), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0020), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
            label: Text('Create First Group', style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700)),
            onPressed: () => _showCreateGroupModal(isWhite),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(SplitwiseGroupModel g, bool isWhite) {
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite ? Colors.black45 : Colors.white54;

    final grpExpenses = _allExpenses.where((e) => e.splitwiseGroupId == g.id).toList();
    final totalSpent = grpExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final balances = SplitwiseService.calculateMemberBalances(g, grpExpenses);
    final userBal = balances.where((b) => b.member == 'You' || b.member == 'Swapnil' || b.member == g.members.first).firstOrNull;
    final net = userBal?.netBalance ?? 0;
    final isOwed = net > 0.01;
    final owes = net < -0.01;

    final color = isOwed ? const Color(0xFF10B981) : (owes ? const Color(0xFFEF4444) : Colors.grey);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SplitwiseGroupDetailScreen(group: g)),
      ).then((_) => _loadData()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isWhite ? Colors.white : const Color(0xFF140404),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.18)),
          boxShadow: isWhite ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))] : [],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFCC0020).withOpacity(0.12),
              radius: 22,
              child: Text(
                g.name.isNotEmpty ? g.name[0].toUpperCase() : 'S',
                style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFFCC0020)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
                  const SizedBox(height: 2),
                  Text('${g.members.length} members • Total ₹${totalSpent.toStringAsFixed(0)}', style: GoogleFonts.sora(fontSize: 11, color: textSec)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isOwed
                      ? 'Gets ₹${net.toStringAsFixed(0)}'
                      : (owes ? 'Owes ₹${net.abs().toStringAsFixed(0)}' : 'Settled'),
                  style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w800, color: color),
                ),
                Icon(Icons.chevron_right_rounded, color: textSec, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
