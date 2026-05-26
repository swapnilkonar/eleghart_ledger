import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String? _selectedCategory;

  static const _categories = [
    ('Trips', Icons.airplanemode_active_rounded),
    ('Friends', Icons.groups_rounded),
    ('Family', Icons.home_rounded),
    ('Work', Icons.work_rounded),
    ('Others', Icons.category_rounded),
  ];

  bool get isEditMode => widget.existingGroup != null;

  @override
  void initState() {
    super.initState();
    AppThemeNotifier.instance.addListener(_onThemeChanged);

    // 👇 Pre-fill data when editing
    if (isEditMode) {
      _controller.text = widget.existingGroup!.name;
      if (widget.existingGroup!.categories.isNotEmpty) {
        _selectedCategory = widget.existingGroup!.categories.first;
      }
      if (widget.existingGroup!.imagePath != null) {
        _imageFile = File(widget.existingGroup!.imagePath!);
      }
    }
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_onThemeChanged);
    _controller.dispose();
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

    final picked = await picker.pickImage(source: source, imageQuality: 75);

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
      final index = groups.indexWhere((g) => g.id == widget.existingGroup!.id);

      if (index != -1) {
        groups[index] = GroupModel(
          id: widget.existingGroup!.id,
          name: name,
          imagePath: _imageFile?.path,
          categories: _selectedCategory != null
              ? [_selectedCategory!]
              : widget.existingGroup!.categories,
        );
      }
    } else {
      // ➕ CREATE NEW GROUP
      final newGroup = GroupModel(
        id: const Uuid().v4(),
        name: name,
        imagePath: _imageFile?.path,
        categories: _selectedCategory != null ? [_selectedCategory!] : [],
      );

      groups.add(newGroup);
    }

    await StorageService.saveGroups(groups);

    if (_selectedCategory != null) {
      final globalCategories = await StorageService.loadGlobalCategories();
      if (!globalCategories.contains(_selectedCategory!)) {
        globalCategories.add(_selectedCategory!);
        globalCategories.sort();
        await StorageService.saveGlobalCategories(globalCategories);
      }
    }

    if (!mounted) return;

    Navigator.pop(context, true); // 👈 refresh HomeDashboard
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final isNameEmpty = _controller.text.trim().isEmpty;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppThemeNotifier.isWhite ? Colors.white : Colors.black,
      body: Stack(
        children: [
          // Background
          Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.70)),

          SafeArea(
            child: Column(
              children: [
                // ── App Bar ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFCC0020).withOpacity(0.6),
                              width: 1.5,
                            ),
                            color: const Color(0xFFCC0020).withOpacity(0.10),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppThemeNotifier.isWhite
                                ? EleghartColors.accentDark
                                : Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditMode ? 'Edit Group' : 'Create Group',
                              style: GoogleFonts.sora(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppThemeNotifier.isWhite
                                    ? EleghartColors.accentDark
                                    : Colors.white,
                              ),
                            ),
                            Text(
                              isEditMode
                                  ? 'Update your financial space'
                                  : 'Create a new financial space',
                              style: GoogleFonts.sora(
                                fontSize: 12,
                                color: AppThemeNotifier.isWhite
                                    ? EleghartColors.accentDark.withOpacity(0.5)
                                    : Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Shield icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFCC0020).withOpacity(0.4),
                            width: 1,
                          ),
                          color: const Color(0xFFCC0020).withOpacity(0.08),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/icons/eleghart_icon.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable body ───────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── Photo Picker ────────────────────────────────
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer dashed ring
                              Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(
                                      0xFFCC0020,
                                    ).withOpacity(0.7),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFCC0020,
                                      ).withOpacity(0.18),
                                      blurRadius: 30,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              // Inner circle
                              ClipOval(
                                child: Container(
                                  width: 136,
                                  height: 136,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppThemeNotifier.isWhite
                                        ? Colors.white
                                        : const Color(0xFF1A0505),
                                    image: _imageFile != null
                                        ? DecorationImage(
                                            image: FileImage(_imageFile!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _imageFile == null
                                      ? Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            // Red gradient at bottom
                                            Container(
                                              height: 60,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.transparent,
                                                    const Color(
                                                      0xFFCC0020,
                                                    ).withOpacity(0.35),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : null,
                                ),
                              ),
                              // Camera icon
                              if (_imageFile == null)
                                Icon(
                                  Icons.camera_alt_rounded,
                                  color: const Color(0xFFCC0020),
                                  size: 36,
                                ),
                              // "+" badge
                              if (_imageFile == null)
                                Positioned(
                                  top: 28,
                                  right: 30,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFCC0020),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 13,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        Text(
                          isEditMode
                              ? 'Change group photo (optional)'
                              : 'Add a group photo (optional)',
                          style: GoogleFonts.sora(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppThemeNotifier.isWhite
                                ? EleghartColors.accentDark
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Give your group a unique identity',
                          style: GoogleFonts.sora(
                            fontSize: 12,
                            color: AppThemeNotifier.isWhite
                                ? EleghartColors.accentDark.withOpacity(0.5)
                                : Colors.white38,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── Group Name ──────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: AppThemeNotifier.isWhite
                                ? Colors.white
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppThemeNotifier.isWhite
                                  ? const Color(0xFFEEEEEE)
                                  : Colors.white.withOpacity(0.10),
                              width: 1,
                            ),
                            boxShadow: AppThemeNotifier.isWhite
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFCC0020,
                                      ).withOpacity(0.09),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              Icon(
                                Icons.group_rounded,
                                color: const Color(0xFFCC0020).withOpacity(0.8),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  textCapitalization: TextCapitalization.words,
                                  onChanged: (_) => setState(() {}),
                                  style: GoogleFonts.sora(
                                    fontSize: 14,
                                    color: AppThemeNotifier.isWhite
                                        ? EleghartColors.accentDark
                                        : Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Group name (e.g. Friends, Trip)',
                                    hintStyle: GoogleFonts.sora(
                                      fontSize: 14,
                                      color: AppThemeNotifier.isWhite
                                          ? EleghartColors.accentDark
                                                .withOpacity(0.35)
                                          : Colors.white30,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Category Selection ──────────────────────────
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Category',
                            style: GoogleFonts.sora(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppThemeNotifier.isWhite
                                  ? EleghartColors.accentDark.withOpacity(0.6)
                                  : Colors.white54,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: _categories.map((entry) {
                            final (label, icon) = entry;
                            final active = _selectedCategory == label;
                            return GestureDetector(
                              onTap: () => setState(() {
                                _selectedCategory = active ? null : label;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? const Color(0xFFCC0020)
                                      : (AppThemeNotifier.isWhite
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.07)),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: active
                                        ? Colors.transparent
                                        : (AppThemeNotifier.isWhite
                                              ? const Color(0xFFEEEEEE)
                                              : Colors.white.withOpacity(0.12)),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      icon,
                                      size: 14,
                                      color: active
                                          ? Colors.white
                                          : (AppThemeNotifier.isWhite
                                                ? EleghartColors.accentDark
                                                      .withOpacity(0.5)
                                                : Colors.white38),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      label,
                                      style: GoogleFonts.sora(
                                        fontSize: 13,
                                        fontWeight: active
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: active
                                            ? Colors.white
                                            : (AppThemeNotifier.isWhite
                                                  ? EleghartColors.accentDark
                                                        .withOpacity(0.6)
                                                  : Colors.white54),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Create Button (pinned at bottom) ──────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, safeBottom + 20),
                  child: GestureDetector(
                    onTap: _saving || isNameEmpty ? null : _saveGroup,
                    child: AnimatedOpacity(
                      opacity: isNameEmpty ? 0.45 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const RadialGradient(
                            center: Alignment.center,
                            radius: 0.9,
                            colors: [Color(0xFFCC0020), Color(0xFF6B0010)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFCC0020).withOpacity(0.55),
                              blurRadius: 22,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: const Color(0xFFCC0020).withOpacity(0.25),
                              blurRadius: 40,
                              spreadRadius: 4,
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFFFF2040).withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Light streak highlight
                            Positioned(
                              top: 6,
                              left: 60,
                              right: 60,
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.25),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Button content
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_saving)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  Icon(
                                    isEditMode
                                        ? Icons.check_rounded
                                        : Icons.group_add_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                const SizedBox(width: 10),
                                Text(
                                  _saving
                                      ? 'Saving...'
                                      : isEditMode
                                      ? 'Save Changes'
                                      : 'Create Group',
                                  style: GoogleFonts.sora(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
}
