import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Pure Programmatic Multi-Layer Ambient Background (Zero Image Assets)
class ThemedBackground extends StatelessWidget {
  final double darkOverlayOpacity;
  const ThemedBackground({super.key, this.darkOverlayOpacity = 0.65});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppThemeNotifier.instance,
      builder: (_, isWhite, __) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // ── 1. Base Multi-Stop Gradient Layer ────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isWhite
                      ? const [
                          Color(0xFFFFFFFF),
                          Color(0xFFF8FAFC),
                          Color(0xFFF1F5F9),
                        ]
                      : const [
                          Color(0xFF1B0205),
                          Color(0xFF0F0103),
                          Color(0xFF060001),
                        ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // ── 2. Top Radiant Crimson Ambient Glow Aura (Dark Theme Only) ──
            if (!isWhite)
              Positioned(
                top: -110,
                left: -70,
                right: -70,
                height: 440,
                child: IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.85,
                        colors: [
                          Color(0x6BCC0020),
                          Color(0x2E660010),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── 3. Center Subtle Ambient Mesh Bloom (Dark Theme Only) ─────
            if (!isWhite)
              Positioned(
                top: 180,
                left: -40,
                right: -40,
                height: 380,
                child: IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.9,
                        colors: [
                          Color(0x298B0000),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── 4. Programmatic Micro Ambient Mesh Painter ────────────────
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _AmbientMeshPainter(isWhite: isWhite),
                ),
              ),
            ),

            // ── 5. Bottom Ambient Vignette Glow (Dark Theme Only) ─────────
            if (!isWhite)
              Positioned(
                bottom: -100,
                left: -60,
                right: -60,
                height: 350,
                child: IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.9,
                        colors: [
                          Color(0x38990018),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── 6. Dark Mode Contrast Vignette ───────────────────────────
            if (!isWhite && darkOverlayOpacity > 0)
              IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: darkOverlayOpacity * 0.35),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Custom painter rendering subtle, high-end micro ambient specks and luminous arcs
class _AmbientMeshPainter extends CustomPainter {
  final bool isWhite;

  _AmbientMeshPainter({required this.isWhite});

  @override
  void paint(Canvas canvas, Size size) {
    if (isWhite) return; // Clean pure white canvas in White theme

    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(42);

    const baseColor = Color(0x26FF3355);

    // Paint 18 subtle ambient dust specks across dark canvas
    for (int i = 0; i < 18; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final radius = 1.2 + random.nextDouble() * 2.2;
      final opacity = 0.03 + random.nextDouble() * 0.08;

      paint.color = baseColor.withValues(alpha: opacity);
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }

    // Paint top subtle luminous arc header curve
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x1FCC0020);

    final path = Path()
      ..moveTo(-20, size.height * 0.12)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.05,
        size.width * 0.65,
        size.height * 0.18,
        size.width + 20,
        size.height * 0.10,
      );

    canvas.drawPath(path, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _AmbientMeshPainter oldDelegate) =>
      oldDelegate.isWhite != isWhite;
}
