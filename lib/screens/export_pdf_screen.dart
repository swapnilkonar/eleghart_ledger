import 'package:flutter/material.dart';
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

    try {
      final file = await PdfExportService.exportGroupReport(
          group: widget.group,
          expenses: filtered,
          from: from,
          to: to,
      );

      if (!mounted) return;

      setState(() => _exporting = false);

    // 👇 SHOW OPEN + SHARE UI INSTEAD OF JUST TOAST
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            const Icon(
                Icons.picture_as_pdf,
                size: 48,
                color: EleghartColors.accentDark,
            ),
            const SizedBox(height: 12),

            const Text(
                'PDF Exported Successfully',
                style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                ),
            ),

            const SizedBox(height: 8),

            Text(
                'Saved to:\n${file.path}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                fontSize: 12.5,
                color: EleghartColors.textSecondary,
                ),
            ),

            const SizedBox(height: 20),

            Row(
                children: [
                // ---- OPEN ----
                Expanded(
                    child: ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: EleghartColors.accentDark,
                        foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                        OpenFilex.open(file.path);
                        Navigator.pop(context); // close bottom sheet
                        Navigator.pop(context); // back to GroupDetailScreen
                    },
                    ),
                ),

                const SizedBox(width: 12),

                // ---- SHARE ----
                Expanded(
                    child: OutlinedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    onPressed: () {
                        Share.shareXFiles([XFile(file.path)]);
                    },
                    ),
                ),
                ],
            ),

            const SizedBox(height: 12),
            ],
        ),
        ),
    );
    } catch (e) {
      if (!mounted) return;
      setState(() => _exporting = false);
      _toast('Export failed: ${e.toString()}');
    }
    }

    void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
    }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export PDF'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Date Range',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 18),

            _dateCard(
              label: 'From',
              date: _fromDate,
              onTap: _pickFromDate,
            ),

            const SizedBox(height: 14),

            _dateCard(
              label: 'To',
              date: _toDate,
              onTap: _pickToDate,
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _exporting ? null : _exportPdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EleghartColors.accentDark,
                  foregroundColor: Colors.white, // 👈 white text as requested
                  elevation: 10,
                  shadowColor: Colors.black38,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: _exporting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(
                  _exporting ? 'Exporting…' : 'Export PDF',
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateCard({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                size: 20, color: EleghartColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$label: ${date.toString().split(' ')[0]}',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.edit, size: 18),
          ],
        ),
      ),
    );
  }
}
