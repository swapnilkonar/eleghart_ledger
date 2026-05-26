import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';
import 'set_pin_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userName;
  final ValueChanged<String>? onNameChanged;
  const ProfileScreen({super.key, required this.userName, this.onNameChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _avatar;
  late String _currentUserName;

  @override
  void initState() {
    super.initState();
    _currentUserName = widget.userName;
    _loadProfileData();
    AppThemeNotifier.instance.addListener(_onThemeChanged);
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final avatarPath = prefs.getString('user_avatar_path');
    if (avatarPath != null && File(avatarPath).existsSync()) {
      setState(() => _avatar = File(avatarPath));
    }
    final name = prefs.getString('user_name');
    if (name != null && name.isNotEmpty) {
      setState(() => _currentUserName = name);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF120404),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppThemeNotifier.isWhite ? Colors.black12 : Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFFCC0020)),
              title: Text('Take photo', style: GoogleFonts.sora(
                  color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white)),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFCC0020)),
              title: Text('Choose from gallery', style: GoogleFonts.sora(
                  color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white)),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (_avatar != null)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Color(0xFFFF3355)),
                title: Text('Remove photo', style: GoogleFonts.sora(
                    color: const Color(0xFFFF3355))),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    final prefs = await SharedPreferences.getInstance();

    if (action == 'remove') {
      await prefs.remove('user_avatar_path');
      setState(() => _avatar = null);
      return;
    }

    if (action == null) return;

    final source = action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    await prefs.setString('user_avatar_path', picked.path);
    setState(() => _avatar = File(picked.path));
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _currentUserName);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppThemeNotifier.isWhite
            ? Colors.white
            : const Color(0xFF120404),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Update Name',
          style: GoogleFonts.sora(
            color: AppThemeNotifier.isWhite
                ? EleghartColors.accentDark
                : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.sora(
            color: AppThemeNotifier.isWhite
                ? EleghartColors.accentDark
                : Colors.white,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: GoogleFonts.sora(
              color: AppThemeNotifier.isWhite
                  ? Colors.black38
                  : Colors.white38,
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppThemeNotifier.isWhite
                    ? const Color(0xFFEEEEEE)
                    : Colors.white24,
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(
                color: Color(0xFFCC0020),
                width: 2,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.sora(
                color: AppThemeNotifier.isWhite ? Colors.black54 : Colors.white54,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(
              'Save',
              style: GoogleFonts.sora(
                color: const Color(0xFFCC0020),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == _currentUserName) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', newName);

    setState(() {
      _currentUserName = newName;
    });

    if (widget.onNameChanged != null) {
      widget.onNameChanged!(newName);
    }
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeNotifier.isWhite ? Colors.white : Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(
            child: ThemedBackground(darkOverlayOpacity: 0.5),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        _buildProfileHeader(),
                        const SizedBox(height: 32),
                        _buildAppearanceCard(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Personal Information'),
                        const SizedBox(height: 12),
                        _buildMenuCard([
                          _MenuItem(
                            icon: Icons.person_rounded,
                            title: 'Name',
                            subtitle: _currentUserName,
                            onTap: _editName,
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Security'),
                        const SizedBox(height: 12),
                        _buildMenuCard([
                          _MenuItem(
                            icon: Icons.security_rounded,
                            title: 'Change PIN',
                            subtitle: 'Update your 4-digit PIN',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SetPinScreen(
                                    userName: widget.userName,
                                    isReset: true,
                                  ),
                                ),
                              );
                            },
                          ),
                          _MenuItem(
                            icon: Icons.fingerprint_rounded,
                            title: 'Biometric Login',
                            subtitle: 'Use fingerprint or face to unlock',
                            trailing: Switch(
                              value: true,
                              onChanged: (v) {},
                              activeColor: const Color(0xFFCC0020),
                            ),
                          ),
                          _MenuItem(
                            icon: Icons.lock_clock_rounded,
                            title: 'Auto Lock',
                            subtitle: 'Lock the app automatically',
                            trailingText: '5 min',
                            onTap: () {},
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildSectionTitle('More'),
                        const SizedBox(height: 12),
                        _buildMenuCard([
                          _MenuItem(
                            icon: Icons.logout_rounded,
                            title: 'Logout',
                            subtitle: 'Sign out from your account',
                            onTap: () {},
                          ),
                        ]),
                        const SizedBox(height: 40),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 48),
          Text(
            'Profile',
            style: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppThemeNotifier.isWhite
                  ? EleghartColors.accentDark
                  : Colors.white,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickAvatar,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppThemeNotifier.isWhite
                      ? Colors.white
                      : const Color(0xFF1A0A0A),
                  border: Border.all(
                    color: const Color(0xFFCC0020).withOpacity(0.3),
                    width: 2,
                  ),
                  image: _avatar != null
                      ? DecorationImage(
                          image: FileImage(_avatar!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCC0020).withOpacity(0.2),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: _avatar == null
                    ? const Center(
                        child: Icon(
                        Icons.person_rounded,
                          size: 50,
                          color: Color(0xFFCC0020),
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppThemeNotifier.isWhite
                        ? Colors.white
                        : const Color(0xFF1A0A0A),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppThemeNotifier.isWhite
                          ? const Color(0xFFEEEEEE)
                          : const Color(0xFFCC0020).withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFFCC0020),
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _editName,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _currentUserName,
                style: GoogleFonts.sora(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppThemeNotifier.isWhite
                      ? EleghartColors.accentDark
                      : Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.verified_rounded,
                color: Color(0xFFCC0020),
                size: 18,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Personal Expense Vault',
          style: GoogleFonts.sora(
            fontSize: 13,
            color: AppThemeNotifier.isWhite
                ? EleghartColors.accentDark.withOpacity(0.55)
                : Colors.white54,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFCC0020).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFCC0020).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shield_rounded,
                color: Color(0xFFCC0020),
                size: 12,
              ),
              const SizedBox(width: 6),
              Text(
                'Eleghart Ledger User',
                style: GoogleFonts.sora(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFCC0020),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.sora(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppThemeNotifier.isWhite
              ? EleghartColors.accentDark.withOpacity(0.5)
              : Colors.white54,
        ),
      ),
    );
  }

  Widget _buildAppearanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFCC0020).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.light_mode_rounded,
              color: Color(0xFFCC0020),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppThemeNotifier.isWhite
                        ? EleghartColors.accentDark
                        : Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Choose your preferred theme',
                  style: GoogleFonts.sora(
                    fontSize: 12,
                    color: AppThemeNotifier.isWhite
                        ? EleghartColors.accentDark.withOpacity(0.55)
                        : Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              AppThemeNotifier.toggle();
            },
            child: Container(
            width: 84,
              height: 36,
              decoration: BoxDecoration(
                color: AppThemeNotifier.isWhite
                    ? const Color(0xFFEEEEEE)
                    : const Color(0xFF1A0A0A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppThemeNotifier.isWhite
                      ? const Color(0xFFDDDDDD)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 32,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: AppThemeNotifier.isWhite
                          ? const Color(0xFFCC0020)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppThemeNotifier.isWhite
                          ? [
                              BoxShadow(
                                color: const Color(0xFFCC0020).withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      Icons.light_mode_rounded,
                      color: AppThemeNotifier.isWhite
                          ? Colors.white
                          : Colors.white54,
                      size: 16,
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 32,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: !AppThemeNotifier.isWhite
                          ? const Color(0xFFCC0020)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: !AppThemeNotifier.isWhite
                          ? [
                              BoxShadow(
                                color: const Color(0xFFCC0020).withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      Icons.dark_mode_rounded,
                      color: !AppThemeNotifier.isWhite
                          ? Colors.white
                          : Colors.white54,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(List<_MenuItem> items) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final isLast = entry.key == items.length - 1;
          final item = entry.value;
          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCC0020).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.icon,
                    color: const Color(0xFFCC0020),
                    size: 20,
                  ),
                ),
                title: Text(
                  item.title,
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppThemeNotifier.isWhite
                        ? EleghartColors.accentDark
                        : Colors.white,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    item.subtitle,
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      color: AppThemeNotifier.isWhite
                          ? EleghartColors.accentDark.withOpacity(0.55)
                          : Colors.white54,
                    ),
                  ),
                ),
                trailing: item.trailing ??
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.trailingText != null) ...[
                          Text(
                            item.trailingText!,
                            style: GoogleFonts.sora(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFCC0020),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (item.onTap != null)
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppThemeNotifier.isWhite
                                ? Colors.black38
                                : Colors.white38,
                          ),
                      ],
                    ),
                onTap: item.onTap,
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 64,
                  color: AppThemeNotifier.isWhite
                      ? const Color(0xFFEEEEEE)
                      : Colors.white.withOpacity(0.05),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF0E0505),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: AppThemeNotifier.isWhite
            ? const Color(0xFFEEEEEE)
            : Colors.white.withOpacity(0.07),
        width: 1,
      ),
      boxShadow: AppThemeNotifier.isWhite
          ? [
              BoxShadow(
                color: const Color(0xFFCC0020).withOpacity(0.10),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ]
          : [],
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingText,
    this.trailing,
    this.onTap,
  });
}