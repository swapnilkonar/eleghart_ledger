import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/ledger_transaction_model.dart';
import '../models/person_model.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';

class AddUdhaarTransactionScreen extends StatefulWidget {
  final PersonModel person;
  final LedgerTransactionModel? existing;

  const AddUdhaarTransactionScreen({
    super.key,
    required this.person,
    this.existing,
  });

  @override
  State<AddUdhaarTransactionScreen> createState() =>
      _AddUdhaarTransactionScreenState();
}

class _AddUdhaarTransactionScreenState
    extends State<AddUdhaarTransactionScreen> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  UdhaarTransactionType _type = UdhaarTransactionType.collection;
  DateTime _date = DateTime.now();
  String? _attachmentPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _type = e.type;
      _amountCtrl.text = e.amount.toStringAsFixed(0);
      _descCtrl.text = e.description;
      _notesCtrl.text = e.notes ?? '';
      _date = e.transactionDate;
      _attachmentPath = e.attachmentPath;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFFCC0020),
            onPrimary: Colors.white,
            surface: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF1A0505),
            onSurface: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickAttachment() async {
    final isWhite = AppThemeNotifier.isWhite;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor:
          isWhite ? Colors.white : const Color(0xFF120404),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: isWhite
                    ? const Color(0xFFCC0020).withValues(alpha: 0.25)
                    : Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: Color(0xFFCC0020)),
              title: Text('Camera',
                  style: GoogleFonts.sora(
                      fontWeight: FontWeight.w600,
                      color: isWhite
                          ? EleghartColors.accentDark
                          : Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: Color(0xFFCC0020)),
              title: Text('Gallery',
                  style: GoogleFonts.sora(
                      fontWeight: FontWeight.w600,
                      color: isWhite
                          ? EleghartColors.accentDark
                          : Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final img = await ImagePicker()
        .pickImage(source: source, imageQuality: 75);
    if (img != null) setState(() => _attachmentPath = img.path);
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amountCtrl.text.trim());
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a description')));
      return;
    }
    setState(() => _saving = true);
    final all = await StorageService.loadUdhaarTransactions();
    if (widget.existing != null) {
      final idx = all.indexWhere((t) => t.id == widget.existing!.id);
      if (idx != -1) {
        all[idx] = LedgerTransactionModel(
          id: widget.existing!.id,
          personId: widget.person.id,
          type: _type,
          amount: amt,
          description: _descCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          attachmentPath: _attachmentPath,
          transactionDate: _date,
          createdAt: widget.existing!.createdAt,
        );
      }
    } else {
      all.add(LedgerTransactionModel(
        id: const Uuid().v4(),
        personId: widget.person.id,
        type: _type,
        amount: amt,
        description: _descCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        attachmentPath: _attachmentPath,
        transactionDate: _date,
        createdAt: DateTime.now(),
      ));
    }
    await StorageService.saveUdhaarTransactions(all);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite
        ? EleghartColors.accentDark.withValues(alpha: 0.55)
        : Colors.white54;
    final cardBg = isWhite ? Colors.white : const Color(0xFF120404);
    final border = isWhite
        ? const Color(0xFFEEEEEE)
        : Colors.white.withValues(alpha: 0.08);
    final inputFill = isWhite ? const Color(0xFFF8F8F8) : const Color(0xFF1A0505);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.88)),
          SafeArea(
            child: Column(
              children: [
                _appBar(textPrimary, textSec),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _typeSelector(isWhite, textPrimary, cardBg, border),
                        const SizedBox(height: 20),
                        _label('Amount', textSec),
                        const SizedBox(height: 6),
                        _inputField(
                          controller: _amountCtrl,
                          hint: '0',
                          prefix: '₹',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                          inputFill: inputFill,
                          border: border,
                          textPrimary: textPrimary,
                          textSec: textSec,
                        ),
                        const SizedBox(height: 16),
                        _label('Description', textSec),
                        const SizedBox(height: 6),
                        _inputField(
                          controller: _descCtrl,
                          hint: _type == UdhaarTransactionType.collection
                              ? 'e.g. Dinner paid for friend'
                              : 'e.g. Tea shop credit',
                          inputFill: inputFill,
                          border: border,
                          textPrimary: textPrimary,
                          textSec: textSec,
                        ),
                        const SizedBox(height: 16),
                        _label('Date', textSec),
                        const SizedBox(height: 6),
                        _dateTile(isWhite, textPrimary, textSec, cardBg, border),
                        const SizedBox(height: 16),
                        _label('Notes (optional)', textSec),
                        const SizedBox(height: 6),
                        _inputField(
                          controller: _notesCtrl,
                          hint: 'Any extra info...',
                          maxLines: 3,
                          inputFill: inputFill,
                          border: border,
                          textPrimary: textPrimary,
                          textSec: textSec,
                        ),
                        const SizedBox(height: 16),
                        _attachmentRow(isWhite, textPrimary, textSec, cardBg, border),
                        const SizedBox(height: 32),
                        _saveButton(),
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

  Widget _appBar(Color textPrimary, Color textSec) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.existing != null ? 'Edit Transaction' : 'Add Transaction',
                    style: GoogleFonts.sora(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textPrimary),
                  ),
                  Text(
                    widget.person.name,
                    style: GoogleFonts.sora(fontSize: 12, color: textSec),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _typeSelector(
      bool isWhite, Color textPrimary, Color cardBg, Color border) {
    final types = [
      (UdhaarTransactionType.collection, 'Collection', Icons.arrow_downward_rounded, const Color(0xFF22C55E)),
      (UdhaarTransactionType.payment, 'Payment', Icons.arrow_upward_rounded, const Color(0xFFCC0020)),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isWhite ? const Color(0xFFF0F0F0) : const Color(0xFF1A0505),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: types.map((t) {
          final sel = _type == t.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _type = t.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: sel ? t.$4.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: sel
                      ? Border.all(color: t.$4.withValues(alpha: 0.5))
                      : Border.all(color: Colors.transparent),
                ),
                child: Column(
                  children: [
                    Icon(t.$3, color: sel ? t.$4 : textPrimary.withValues(alpha: 0.4), size: 20),
                    const SizedBox(height: 4),
                    Text(
                      t.$2,
                      style: GoogleFonts.sora(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                          color: sel ? t.$4 : textPrimary.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _label(String text, Color textSec) => Text(
        text,
        style: GoogleFonts.sora(
            fontSize: 12, fontWeight: FontWeight.w600, color: textSec),
      );

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required Color inputFill,
    required Color border,
    required Color textPrimary,
    required Color textSec,
    String? prefix,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            if (prefix != null)
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Text(prefix,
                    style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFCC0020))),
              ),
            Expanded(
              child: TextField(
                controller: controller,
                style: GoogleFonts.sora(color: textPrimary, fontSize: 14),
                keyboardType: keyboardType,
                inputFormatters: inputFormatters,
                maxLines: maxLines,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: GoogleFonts.sora(color: textSec, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _dateTile(bool isWhite, Color textPrimary, Color textSec,
      Color cardBg, Color border) =>
      GestureDetector(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isWhite ? const Color(0xFFF8F8F8) : const Color(0xFF1A0505),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  color: const Color(0xFFCC0020), size: 18),
              const SizedBox(width: 10),
              Text(
                DateFormat('dd MMM yyyy').format(_date),
                style: GoogleFonts.sora(fontSize: 14, color: textPrimary),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: textSec, size: 18),
            ],
          ),
        ),
      );

  Widget _attachmentRow(bool isWhite, Color textPrimary, Color textSec,
      Color cardBg, Color border) {
    if (_attachmentPath != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_attachmentPath!),
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: () => setState(() => _attachmentPath = null),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ),
          Positioned(
            bottom: 8, left: 8,
            child: GestureDetector(
              onTap: _pickAttachment,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.edit_rounded,
                      color: Colors.white, size: 13),
                  const SizedBox(width: 4),
                  Text('Change',
                      style: GoogleFonts.sora(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _pickAttachment,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isWhite ? const Color(0xFFF8F8F8) : const Color(0xFF1A0505),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            const Icon(Icons.attach_file_rounded,
                color: Color(0xFFCC0020), size: 20),
            const SizedBox(width: 10),
            Text('Attach receipt (optional)',
                style: GoogleFonts.sora(fontSize: 13, color: textSec)),
          ],
        ),
      ),
    );
  }

  Widget _saveButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFCC0020),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(
                  widget.existing != null ? 'Update Transaction' : 'Save Transaction',
                  style: GoogleFonts.sora(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
        ),
      );
}
