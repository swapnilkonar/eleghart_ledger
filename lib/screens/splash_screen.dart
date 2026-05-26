import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'premium_onboarding_screen.dart';
import 'welcome_screen.dart';
import 'pin_unlock_screen.dart';

class PremiumSplashScreen extends StatefulWidget {
  const PremiumSplashScreen({super.key});

  @override
  State<PremiumSplashScreen> createState() => _PremiumSplashScreenState();
}

class _PremiumSplashScreenState extends State<PremiumSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController controller;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    Future.delayed(const Duration(seconds: 3), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');
    final pin = prefs.getString('user_pin');

    if (!mounted) return;

    Widget next;
    if (pin == null || pin.isEmpty) {
      next = const WelcomeScreen();
    } else {
      next = PinUnlockScreen(userName: name ?? '');
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final isWhite = AppThemeNotifier.isWhite;

    return Scaffold(
      backgroundColor: isWhite ? Colors.white : Colors.black,
      body: Stack(
        children: [

          /// 1. BACKGROUND
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isWhite
                    ? [Colors.white, const Color(0xFFFFF0F0), Colors.white]
                    : const [
                        Color(0xFF3B0008),
                        Color(0xFF0E0002),
                        Color(0xFF000000),
                      ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          /// 2. SPLASH IMAGE
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              isWhite ? 'assets/images/splash_screen_white.png' : 'assets/images/splash_screen.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
          ),

          /// 3. BOTTOM FADE — only for dark theme
          if (!isWhite)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: size.height * 0.20,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0xCC000000),
                      Color(0xFF000000),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

          /// 4. ANIMATED PULSING RING over the logo
          Positioned(
            top: size.height * 0.035,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: controller,
                builder: (_, __) => Container(
                  height: 285 + controller.value * 14,
                  width: 285 + controller.value * 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red
                          .withOpacity(0.08 + controller.value * 0.16),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red
                            .withOpacity(0.10 + controller.value * 0.12),
                        blurRadius: 32,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          /// 5. LOADER — positioned just below the image content area
          Positioned(
            top: size.height * 0.76,
            left: 36,
            right: 36,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Loading your financial world...',
                  style: GoogleFonts.sora(
                    color: isWhite ? const Color(0xFF8E1D1D).withOpacity(0.6) : Colors.white54,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, _) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final fillWidth =
                            constraints.maxWidth * _progressController.value;
                        return SizedBox(
                          height: 16,
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              Container(
                                height: 4,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                              if (fillWidth > 0)
                                Container(
                                  height: 4,
                                  width: fillWidth,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF7A0010),
                                        Color(0xFFFF0033),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(100),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.5),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              if (fillWidth > 6)
                                Positioned(
                                  left: fillWidth - 6,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFFF2040),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.9),
                                          blurRadius: 14,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SplashItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const SplashItem({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.redAccent, size: 30),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _LightRaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.52);

    final angles = [
      -160.0, -140.0, -120.0, -100.0,
      -80.0,  -60.0,  -40.0,  -20.0,
       20.0,   40.0,   60.0,   80.0,
      100.0,  120.0,  140.0,  160.0,
    ];

    for (final angleDeg in angles) {
      final rad = angleDeg * pi / 180.0;
      final length = size.width * 0.9;
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
            const Color(0xFFCC0020).withOpacity(0.28),
            Colors.transparent,
          ],
        );

      canvas.drawLine(center, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
