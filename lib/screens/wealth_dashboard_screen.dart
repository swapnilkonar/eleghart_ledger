import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/wealth_models.dart';
import '../services/wealth_repository.dart';
import '../services/wealth_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';
import 'create_goal_screen.dart';
import 'goal_detail_screen.dart';

class WealthDashboardScreen extends StatefulWidget {
  const WealthDashboardScreen({super.key});

  @override
  State<WealthDashboardScreen> createState() =>
      _WealthDashboardScreenState();
}

class _WealthDashboardScreenState extends State<WealthDashboardScreen>
    with SingleTickerProviderStateMixin {
  List<WealthGoal> _goals = [];
  bool _loading = true;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _load();
  }

  Future<void> _load() async {
    final goals = await WealthRepository.loadGoals();
    if (mounted) {
      setState(() {
        _goals = goals;
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

  double get _totalTarget =>
      _goals.fold(0, (s, g) => s + g.targetAmount);
  double get _totalCurrent =>
      _goals.fold(0, (s, g) => s + g.currentAmount);
  double get _overallProgress =>
      _totalTarget > 0 ? (_totalCurrent / _totalTarget).clamp(0, 1) : 0;
  double get _avgProgress => _goals.isEmpty
      ? 0
      : _goals.fold(0.0, (s, g) => s + g.progressPercent) /
          _goals.length;
  int get _avgMonthsLeft => _goals.isEmpty
      ? 0
      : (_goals.fold(0, (s, g) => s + WealthService.remainingMonths(g)) /
              _goals.length)
          .round();

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

    return Scaffold(
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
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: textPrimary, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Wealth ',
                                    style: GoogleFonts.sora(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Journey',
                                    style: GoogleFonts.sora(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFCC0020),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text('Plan. Save. Achieve.',
                                style: GoogleFonts.sora(
                                    fontSize: 11, color: textSec)),
                          ],
                        ),
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
                        // ── Hero Summary Card ─────────────────────
                        _buildHeroCard(),
                        const SizedBox(height: 24),

                        // ── Goals Section ─────────────────────────
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Your Goals (${_goals.length})',
                              style: GoogleFonts.sora(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_goals.isEmpty)
                          _buildEmptyState(cardBg, border, textPrimary,
                              textSec)
                        else
                          ...(_goals.map((g) => _buildGoalCard(
                              g, cardBg, border, textPrimary, textSec))),

                        if (_goals.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          // ── AI Wealth Coach ───────────────────
                          _buildCoachBanner(cardBg, border, textPrimary,
                              textSec),
                          const SizedBox(height: 24),
                          // ── Wealth Summary ────────────────────
                          _buildSummaryStrip(
                              cardBg, border, textPrimary, textSec),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push<WealthGoal>(
            context,
            MaterialPageRoute(
                builder: (_) => const CreateGoalScreen()),
          );
          _load();
        },
        backgroundColor: const Color(0xFFCC0020),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _buildHeroCard() {
    final health = _goals.isEmpty
        ? GoalHealth.onTrack
        : WealthService.calculateHealth(_goals.first);
    final monthly = _goals.isEmpty
        ? 0.0
        : _goals.fold(
            0.0,
            (s, g) =>
                s + WealthService.calculateMonthlyRequired(g));

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (_, __) {
        final anim = CurvedAnimation(
            parent: _animCtrl, curve: Curves.easeOutCubic);
        final animProg = _overallProgress * anim.value;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5A000E), Color(0xFFCC0020)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFCC0020).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Goal Value',
                        style: GoogleFonts.sora(
                            fontSize: 11, color: Colors.white60)),
                    const SizedBox(height: 4),
                    Text(
                      WealthService.formatAmountFull(_totalTarget),
                      style: GoogleFonts.sora(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text('Current Wealth',
                        style: GoogleFonts.sora(
                            fontSize: 11, color: Colors.white60)),
                    const SizedBox(height: 2),
                    Text(
                      WealthService.formatAmountFull(_totalCurrent),
                      style: GoogleFonts.sora(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: health.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('Status',
                          style: GoogleFonts.sora(
                              fontSize: 10, color: Colors.white54)),
                      const SizedBox(width: 6),
                      Text(health.label,
                          style: GoogleFonts.sora(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: health.color)),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text('Need This Month',
                          style: GoogleFonts.sora(
                              fontSize: 10, color: Colors.white54)),
                      const SizedBox(width: 6),
                      Text(
                        WealthService.formatAmountFull(monthly),
                        style: GoogleFonts.sora(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 90,
                height: 90,
                child: CustomPaint(
                  painter: _CircularProgressPainter(
                    progress: animProg,
                    progressColor: Colors.white,
                    bgColor: Colors.white.withOpacity(0.2),
                    strokeWidth: 8,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(animProg * 100).toStringAsFixed(1)}%',
                          style: GoogleFonts.sora(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white),
                        ),
                        Text('Complete',
                            style: GoogleFonts.sora(
                                fontSize: 8, color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGoalCard(WealthGoal g, Color cardBg, Color border,
      Color textPrimary, Color textSec) {
    final health = WealthService.calculateHealth(g);
    final elapsed = WealthService.elapsedMonths(g);
    final total = WealthService.totalMonths(g);

    return GestureDetector(
      onTap: () async {
        await Navigator.push<WealthGoal>(
          context,
          MaterialPageRoute(
              builder: (_) => GoalDetailScreen(goal: g)),
        );
        _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: g.goalType.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(g.goalType.icon,
                      color: g.goalType.color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPrimary),
                      ),
                      Text(
                        '${WealthService.formatAmount(g.currentAmount)} / ${WealthService.formatAmountFull(g.targetAmount)}',
                        style: GoogleFonts.sora(
                            fontSize: 12, color: textSec),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: textSec, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: g.progress,
                minHeight: 5,
                backgroundColor: AppThemeNotifier.isWhite
                    ? const Color(0xFFEEEEEE)
                    : Colors.white.withOpacity(0.1),
                valueColor:
                    AlwaysStoppedAnimation<Color>(health.color),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Month ${(elapsed + 1).clamp(1, total)} of $total',
                  style:
                      GoogleFonts.sora(fontSize: 11, color: textSec),
                ),
                Row(children: [
                  Text(
                    '${g.progressPercent.toStringAsFixed(1)}%',
                    style: GoogleFonts.sora(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: health.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      health.label,
                      style: GoogleFonts.sora(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: health.color),
                    ),
                  ),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachBanner(Color cardBg, Color border, Color textPrimary,
      Color textSec) {
    if (_goals.isEmpty) return const SizedBox.shrink();
    final worst = _goals.reduce((a, b) =>
        WealthService.calculateHealth(a).index >
                WealthService.calculateHealth(b).index
            ? a
            : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFCC0020).withOpacity(0.08),
            const Color(0xFFCC0020).withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFCC0020).withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFCC0020).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFFCC0020), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Wealth Coach',
                    style: GoogleFonts.sora(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFCC0020))),
                const SizedBox(height: 4),
                Text(
                  WealthService.coachMessage(worst),
                  style:
                      GoogleFonts.sora(fontSize: 13, color: textPrimary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: textSec, size: 18),
        ],
      ),
    );
  }

  Widget _buildSummaryStrip(Color cardBg, Color border, Color textPrimary,
      Color textSec) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _summaryCell('${_goals.length}', 'Active Goals',
              Icons.track_changes_rounded, textPrimary, textSec),
          _summaryCell(
              WealthService.formatAmount(_totalCurrent),
              'Total Saved',
              Icons.savings_rounded,
              textPrimary,
              textSec),
          _summaryCell(
              '${_avgProgress.toStringAsFixed(1)}%',
              'Avg Progress',
              Icons.trending_up_rounded,
              textPrimary,
              textSec),
          _summaryCell('$_avgMonthsLeft', 'Months Left',
              Icons.hourglass_bottom_rounded, textPrimary, textSec),
        ],
      ),
    );
  }

  Widget _summaryCell(String value, String label, IconData icon,
      Color textPrimary, Color textSec) {
    return Expanded(
      child: Column(children: [
        Icon(icon, size: 18, color: const Color(0xFFCC0020)),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.sora(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(label,
            style: GoogleFonts.sora(fontSize: 9, color: textSec),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildEmptyState(Color cardBg, Color border, Color textPrimary,
      Color textSec) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFCC0020).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.track_changes_rounded,
              color: Color(0xFFCC0020), size: 30),
        ),
        const SizedBox(height: 16),
        Text('No Goals Yet',
            style: GoogleFonts.sora(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textPrimary)),
        const SizedBox(height: 6),
        Text('Tap + to set your first financial goal',
            style: GoogleFonts.sora(fontSize: 13, color: textSec),
            textAlign: TextAlign.center),
      ]),
    );
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
    this.strokeWidth = 10,
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
