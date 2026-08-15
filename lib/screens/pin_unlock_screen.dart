import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/pin_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';
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
  String _pin = '';
  bool _unlocking = false;
  bool _errorState = false;
  int _remainingAttempts = PinService.maxAttempts;
  int _lockoutSecondsLeft = 0;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initBiometric();
      _checkLockout();
    });
  }

  void _onThemeChanged() => setState(() {});

  Future<void> _initBiometric() async {
    final available = await PinService.isBiometricAvailable();
    final enabled = await PinService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
    if (available && enabled) _tryBiometric();
  }

  Future<void> _checkLockout() async {
    final secs = await PinService.lockoutSecondsRemaining();
    if (secs != null && mounted) {
      setState(() => _lockoutSecondsLeft = secs);
      _startLockoutTimer();
    } else {
      final rem = await PinService.remainingAttempts();
      if (mounted) setState(() => _remainingAttempts = rem);
    }
  }

  void _startLockoutTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      final secs = await PinService.lockoutSecondsRemaining();
      if (secs == null) {
        setState(() => _lockoutSecondsLeft = 0);
        return false;
      }
      setState(() => _lockoutSecondsLeft = secs);
      return true;
    });
  }

  Future<void> _tryBiometric() async {
    final ok = await PinService.authenticateWithBiometric();
    if (ok && mounted) _navigateHome();
  }

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_onThemeChanged);
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _handleKeyPress(String key) {
    if (_unlocking || _lockoutSecondsLeft > 0) return;
    if (_pin.length >= 4) return;

    HapticFeedback.lightImpact();

    setState(() => _pin += key);
    if (_pin.length == 4) {
      _verifyPin();
    }
  }

  void _handleBackspace() {
    if (_unlocking || _pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verifyPin() async {
    if (_lockoutSecondsLeft > 0) {
      _toast('Locked out. Please wait $_lockoutSecondsLeft seconds.');
      return;
    }

    setState(() => _unlocking = true);

    try {
      final correct = await PinService.verifyPin(_pin);
      if (!mounted) return;

      if (correct) {
        HapticFeedback.lightImpact();
        _navigateHome();
      } else {
        final rem = await PinService.remainingAttempts();
        _failFeedback('Incorrect PIN — $rem attempt${rem == 1 ? '' : 's'} left', rem);
      }
    } on PinLockedException catch (e) {
      if (!mounted) return;
      setState(() => _lockoutSecondsLeft = e.secondsRemaining);
      _startLockoutTimer();
      _failFeedback('Too many failed attempts. Locked for ${e.secondsRemaining}s', 0);
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  void _failFeedback(String msg, int rem) {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0);
    setState(() {
      _errorState = true;
      _remainingAttempts = rem;
    });
    _toast(msg);

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _pin = '';
          _errorState = false;
        });
      }
    });
  }

  void _navigateHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeDashboard(userName: widget.userName),
      ),
    );
  }

  Future<void> _forgotPin() async {
    final isWhite = AppThemeNotifier.isWhite;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isWhite ? Colors.white : const Color(0xFF1B0205),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Reset Security PIN?',
          style: GoogleFonts.sora(
            color: isWhite ? EleghartColors.accentDark : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'If you forgot your passkey, you can clear and create a new 4-digit PIN.',
          style: GoogleFonts.sora(
            fontSize: 13,
            color: isWhite ? Colors.black54 : Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.sora(
                color: isWhite ? Colors.black45 : Colors.white54,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCC0020),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Reset PIN',
              style: GoogleFonts.sora(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_pin');
    await prefs.remove('user_pin_hash');

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SetPinScreen(userName: widget.userName)),
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

    return Scaffold(
      backgroundColor: isWhite ? Colors.white : const Color(0xFF0A0204),
      body: Stack(
        children: [
          const Positioned.fill(child: ThemedBackground()),

          SafeArea(
            child: Column(
              children: [
                SizedBox(height: size.height * 0.03),

                // Animated Logo Emblem
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, child) => Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFCC0020).withValues(
                            alpha: 0.22 + _pulseController.value * 0.24,
                          ),
                          blurRadius: 40 + _pulseController.value * 22,
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

                const SizedBox(height: 18),

                // Greeting & Title
                Text(
                  widget.userName.isNotEmpty
                      ? 'Welcome, ${widget.userName}'
                      : 'Welcome Back',
                  style: GoogleFonts.sora(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter your 4-digit security PIN',
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
                      final filled = index < _pin.length;
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

                const SizedBox(height: 14),

                // Status & Lockout Info
                if (_lockoutSecondsLeft > 0)
                  Text(
                    'App locked. Try again in $_lockoutSecondsLeft s',
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFF2040),
                    ),
                  )
                else if (_remainingAttempts < PinService.maxAttempts)
                  Text(
                    '$_remainingAttempts attempt${_remainingAttempts == 1 ? '' : 's'} remaining',
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  )
                else
                  const SizedBox(height: 16),

                const Spacer(),

                // Custom Numpad Keyboard Grid
                _buildNumpad(isWhite),

                const SizedBox(height: 12),

                // Forgot PIN Action Button
                TextButton(
                  onPressed: _forgotPin,
                  child: Text(
                    'Forgot PIN?',
                    style: GoogleFonts.sora(
                      color: const Color(0xFFCC0020),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),

                SizedBox(height: size.height * 0.02),
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
              // Biometric key or empty space
              if (_biometricAvailable && _biometricEnabled)
                _buildActionKey(
                  icon: Icons.fingerprint_rounded,
                  onPressed: _tryBiometric,
                  isWhite: isWhite,
                  iconColor: const Color(0xFFCC0020),
                )
              else
                const SizedBox(width: 72, height: 72),

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
    Color? iconColor,
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
            color: iconColor ?? (isWhite ? EleghartColors.accentDark : Colors.white70),
          ),
        ),
      ),
    );
  }
}
