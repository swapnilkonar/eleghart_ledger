import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/splitwise_models.dart';
import '../services/splitwise_service.dart';
import '../services/splitwise_storage_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../utils/data_sync.dart';
import '../widgets/themed_background.dart';
import 'add_splitwise_expense_screen.dart';

class SplitwiseDashboardScreen extends StatefulWidget {
  final SplitwiseGroupModel? initialGroup;

  const SplitwiseDashboardScreen({super.key, this.initialGroup});

  @override
  State<SplitwiseDashboardScreen> createState() => _SplitwiseDashboardScreenState();
}

class _SplitwiseDashboardScreenState extends State<SplitwiseDashboardScreen> {
  bool _loading = true;
  List<SplitwiseGroupModel> _groups = [];
  SplitwiseGroupModel? _activeGroup;

  List<MemberBalance> _balances = [];
  List<SplitTransfer> _transfers = [];
  double _totalGroupExpenses = 0;

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

    SplitwiseGroupModel? selectedGroup;
    if (widget.initialGroup != null) {
      selectedGroup = groups.where((g) => g.id == widget.initialGroup!.id).firstOrNull ?? widget.initialGroup;
    } else if (_activeGroup != null) {
      selectedGroup = groups.where((g) => g.id == _activeGroup!.id).firstOrNull;
    }
    selectedGroup ??= groups.isNotEmpty ? groups.first : null;

    if (selectedGroup != null) {
      final grpExpenses = expenses.where((e) => e.splitwiseGroupId == selectedGroup!.id).toList();
      _totalGroupExpenses = grpExpenses.fold(0.0, (sum, e) => sum + e.amount);
      _balances = SplitwiseService.calculateMemberBalances(selectedGroup, grpExpenses);
      _transfers = SplitwiseService.simplifyDebts(_balances);
    }

    if (mounted) {
      setState(() {
        _groups = groups;
        _activeGroup = selectedGroup;
        _loading = false;
      });
    }
  }

  void _recordSettlement(SplitTransfer transfer) async {
    if (_activeGroup == null) return;

    final settlementExpense = SplitwiseExpenseModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      splitwiseGroupId: _activeGroup!.id,
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

  void _shareWhatsAppSummary() {
    if (_activeGroup == null) return;
    final summary = SplitwiseService.generateWhatsAppSummary(
      group: _activeGroup!,
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
                          Text('Splitz', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
                          Text(_activeGroup?.name ?? 'Select Group', style: GoogleFonts.sora(fontSize: 12, color: textSec)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.share_rounded, color: Color(0xFFCC0020), size: 20),
                        tooltip: 'Share to WhatsApp',
                        onPressed: _shareWhatsAppSummary,
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
                        // Group Picker Bar
                        _buildGroupSelectorBar(isWhite),
                        const SizedBox(height: 16),

                        if (_activeGroup != null) ...[
                          // Hero Debt Card
                          _buildHeroDebtCard(isWhite),
                          const SizedBox(height: 24),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFCC0020),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                  label: Text('+ Add Split', style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700)),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => AddSplitwiseExpenseScreen(group: _activeGroup!)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFCC0020)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                icon: const Icon(Icons.copy_rounded, color: Color(0xFFCC0020), size: 18),
                                label: Text('Copy Text', style: GoogleFonts.sora(color: const Color(0xFFCC0020), fontWeight: FontWeight.w700)),
                                onPressed: _shareWhatsAppSummary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Section 1: Member Balances
                          Text('Member Balances', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                          const SizedBox(height: 12),
                          _buildMemberBalancesList(isWhite),
                          const SizedBox(height: 24),

                          // Section 2: Simplified Debt Settlements
                          Text('Simplified Debt Settlements', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                          Text('Min-Cash-Flow algorithm reduces group transfers into direct settlements:', style: GoogleFonts.sora(fontSize: 11, color: textSec)),
                          const SizedBox(height: 12),
                          _buildSimplifiedSettlementsList(isWhite),
                        ],
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

  Widget _buildGroupSelectorBar(bool isWhite) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isWhite ? Colors.white : const Color(0xFF140404),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SplitwiseGroupModel>(
          value: _activeGroup,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFCC0020)),
          items: _groups.map((g) {
            return DropdownMenuItem<SplitwiseGroupModel>(
              value: g,
              child: Text(g.name, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: isWhite ? EleghartColors.accentDark : Colors.white)),
            );
          }).toList(),
          onChanged: (g) {
            if (g != null) setState(() => _activeGroup = g);
            _loadData();
          },
        ),
      ),
    );
  }

  Widget _buildHeroDebtCard(bool isWhite) {
    final userBalance = _balances.where((b) => b.member == 'You' || b.member == 'Swapnil' || b.member == _activeGroup?.members.first).firstOrNull;
    final net = userBalance?.netBalance ?? 0;
    final isOwed = net > 0.01;
    final owes = net < -0.01;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOwed
              ? [const Color(0xFF047857), const Color(0xFF10B981)]
              : (owes
                  ? [const Color(0xFFB91C1C), const Color(0xFFEF4444)]
                  : [const Color(0xFF475569), const Color(0xFF64748B)]),
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
                Text('YOUR GROUP BALANCE', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70)),
                const SizedBox(height: 4),
                Text(
                  isOwed
                      ? 'You are owed ₹${net.toStringAsFixed(0)}'
                      : (owes ? 'You owe ₹${net.abs().toStringAsFixed(0)}' : 'You are fully settled!'),
                  style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text('Total Group Expenses: ₹${_totalGroupExpenses.toStringAsFixed(0)}', style: GoogleFonts.sora(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(
              isOwed ? Icons.arrow_downward_rounded : (owes ? Icons.arrow_upward_rounded : Icons.check_circle_rounded),
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberBalancesList(bool isWhite) {
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;

    return Column(
      children: _balances.map((b) {
        final isOwed = b.isOwed;
        final owes = b.owes;
        final color = isOwed ? const Color(0xFF10B981) : (owes ? const Color(0xFFEF4444) : Colors.grey);

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
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                radius: 18,
                child: Text(
                  b.member.isNotEmpty ? b.member[0].toUpperCase() : 'M',
                  style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: color),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.member, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
                    Text(
                      'Paid ₹${b.totalPaid.toStringAsFixed(0)} • Owed ₹${b.totalOwed.toStringAsFixed(0)}',
                      style: GoogleFonts.sora(fontSize: 11, color: isWhite ? Colors.black45 : Colors.white54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  isOwed
                      ? 'Gets ₹${b.netBalance.toStringAsFixed(0)}'
                      : (owes ? 'Owes ₹${b.netBalance.abs().toStringAsFixed(0)}' : 'Settled'),
                  style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSimplifiedSettlementsList(bool isWhite) {
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;

    if (_transfers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isWhite ? Colors.white : const Color(0xFF140404),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.15)),
        ),
        child: Center(
          child: Text(
            '🎉 Everyone in this group is fully settled!',
            style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
          ),
        ),
      );
    }

    return Column(
      children: _transfers.map((t) {
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
                    const SizedBox(height: 2),
                    Text('₹${t.amount.toStringAsFixed(0)}', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFFCC0020))),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0020),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () => _recordSettlement(t),
                child: Text('Settle Up', style: GoogleFonts.sora(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
