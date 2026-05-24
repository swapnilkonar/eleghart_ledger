import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeNotifier {
  static const _key = 'is_white_theme';
  static final ValueNotifier<bool> instance = ValueNotifier<bool>(false);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    instance.value = prefs.getBool(_key) ?? false;
  }

  static Future<void> toggle() async {
    instance.value = !instance.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, instance.value);
  }

  static bool get isWhite => instance.value;
}
