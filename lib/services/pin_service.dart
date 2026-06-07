import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinService {
  static const _pinHashKey = 'user_pin_hash';
  static const _failCountKey = 'pin_fail_count';
  static const _lockoutUntilKey = 'pin_lockout_until';
  static const _biometricEnabledKey = 'biometric_enabled';

  static const int maxAttempts = 5;
  static const int lockoutSeconds = 30;

  static final _auth = LocalAuthentication();

  // ─── Hashing ──────────────────────────────────────────────────────────────

  static String hashPin(String pin) =>
      sha256.convert(utf8.encode(pin)).toString();

  // ─── Store / verify ───────────────────────────────────────────────────────

  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinHashKey, hashPin(pin));
    await prefs.remove('user_pin');
    await prefs.setInt(_failCountKey, 0);
    await prefs.remove(_lockoutUntilKey);
  }

  static Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pinHashKey) || prefs.containsKey('user_pin');
  }

  /// Returns true if PIN is correct. Handles attempt counting + lockout.
  /// Throws [PinLockedException] when locked out.
  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();

    final lockoutUntil = prefs.getInt(_lockoutUntilKey);
    if (lockoutUntil != null) {
      final remaining =
          lockoutUntil - DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (remaining > 0) throw PinLockedException(remaining);
      await prefs.remove(_lockoutUntilKey);
      await prefs.setInt(_failCountKey, 0);
    }

    final storedHash = prefs.getString(_pinHashKey);
    bool correct;
    if (storedHash != null) {
      correct = hashPin(pin) == storedHash;
    } else {
      correct = pin == (prefs.getString('user_pin') ?? '');
      if (correct) await setPin(pin);
    }

    if (correct) {
      await prefs.setInt(_failCountKey, 0);
      return true;
    }

    final fails = (prefs.getInt(_failCountKey) ?? 0) + 1;
    await prefs.setInt(_failCountKey, fails);
    if (fails >= maxAttempts) {
      final lockUntil =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + lockoutSeconds;
      await prefs.setInt(_lockoutUntilKey, lockUntil);
      await prefs.setInt(_failCountKey, 0);
      throw PinLockedException(lockoutSeconds);
    }
    return false;
  }

  static Future<int> remainingAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final fails = prefs.getInt(_failCountKey) ?? 0;
    return maxAttempts - fails;
  }

  static Future<int?> lockoutSecondsRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutUntil = prefs.getInt(_lockoutUntilKey);
    if (lockoutUntil == null) return null;
    final remaining =
        lockoutUntil - DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return remaining > 0 ? remaining : null;
  }

  // ─── Biometrics ───────────────────────────────────────────────────────────

  static Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  static Future<bool> authenticateWithBiometric() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Eleghart Ledger',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

class PinLockedException implements Exception {
  final int secondsRemaining;
  PinLockedException(this.secondsRemaining);
}
