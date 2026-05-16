import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/group_model.dart';
import '../services/storage_service.dart';
import '../theme/eleghart_colors.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isEditMode ? 'Edit Group' : 'Create Group',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: EleghartColors.textPrimary,
      ),
      body: Stack(
        children: [
          // Floating background effects
          Positioned(
            top: -80,
            right: -80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(150),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      EleghartColors.accentDark.withOpacity(0.06),
                      EleghartColors.accentLight.withOpacity(0.02),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(120),
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.blue.withOpacity(0.03),
                      Colors.cyan.withOpacity(0.02),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Main content
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // ---- Animated Avatar Picker ----
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Opacity(
                      opacity: value,
                      child: Transform.scale(
                        scale: 0.6 + (value * 0.4),
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.15),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: EleghartColors.accentDark.withOpacity(0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (_imageFile != null)
                                      Image.file(
                                        _imageFile!,
                                        fit: BoxFit.cover,
                                        width: 120,
                                        height: 120,
                                      )
                                    else
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.camera_alt,
                                            size: 40,
                                            color: EleghartColors.accentDark,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tap to add',
                                            style: GlassTheme.bodySmall.copyWith(
                                              color: EleghartColors.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (_imageFile != null)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: EleghartColors.accentDark,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    },
                  ),

                const SizedBox(height: 18),

                Text(
                  isEditMode
                      ? 'Change group photo (optional)'
                      : 'Add a group photo (optional)',
                  style: GlassTheme.bodySmall.copyWith(
                    color: EleghartColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 36),

                // ---- Group Name Glass Input ----
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white.withOpacity(0.15),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: TextField(
                                controller: _controller,
                                textCapitalization: TextCapitalization.words,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Group name (e.g. Friends, Trip)',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(
                                    color: EleghartColors.textHint.withOpacity(0.6),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                style: const TextStyle(
                                  color: EleghartColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    },
                  ),

                const SizedBox(height: 40),

                // ---- Create / Save Button ----
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Transform.scale(
                      scale: 0.8 + (value * 0.2),
                      alignment: Alignment.center,
                      child: Opacity(
                        opacity: value,
                        child: SizedBox(
                          width: double.infinity,
                          child: GlassButton(
                            label: isEditMode ? 'Save Changes' : 'Create Group',
                            icon: isEditMode ? Icons.save : Icons.add,
                            onPressed: _saving || isNameEmpty ? () {} : _saveGroup,
                            isLoading: _saving,
                            borderRadius: 20,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
