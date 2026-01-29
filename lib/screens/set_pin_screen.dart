import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/eleghart_colors.dart';
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
                'Set a 4-digit PIN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: EleghartColors.textPrimary,
                ),
              ),

              const SizedBox(height: 18),

              _pinRow(_pinController, label: 'Enter PIN'),
              const SizedBox(height: 14),
              _pinRow(_confirmController, label: 'Confirm PIN'),

              const SizedBox(height: 24),

              // ---- CONTINUE BUTTON ----
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _saving ? null : _savePin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EleghartColors.accentDark,
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Continue',
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

  Widget _pinRow(TextEditingController controller, {required String label}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: EleghartColors.textSecondary,
        ),
      ),
      const SizedBox(height: 10),
      Center(
        child: SizedBox(
          width: 230,
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
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: EleghartColors.accentDark,
                  width: 1.6,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: EleghartColors.accentDark,
                  width: 2.2,
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
