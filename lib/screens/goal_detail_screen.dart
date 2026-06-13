import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/wealth_models.dart';
import '../services/wealth_repository.dart';
import '../services/wealth_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';
import 'create_goal_screen.dart';

class GoalDetailScreen extends StatefulWidget {
  final WealthGoal goal;

  const GoalDetailScreen({super.key, required this.goal});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen>
    with SingleTickerProviderStateMixin {
  late WealthGoal _goal;
  List<WealthContribution> _contributions = [];
  bool _loading = true;
  late AnimationController _animCtrl;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _goal = widget.goal;
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _progressAnim =
        Tween<double>(begin: 0, end: _goal.progress).animate(
          CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
        );
    _load();
  }

  Future<void> _load() async {
    final contribs =
        await WealthRepository.loadContributions(_goal.id);
    if (mounted) {
      setState(() {
        _contributions = contribs;
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _showAddContribution() {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite
        ? EleghartColors.accentDark.withOpacity(0.5)
        : Colors.white54;
    final sheetBg = isWhite ? Colors.white : const Color(0xFF0E0303);
    final inputFill =
        isWhite ? const Color(0xFFF5F5F5) : const Color(0xFF1A0505);

    final amtCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime date = DateTime.now();
    bool isCredit = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isWhite ? Colors.black12 : Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Text('Add Contribution',
                      style: GoogleFonts.sora(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Icon(Icons.close_rounded,
                        color: textSec, size: 20),
                  ),
                ]),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => isCredit = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isCredit
                                  ? const Color(0xFF22C55E)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_upward_rounded,
                                    size: 14,
                                    color: isCredit
                                        ? Colors.white
                                        : textSec),
                                const SizedBox(width: 6),
                                Text('Credit',
                                    style: GoogleFonts.sora(
                                        fontSize: 13,
                                        fontWeight: isCredit
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isCredit
                                            ? Colors.white
                                            : textSec)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => isCredit = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !isCredit
                                  ? const Color(0xFFCC0020)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_downward_rounded,
                                    size: 14,
                                    color: !isCredit
                                        ? Colors.white
                                        : textSec),
                                const SizedBox(width: 6),
                                Text('Debit',
                                    style: GoogleFonts.sora(
                                        fontSize: 13,
                                        fontWeight: !isCredit
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: !isCredit
                                            ? Colors.white
                                            : textSec)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text('Amount (₹)',
                    style: GoogleFonts.sora(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textSec)),
                const SizedBox(height: 8),
                TextField(
                  controller: amtCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  style: GoogleFonts.sora(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textPrimary),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: GoogleFonts.sora(
                        fontSize: 20, color: textSec.withOpacity(0.4)),
                    prefixText: '₹ ',
                    prefixStyle: GoogleFonts.sora(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isCredit
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFCC0020)),
                    filled: true,
                    fillColor: inputFill,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFCC0020), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: _goal.createdAt
                          .subtract(const Duration(days: 1)),
                      lastDate: DateTime.now(),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Color(0xFFCC0020),
                            onPrimary: Colors.white,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setSheetState(() => date = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isWhite
                              ? const Color(0xFFEEEEEE)
                              : Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 15,
                          color: const Color(0xFFCC0020)),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('dd MMM yyyy').format(date),
                        style: GoogleFonts.sora(
                            fontSize: 13, color: textPrimary),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  style:
                      GoogleFonts.sora(fontSize: 13, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Notes (optional)',
                    hintStyle: GoogleFonts.sora(
                        fontSize: 13, color: textSec),
                    filled: true,
                    fillColor: inputFill,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFCC0020), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCredit
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFCC0020),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final amt = double.tryParse(amtCtrl.text);
                      if (amt == null || amt <= 0) return;
                      Navigator.pop(ctx);
                      final signedAmt = isCredit ? amt : -amt;
                      final updated = await WealthRepository
                          .addContribution(
                        goal: _goal,
                        amount: signedAmt,
                        date: date,
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      );
                      final contribs =
                          await WealthRepository.loadContributions(
                              _goal.id);
                      if (mounted) {
                        setState(() {
                          _goal = updated;
                          _contributions = contribs;
                          _progressAnim = Tween<double>(
                                  begin: _progressAnim.value,
                                  end: updated.progress)
                              .animate(CurvedAnimation(
                                  parent: _animCtrl,
                                  curve: Curves.easeOutCubic));
                        });
                        _animCtrl.forward(from: 0);
                      }
                    },
                    child: Text(isCredit ? 'Save Credit' : 'Save Debit',
                        style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite
        ? EleghartColors.accentDark.withOpacity(0.5)
        : Colors.white54;
    final cardBg = isWhite ? Colors.white : const Color(0xFF120404);
    final border = isWhite
        ? const Color(0xFFEEEEEE)
        : Colors.white.withOpacity(0.08);
    final health = WealthService.calculateHealth(_goal);
    final monthly = WealthService.calculateMonthlyRequired(_goal);
    final elapsed = WealthService.elapsedMonths(_goal);
    final remaining = WealthService.remainingMonths(_goal);
    final total = WealthService.totalMonths(_goal);
    final expected = WealthService.expectedSaved(_goal);
    final gapAmt = WealthService.gap(_goal);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _goal);
      },
      child: Scaffold(
      backgroundColor: isWhite ? Colors.white : Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(
              child: ThemedBackground(darkOverlayOpacity: 0.65)),
          SafeArea(
            child: Column(
              children: [
                // ── AppBar ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: textPrimary, size: 20),
                        onPressed: () => Navigator.pop(context, _goal),
                      ),
                      Expanded(
                        child: Text(
                          _goal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sora(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textPrimary),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_rounded,
                            color: const Color(0xFFCC0020), size: 20),
                        tooltip: 'Edit Goal',
                        onPressed: () async {
                          final updated =
                              await Navigator.push<WealthGoal>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CreateGoalScreen(goal: _goal),
                            ),
                          );
                          if (updated != null && mounted) {
                            setState(() => _goal = updated);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFCC0020), strokeWidth: 2),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      padding:
                          const EdgeInsets.fromLTRB(20, 16, 20, 120),
                      children: [
                        // ── Circular Progress Hero ────────────────
                        Center(
                          child: Column(children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _goal.goalType.color
                                    .withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_goal.goalType.icon,
                                  color: _goal.goalType.color, size: 20),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _goal.name,
                              style: GoogleFonts.sora(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary),
                            ),
                            if (_goal.notes != null) ...[
                              const SizedBox(height: 4),
                              Text(_goal.notes!,
                                  style: GoogleFonts.sora(
                                      fontSize: 12, color: textSec)),
                            ],
                            const SizedBox(height: 24),
                            AnimatedBuilder(
                              animation: _progressAnim,
                              builder: (_, __) => SizedBox(
                                width: 160,
                                height: 160,
                                child: CustomPaint(
                                  painter: _CircularProgressPainter(
                                    progress: _progressAnim.value,
                                    progressColor:
                                        const Color(0xFFCC0020),
                                    bgColor: isWhite
                                        ? const Color(0xFFEEEEEE)
                                        : Colors.white.withOpacity(0.1),
                                    strokeWidth: 14,
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${(_progressAnim.value * 100).toStringAsFixed(1)}%',
                                          style: GoogleFonts.sora(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w900,
                                            color: textPrimary,
                                          ),
                                        ),
                                        Text('Complete',
                                            style: GoogleFonts.sora(
                                                fontSize: 11,
                                                color: textSec)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              WealthService.formatAmount(
                                  _goal.currentAmount),
                              style: GoogleFonts.sora(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary),
                            ),
                            Text(
                              'of ${WealthService.formatAmount(_goal.targetAmount)}',
                              style: GoogleFonts.sora(
                                  fontSize: 13, color: textSec),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 24),

                        // ── Timeline Grid ─────────────────────────
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              _timelineCell(
                                  'Started On',
                                  DateFormat('dd MMM yy')
                                      .format(_goal.createdAt),
                                  Icons.play_circle_outline_rounded,
                                  textPrimary,
                                  textSec),
                              _vDivider(border),
                              _timelineCell(
                                  'Target Date',
                                  DateFormat('dd MMM yy')
                                      .format(_goal.targetDate),
                                  Icons.flag_outlined,
                                  textPrimary,
                                  textSec),
                              _vDivider(border),
                              _timelineCell(
                                  'Elapsed',
                                  '$elapsed Months',
                                  Icons.timer_outlined,
                                  textPrimary,
                                  textSec),
                              _vDivider(border),
                              _timelineCell(
                                  'Remaining',
                                  '$remaining Months',
                                  Icons.hourglass_bottom_rounded,
                                  textPrimary,
                                  textSec),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Goal Status ───────────────────────────
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Goal Status',
                                      style: GoogleFonts.sora(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: health.color.withOpacity(0.12),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${health.emoji} ${health.label}',
                                      style: GoogleFonts.sora(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: health.color),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _goal.progress,
                                  minHeight: 6,
                                  backgroundColor: isWhite
                                      ? const Color(0xFFEEEEEE)
                                      : Colors.white.withOpacity(0.1),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                          health.color),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  _statusCell(
                                      'Expected',
                                      WealthService.formatAmount(expected),
                                      textSec,
                                      textPrimary),
                                  _statusCell(
                                      'Actual',
                                      WealthService.formatAmount(
                                          _goal.currentAmount),
                                      textSec,
                                      textPrimary),
                                  _statusCell(
                                      'Gap',
                                      WealthService.formatAmount(gapAmt),
                                      textSec,
                                      const Color(0xFFCC0020)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Monthly Plan ──────────────────────────
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Monthly Plan',
                                  style: GoogleFonts.sora(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary)),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(
                                    child: _planCell(
                                  'Required Monthly',
                                  WealthService.formatAmountFull(
                                      _goal.remaining / total),
                                  textSec,
                                  textPrimary,
                                )),
                                Expanded(
                                    child: _planCell(
                                  'You Need to Save',
                                  WealthService.formatAmountFull(monthly),
                                  textSec,
                                  const Color(0xFFCC0020),
                                )),
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── AI Wealth Coach ───────────────────────
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFCC0020).withOpacity(0.08),
                                const Color(0xFFCC0020).withOpacity(0.04),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFCC0020)
                                    .withOpacity(0.15)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCC0020)
                                      .withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Color(0xFFCC0020),
                                    size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('AI Wealth Coach',
                                        style: GoogleFonts.sora(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                const Color(0xFFCC0020))),
                                    const SizedBox(height: 4),
                                    Text(
                                      WealthService.coachMessage(_goal),
                                      style: GoogleFonts.sora(
                                          fontSize: 13, color: textPrimary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Contributions ─────────────────────────
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Recent Contributions',
                                style: GoogleFonts.sora(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary)),
                            if (_contributions.isNotEmpty)
                              Text('${_contributions.length} total',
                                  style: GoogleFonts.sora(
                                      fontSize: 12, color: textSec)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_contributions.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: border),
                            ),
                            child: Center(
                              child: Text('No contributions yet',
                                  style: GoogleFonts.sora(
                                      fontSize: 13, color: textSec)),
                            ),
                          )
                        else
                          ...(_contributions.map((c) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: border),
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: (c.amount >= 0
                                              ? const Color(0xFF22C55E)
                                              : const Color(0xFFCC0020))
                                          .withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                        c.amount >= 0
                                            ? Icons.arrow_upward_rounded
                                            : Icons.arrow_downward_rounded,
                                        color: c.amount >= 0
                                            ? const Color(0xFF22C55E)
                                            : const Color(0xFFCC0020),
                                        size: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.notes ??
                                                (c.amount >= 0
                                                    ? 'Credit'
                                                    : 'Debit'),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: GoogleFonts.sora(
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.w600,
                                                color: textPrimary),
                                          ),
                                          Text(
                                            DateFormat('dd MMM yyyy')
                                                .format(c.contributionDate),
                                            style: GoogleFonts.sora(
                                                fontSize: 11,
                                                color: textSec),
                                          ),
                                        ]),
                                  ),
                                  Text(
                                    '${c.amount >= 0 ? '+' : ''}${WealthService.formatAmount(c.amount)}',
                                    style: GoogleFonts.sora(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: c.amount >= 0
                                            ? const Color(0xFF22C55E)
                                            : const Color(0xFFCC0020)),
                                  ),
                                ]),
                              ))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddContribution,
        backgroundColor: const Color(0xFFCC0020),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Contribution',
            style: GoogleFonts.sora(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),
    ), // Scaffold
    ); // PopScope
  }

  Widget _timelineCell(String label, String value, IconData icon,
      Color textPrimary, Color textSec) {
    return Expanded(
      child: Column(children: [
        Icon(icon, size: 16, color: const Color(0xFFCC0020)),
        const SizedBox(height: 4),
        Text(label,
            style:
                GoogleFonts.sora(fontSize: 9, color: textSec),
            textAlign: TextAlign.center),
        const SizedBox(height: 3),
        Text(value,
            style: GoogleFonts.sora(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textPrimary),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _vDivider(Color border) => Container(
      width: 1, height: 40, color: border, margin: const EdgeInsets.symmetric(horizontal: 4));

  Widget _statusCell(
      String label, String value, Color textSec, Color valColor) {
    return Expanded(
      child: Column(children: [
        Text(label,
            style: GoogleFonts.sora(fontSize: 10, color: textSec),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.sora(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: valColor),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _planCell(
      String label, String value, Color textSec, Color valColor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.sora(fontSize: 11, color: textSec)),
      const SizedBox(height: 4),
      Text(value,
          style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valColor)),
    ]);
  }
}

// ─── Circular Progress Painter ────────────────────────────────────────────────

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color bgColor;
  final double strokeWidth;

  const _CircularProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.bgColor,
    this.strokeWidth = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    paint.color = bgColor;
    canvas.drawCircle(center, radius, paint);

    if (progress > 0) {
      paint.color = progressColor;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress.clamp(0.0, 1.0),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter old) =>
      old.progress != progress;
}
