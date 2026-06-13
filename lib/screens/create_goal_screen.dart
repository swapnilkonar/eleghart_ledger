import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/wealth_models.dart';
import '../services/wealth_repository.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';

class CreateGoalScreen extends StatefulWidget {
  final WealthGoal? goal;
  const CreateGoalScreen({super.key, this.goal});

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  GoalType _selectedType = GoalType.house;
  DateTime _targetDate = DateTime.now().add(const Duration(days: 365 * 3));
  bool _saving = false;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    if (g != null) {
      _nameCtrl.text = g.name;
      _targetCtrl.text = g.targetAmount.toStringAsFixed(0);
      _startCtrl.text = g.startAmount.toStringAsFixed(0);
      _notesCtrl.text = g.notes ?? '';
      _selectedType = g.goalType;
      _targetDate = g.targetDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _startCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now().add(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFCC0020),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final WealthGoal goal;
      if (_isEditing) {
        final orig = widget.goal!;
        goal = WealthGoal(
          id: orig.id,
          name: _nameCtrl.text.trim(),
          goalType: _selectedType,
          targetAmount: double.parse(_targetCtrl.text.replaceAll(',', '')),
          currentAmount: orig.currentAmount,
          startAmount: orig.startAmount,
          targetDate: _targetDate,
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
          createdAt: orig.createdAt,
        );
        await WealthRepository.updateGoal(goal);
      } else {
        final startAmt =
            double.tryParse(_startCtrl.text.replaceAll(',', '')) ?? 0;
        goal = WealthGoal(
          id: WealthRepository.generateId(),
          name: _nameCtrl.text.trim(),
          goalType: _selectedType,
          targetAmount: double.parse(_targetCtrl.text.replaceAll(',', '')),
          currentAmount: startAmt,
          startAmount: startAmt,
          targetDate: _targetDate,
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
          createdAt: DateTime.now(),
        );
        await WealthRepository.insertGoal(goal);
      }
      if (mounted) Navigator.pop(context, goal);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving goal: $e'),
              backgroundColor: const Color(0xFFCC0020)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec =
        isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white54;
    final cardBg = isWhite ? Colors.white : const Color(0xFF120404);
    final inputFill =
        isWhite ? const Color(0xFFF5F5F5) : const Color(0xFF1A0505);

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
                        child: Text(
                          _isEditing ? 'Edit Goal' : 'New Goal',
                          style: GoogleFonts.sora(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                      children: [
                        // ── Goal Type Picker ─────────────────────
                        Text('Goal Type',
                            style: GoogleFonts.sora(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textPrimary)),
                        const SizedBox(height: 12),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.85,
                          children: GoalType.values.map((type) {
                            final sel = _selectedType == type;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedType = type),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? type.color.withOpacity(0.15)
                                      : (isWhite
                                          ? const Color(0xFFF8F8F8)
                                          : Colors.white
                                              .withOpacity(0.05)),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: sel
                                        ? type.color
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(type.icon,
                                        color: sel
                                            ? type.color
                                            : textSec,
                                        size: 22),
                                    const SizedBox(height: 6),
                                    Text(
                                      type.label,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.sora(
                                        fontSize: 9,
                                        fontWeight: sel
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: sel ? type.color : textSec,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // ── Fields ───────────────────────────────
                        _label('Goal Name', textPrimary),
                        const SizedBox(height: 8),
                        _field(
                          controller: _nameCtrl,
                          hint: 'e.g. House Fund, Emergency Fund',
                          fill: inputFill,
                          textPrimary: textPrimary,
                          textSec: textSec,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Enter a goal name'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        _label('Target Amount (₹)', textPrimary),
                        const SizedBox(height: 8),
                        _field(
                          controller: _targetCtrl,
                          hint: 'e.g. 1000000',
                          fill: inputFill,
                          textPrimary: textPrimary,
                          textSec: textSec,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Enter target amount';
                            }
                            final n =
                                double.tryParse(v.replaceAll(',', ''));
                            if (n == null || n <= 0) {
                              return 'Enter a valid amount';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        if (!_isEditing) ...[
                          _label('Starting Amount (₹)', textPrimary),
                          const SizedBox(height: 8),
                          _field(
                            controller: _startCtrl,
                            hint: 'Already saved (0 if starting fresh)',
                            fill: inputFill,
                            textPrimary: textPrimary,
                            textSec: textSec,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            validator: (v) => null,
                          ),
                          const SizedBox(height: 16),
                        ],

                        _label('Target Date', textPrimary),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: inputFill,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: isWhite
                                      ? const Color(0xFFEEEEEE)
                                      : Colors.white.withOpacity(0.08)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded,
                                    size: 16,
                                    color: const Color(0xFFCC0020)),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat('dd MMM yyyy')
                                      .format(_targetDate),
                                  style: GoogleFonts.sora(
                                      fontSize: 14, color: textPrimary),
                                ),
                                const Spacer(),
                                Icon(Icons.chevron_right_rounded,
                                    color: textSec, size: 18),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        _label('Notes (optional)', textPrimary),
                        const SizedBox(height: 8),
                        _field(
                          controller: _notesCtrl,
                          hint: 'e.g. My dream home 🏠',
                          fill: inputFill,
                          textPrimary: textPrimary,
                          textSec: textSec,
                          maxLines: 3,
                          validator: (v) => null,
                        ),
                        const SizedBox(height: 32),

                        // ── Save Button ───────────────────────────
                        GestureDetector(
                          onTap: _saving ? null : _save,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF7A0010),
                                  Color(0xFFCC0020)
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFCC0020)
                                      .withOpacity(0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                )
                              ],
                            ),
                            child: Center(
                              child: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2),
                                    )
                                  : Text(
                                      _isEditing
                                          ? 'Save Changes'
                                          : 'Create Goal',
                                      style: GoogleFonts.sora(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
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

  Widget _label(String text, Color color) => Text(
        text,
        style: GoogleFonts.sora(
            fontSize: 13, fontWeight: FontWeight.w600, color: color),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required Color fill,
    required Color textPrimary,
    required Color textSec,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      style: GoogleFonts.sora(fontSize: 14, color: textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.sora(fontSize: 13, color: textSec),
        filled: true,
        fillColor: fill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: AppThemeNotifier.isWhite
                  ? const Color(0xFFEEEEEE)
                  : Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFCC0020), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFCC0020), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFCC0020), width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}
