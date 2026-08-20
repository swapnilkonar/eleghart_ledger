import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/splitwise_storage_service.dart';
import '../services/storage_service.dart';

class LiveNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static const String _notifPrefKey = 'notifications_enabled';

  static Future<bool> isNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifPrefKey) ?? true;
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifPrefKey, enabled);
    if (!enabled) {
      await _notificationsPlugin.cancelAll();
    } else {
      await checkAndTriggerLiveAlerts();
    }
  }

  static Future<void> init() async {
    if (_isInitialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint("Notification tapped: ${details.payload}");
      },
    );

    // Request Android 13+ permission
    if (Platform.isAndroid) {
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }

    _isInitialized = true;
    checkAndTriggerLiveAlerts();
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final enabled = await isNotificationsEnabled();
    if (!enabled) return;

    const androidDetails = AndroidNotificationDetails(
      'eleghart_financial_alerts',
      'Financial Alerts & Reminders',
      channelDescription: 'Alerts for EMIs, recurring bills, and debt reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(id, title, body, notificationDetails,
        payload: payload);
  }

  static Future<void> checkAndTriggerLiveAlerts() async {
    final enabled = await isNotificationsEnabled();
    if (!enabled) return;

    try {
      final now = DateTime.now();
      final soon = now.add(const Duration(days: 3));

      // 1. EMI Due Notifications
      final emis = await StorageService.loadEmis();
      for (int i = 0; i < emis.length; i++) {
        final emi = emis[i];
        if (!emi.isCompleted && emi.nextDueDate.isBefore(soon)) {
          final days = emi.nextDueDate.difference(now).inDays;
          final timeStr = days <= 0 ? 'is due TODAY!' : 'is due in $days days';
          await showNotification(
            id: 100 + i,
            title: '💳 EMI Payment Alert',
            body: '₹${emi.amount.toStringAsFixed(0)} for ${emi.productName} $timeStr',
          );
        }
      }

      // 2. Udhaar Reminders
      final txns = await StorageService.loadUdhaarTransactions();
      final persons = await StorageService.loadPersons();
      final personMap = {for (final p in persons) p.id: p};
      final netByPerson = <String, double>{};
      for (final t in txns) {
        final sign = t.isCollection ? 1.0 : -1.0;
        netByPerson[t.personId] = (netByPerson[t.personId] ?? 0) + sign * t.amount;
      }

      int notifIndex = 200;
      for (final entry in netByPerson.entries) {
        if (entry.value > 100) {
          final person = personMap[entry.key];
          final name = person?.name ?? 'Someone';
          await showNotification(
            id: notifIndex++,
            title: '💸 Pending Debt Collection',
            body: '$name owes you ₹${entry.value.toStringAsFixed(0)}. Tap to send WhatsApp reminder.',
          );
        }
      }

      // 3. Splitwise Net Balance Alert
      final splitwiseGroups = await SplitwiseStorageService.loadGroups();
      final splitwiseExpenses = await SplitwiseStorageService.loadExpenses();
      double totalOwedToYou = 0;
      for (final g in splitwiseGroups) {
        final groupExp = splitwiseExpenses.where((e) => e.splitwiseGroupId == g.id).toList();
        for (final e in groupExp) {
          final perPerson = e.amount / g.members.length;
          for (final m in g.members) {
            if (m.toLowerCase() != 'you') {
              totalOwedToYou += perPerson;
            }
          }
        }
      }
      if (totalOwedToYou > 50) {
        await showNotification(
          id: 500,
          title: '⚖️ Eleghart Split Settlement Alert',
          body: 'Group members owe you ₹${totalOwedToYou.toStringAsFixed(0)} total across split groups.',
        );
      }
    } catch (e) {
      debugPrint("LiveNotificationService error: $e");
    }
  }

  static Future<void> sendWhatsAppReminder(String phone, String name, double amount) async {
    final text = Uri.encodeComponent(
      "Hi $name, gently reminding you about the pending balance of ₹${amount.toStringAsFixed(0)}. You can send it via UPI when convenient. Thank you! 🙏",
    );
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final url = cleanPhone.isNotEmpty
        ? Uri.parse("https://wa.me/$cleanPhone?text=$text")
        : Uri.parse("https://wa.me/?text=$text");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
