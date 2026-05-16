import 'package:flutter/material.dart';
import 'eleghart_colors.dart';

/// Glass Morphism & Interactive Design System
class GlassTheme {
  // ====== GLASS MORPHISM UTILITIES ======

  /// Primary glass overlay with blur for premium feel
  static BoxDecoration glassBox({
    double borderRadius = 24,
    double opacity = 0.15,
    Color glassColor = Colors.white,
    bool withBorder = true,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      color: glassColor.withOpacity(opacity),
      border: withBorder
          ? Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            )
          : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 25,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.15),
          blurRadius: 15,
          offset: const Offset(-5, -5),
        ),
      ],
    );
  }

  /// Accent glass with metallic appearance
  static BoxDecoration accentGlass({
    double borderRadius = 24,
    bool withBorder = true,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          EleghartColors.accentDark.withOpacity(0.25),
          EleghartColors.accentLight.withOpacity(0.12),
        ],
      ),
      border: withBorder
          ? Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1.5,
            )
          : null,
      boxShadow: [
        BoxShadow(
          color: EleghartColors.accentDark.withOpacity(0.15),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.1),
          blurRadius: 20,
          offset: const Offset(-8, -8),
        ),
      ],
    );
  }

  /// Interactive button glass effect
  static BoxDecoration interactiveGlass({
    double borderRadius = 18,
    bool isPressed = false,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      color: Colors.white.withOpacity(isPressed ? 0.25 : 0.15),
      border: Border.all(
        color: Colors.white.withOpacity(isPressed ? 0.4 : 0.2),
        width: 1.5,
      ),
      boxShadow: [
        if (!isPressed)
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
      ],
    );
  }

  /// Elevated card with subtle depth
  static BoxDecoration elevatedCard({
    double borderRadius = 22,
    Color backgroundColor = Colors.white,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      color: backgroundColor,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          backgroundColor,
          backgroundColor.withOpacity(0.95),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Neumorphic shadow pair for depth
  static List<BoxShadow> neumorphicShadows() {
    return [
      BoxShadow(
        color: Colors.white.withOpacity(0.8),
        offset: const Offset(-3, -3),
        blurRadius: 8,
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.15),
        offset: const Offset(3, 3),
        blurRadius: 8,
      ),
    ];
  }

  /// Modern gradient collection
  static LinearGradient accentGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        EleghartColors.accentDark,
        EleghartColors.accentMid,
        EleghartColors.accentLight,
      ],
    );
  }

  static LinearGradient coolGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.blue.withOpacity(0.4),
        Colors.cyan.withOpacity(0.3),
        Colors.teal.withOpacity(0.2),
      ],
    );
  }

  static LinearGradient warmGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.orange.withOpacity(0.3),
        Colors.red.withOpacity(0.2),
        Colors.pink.withOpacity(0.15),
      ],
    );
  }

  // ====== TEXT STYLES ======

  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.3,
    color: EleghartColors.textPrimary,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
    color: EleghartColors.textPrimary,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
    color: EleghartColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: EleghartColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: EleghartColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: EleghartColors.textHint,
  );
}
