import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/eleghart_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/themed_background.dart';

class GoogleLoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const GoogleLoginScreen({
    super.key,
    required this.onLoginSuccess,
  });

  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _errorMessage;
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

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await AuthService().signInWithGoogle();
      if (credential != null) {
        widget.onLoginSuccess();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Google Sign-In failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textSec = isWhite
        ? EleghartColors.accentDark.withValues(alpha: 0.5)
        : Colors.white54;
    final cardBg = isWhite ? Colors.white : Colors.white.withValues(alpha: 0.05);
    final cardBorder =
        isWhite ? const Color(0xFFEEEEEE) : Colors.white.withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: isWhite ? Colors.white : Colors.black,
      body: Stack(
        children: [
          // Background image
          const Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.40)),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    SizedBox(height: size.height * 0.02),

                    // Logo with pulsing glow
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, child) => Container(
                        height: size.height * 0.25,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(
                                  alpha: (isWhite ? 0.08 : 0.15) +
                                      _pulseController.value * 0.10),
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

                    const SizedBox(height: 8),

                    Text(
                      'Your personal expense vault',
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        color: textSec,
                        letterSpacing: 1.5,
                      ),
                    ),

                    SizedBox(height: size.height * 0.025),

                    // Feature card
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cardBorder, width: 1),
                        boxShadow: isWhite
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
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
                                              color: textPrimary,
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
                                        color: textSec,
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
                                      const Color(0xFFCC0020).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFFCC0020)
                                          .withValues(alpha: 0.25),
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

                    const SizedBox(height: 28),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ─── Google Sign-In Button (Elevated Position & Custom G Icon) ───
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleGoogleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF3C4043),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF3C4043),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Official Google G Logo
                                    Image.network(
                                      'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                                      height: 24,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(
                                        Icons.g_mobiledata_rounded,
                                        size: 32,
                                        color: Color(0xFF4285F4),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Text(
                                      'Continue with Google',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF3C4043),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String subtitle) {
    final isWhite = AppThemeNotifier.isWhite;
    final textPrimary = isWhite ? EleghartColors.accentDark : Colors.white;
    final textMuted = isWhite
        ? EleghartColors.accentDark.withValues(alpha: 0.38)
        : Colors.white38;
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFCC0020).withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
                color: const Color(0xFFCC0020).withValues(alpha: 0.25), width: 1),
          ),
          child: Icon(icon, color: const Color(0xFFCC0020), size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(
            fontSize: 9,
            color: textMuted,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
