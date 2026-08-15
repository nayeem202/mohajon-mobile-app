import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notifications/models/notification_model.dart';
import '../../features/notifications/providers/notification_providers.dart';
import '../app/app_providers.dart';
import 'api_client.dart';
import '../../firebase_options.dart';
import 'notification_preferences.dart';

/// Entry point used by Android/iOS when an FCM message arrives in the
/// background or after the app has been terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase native config is supplied by `flutterfire configure`. Until
    // then, a missing config must not prevent the app from starting.
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) => FcmService(ref));

class FcmService {
  FcmService(this._ref);

  final Ref _ref;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  Future<void>? _initializing;
  String? _registeredToken;

  Future<void> initialize() {
    return _initializing ??= _initialize().whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initialize() async {
    if (kIsWeb) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (!isNotificationPushEnabled()) {
        if (token != null) await _disableToken(token);
        return;
      }
      if (token != null) await _registerToken(token);
      await _tokenSubscription?.cancel();
      _tokenSubscription = messaging.onTokenRefresh.listen(_registerToken);
      await _messageSubscription?.cancel();
      _messageSubscription = FirebaseMessaging.onMessage.listen(_showInApp);
    } catch (error) {
      debugPrint('FCM is not configured yet: $error');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    await setNotificationPushEnabled(enabled);
    if (enabled) {
      await initialize();
      return;
    }
    try {
      if (Firebase.apps.isEmpty) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _disableToken(token);
    } catch (error) {
      debugPrint('Could not disable FCM token: $error');
    }
  }

  /// Rebinds the current device token to the newly signed-in account. The
  /// FCM token can stay identical across logout/login, but its shop/user
  /// ownership must still be updated on the backend.
  Future<void> refreshRegistration() async {
    if (kIsWeb || !isNotificationPushEnabled()) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      _registeredToken = null;
      await _registerToken(token);
      await syncPreferences();
    } catch (error) {
      debugPrint('FCM account registration refresh failed: $error');
    }
  }

  Future<void> _disableToken(String token) {
    return ApiClient(_ref.read(localDatabaseProvider)).post(
      '/api/v1/notifications/devices/disable',
      {'token': token},
    );
  }

  Future<void> _registerToken(String token) async {
    if (token.isEmpty || token == _registeredToken) return;
    try {
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
      await ApiClient(_ref.read(localDatabaseProvider)).post(
        '/api/v1/notifications/devices',
        {
          'token': token,
          'platform': platform,
          'enabledTypes': enabledNotificationTypeKeys(),
        },
      );
      _registeredToken = token;
    } catch (error) {
      debugPrint('FCM token registration failed: $error');
    }
  }

  Future<void> syncPreferences() async {
    if (!isNotificationPushEnabled() || kIsWeb) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await ApiClient(_ref.read(localDatabaseProvider)).post(
        '/api/v1/notifications/devices/preferences',
        {'token': token, 'enabledTypes': enabledNotificationTypeKeys()},
      );
    } catch (error) {
      debugPrint('FCM preference sync failed: $error');
    }
  }

  void _showInApp(RemoteMessage message) {
    if (!isNotificationPushEnabled()) return;
    final typeName = message.data['type']?.toString();
    final type = NotificationType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => NotificationType.platform,
    );
    if (!isNotificationTypeEnabled(type)) return;
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null || body == null) return;
    final category = type == NotificationType.platform ||
            type == NotificationType.system
        ? NotificationCategory.platform
        : NotificationCategory.shop;
    _ref.read(notificationServiceProvider).add(
          type: type,
          category: category,
          title: title,
          message: body,
          senderUserId: message.data['senderUserId']?.toString(),
          sourceKey: message.data['notificationId'] != null
              ? 'server:${message.data['notificationId']}'
              : 'fcm:${message.messageId ?? message.sentTime}',
        );
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
  }
}
