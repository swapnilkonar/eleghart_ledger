import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';

/// Reusable "Expense Distribution" section widget.
///
/// - Shows only when [items].length > 1.
/// - Default mode: Equal Split.
/// - Custom mode: per-item amount fields with live validation.
/// - Calls [onChanged] with (distribution, isValid):
///     • distribution == null  → equal split (always valid)
///     • distribution != null  → custom map; isValid when sum == totalAmount
class ExpenseDistributionWidget extends StatefulWidget {
  final double totalAmount;
  final List<String> items;
  final Map<String, double>? initialDistribution;
  final void Function(Map<String, double>? distribution, bool isValid) onChanged;

  const ExpenseDistributionWidget({
    super.key,
    required this.totalAmount,
    required this.items,
    this.initialDistribution,
    required this.onChanged,
  });

  @override
  State<ExpenseDistributionWidget> createState() =>
      _ExpenseDistributionWidgetState();
}

class _ExpenseDistributionWidgetState
    extends State<ExpenseDistributionWidget> {
  bool _isCustom = false;
  final Map<String, TextEditingController> _ctrls = {};

  @override
  void initState() {
    super.initState();
    _isCustom = widget.initialDistribution != null;
    _initControllers(widget.items, widget.totalAmount, widget.initialDistribution);
  }

  @override
  void didUpdateWidget(ExpenseDistributionWidget old) {
    super.didUpdateWidget(old);

    final itemsChanged = !_listsEqual(old.items, widget.items);
    final amountChanged = old.totalAmount != widget.totalAmount;

    if (itemsChanged) {
      // Add controllers for new items
      for (final item in widget.items) {
        if (!_ctrls.containsKey(item)) {
          final share = widget.totalAmount > 0 && widget.items.isNotEmpty
              ? widget.totalAmount / widget.items.length
              : 0.0;
          _ctrls[item] = TextEditingController(
              text: share.toStringAsFixed(0))
            ..addListener(_onAmountChanged);
        }
      }
      // Remove controllers for items no longer in list
      final gone = _ctrls.keys
          .where((k) => !widget.items.contains(k))
          .toList();
      for (final k in gone) {
        _ctrls[k]!.dispose();
        _ctrls.remove(k);
      }
      if (widget.items.length <= 1) _isCustom = false;
      _notifyParent();
    } else if (amountChanged && !_isCustom) {
      _updateEqualAmounts(widget.totalAmount, widget.items);
    }
  }

  void _initControllers(
      List<String> items, double total, Map<String, double>? dist) {
    for (final item in items) {
      final val = dist?[item] ??
          (total > 0 && items.isNotEmpty ? total / items.length : 0.0);
      _ctrls[item] =
          TextEditingController(text: val.toStringAsFixed(0))
            ..addListener(_onAmountChanged);
    }
  }

  void _updateEqualAmounts(double total, List<String> items) {
    if (items.isEmpty) return;
    final share = total > 0 ? total / items.length : 0.0;
    for (final item in items) {
      _ctrls[item]?.text = share.toStringAsFixed(0);
    }
  }

  void _onAmountChanged() {
    if (!mounted) return;
    setState(() {});
    _notifyParent();
  }

  void _notifyParent() {
    if (!_isCustom) {
      widget.onChanged(null, true);
      return;
    }
    final dist = <String, double>{};
    for (final item in widget.items) {
      dist[item] = double.tryParse(_ctrls[item]?.text ?? '') ?? 0;
    }
    final sum = dist.values.fold(0.0, (a, b) => a + b);
    final valid = (sum - widget.totalAmount).abs() < 0.5;
    widget.onChanged(dist, valid);
  }

  double get _assigned => widget.items.fold(0.0, (s, item) {
        return s + (double.tryParse(_ctrls[item]?.text ?? '') ?? 0);
      });

  double get _remaining => widget.totalAmount - _assigned;

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.items.length <= 1) return const SizedBox.shrink();

    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary =
        isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite
        ? EleghartColors.accentDark.withOpacity(0.5)
        : Colors.white54;
    final cardBg =
        isWhite ? Colors.white : const Color(0xFF1A0505);
    final borderColor = isWhite
        ? const Color(0xFFEEEEEE)
        : Colors.white.withOpacity(0.09);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCC0020).withOpacity(0.30)),
        boxShadow: isWhite
            ? [
                BoxShadow(
                    color: const Color(0xFFCC0020).withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2))
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCC0020).withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pie_chart_outline_rounded,
                      color: Color(0xFFCC0020), size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  'Expense Distribution',
                  style: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textPrimary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCC0020).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _isCustom ? 'Custom' : 'Equal',
                    style: GoogleFonts.sora(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFCC0020)),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),

          // ── Mode Toggle ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                _modeChip('Equal Split', !_isCustom, () {
                  setState(() => _isCustom = false);
                  _updateEqualAmounts(widget.totalAmount, widget.items);
                  widget.onChanged(null, true);
                }, textPrimary),
                const SizedBox(width: 10),
                _modeChip('Custom Split', _isCustom, () {
                  setState(() => _isCustom = true);
                  _notifyParent();
                }, textPrimary),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Content ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _isCustom
                ? _buildCustom(textPrimary, textSec, cardBg, borderColor)
                : _buildEqual(textPrimary, textSec),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(
      String label, bool selected, VoidCallback onTap, Color textPrimary) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFCC0020)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFFCC0020)
                : Colors.grey.withOpacity(0.35),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.sora(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : textPrimary.withOpacity(0.55)),
        ),
      ),
    );
  }

  Widget _buildEqual(Color textPrimary, Color textSec) {
    if (widget.totalAmount <= 0) {
      return Text('Enter total amount first',
          style: GoogleFonts.sora(fontSize: 12, color: textSec));
    }
    final share = widget.totalAmount / widget.items.length;
    return Column(
      children: widget.items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  color: Color(0xFFCC0020), size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item,
                    style: GoogleFonts.sora(
                        fontSize: 13, color: textPrimary)),
              ),
              Text(
                '₹${share.toStringAsFixed(0)}',
                style: GoogleFonts.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustom(Color textPrimary, Color textSec, Color cardBg,
      Color borderColor) {
    final assigned = _assigned;
    final remaining = _remaining;
    final isValid = remaining.abs() < 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    color: Color(0xFFCC0020), size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item,
                      style: GoogleFonts.sora(
                          fontSize: 13, color: textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 120,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        Text('₹',
                            style: GoogleFonts.sora(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFCC0020))),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _ctrls[item],
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]'))
                            ],
                            style: GoogleFonts.sora(
                                fontSize: 13, color: textPrimary),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 10),
                              hintText: '0',
                              hintStyle: GoogleFonts.sora(
                                  fontSize: 13, color: textSec),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        // ── Validation strip ─────────────────────────────────────────
        const SizedBox(height: 2),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isValid
                ? const Color(0xFF00CC66).withOpacity(0.10)
                : const Color(0xFFCC0020).withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isValid
                  ? const Color(0xFF00CC66).withOpacity(0.35)
                  : const Color(0xFFCC0020).withOpacity(0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isValid
                    ? Icons.check_circle_outline_rounded
                    : Icons.warning_amber_rounded,
                size: 14,
                color: isValid
                    ? const Color(0xFF00CC66)
                    : const Color(0xFFCC0020),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  isValid
                      ? 'Assigned: ₹${assigned.toStringAsFixed(0)} ✓'
                      : remaining > 0
                          ? 'Assigned: ₹${assigned.toStringAsFixed(0)}   Remaining: ₹${remaining.toStringAsFixed(0)}'
                          : 'Assigned: ₹${assigned.toStringAsFixed(0)}   Over by: ₹${(-remaining).toStringAsFixed(0)}',
                  style: GoogleFonts.sora(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isValid
                        ? const Color(0xFF00CC66)
                        : const Color(0xFFCC0020),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
