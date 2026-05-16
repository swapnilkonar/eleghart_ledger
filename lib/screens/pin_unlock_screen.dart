import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/eleghart_colors.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';
import 'home_dashboard.dart';
import 'set_pin_screen.dart';

class PinUnlockScreen extends StatefulWidget {
  final String userName;
  const PinUnlockScreen({super.key, required this.userName});

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen>
    with SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();
  bool _unlocking = false;
  bool _errorGlow = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 14)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final pin = _pinController.text.trim();
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

    setState(() => _errorGlow = true);

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
        title: const Text('Reset PIN?'),
        content: const Text(
          'If you forgot your PIN, you can set a new one.\n\n'
          'This will replace your old PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: EleghartColors.accentDark,
            ),
            child: const Text('Reset PIN'),
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
      MaterialPageRoute(
        builder: (_) => SetPinScreen(userName: widget.userName),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final h = media.size.height;
    final bottomInset = media.viewInsets.bottom;
    final keyboardOpen = bottomInset > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Background effects
            Positioned(
              top: -100,
              left: -80,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(150),
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        EleghartColors.accentDark.withOpacity(0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Content
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(28, 16, 28, bottomInset + 16),
              child: Column(
                children: [
                  // Logo
                  SizedBox(
                    height: keyboardOpen ? h * 0.22 : h * 0.42,
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return Opacity(
                            opacity: value,
                            child: Transform.scale(scale: 0.7 + (value * 0.3)),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/eleghart_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Heading
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: Text(
                            'Enter your PIN',
                            style: GlassTheme.headingSmall.copyWith(
                              fontSize: 20,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // PIN Input
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return Opacity(
                              opacity: value,
                              child: Center(
                                child: SizedBox(
                                  width: 230,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 10,
                                        sigmaY: 10,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          color: Colors.white.withOpacity(0.15),
                                          border: Border.all(
                                            color: _errorGlow
                                                ? Colors.redAccent
                                                    .withOpacity(0.4)
                                                : Colors.white
                                                    .withOpacity(0.3),
                                            width: _errorGlow ? 2 : 1.5,
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _pinController,
                                          maxLength: 4,
                                          keyboardType: TextInputType.number,
                                          obscureText: true,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            letterSpacing: 16,
                                            fontWeight: FontWeight.w700,
                                            color: EleghartColors.textPrimary,
                                          ),
                                          decoration: InputDecoration(
                                            counterText: '',
                                            border: InputBorder.none,
                                            hintText: '• • • •',
                                            hintStyle: TextStyle(
                                              letterSpacing: 14,
                                              color: EleghartColors.textHint
                                                  .withOpacity(0.4),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    },
                  ),

                  const SizedBox(height: 16),

                  GlassContainer(
                    borderRadius: 14,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    interactive: true,
                    onTap: _forgotPin,
                    child: Text(
                      'Forgot PIN?',
                      style: GlassTheme.label.copyWith(
                        color: EleghartColors.accentDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Unlock button
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
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
                              label: 'Unlock',
                              icon: Icons.lock_open,
                              onPressed: _unlocking ? () {} : _unlock,
                              isLoading: _unlocking,
                              borderRadius: 20,
                            ),
                          ),
                        ),
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
      ),
    );
  }
}
