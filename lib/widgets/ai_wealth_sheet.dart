import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../models/wealth_models.dart';
import '../services/ai_wealth_service.dart';
import '../services/wealth_repository.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../utils/data_sync.dart';

class AIWealthSheet extends StatefulWidget {
  final List<WealthGoal> goals;

  const AIWealthSheet({super.key, required this.goals});

  @override
  State<AIWealthSheet> createState() => _AIWealthSheetState();
}

class _AIWealthSheetState extends State<AIWealthSheet> {
  final _inputCtrl = TextEditingController();
  WealthAIAction? _parsedAction;
  bool _thinking = false;
  String? _error;

  static const _uuid = Uuid();

  final List<String> _quickPrompts = [
    '🚗 Save ₹5,00,000 for New Car in 2 years',
    '💰 Add ₹10,000 savings to Emergency Fund',
    '🏖️ Save ₹50,000 for Goa Trip in 6 months',
  ];

  void _analyzePrompt(String text) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _thinking = true;
      _parsedAction = null;
      _error = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    final action = await AIWealthService.parsePrompt(text, widget.goals);

    if (mounted) {
      setState(() {
        _thinking = false;
        if (action == null) {
          _error = 'AI could not recognize wealth action. Try saying "Save ₹50,000 for New Phone" or "Add 5000 to Emergency Fund".';
        } else {
          _parsedAction = action;
        }
      });
    }
  }

  Future<void> _executeAction() async {
    if (_parsedAction == null) return;
    final act = _parsedAction!;

    try {
      if (act.action == 'CREATE') {
        final now = DateTime.now();
        final targetDate = DateTime(now.year, now.month + act.months, now.day);
        final newGoal = WealthGoal(
          id: _uuid.v4(),
          name: act.title,
          goalType: GoalType.custom,
          targetAmount: act.targetAmount,
          currentAmount: 0,
          startAmount: 0,
          targetDate: targetDate,
          createdAt: now,
        );
        await WealthRepository.insertGoal(newGoal);
      } else if (act.action == 'ADD_SAVINGS' && act.goalId != null) {
        final targetGoal = widget.goals.firstWhere((g) => g.id == act.goalId);
        await WealthRepository.addContribution(
          goal: targetGoal,
          amount: act.amount,
          date: DateTime.now(),
          notes: 'Added via Eleghart AI',
        );
      } else if (act.action == 'DELETE' && act.goalId != null) {
        await WealthRepository.deleteGoal(act.goalId!);
      }

      DataSyncNotifier.notifyDataChanged();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00CC66),
            content: Text(
              '✨ AI Goal action executed successfully!',
              style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to execute: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final bg = isWhite ? Colors.white : const Color(0xFF140505);
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite ? Colors.black54 : Colors.white54;
    final cardBg = isWhite ? const Color(0xFFF8F9FA) : const Color(0xFF1F0808);
    final border = isWhite ? const Color(0xFFEEEEEE) : const Color(0xFFCC0020).withOpacity(0.2);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFCC0020).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFCC0020), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Eleghart AI Wealth Architect', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                    Text('Natural language goal creation & updates', style: GoogleFonts.sora(fontSize: 11, color: textSec)),
                  ],
                ),
              ),
              IconButton(icon: Icon(Icons.close_rounded, color: textSec), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),

          // Input field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  style: GoogleFonts.sora(fontSize: 14, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. Save ₹50,000 for New Phone in 6 months',
                    hintStyle: GoogleFonts.sora(fontSize: 12, color: textSec),
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCC0020))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: _analyzePrompt,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _analyzePrompt(_inputCtrl.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0020),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quick Prompts
          if (_parsedAction == null && !_thinking) ...[
            Text('Quick AI Prompts:', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: textSec)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quickPrompts.map((qp) {
                return ActionChip(
                  label: Text(qp, style: GoogleFonts.sora(fontSize: 11, color: textPrimary)),
                  backgroundColor: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: border)),
                  onPressed: () {
                    _inputCtrl.text = qp.substring(3);
                    _analyzePrompt(qp.substring(3));
                  },
                );
              }).toList(),
            ),
          ],

          if (_thinking) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator(color: Color(0xFFCC0020))),
          ],

          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFCC0020).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFCC0020), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: GoogleFonts.sora(fontSize: 12, color: const Color(0xFFCC0020)))),
                ],
              ),
            ),
          ],

          // Confirmation Card
          if (_parsedAction != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCC0020), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _parsedAction!.action == 'DELETE' ? const Color(0xFFCC0020) : const Color(0xFF00CC66),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _parsedAction!.action == 'CREATE'
                              ? 'PROPOSED: NEW GOAL'
                              : _parsedAction!.action == 'ADD_SAVINGS'
                                  ? 'PROPOSED: ADD SAVINGS'
                                  : 'PROPOSED: DELETE GOAL',
                          style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                      const Spacer(),
                      Text('Human-in-the-Loop AI', style: GoogleFonts.sora(fontSize: 10, color: textSec)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_parsedAction!.title, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                  const SizedBox(height: 6),
                  if (_parsedAction!.action == 'CREATE') ...[
                    Text('Target Amount: ₹${_parsedAction!.targetAmount.toStringAsFixed(0)}', style: GoogleFonts.sora(fontSize: 13, color: textPrimary)),
                    Text('Target Period: ${_parsedAction!.months} months (₹${(_parsedAction!.targetAmount / _parsedAction!.months).toStringAsFixed(0)}/mo)', style: GoogleFonts.sora(fontSize: 12, color: textSec)),
                  ] else if (_parsedAction!.action == 'ADD_SAVINGS') ...[
                    Text('Add Savings Amount: ₹${_parsedAction!.amount.toStringAsFixed(0)}', style: GoogleFonts.sora(fontSize: 13, color: const Color(0xFF00CC66), fontWeight: FontWeight.w600)),
                  ] else if (_parsedAction!.action == 'DELETE') ...[
                    Text('Goal will be permanently removed from your Wealth Journey.', style: GoogleFonts.sora(fontSize: 12, color: const Color(0xFFCC0020))),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _executeAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _parsedAction!.action == 'DELETE' ? const Color(0xFFCC0020) : const Color(0xFF00CC66),
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _parsedAction!.action == 'CREATE'
                          ? '✨ Confirm & Create Goal'
                          : _parsedAction!.action == 'ADD_SAVINGS'
                              ? '✨ Confirm & Add Savings'
                              : '⚠️ Confirm & Delete Goal',
                      style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
