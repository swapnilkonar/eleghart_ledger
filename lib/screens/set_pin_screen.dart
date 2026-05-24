import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_dashboard.dart';

class SetPinScreen extends StatefulWidget {
  final String userName;
  const SetPinScreen({super.key, required this.userName});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen>
    with SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _pinFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _saving = false;
  String _pin = '';
  String _confirm = '';

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    AppThemeNotifier.instance.addListener(_onThemeChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pinFocus.addListener(() => setState(() {}));
    _confirmFocus.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocus.requestFocus();
    });
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_onThemeChanged);
    _pulseController.dispose();
    _pinController.dispose();
    _confirmController.dispose();
    _pinFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _onPinChanged(String val) {
    setState(() => _pin = val);
    if (val.length == 4) {
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) _confirmFocus.requestFocus();
      });
    }
  }

  void _onConfirmChanged(String val) {
    setState(() => _confirm = val);
    if (val.length == 4) _savePin();
  }

  Future<void> _savePin() async {
    final pin = _pin.trim();
    final confirm = _confirm.trim();

    if (pin.length != 4 || confirm.length != 4) {
      _toast('PIN must be exactly 4 digits');
      return;
    }

    if (pin != confirm) {
      _toast('PINs do not match');
      _confirmController.clear();
      setState(() => _confirm = '');
      _confirmFocus.requestFocus();
      return;
    }

    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_pin', pin);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeDashboard(userName: widget.userName),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF8E1D1D),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background image
          Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.25)),

          // Subtle light rays from logo
          Positioned.fill(
            child: CustomPaint(painter: _SetPinRaysPainter()),
          ),

          // Main content
          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    SizedBox(height: size.height * 0.04),

                    // Logo with pulsing red glow
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, child) => Container(
                        height: size.height * 0.28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(
                                  0.15 + _pulseController.value * 0.14),
                              blurRadius: 60 + _pulseController.value * 25,
                              spreadRadius: 12,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                      child: Image.asset(
                        'assets/icons/eleghart_icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Title
                    Text(
                      'Set your PIN',
                      style: GoogleFonts.sora(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppThemeNotifier.isWhite ? const Color(0xFF8E1D1D) : Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a 4-digit PIN to secure your app',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        color: AppThemeNotifier.isWhite ? const Color(0xFF8E1D1D).withOpacity(0.6) : Colors.white54,
                        letterSpacing: 0.3,
                      ),
                    ),

                    SizedBox(height: size.height * 0.04),

                    // Enter PIN row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _buildLabeledPinRow(
                        label: 'Enter PIN',
                        pin: _pin,
                        focusNode: _pinFocus,
                        isActive: _pinFocus.hasFocus,
                        onTap: () => _pinFocus.requestFocus(),
                      ),
                    ),

                    SizedBox(height: size.height * 0.02),

                    // Confirm PIN row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _buildLabeledPinRow(
                        label: 'Confirm PIN',
                        pin: _confirm,
                        focusNode: _confirmFocus,
                        isActive: _confirmFocus.hasFocus,
                        onTap: () => _confirmFocus.requestFocus(),
                      ),
                    ),

                    const Spacer(),

                    // Continue button
                    _buildContinueButton(),

                    SizedBox(height: safeBottom + 24),
                  ],
                ),
              ),
            ),
          ),

          // Hidden text fields for keyboard capture
          Positioned(
            left: -300,
            top: 0,
            child: SizedBox(
              width: 10,
              height: 10,
              child: TextField(
                controller: _pinController,
                focusNode: _pinFocus,
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                obscureText: true,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
                onChanged: _onPinChanged,
              ),
            ),
          ),
          Positioned(
            left: -300,
            top: 50,
            child: SizedBox(
              width: 10,
              height: 10,
              child: TextField(
                controller: _confirmController,
                focusNode: _confirmFocus,
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                obscureText: true,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
                onChanged: _onConfirmChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledPinRow({
    required String label,
    required String pin,
    required FocusNode focusNode,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final borderColor =
        isActive ? const Color(0xFFCC0020) : const Color(0xFF8E1D1D);
    final glowColor = isActive
        ? Colors.red.withOpacity(0.5)
        : const Color(0xFF8E1D1D).withOpacity(0.3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            label,
            style: GoogleFonts.sora(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? (AppThemeNotifier.isWhite ? const Color(0xFF8E1D1D) : Colors.white70)
                  : (AppThemeNotifier.isWhite ? const Color(0xFF8E1D1D).withOpacity(0.5) : Colors.white38),
              letterSpacing: 0.3,
            ),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 68,
            decoration: BoxDecoration(
              color: AppThemeNotifier.isWhite ? const Color(0xFFFFECEC) : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.8),
              boxShadow: [
                BoxShadow(color: glowColor, blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (i) {
                final filled = i < pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? const Color(0xFFCC0020) : Colors.transparent,
                    border: Border.all(
                      color: filled ? const Color(0xFFCC0020) : (AppThemeNotifier.isWhite ? const Color(0xFFCC0020).withOpacity(0.35) : Colors.white38),
                      width: 2,
                    ),
                    boxShadow: filled
                        ? [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7A0010), Color(0xFFCC0020)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.45),
              blurRadius: 22,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _saving ? null : _savePin,
          icon: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
          label: _saving
              ? const SizedBox.shrink()
              : Text(
                  'Continue',
                  style: GoogleFonts.sora(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class _SetPinRaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.22);
    final angles = [-160.0, -140.0, -120.0, 120.0, 140.0, 160.0];

    for (final angleDeg in angles) {
      final rad = angleDeg * pi / 180.0;
      final length = size.width * 0.95;
      final end = Offset(
        center.dx + cos(rad) * length,
        center.dy + sin(rad) * length,
      );

      final paint = Paint()
        ..strokeWidth = 1.0
        ..shader = ui.Gradient.linear(
          center,
          end,
          [
            const Color(0xFFCC0020).withOpacity(0.18),
            Colors.transparent,
          ],
        );

      canvas.drawLine(center, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
