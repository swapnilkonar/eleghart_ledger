// ProfileSheet — Clean UI + Inline Validation + Eleghart Theme
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/eleghart_colors.dart';

class ProfileSheet extends StatefulWidget {
  final VoidCallback onUpdated;
  const ProfileSheet({super.key, required this.onUpdated});

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  final _nameController = TextEditingController();
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  String? _storedPin;
  File? _avatar;
  bool _saving = false;

  // ---- INLINE ERRORS ----
  String? _nameError;
  String? _oldPinError;
  String? _newPinError;
  String? _confirmPinError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController.text = prefs.getString('user_name') ?? '';
    _storedPin = prefs.getString('user_pin');

    final avatarPath = prefs.getString('user_avatar_path');
    if (avatarPath != null && File(avatarPath).existsSync()) {
      _avatar = File(avatarPath);
    }

    setState(() {});
  }

  // 🔹 UPDATED: generic picker
  Future<void> _pickAvatar(ImageSource source) async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: source, imageQuality: 80);

    if (picked == null) return;

    setState(() => _avatar = File(picked.path));
  }

  // 🔹 NEW: bottom sheet chooser
  Future<void> _showAvatarPicker() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  bool _isValidPin(String pin) {
    return RegExp(r'^\d{4}$').hasMatch(pin);
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final oldPin = _oldPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    // ---- RESET ERRORS ----
    setState(() {
      _nameError = null;
      _oldPinError = null;
      _newPinError = null;
      _confirmPinError = null;
    });

    bool hasError = false;

    // ---- NAME VALIDATION ----
    if (name.isEmpty) {
      _nameError = 'Name cannot be empty';
      hasError = true;
    }

    // ---- PIN CHANGE VALIDATION ----
    final wantsPinChange =
        oldPin.isNotEmpty || newPin.isNotEmpty || confirmPin.isNotEmpty;

    if (wantsPinChange) {
      if (oldPin.isEmpty) {
        _oldPinError = 'Enter your old PIN';
        hasError = true;
      } else if (oldPin != _storedPin) {
        _oldPinError = 'Old PIN is incorrect';
        hasError = true;
      }

      if (!_isValidPin(newPin)) {
        _newPinError = 'New PIN must be exactly 4 digits';
        hasError = true;
      }

      if (confirmPin != newPin) {
        _confirmPinError = 'PINs do not match';
        hasError = true;
      }
    }

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);

    if (wantsPinChange) {
      await prefs.setString('user_pin', newPin);
    }

    if (_avatar != null) {
      await prefs.setString('user_avatar_path', _avatar!.path);
    }

    widget.onUpdated();

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- HEADER ----
              Row(
                children: [
                  const Text(
                    'Profile',
                    style:
                        TextStyle(fontSize: 18.5, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ---- AVATAR ----
              Center(
                child: GestureDetector(
                  onTap: _showAvatarPicker, // 🔹 only changed line
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: EleghartColors.accentDark,
                        backgroundImage:
                            _avatar != null ? FileImage(_avatar!) : null,
                        child: _avatar == null
                            ? const Icon(Icons.person,
                                color: Colors.white, size: 38)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: EleghartColors.accentDark,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ---- NAME FIELD ----
              _sectionTitle('Name'),
              _outlinedField(
                controller: _nameController,
                hint: 'Enter your name',
                error: _nameError,
              ),

              const SizedBox(height: 18),

              // ---- CHANGE PIN ----
              _sectionTitle('Change PIN'),

              _pinField(
                label: 'Old PIN',
                controller: _oldPinController,
                error: _oldPinError,
              ),
              const SizedBox(height: 12),

              _pinField(
                label: 'New PIN',
                controller: _newPinController,
                error: _newPinError,
              ),
              const SizedBox(height: 12),

              _pinField(
                label: 'Confirm PIN',
                controller: _confirmPinController,
                error: _confirmPinError,
              ),

              const SizedBox(height: 26),

              // ---- SAVE BUTTON ----
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EleghartColors.accentDark,
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.4),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- UI HELPERS ----------------

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
          color: EleghartColors.textPrimary,
        ),
      ),
    );
  }

  Widget _outlinedField({
    required TextEditingController controller,
    required String hint,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          style: const TextStyle(
            color: EleghartColors.textPrimary,
            fontSize: 15.5,
          ),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: error != null
                    ? Colors.redAccent
                    : EleghartColors.textSecondary.withOpacity(0.25),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: EleghartColors.accentDark,
                width: 2,
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _pinField({
    required String label,
    required TextEditingController controller,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: EleghartColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            letterSpacing: 12,
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            hintText: '• • • •',
            hintStyle: const TextStyle(
              letterSpacing: 12,
              color: EleghartColors.textHint,
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: error != null
                    ? Colors.redAccent
                    : EleghartColors.accentDark,
                width: 1.6,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: error != null
                    ? Colors.redAccent
                    : EleghartColors.accentDark,
                width: 2.2,
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
