import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'auth_service.dart';

/// Top-level background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('Handling background message: ${message.messageId}');
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Function(Map<String, dynamic> payload)? onNotificationTap;

  /// Initialize FCM, setup notification channels, and attach listeners
  Future<void> initialize({
    Function(Map<String, dynamic> payload)? onTap,
  }) async {
    onNotificationTap = onTap;

    // Request permissions (iOS & Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission');
    }

    // Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Setup local notifications for foreground popups
    try {
      await _initLocalNotifications();
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }

    // Get current FCM token & sync to Firestore
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await AuthService().syncFcmToken(token);
      }

      // Token refresh listener
      _fcm.onTokenRefresh.listen((newToken) {
        AuthService().syncFcmToken(newToken);
      });

      // Foreground messages listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showForegroundNotification(message);
      });

      // Background notification tap (App opened from background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationClick(message.data);
      });

      // Check if app was opened from terminated state by a notification
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationClick(initialMessage.data);
      }
    } catch (e) {
      debugPrint('FCM Messaging listeners deferred/unavailable: $e');
    }
  }

  /// Initialize Flutter Local Notifications Plugin
  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (details.payload != null && details.payload!.isNotEmpty) {
          try {
            final Map<String, dynamic> data = jsonDecode(details.payload!);
            _handleNotificationClick(data);
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );

    // Create high-importance Android channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'eleghart_split_channel',
      'Split Notifications',
      description: 'Notifications for Splitwise-style group expenses and payments',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Show a Heads-Up Banner Notification when app is in foreground
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;

    if (notification != null) {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'eleghart_split_channel',
        'Split Notifications',
        channelDescription: 'Notifications for Splitwise-style group expenses and payments',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        platformDetails,
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Dispatch tap navigation payload
  void _handleNotificationClick(Map<String, dynamic> data) {
    debugPrint('Notification clicked with payload: $data');
    if (onNotificationTap != null) {
      onNotificationTap!(data);
    }
  }
}
