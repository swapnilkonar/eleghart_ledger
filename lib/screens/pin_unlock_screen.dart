import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_dashboard.dart';
import 'set_pin_screen.dart';

class PinUnlockScreen extends StatefulWidget {
  final String userName;
  const PinUnlockScreen({super.key, required this.userName});

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen>
    with TickerProviderStateMixin {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  bool _unlocking = false;
  bool _errorGlow = false;
  String _pin = '';

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    AppThemeNotifier.instance.addListener(_onThemeChanged);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 14)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_onThemeChanged);
    _shakeController.dispose();
    _pulseController.dispose();
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onPinChanged(String val) {
    setState(() => _pin = val);
    if (val.length == 4) _unlock();
  }

  Future<void> _unlock() async {
    final pin = _pin.trim();
    if (pin.length != 4) {
      _failFeedback('Enter your 4-digit PIN');
      return;
    }

    setState(() => _unlocking = true);

    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString('user_pin');

    if (pin != storedPin) {
      setState(() => _unlocking = false);
      _failFeedback('Incorrect PIN');
      return;
    }

    HapticFeedback.lightImpact();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeDashboard(userName: widget.userName),
      ),
    );
  }

  void _failFeedback(String msg) {
    _pinController.clear();
    setState(() {
      _pin = '';
      _errorGlow = true;
    });
    _shakeController.forward(from: 0);
    HapticFeedback.heavyImpact();
    _toast(msg);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _errorGlow = false);
    });
  }

  Future<void> _forgotPin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF1A0005),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset PIN?',
          style: TextStyle(color: AppThemeNotifier.isWhite ? const Color(0xFF8E1D1D) : Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'If you forgot your PIN, you can set a new one.\n\nThis will replace your old PIN.',
          style: TextStyle(color: AppThemeNotifier.isWhite ? Colors.black54 : Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppThemeNotifier.isWhite ? Colors.black45 : Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF2040)),
            child: const Text('Reset PIN', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_pin');

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SetPinScreen(userName: widget.userName)),
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
            child: CustomPaint(painter: _PinRaysPainter()),
          ),

          // Main content
          SafeArea(
            child: GestureDetector(
              onTap: () => _focusNode.requestFocus(),
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
                        height: size.height * 0.30,
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
                      'Enter your PIN',
                      style: GoogleFonts.sora(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppThemeNotifier.isWhite ? const Color(0xFF8E1D1D) : Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome back!',
                      style: GoogleFonts.sora(
                        fontSize: 14,
                        color: AppThemeNotifier.isWhite ? const Color(0xFF8E1D1D).withOpacity(0.6) : Colors.white54,
                        letterSpacing: 0.3,
                      ),
                    ),

                    SizedBox(height: size.height * 0.045),

                    // PIN dots with shake animation
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: child,
                        ),
                        child: GestureDetector(
                          onTap: () => _focusNode.requestFocus(),
                          child: _buildPinDotsContainer(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Forgot PIN
                    TextButton(
                      onPressed: _forgotPin,
                      child: Text(
                        'Forgot PIN?',
                        style: GoogleFonts.sora(
                          color: const Color(0xFFFF2040),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Unlock button
                    _buildUnlockButton(),

                    SizedBox(height: safeBottom + 24),
                  ],
                ),
              ),
            ),
          ),

          // Hidden text field to capture keyboard input
          Positioned(
            left: -300,
            top: 0,
            child: SizedBox(
              width: 10,
              height: 10,
              child: TextField(
                controller: _pinController,
                focusNode: _focusNode,
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
        ],
      ),
    );
  }

  Widget _buildPinDotsContainer() {
    final borderColor =
        _errorGlow ? const Color(0xFFFF2040) : const Color(0xFF8E1D1D);
    final glowColor = _errorGlow
        ? Colors.red.withOpacity(0.6)
        : const Color(0xFF8E1D1D).withOpacity(0.5);

    return Container(
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
          final filled = i < _pin.length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? const Color(0xFFCC0020) : Colors.transparent,
              border: Border.all(
                color: filled ? const Color(0xFFCC0020) : (AppThemeNotifier.isWhite ? const Color(0xFFCC0020).withOpacity(0.35) : Colors.white54),
                width: 2,
              ),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.55),
                        blurRadius: 12,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildUnlockButton() {
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
          onPressed: _unlocking ? null : _unlock,
          icon: _unlocking
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.lock_rounded, color: Colors.white, size: 22),
          label: _unlocking
              ? const SizedBox.shrink()
              : Text(
                  'Unlock',
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

class _PinRaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.28);
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
