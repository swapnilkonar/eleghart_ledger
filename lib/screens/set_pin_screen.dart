import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/pin_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';
import 'home_dashboard.dart';

class SetPinScreen extends StatefulWidget {
  final String userName;
  final bool isReset;
  const SetPinScreen({super.key, required this.userName, this.isReset = false});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen>
    with TickerProviderStateMixin {
  String _pin = '';
  String _confirmPin = '';
  int _step = 1; // 1 = Enter PIN, 2 = Confirm PIN
  bool _saving = false;
  bool _errorState = false;

  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    AppThemeNotifier.instance.addListener(_onThemeChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 14)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_onThemeChanged);
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _handleKeyPress(String key) {
    if (_saving) return;

    HapticFeedback.lightImpact();

    if (_step == 1) {
      if (_pin.length < 4) {
        setState(() => _pin += key);
        if (_pin.length == 4) {
          Future.delayed(const Duration(milliseconds: 220), () {
            if (mounted) setState(() => _step = 2);
          });
        }
      }
    } else {
      if (_confirmPin.length < 4) {
        setState(() => _confirmPin += key);
        if (_confirmPin.length == 4) {
          _verifyAndSave();
        }
      }
    }
  }

  void _handleBackspace() {
    if (_saving) return;
    HapticFeedback.selectionClick();

    if (_step == 1) {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
    } else {
      if (_confirmPin.isNotEmpty) {
        setState(() => _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1));
      } else {
        // Go back to step 1 if backspace on empty confirm
        setState(() {
          _step = 1;
          _pin = '';
        });
      }
    }
  }

  Future<void> _verifyAndSave() async {
    if (_pin != _confirmPin) {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0);
      setState(() => _errorState = true);
      _toast('PINs do not match. Try again.');

      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          setState(() {
            _confirmPin = '';
            _errorState = false;
          });
        }
      });
      return;
    }

    setState(() => _saving = true);
    await PinService.setPin(_pin);

    if (!mounted) return;

    if (widget.isReset) {
      Navigator.pop(context);
      return;
    }

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
        content: Text(msg, style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF8E1D1D),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final size = MediaQuery.of(context).size;
    final primaryColor = isWhite ? EleghartColors.accentDark : Colors.white;

    final currentPin = _step == 1 ? _pin : _confirmPin;

    return Scaffold(
      backgroundColor: isWhite ? Colors.white : const Color(0xFF0A0204),
      body: Stack(
        children: [
          const Positioned.fill(child: ThemedBackground()),

          SafeArea(
            child: Column(
              children: [
                // Top Header Navigation Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.isReset || _step == 2)
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                          onPressed: () {
                            if (_step == 2) {
                              setState(() {
                                _step = 1;
                                _confirmPin = '';
                              });
                            } else {
                              Navigator.pop(context);
                            }
                          },
                        )
                      else
                        const SizedBox(width: 48),

                      // Step Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCC0020).withValues(alpha: isWhite ? 0.12 : 0.22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFCC0020).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          'STEP $_step OF 2',
                          style: GoogleFonts.sora(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: const Color(0xFFCC0020),
                          ),
                        ),
                      ),

                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                const Spacer(),

                // Animated Logo Emblem
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, child) => Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFCC0020).withValues(
                            alpha: 0.20 + _pulseController.value * 0.22,
                          ),
                          blurRadius: 35 + _pulseController.value * 20,
                          spreadRadius: 4,
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

                const SizedBox(height: 20),

                // Title & Subtitle
                Text(
                  _step == 1
                      ? (widget.isReset ? 'Set New Security PIN' : 'Create Security PIN')
                      : 'Confirm Your PIN',
                  style: GoogleFonts.sora(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _step == 1
                      ? 'Enter a 4-digit passkey to lock your ledger'
                      : 'Re-enter your 4-digit passkey to verify',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    color: isWhite ? Colors.black54 : Colors.white54,
                  ),
                ),

                const SizedBox(height: 28),

                // PIN Dots Indicator with Shake Animation
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: child,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final filled = index < currentPin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: filled ? 22 : 18,
                        height: filled ? 22 : 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled
                              ? (_errorState
                                  ? const Color(0xFFFF2040)
                                  : const Color(0xFFCC0020))
                              : Colors.transparent,
                          border: Border.all(
                            color: filled
                                ? (_errorState
                                    ? const Color(0xFFFF2040)
                                    : const Color(0xFFCC0020))
                                : (isWhite
                                    ? const Color(0xFFCC0020).withValues(alpha: 0.35)
                                    : Colors.white38),
                            width: 2,
                          ),
                          boxShadow: filled
                              ? [
                                  BoxShadow(
                                    color: (_errorState
                                            ? const Color(0xFFFF2040)
                                            : const Color(0xFFCC0020))
                                        .withValues(alpha: 0.55),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      );
                    }),
                  ),
                ),

                const Spacer(),

                // Custom Numpad Keyboard Grid
                _buildNumpad(isWhite),

                SizedBox(height: size.height * 0.03),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpad(bool isWhite) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['1', '2', '3'].map((k) => _buildKey(k, isWhite)).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['4', '5', '6'].map((k) => _buildKey(k, isWhite)).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['7', '8', '9'].map((k) => _buildKey(k, isWhite)).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 72, height: 72), // Spacer
              _buildKey('0', isWhite),
              _buildActionKey(
                icon: Icons.backspace_outlined,
                onPressed: _handleBackspace,
                isWhite: isWhite,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String key, bool isWhite) {
    final keyBg = isWhite
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.08);
    final textColor = isWhite ? EleghartColors.accentDark : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleKeyPress(key),
        borderRadius: BorderRadius.circular(36),
        splashColor: const Color(0xFFCC0020).withValues(alpha: 0.25),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: keyBg,
            border: Border.all(
              color: isWhite
                  ? const Color(0xFFCC0020).withValues(alpha: 0.20)
                  : Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
            boxShadow: isWhite
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Text(
            key,
            style: GoogleFonts.sora(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isWhite,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(36),
        splashColor: const Color(0xFFCC0020).withValues(alpha: 0.25),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isWhite
                ? Colors.white.withValues(alpha: 0.65)
                : Colors.white.withValues(alpha: 0.05),
          ),
          child: Icon(
            icon,
            size: 24,
            color: isWhite ? EleghartColors.accentDark : Colors.white70,
          ),
        ),
      ),
    );
  }
}
