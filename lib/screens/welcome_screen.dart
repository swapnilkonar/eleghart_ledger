import 'package:flutter/material.dart';
import '../widgets/themed_background.dart';
import 'package:google_fonts/google_fonts.dart';

import 'onboarding_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _getStarted() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background image
          Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.40)),

          // Content
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: size.height * 0.02),

                // Logo with pulsing glow
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, child) => Container(
                    height: size.height * 0.28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(
                              0.15 + _pulseController.value * 0.12),
                          blurRadius: 60 + _pulseController.value * 20,
                          spreadRadius: 10,
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

                const SizedBox(height: 10),

                Text(
                  'Your personal expense vault',
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    color: Colors.white54,
                    letterSpacing: 1.5,
                  ),
                ),

                SizedBox(height: size.height * 0.028),

                // Feature card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.08), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'Smart finance, ',
                                          style: GoogleFonts.sora(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        TextSpan(
                                          text: 'redefined',
                                          style: GoogleFonts.sora(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFCC0020),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Track, split and grow your money\nwith AI-powered insights.',
                                    style: GoogleFonts.sora(
                                      fontSize: 12,
                                      color: Colors.white60,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFFCC0020).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: const Color(0xFFCC0020)
                                        .withOpacity(0.25),
                                    width: 1),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Color(0xFFCC0020),
                                size: 34,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildFeature(Icons.lock_rounded, '100% Secure',
                                'PIN-protected\nvault'),
                            _buildFeature(Icons.psychology_rounded, 'AI Powered',
                                'Smart insights\nfor smarter you'),
                            _buildFeature(Icons.group_rounded, 'Shared Easily',
                                'Split & settle\nwith anyone'),
                            _buildFeature(Icons.trending_up_rounded,
                                'Track Growth', 'See your money\ngrow over time'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Spacer(),

                // Get Started button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      child: ElevatedButton(
                        onPressed: _getStarted,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Get Started',
                              style: GoogleFonts.sora(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: safeBottom + 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFCC0020).withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(
                color: const Color(0xFFCC0020).withOpacity(0.25), width: 1),
          ),
          child: Icon(icon, color: const Color(0xFFCC0020), size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(
            fontSize: 9,
            color: Colors.white38,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
