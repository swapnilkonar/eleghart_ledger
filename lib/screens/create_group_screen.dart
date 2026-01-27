import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/group_model.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';

class CreateGroupScreen extends StatefulWidget {
  final GroupModel? existingGroup; // 👈 edit support

  const CreateGroupScreen({super.key, this.existingGroup});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _controller = TextEditingController();
  File? _imageFile;
  bool _saving = false;

  bool get isEditMode => widget.existingGroup != null;

  @override
  void initState() {
    super.initState();

    // 👇 Pre-fill data when editing
    if (isEditMode) {
      _controller.text = widget.existingGroup!.name;

      if (widget.existingGroup!.imagePath != null) {
        _imageFile = File(widget.existingGroup!.imagePath!);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose(); // ✅ memory safety
    super.dispose();
  }

  // ---------------- IMAGE PICKER ----------------

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(
      source: source,
      imageQuality: 75,
    );

    if (picked == null) return;

    setState(() {
      _imageFile = File(picked.path);
    });
  }

  // ---------------- SAVE / UPDATE GROUP ----------------

  Future<void> _saveGroup() async {
    if (_saving) return; // ✅ guard against double taps

    final name = _controller.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    setState(() => _saving = true);

    final groups = await StorageService.loadGroups();

    if (isEditMode) {
      // 🔁 UPDATE EXISTING GROUP
      final index =
          groups.indexWhere((g) => g.id == widget.existingGroup!.id);

      if (index != -1) {
        groups[index] = GroupModel(
          id: widget.existingGroup!.id,
          name: name,
          imagePath: _imageFile?.path,
          categories: widget.existingGroup!.categories,
        );
      }
    } else {
      // ➕ CREATE NEW GROUP
      final newGroup = GroupModel(
        id: const Uuid().v4(),
        name: name,
        imagePath: _imageFile?.path,
        categories: [],
      );

      groups.add(newGroup);
    }

    await StorageService.saveGroups(groups);

    if (!mounted) return;

    Navigator.pop(context, true); // 👈 refresh HomeDashboard
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final isNameEmpty = _controller.text.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Group' : 'Create Group'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),

            // ---- Avatar Picker ----
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: EleghartColors.divider,
                  backgroundImage:
                      _imageFile != null ? FileImage(_imageFile!) : null,
                  child: _imageFile == null
                      ? const Icon(
                          Icons.camera_alt,
                          size: 30,
                          color: EleghartColors.textSecondary,
                        )
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 14),

            Text(
              isEditMode
                  ? 'Change group photo (optional)'
                  : 'Add a group photo (optional)',
              style: const TextStyle(
                fontSize: 13.5,
                color: EleghartColors.textSecondary,
              ),
            ),

            const SizedBox(height: 28),

            // ---- Group Name ----
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}), // 👈 live button enable
              decoration: InputDecoration(
                hintText: 'Group name (e.g. Friends, Trip)',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 34),

            // ---- Create / Save Button ----
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed:
                    _saving || isNameEmpty ? null : _saveGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EleghartColors.accentDark,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isEditMode
                            ? 'Save Changes'
                            : 'Create Group',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
