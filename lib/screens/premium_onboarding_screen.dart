import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../utils/app_theme.dart';
import '../theme/eleghart_colors.dart';
import 'onboarding_screen.dart';

class PremiumOnboardingScreen extends StatefulWidget {
  const PremiumOnboardingScreen({super.key});

  @override
  State<PremiumOnboardingScreen> createState() =>
      _PremiumOnboardingScreenState();
}

class _PremiumOnboardingScreenState extends State<PremiumOnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      "title": "Track money effortlessly",
      "subtitle": "Understand exactly where your money goes.",
      "icon": Icons.account_balance_wallet_rounded,
    },
    {
      "title": "Split expenses beautifully",
      "subtitle": "Trips, roommates, family & shared moments.",
      "icon": Icons.groups_rounded,
    },
    {
      "title": "AI-powered insights",
      "subtitle": "Get predictions, alerts & smart guidance.",
      "icon": Icons.psychology_alt_rounded,
    },
    {
      "title": "Private & secure vault",
      "subtitle": "Protected with PIN & biometric security.",
      "icon": Icons.shield_rounded,
    },
  ];

  void _goToOnboarding() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  void _onNextPressed() {
    if (_currentIndex < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _goToOnboarding();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite
        ? EleghartColors.accentDark.withOpacity(0.55)
        : Colors.white70;
    final cardBg = isWhite
        ? Colors.white
        : Colors.white.withOpacity(0.06);
    final cardBorder = isWhite
        ? const Color(0xFFEEEEEE)
        : Colors.white.withOpacity(0.08);
    final dotInactive = isWhite
        ? EleghartColors.accentDark.withOpacity(0.15)
        : Colors.white24;

    return Scaffold(
      backgroundColor: isWhite ? Colors.white : Colors.black,
      body: Stack(
        children: [
          /// BACKGROUND
          if (!isWhite)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF050505),
                    Color(0xFF2B0007),
                    Color(0xFF700014),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            )
          else
            Positioned.fill(
              child: Image.asset(
                'assets/images/background_theme_white.png',
                fit: BoxFit.cover,
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),

                /// LOGO
                Container(
                  height: 90,
                  width: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(isWhite ? 0.2 : 0.4),
                        blurRadius: 35,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/eleghart_logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  "ELEGHART LEDGER",
                  style: GoogleFonts.orbitron(
                    color: textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 30),

                /// PAGE VIEW
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    itemBuilder: (_, index) {
                      final item = _pages[index];
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(color: cardBorder),
                                boxShadow: isWhite
                                    ? [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(0.06),
                                          blurRadius: 20,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    height: 130,
                                    width: 130,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.red.shade900,
                                          Colors.redAccent,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(
                                              isWhite ? 0.25 : 0.4),
                                          blurRadius: 40,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      item["icon"] as IconData,
                                      size: 65,
                                      color: Colors.white,
                                    ),
                                  ),

                                  const SizedBox(height: 50),

                                  Text(
                                    item["title"] as String,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.sora(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  Text(
                                    item["subtitle"] as String,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.sora(
                                      fontSize: 16,
                                      color: textSec,
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                /// DOT INDICATOR
                SmoothPageIndicator(
                  controller: _controller,
                  count: _pages.length,
                  effect: ExpandingDotsEffect(
                    dotHeight: 8,
                    dotWidth: 8,
                    activeDotColor: Colors.redAccent,
                    dotColor: dotInactive,
                  ),
                ),

                const SizedBox(height: 35),

                /// NEXT / GET STARTED BUTTON
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    height: 65,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF7A0014),
                          Color(0xFFFF003C),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.35),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      onPressed: _onNextPressed,
                      child: Text(
                        _currentIndex == _pages.length - 1
                            ? "Get Started"
                            : "Next",
                        style: GoogleFonts.sora(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// SKIP BUTTON
                TextButton(
                  onPressed: _goToOnboarding,
                  child: Text(
                    "Skip",
                    style: GoogleFonts.sora(
                        color: isWhite
                            ? EleghartColors.accentDark.withOpacity(0.4)
                            : Colors.white60),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
