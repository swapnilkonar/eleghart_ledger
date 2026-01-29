import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/eleghart_colors.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_dashboard.dart';
import 'screens/set_pin_screen.dart';
import 'screens/pin_unlock_screen.dart';

void main() {
  runApp(const EleghartLedgerApp());
}

class EleghartLedgerApp extends StatelessWidget {
  const EleghartLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eleghart Ledger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: EleghartColors.bgLight,

        appBarTheme: const AppBarTheme(
          backgroundColor: EleghartColors.accentDark,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.4,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),

        cardTheme: const CardThemeData(
          color: EleghartColors.cardBg,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: EleghartColors.accentDark,
        ),
      ),
      home: const AppEntryGate(),
    );
  }
}

class AppEntryGate extends StatefulWidget {
  const AppEntryGate({super.key});

  @override
  State<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<AppEntryGate> {
  String? _userName;
  String? _userPin;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserState();
  }

  Future<void> _loadUserState() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');
    final pin = prefs.getString('user_pin');

    setState(() {
      _userName = name;
      _userPin = pin;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 1️⃣ First launch → ask name
    if (_userName == null || _userName!.isEmpty) {
      return const OnboardingScreen();
    }

    // 2️⃣ Name exists but PIN not set yet
    if (_userPin == null || _userPin!.isEmpty) {
      return SetPinScreen(userName: _userName!);
    }

    // 3️⃣ Normal launch → require PIN unlock ✅
    return PinUnlockScreen(userName: _userName!);
  }
}
