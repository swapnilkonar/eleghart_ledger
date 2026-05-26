import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class ThemedBackground extends StatelessWidget {
  final double darkOverlayOpacity;
  const ThemedBackground({super.key, this.darkOverlayOpacity = 0.65});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppThemeNotifier.instance,
      builder: (_, isWhite, __) => Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            isWhite
                ? 'assets/images/background_theme_white.png'
                : 'assets/images/background_theme_top_glow.png',
            fit: BoxFit.cover,
          ),
          if (!isWhite)
            Container(color: Colors.black.withOpacity(darkOverlayOpacity)),
        ],
      ),
    );
  }
}
