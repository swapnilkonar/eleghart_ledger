import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/eleghart_colors.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';
import 'home_dashboard.dart';

class SetPinScreen extends StatefulWidget {
  final String userName;
  const SetPinScreen({super.key, required this.userName});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;

  Future<void> _savePin() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pin.length != 4 || confirm.length != 4) {
      _toast('PIN must be exactly 4 digits');
      return;
    }

    if (pin != confirm) {
      _toast('PINs do not match');
      return;
    }

    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_pin', pin);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeDashboard(userName: widget.userName),
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
      backgroundColor: EleghartColors.bgLight,
      body: SafeArea(
        child: Stack(
          children: [
            // Background effects
            Positioned(
              top: -100,
              right: -80,
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
                            child: Transform.scale(
                              scale: 0.7 + (value * 0.3),
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
                          );
                        },
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
                            'Set a 4-digit PIN',
                            style: GlassTheme.headingSmall.copyWith(
                              fontSize: 20,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  _pinRow(_pinController, label: 'Enter PIN', index: 0),
                  const SizedBox(height: 18),
                  _pinRow(_confirmController, label: 'Confirm PIN', index: 1),

                  const SizedBox(height: 28),

                  // Continue button
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
                              label: 'Continue',
                              icon: Icons.arrow_forward,
                              onPressed: _saving ? () {} : _savePin,
                              isLoading: _saving,
                              borderRadius: 20,
                            ),
                          ),
                        ),
                      );
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

  Widget _pinRow(
    TextEditingController controller, {
    required String label,
    required int index,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(30 * (1 - value), 0),
          child: Opacity(
            opacity: value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GlassTheme.label.copyWith(
                    color: EleghartColors.textSecondary,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: SizedBox(
                    width: 230,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.white.withOpacity(0.15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: TextField(
                            controller: controller,
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
                                color: EleghartColors.textHint.withOpacity(0.4),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
