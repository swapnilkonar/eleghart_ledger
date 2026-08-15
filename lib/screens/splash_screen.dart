import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_theme.dart';
import 'welcome_screen.dart';
import 'pin_unlock_screen.dart';

/// Ultra-Premium Animated Splash Screen for Eleghart Ledger
class PremiumSplashScreen extends StatefulWidget {
  const PremiumSplashScreen({super.key});

  @override
  State<PremiumSplashScreen> createState() => _PremiumSplashScreenState();
}

class _PremiumSplashScreenState extends State<PremiumSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;
  late AnimationController _pulseRingController;

  late Animation<double> _logoScaleAnim;
  late Animation<double> _logoFadeAnim;
  late Animation<double> _ringPulseAnim;
  late Animation<double> _textSlideAnim;
  late Animation<double> _textFadeAnim;
  late Animation<double> _progressAnim;

  final List<_Particle> _particles = [];
  final Random _random = Random();

  String _statusText = 'Securing financial vault...';

  @override
  void initState() {
    super.initState();

    // 1. Initialize Particles
    for (int i = 0; i < 28; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        radius: _random.nextDouble() * 2.5 + 1.0,
        speed: _random.nextDouble() * 0.15 + 0.05,
        opacity: _random.nextDouble() * 0.5 + 0.2,
      ));
    }

    // 2. Main Timeline Controller (3.5 seconds)
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    // 3. Continuous Loop Controllers for Particles and Pulse Rings
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _pulseRingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // 4. Animation Curves
    _logoScaleAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
    );

    _logoFadeAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.25, curve: Curves.easeIn),
    );

    _ringPulseAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.20, 0.65, curve: Curves.easeOutCubic),
    );

    _textSlideAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.35, 0.70, curve: Curves.easeOutCubic),
    );

    _textFadeAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.35, 0.65, curve: Curves.easeIn),
    );

    _progressAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.10, 0.95, curve: Curves.easeInOutQuad),
    );

    // Dynamic Status Captions
    _mainController.addListener(() {
      final val = _mainController.value;
      if (val > 0.75) {
        if (_statusText != 'Welcome back!') {
          setState(() => _statusText = 'Welcome back!');
        }
      } else if (val > 0.45) {
        if (_statusText != 'Loading smart ledger...') {
          setState(() => _statusText = 'Loading smart ledger...');
        }
      } else if (val > 0.20) {
        if (_statusText != 'Initializing encryption...') {
          setState(() => _statusText = 'Initializing encryption...');
        }
      }
    });

    _mainController.forward();

    // Navigate when animation completes
    Future.delayed(const Duration(milliseconds: 3600), _navigateNext);
  }

  Future<void> _navigateNext() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');
    final pin =
        prefs.getString('user_pin_hash') ?? prefs.getString('user_pin');

    if (!mounted) return;

    final Widget nextScreen = (pin == null || pin.isEmpty)
        ? const WelcomeScreen()
        : PinUnlockScreen(userName: name ?? '');

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, __, ___) => nextScreen,
        transitionsBuilder: (_, animation, __, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );
          final scale = Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    _pulseRingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isWhite ? const Color(0xFFFAFAFA) : const Color(0xFF090203),
      body: Stack(
        children: [
          // ── 1. Gradient Background ──────────────────────────────────────────
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 1.2,
                  colors: isWhite
                      ? [
                          const Color(0xFFFFF5F5),
                          const Color(0xFFF8FAFC),
                          const Color(0xFFEEEEEE),
                        ]
                      : [
                          const Color(0xFF4A000B),
                          const Color(0xFF1B0105),
                          const Color(0xFF070001),
                        ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // ── 2. Ambient Floating Dust Particle Field ────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ParticleFieldPainter(
                    particles: _particles,
                    progress: _particleController.value,
                    isWhite: isWhite,
                  ),
                );
              },
            ),
          ),

          // ── 3. Central Content: Logo + Rings + Brand ────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // ── Hero Logo Container with Dual Concentric Pulse Rings ──────
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Expanding Outer Ring 1
                      AnimatedBuilder(
                        animation: Listenable.merge([_mainController, _pulseRingController]),
                        builder: (context, _) {
                          final ringExpand = _ringPulseAnim.value;
                          final subtleBreath = _pulseRingController.value * 8;
                          final outerSize = 130.0 + (ringExpand * 60) + subtleBreath;
                          final outerOpacity = (1.0 - ringExpand * 0.6) * (isWhite ? 0.25 : 0.40);

                          return Container(
                            width: outerSize,
                            height: outerSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFCC0020).withOpacity(outerOpacity),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFCC0020).withOpacity(outerOpacity * 0.5),
                                  blurRadius: 30,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Inner Glowing Ring 2
                      AnimatedBuilder(
                        animation: _mainController,
                        builder: (context, _) {
                          final innerSize = 110.0 + (_ringPulseAnim.value * 30);
                          return Container(
                            width: innerSize,
                            height: innerSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFFCC0020).withOpacity(isWhite ? 0.12 : 0.25),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // Main Animated Logo PNG Image
                      AnimatedBuilder(
                        animation: _mainController,
                        builder: (context, _) {
                          final scale = _logoScaleAnim.value;
                          final opacity = _logoFadeAnim.value;

                          return Transform.scale(
                            scale: scale.clamp(0.0, 1.2),
                            child: Opacity(
                              opacity: opacity.clamp(0.0, 1.0),
                              child: SizedBox(
                                width: 130,
                                height: 130,
                                child: Image.asset(
                                  'assets/images/eleghart_logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    size: 64,
                                    color: Color(0xFFCC0020),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Brand Title & Tagline ─────────────────────────────────────
                AnimatedBuilder(
                  animation: _mainController,
                  builder: (context, _) {
                    final slide = (1.0 - _textSlideAnim.value) * 24.0;
                    final opacity = _textFadeAnim.value.clamp(0.0, 1.0);

                    return Transform.translate(
                      offset: Offset(0, slide),
                      child: Opacity(
                        opacity: opacity,
                        child: Column(
                          children: [
                            // App Brand Name
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: isWhite
                                    ? const [
                                        Color(0xFF8B0000),
                                        Color(0xFFCC0020),
                                        Color(0xFF8B0000),
                                      ]
                                    : const [
                                        Color(0xFFFFFFFF),
                                        Color(0xFFFF4D6D),
                                        Color(0xFFFFFFFF),
                                      ],
                              ).createShader(bounds),
                              child: Text(
                                'ELEGHART LEDGER',
                                style: GoogleFonts.sora(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 4.0,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            const SizedBox(height: 6),

                            // Subtitle Tagline
                            Text(
                              'SMART LEDGER & WEALTH TRACKING',
                              style: GoogleFonts.sora(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.5,
                                color: isWhite
                                    ? const Color(0xFF7A1C1C).withOpacity(0.7)
                                    : Colors.white.withOpacity(0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── 4. Bottom Fluid Progress Bar & Dynamic Status ───────────────────
          Positioned(
            bottom: size.height * 0.08,
            left: 44,
            right: 44,
            child: AnimatedBuilder(
              animation: _mainController,
              builder: (context, _) {
                final progressVal = _progressAnim.value;
                final opacity = _logoFadeAnim.value.clamp(0.0, 1.0);

                return Opacity(
                  opacity: opacity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dynamic Status Caption
                      Text(
                        _statusText,
                        style: GoogleFonts.sora(
                          color: isWhite
                              ? const Color(0xFF7A1C1C).withOpacity(0.65)
                              : Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Progress Fill Bar with Pulse Dot
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final barWidth = constraints.maxWidth;
                          final filledWidth = barWidth * progressVal;

                          return SizedBox(
                            height: 14,
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                // Background Track
                                Container(
                                  height: 4,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: isWhite
                                        ? const Color(0xFFE0C0C0).withOpacity(0.4)
                                        : Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                ),

                                // Gradient Active Fill
                                if (filledWidth > 0)
                                  Container(
                                    height: 4,
                                    width: filledWidth,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF8B0000),
                                          Color(0xFFFF2040),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(100),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF2040).withOpacity(0.6),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),

                                // Glowing Pulse Dot
                                if (filledWidth > 4)
                                  Positioned(
                                    left: (filledWidth - 6).clamp(0.0, barWidth - 12),
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFFFF2040),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFF2040).withOpacity(0.9),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Particle Data Class ──────────────────────────────────────────────────────
class _Particle {
  double x;
  double y;
  double radius;
  double speed;
  double opacity;

  _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.opacity,
  });
}

// ── Particle Field Custom Painter ─────────────────────────────────────────────
class _ParticleFieldPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final bool isWhite;

  _ParticleFieldPainter({
    required this.particles,
    required this.progress,
    required this.isWhite,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      // Calculate current vertical drift position
      final currentY = (p.y - (progress * p.speed)) % 1.0;
      final offset = Offset(p.x * size.width, currentY * size.height);

      final color = isWhite ? const Color(0xFFCC0020) : Colors.white;
      paint.color = color.withOpacity((p.opacity * (1.0 - (currentY * 0.4))).clamp(0.05, 0.6));

      canvas.drawCircle(offset, p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleFieldPainter oldDelegate) => true;
}
