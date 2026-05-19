import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../services/pdf_export_service.dart';
import '../theme/eleghart_colors.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';


class ExportPdfScreen extends StatefulWidget {
  final GroupModel group;
  final List<ExpenseModel> allExpenses;

  const ExportPdfScreen({
    super.key,
    required this.group,
    required this.allExpenses,
  });

  @override
  State<ExportPdfScreen> createState() => _ExportPdfScreenState();
}

class _ExportPdfScreenState extends State<ExportPdfScreen> {
  late DateTime _fromDate;
  late DateTime _toDate;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _toDate = now;
    _fromDate = DateTime(now.year, now.month - 1, now.day);
  }

  // ---------------- DATE PICKERS ----------------

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: _toDate,
    );

    if (picked != null) {
      setState(() => _fromDate = picked);
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _toDate = picked);
    }
  }

  // ---------------- EXPORT ----------------
    Future<void> _exportPdf() async {
    final from = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final to = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);

    final filtered = widget.allExpenses.where((e) {
        return !e.date.isBefore(from) && !e.date.isAfter(to);
    }).toList();

    if (filtered.isEmpty) {
        _toast('No expenses found in selected range');
        return;
    }

    setState(() => _exporting = true);

    final file = await PdfExportService.exportGroupReport(
        group: widget.group,
        expenses: filtered,
        from: from,
        to: to,
    );

    if (!mounted) return;

    setState(() => _exporting = false);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF120404),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFCC0020).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFCC0020).withOpacity(0.4), width: 1),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded,
                  size: 26, color: Color(0xFFCC0020)),
            ),
            const SizedBox(height: 14),
            Text('PDF Exported Successfully',
                style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Text(
              file.path.split('/').last,
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(fontSize: 12, color: Colors.white38),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      OpenFilex.open(file.path);
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCC0020).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFCC0020).withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.open_in_new_rounded,
                              color: Color(0xFFCC0020), size: 16),
                          const SizedBox(width: 8),
                          Text('Open',
                              style: GoogleFonts.sora(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Share.shareXFiles([XFile(file.path)]),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.share_rounded,
                              color: Colors.white54, size: 16),
                          const SizedBox(width: 8),
                          Text('Share',
                              style: GoogleFonts.sora(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

    void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
    }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_theme_top_glow.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.72)),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── App bar ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFCC0020).withOpacity(0.6),
                              width: 1.5,
                            ),
                            color: const Color(0xFFCC0020).withOpacity(0.10),
                          ),
                          child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Export PDF',
                        style: GoogleFonts.sora(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Section header ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCC0020).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.calendar_month_rounded,
                            size: 18, color: Color(0xFFCC0020)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select Date Range',
                              style: GoogleFonts.sora(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          Text('Choose the period for your report',
                              style: GoogleFonts.sora(
                                  fontSize: 12, color: Colors.white38)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Date cards ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _dateCard(
                          label: 'From',
                          subLabel: 'Start date',
                          date: _fromDate,
                          onTap: _pickFromDate),
                      const SizedBox(height: 14),
                      _dateCard(
                          label: 'To',
                          subLabel: 'End date',
                          date: _toDate,
                          onTap: _pickToDate),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Export button ────────────────────────────────────────
                Padding(
                  padding:
                      EdgeInsets.fromLTRB(20, 8, 20, safeBottom + 16),
                  child: GestureDetector(
                    onTap: _exporting ? null : _exportPdf,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const RadialGradient(
                          center: Alignment.center,
                          radius: 0.9,
                          colors: [
                            Color(0xFFCC0020),
                            Color(0xFF6B0010),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFCC0020).withOpacity(0.5),
                            blurRadius: 22,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color:
                              const Color(0xFFFF2040).withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 6, left: 60, right: 60,
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                gradient: LinearGradient(colors: [
                                  Colors.transparent,
                                  Colors.white.withOpacity(0.22),
                                  Colors.transparent,
                                ]),
                              ),
                            ),
                          ),
                          _exporting
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white),
                                )
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                        Icons.picture_as_pdf_rounded,
                                        color: Colors.white, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Export PDF',
                                      style: GoogleFonts.sora(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
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

  Widget _dateCard({
    required String label,
    required String subLabel,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFFCC0020).withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFCC0020).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  size: 18, color: Color(0xFFCC0020)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.sora(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFCC0020),
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date.toString().split(' ')[0],
                    style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                  Text(
                    subLabel,
                    style: GoogleFonts.sora(
                        fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
            ),
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFCC0020).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_rounded,
                  size: 15, color: Color(0xFFCC0020)),
            ),
          ],
        ),
      ),
    );
  }
}
