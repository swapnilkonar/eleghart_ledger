import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/person_model.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';

class AddPersonScreen extends StatefulWidget {
  final PersonModel? existing;

  const AddPersonScreen({super.key, this.existing});

  @override
  State<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends State<AddPersonScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _photoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _phoneCtrl.text = e.phone ?? '';
      _addressCtrl.text = e.address ?? '';
      _notesCtrl.text = e.notes ?? '';
      _photoPath = e.photoPath;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF1A0505),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFFCC0020)),
              title: Text('Camera', style: GoogleFonts.sora()),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFCC0020)),
              title: Text('Gallery', style: GoogleFonts.sora()),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      final img = await ImagePicker().pickImage(source: result, imageQuality: 75);
      if (img != null) setState(() => _photoPath = img.path);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a name')));
      return;
    }
    setState(() => _saving = true);
    final all = await StorageService.loadPersons();
    if (widget.existing != null) {
      final idx = all.indexWhere((p) => p.id == widget.existing!.id);
      if (idx != -1) {
        all[idx] = widget.existing!.copyWith(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          photoPath: _photoPath,
        );
      }
    } else {
      all.add(PersonModel(
        id: const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        photoPath: _photoPath,
        createdAt: DateTime.now(),
      ));
    }
    await StorageService.savePersons(all);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite
        ? EleghartColors.accentDark.withValues(alpha: 0.55)
        : Colors.white54;
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
                _appBar(textPrimary),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _photoSection(isWhite, textSec),
                        const SizedBox(height: 24),
                        _label('Name *', textSec),
                        const SizedBox(height: 6),
                        _inputField(
                            controller: _nameCtrl,
                            hint: 'e.g. Rahul Sharma',
                            inputFill: inputFill,
                            border: border,
                            textPrimary: textPrimary,
                            textSec: textSec),
                        const SizedBox(height: 16),
                        _label('Phone Number', textSec),
                        const SizedBox(height: 6),
                        _inputField(
                            controller: _phoneCtrl,
                            hint: '9876543210',
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            inputFill: inputFill,
                            border: border,
                            textPrimary: textPrimary,
                            textSec: textSec),
                        const SizedBox(height: 16),
                        _label('Address (optional)', textSec),
                        const SizedBox(height: 6),
                        _inputField(
                            controller: _addressCtrl,
                            hint: 'Shop / flat address...',
                            maxLines: 2,
                            inputFill: inputFill,
                            border: border,
                            textPrimary: textPrimary,
                            textSec: textSec),
                        const SizedBox(height: 16),
                        _label('Notes (optional)', textSec),
                        const SizedBox(height: 6),
                        _inputField(
                            controller: _notesCtrl,
                            hint: 'Any note about this person...',
                            maxLines: 3,
                            inputFill: inputFill,
                            border: border,
                            textPrimary: textPrimary,
                            textSec: textSec),
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

  Widget _appBar(Color textPrimary) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            Text(
              widget.existing != null ? 'Edit Person' : 'Add Person',
              style: GoogleFonts.sora(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textPrimary),
            ),
          ],
        ),
      );

  Widget _photoSection(bool isWhite, Color textSec) => Center(
        child: GestureDetector(
          onTap: _pickPhoto,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor:
                    const Color(0xFFCC0020).withValues(alpha: 0.12),
                backgroundImage:
                    _photoPath != null ? FileImage(File(_photoPath!)) : null,
                child: _photoPath == null
                    ? const Icon(Icons.person_rounded,
                        color: Color(0xFFCC0020), size: 44)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                      color: Color(0xFFCC0020), shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ),
      );

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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      );

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
                  widget.existing != null ? 'Update Person' : 'Save Person',
                  style: GoogleFonts.sora(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
        ),
      );
}
