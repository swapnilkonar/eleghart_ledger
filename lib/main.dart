import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/eleghart_colors.dart';
import 'utils/app_theme.dart';
import 'services/database_service.dart';
import 'services/live_notification_service.dart';
import 'services/recurring_engine.dart';
import 'services/shared_intent_service.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_dashboard.dart';
import 'screens/set_pin_screen.dart';
import 'screens/pin_unlock_screen.dart';

import 'utils/image_picker_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppThemeNotifier.initialize();
  await DatabaseService.migrateFromSharedPreferences();
  await RecurringEngine.run();
  SharedIntentService.init();
  await LiveNotificationService.init();
  runApp(const EleghartLedgerApp());
}

class EleghartLedgerApp extends StatelessWidget {
  const EleghartLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: SharedIntentService.navigatorKey,
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
      home: const PremiumSplashScreen(),
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
  bool _isLostDataReturn = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserState();
  }

  Future<void> _loadUserState() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');
    final pin = prefs.getString('user_pin_hash') ?? prefs.getString('user_pin');

    // Check if process was killed by Android OS during ImagePicker
    final lostFile = await ImagePickerHelper.checkLostData();
    if (lostFile != null) {
      _isLostDataReturn = true;
      SharedIntentService.isUnlocked = true;
    }

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

    // 2.5️⃣ Returning from ImagePicker process recovery → bypass PIN unlock
    if (_isLostDataReturn) {
      return HomeDashboard(userName: _userName ?? 'User');
    }

    // 3️⃣ Normal launch → require PIN unlock ✅
    return PinUnlockScreen(userName: _userName!);
  }
}
