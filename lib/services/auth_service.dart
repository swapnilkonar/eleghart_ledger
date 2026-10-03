import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (e) {
      debugPrint('Firebase Auth not ready: $e');
      return null;
    }
  }

  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (e) {
      return Stream.value(null);
    }
  }

  /// Sign in with Google Auth & register user + device in Firestore
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Cancelled by user

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        await _recordUserAndDevice(user);
      }

      return userCredential;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Record or update User document and Device document in Firestore
  Future<void> _recordUserAndDevice(User user) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userRef.get();

      final now = DateTime.now().toIso8601String();

      if (!userDoc.exists) {
        // Initialize new user profile with default Subscription & Preferences
        await userRef.set({
          'userId': user.uid,
          'name': user.displayName ?? 'User',
          'email': user.email ?? '',
          'photoUrl': user.photoURL ?? '',
          'createdAt': now,
          'lastLoginAt': now,
          'activeDeviceCount': 1,
          'fcmTokens': [],
          'subscription': {
            'tier': 'free', // 'free', 'pro', 'enterprise'
            'status': 'active',
            'validUntil': null,
            'maxGroupsAllowed': 5,
            'maxMembersPerGroup': 10,
          },
          'preferences': {
            'splitNotifications': true,
            'expenseAddedNotif': true,
            'expenseUpdatedNotif': true,
            'expenseDeletedNotif': true,
            'paymentNotif': true,
          },
        });
      } else {
        // Update existing user profile & auto-sync paid tier limits
        final data = userDoc.data();
        Map<dynamic, dynamic>? sub;
        if (data != null && data['subscription'] is Map) {
          sub = data['subscription'] as Map;
        }

        final rawTier = (sub?['tier'] ?? data?['tier'] ?? data?['subscription_tier'] ?? 'free').toString().toLowerCase().trim();
        final isPaid = rawTier == 'paid' || rawTier == 'pro' || rawTier == 'premium' || rawTier == 'enterprise';

        final Map<String, dynamic> updates = {
          'name': user.displayName ?? 'User',
          'email': user.email ?? '',
          'photoUrl': user.photoURL ?? '',
          'lastLoginAt': now,
        };

        await userRef.set(updates, SetOptions(merge: true));

        if (isPaid) {
          await userRef.set({
            'subscription': {
              'tier': rawTier,
              'status': sub?['status'] ?? 'active',
              'validUntil': sub?['validUntil'],
              'maxGroupsAllowed': 999999,
              'maxMembersPerGroup': 999999,
            }
          }, SetOptions(merge: true));
        }
      }

      // Register device info
      await _registerDevice(user.uid);

      // Start real-time subscription listener
      startSubscriptionTierListener();
    } catch (e) {
      debugPrint('Error recording user and device: $e');
    }
  }

  StreamSubscription<DocumentSnapshot>? _subscriptionListener;

  /// Start real-time Firestore listener for live subscription tier changes
  void startSubscriptionTierListener() {
    final user = currentUser;
    if (user == null) return;

    _subscriptionListener?.cancel();
    _subscriptionListener = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) async {
      try {
        if (!snapshot.exists) return;

        final data = snapshot.data();
        if (data == null) return;

        Map<dynamic, dynamic>? sub;
        if (data['subscription'] is Map) {
          sub = data['subscription'] as Map;
        }

        final rawTier = (sub?['tier'] ?? data['tier'] ?? data['subscription_tier'] ?? 'free').toString().toLowerCase().trim();
        final isPaid = rawTier == 'paid' || rawTier == 'pro' || rawTier == 'premium' || rawTier == 'enterprise';

        final maxGroups = sub?['maxGroupsAllowed'];
        final maxMembers = sub?['maxMembersPerGroup'];

        // If tier is set to paid in Firestore Console, automatically update max fields in Firestore live!
        if (isPaid && (maxGroups != 999999 || maxMembers != 999999)) {
          await _firestore.collection('users').doc(user.uid).set({
            'subscription': {
              'tier': rawTier,
              'status': sub?['status'] ?? 'active',
              'validUntil': sub?['validUntil'],
              'maxGroupsAllowed': 999999,
              'maxMembersPerGroup': 999999,
            }
          }, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('Error in subscription tier listener: $e');
      }
    });
  }

  /// Check if user has Paid / Premium Tier access (Unlimited App Access)
  Future<bool> isPaidUser() async {
    final user = currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      Map<dynamic, dynamic>? sub;
      if (data['subscription'] is Map) {
        sub = data['subscription'] as Map;
      }

      final rawTier = (sub?['tier'] ?? data['tier'] ?? data['subscription_tier'] ?? 'free').toString().toLowerCase().trim();
      return rawTier == 'paid' || rawTier == 'pro' || rawTier == 'premium' || rawTier == 'enterprise';
    } catch (e) {
      debugPrint('Error checking user tier: $e');
      return false;
    }
  }

  /// Update user tier in Firestore (e.g. set to 'paid' for full unlimited access)
  Future<void> setUserTier(String userId, String tier) async {
    try {
      final isPaid = tier.toLowerCase() == 'paid' ||
          tier.toLowerCase() == 'pro' ||
          tier.toLowerCase() == 'premium' ||
          tier.toLowerCase() == 'enterprise';

      await _firestore.collection('users').doc(userId).set({
        'tier': tier,
        'subscription': {
          'tier': tier,
          'status': 'active',
          'maxGroupsAllowed': isPaid ? 999999 : 5,
          'maxMembersPerGroup': isPaid ? 999999 : 10,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error setting user tier: $e');
    }
  }

  /// Registers or updates current device details under `users/{userId}/devices/{deviceId}`
  Future<void> _registerDevice(String userId) async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = 'unknown_device';
      String deviceModel = 'Unknown Device';
      String os = 'Unknown OS';
      String osVersion = '';

      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceId = 'web_${webInfo.userAgent.hashCode}';
        deviceModel = webInfo.browserName.name;
        os = 'Web';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
        os = 'Android';
        osVersion = androidInfo.version.release;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'ios_device';
        deviceModel = iosInfo.utsname.machine;
        os = 'iOS';
        osVersion = iosInfo.systemVersion;
      }

      final deviceRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(deviceId);

      final deviceDoc = await deviceRef.get();
      final now = DateTime.now().toIso8601String();

      if (!deviceDoc.exists) {
        await deviceRef.set({
          'deviceId': deviceId,
          'deviceModel': deviceModel,
          'os': os,
          'osVersion': osVersion,
          'appVersion': '1.1.0+2',
          'firstLoginAt': now,
          'lastActiveAt': now,
          'isCurrentDevice': true,
        });
      } else {
        await deviceRef.update({
          'deviceModel': deviceModel,
          'osVersion': osVersion,
          'lastActiveAt': now,
          'isCurrentDevice': true,
        });
      }
    } catch (e) {
      debugPrint('Error registering device: $e');
    }
  }

  /// Sync user FCM token to Firestore
  Future<void> syncFcmToken(String token) async {
    final user = currentUser;
    if (user == null || token.isEmpty) return;

    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      await userRef.update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (e) {
      debugPrint('Error syncing FCM token: $e');
    }
  }
}
