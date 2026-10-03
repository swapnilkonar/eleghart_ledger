import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

import 'theme/eleghart_colors.dart';
import 'utils/app_theme.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/database_service.dart';
import 'services/live_notification_service.dart';
import 'services/recurring_engine.dart';
import 'services/shared_intent_service.dart';
import 'screens/splash_screen.dart';
import 'screens/google_login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_dashboard.dart';
import 'screens/set_pin_screen.dart';
import 'screens/pin_unlock_screen.dart';
import 'utils/image_picker_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (safely catch if config file is pending)
  try {
    await Firebase.initializeApp();
    await FcmService().initialize();
  } catch (e) {
    debugPrint('Firebase init deferred/pending google-services.json setup: $e');
  }

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
      title: 'Eleghart',
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
  bool _isGoogleLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadUserState();
  }

  Future<void> _loadUserState() async {
    final prefs = await SharedPreferences.getInstance();
    var name = prefs.getString('user_name');
    final pin = prefs.getString('user_pin_hash') ?? prefs.getString('user_pin');

    // Check Firebase Auth User (Mandatory Google Login)
    final googleUser = AuthService().currentUser;
    final isGoogleAuth = googleUser != null;

    // Check if process was killed by Android OS during ImagePicker
    final lostFile = await ImagePickerHelper.checkLostData();
    if (lostFile != null) {
      _isLostDataReturn = true;
      SharedIntentService.isUnlocked = true;
    }

    setState(() {
      _userName = name;
      _userPin = pin;
      _isGoogleLoggedIn = isGoogleAuth;
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

    // 1️⃣ Step 1: Mandatory Google Login Gate (After Splash)
    if (!_isGoogleLoggedIn) {
      return GoogleLoginScreen(
        onLoginSuccess: () async {
          _loadUserState();
        },
      );
    }

    // 2️⃣ Step 2: Ask for Name (if not set)
    if (_userName == null || _userName!.isEmpty) {
      return const OnboardingScreen();
    }

    // 3️⃣ Step 3: Ask for PIN (if not set)
    if (_userPin == null || _userPin!.isEmpty) {
      return SetPinScreen(userName: _userName!);
    }

    // 3.5️⃣ Returning from ImagePicker process recovery → bypass PIN unlock
    if (_isLostDataReturn) {
      return HomeDashboard(userName: _userName ?? 'User');
    }

    // 4️⃣ Step 4: Normal launch → Require PIN unlock ✅
    return PinUnlockScreen(userName: _userName!);
  }
}
