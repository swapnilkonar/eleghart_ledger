// ProfileSheet — Clean UI + Inline Validation + Eleghart Theme
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';

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
    return SafeArea(
      child: Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            Responsive.width(context, 0.06),
            Responsive.height(context, 0.02),
            Responsive.width(context, 0.06),
            Responsive.height(context, 0.025)
          ),
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
                    Text(
                      'Profile',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: Responsive.text(context, 18.5),
                        fontWeight: FontWeight.w800
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, size: Responsive.icon(context, 24)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                SizedBox(height: Responsive.height(context, 0.012)),

                // ---- AVATAR ----
                Center(
                  child: GestureDetector(
                    onTap: _showAvatarPicker, // 🔹 only changed line
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: Responsive.width(context, 0.12),
                          backgroundColor: EleghartColors.accentDark,
                          backgroundImage:
                              _avatar != null ? FileImage(_avatar!) : null,
                          child: _avatar == null
                              ? Icon(Icons.person,
                                  color: Colors.white, size: Responsive.icon(context, 38))
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(Responsive.width(context, 0.015)),
                            decoration: const BoxDecoration(
                              color: EleghartColors.accentDark,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.camera_alt,
                                size: Responsive.icon(context, 14), color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: Responsive.height(context, 0.012)),

                // ---- THEME TOGGLE ----
                ValueListenableBuilder<bool>(
                  valueListenable: AppThemeNotifier.instance,
                  builder: (_, isWhite, __) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'White Theme',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: Responsive.text(context, 14.5),
                        fontWeight: FontWeight.w700,
                        color: EleghartColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      isWhite ? 'Light background enabled' : 'Dark background enabled',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: Responsive.text(context, 12.5),
                        color: EleghartColors.textSecondary,
                      ),
                    ),
                    value: isWhite,
                    activeColor: EleghartColors.accentDark,
                    onChanged: (_) => AppThemeNotifier.toggle(),
                  ),
                ),

                SizedBox(height: Responsive.height(context, 0.01)),

                // ---- NAME FIELD ----
                _sectionTitle('Name'),
                _outlinedField(
                  controller: _nameController,
                  hint: 'Enter your name',
                  error: _nameError,
                ),

                SizedBox(height: Responsive.height(context, 0.022)),

                // ---- CHANGE PIN ----
                _sectionTitle('Change PIN'),

                _pinField(
                  label: 'Old PIN',
                  controller: _oldPinController,
                  error: _oldPinError,
                ),
                SizedBox(height: Responsive.height(context, 0.015)),

                _pinField(
                  label: 'New PIN',
                  controller: _newPinController,
                  error: _newPinError,
                ),
                SizedBox(height: Responsive.height(context, 0.015)),

                _pinField(
                  label: 'Confirm PIN',
                  controller: _confirmPinController,
                  error: _confirmPinError,
                ),

                SizedBox(height: Responsive.height(context, 0.03)),

                // ---- SAVE BUTTON ----
                SizedBox(
                  width: double.infinity,
                  height: Responsive.height(context, 0.066),
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
                        ? SizedBox(
                            width: Responsive.icon(context, 22),
                            height: Responsive.icon(context, 22),
                            child: const CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.4),
                          )
                        : Text(
                            'Save Changes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: Responsive.text(context, 16.5),
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
      ),
    );
  }

  // ---------------- UI HELPERS ----------------

  Widget _sectionTitle(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(context, 0.012)),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: Responsive.text(context, 14.5),
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
          maxLines: 1,
          style: TextStyle(
            color: EleghartColors.textPrimary,
            fontSize: Responsive.text(context, 15.5),
          ),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: Responsive.width(context, 0.048),
              vertical: Responsive.height(context, 0.018),
            ),
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
          SizedBox(height: Responsive.height(context, 0.007)),
          Text(
            error,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: Responsive.text(context, 12.5),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: Responsive.text(context, 13.5),
            fontWeight: FontWeight.w700,
            color: EleghartColors.textSecondary,
          ),
        ),
        SizedBox(height: Responsive.height(context, 0.007)),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: Responsive.text(context, 20),
            letterSpacing: Responsive.width(context, 0.03),
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            hintText: '• • • •',
            hintStyle: TextStyle(
              letterSpacing: Responsive.width(context, 0.03),
              color: EleghartColors.textHint,
            ),
            contentPadding: EdgeInsets.symmetric(
              vertical: Responsive.height(context, 0.017),
              horizontal: Responsive.width(context, 0.04),
            ),
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
          SizedBox(height: Responsive.height(context, 0.007)),
          Text(
            error,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: Responsive.text(context, 12.5),
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
