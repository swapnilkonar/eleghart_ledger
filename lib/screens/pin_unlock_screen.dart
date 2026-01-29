import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/eleghart_colors.dart';
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
      backgroundColor: EleghartColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(28, 16, 28, bottomInset + 16),
          child: Column(
            children: [
              // ---- BIG LOGO (RESPONSIVE TO KEYBOARD) ----
              SizedBox(
                height: keyboardOpen ? h * 0.22 : h * 0.42,
                child: Center(
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

              const SizedBox(height: 20),

              // ---- PIN SECTION ----
              const Text(
                'Enter your PIN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: EleghartColors.textPrimary,
                ),
              ),

              const SizedBox(height: 18),

              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: child,
                  );
                },
                child: Center(
                  child: SizedBox(
                    width: 230,
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
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        hintText: '• • • •',
                        hintStyle: const TextStyle(
                          letterSpacing: 14,
                          color: EleghartColors.textHint,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: _errorGlow
                                ? Colors.redAccent
                                : EleghartColors.accentDark,
                            width: 1.6,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: _errorGlow
                                ? Colors.redAccent
                                : EleghartColors.accentDark,
                            width: 2.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              TextButton(
                onPressed: _forgotPin,
                child: const Text(
                  'Forgot PIN?',
                  style: TextStyle(
                    color: EleghartColors.accentDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ---- UNLOCK BUTTON ----
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _unlocking ? null : _unlock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EleghartColors.accentDark,
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _unlocking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Unlock',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
